//
//  SpringBoardOverlay.m — SpringBoard overlay via remote_objc
//
//  SINGLE-LAYER vector mirror (fast): all 16 ESP paths (box/bone/line/hp/
//  fov/aim) are merged into ONE local CGMutablePath, serialized once, then
//  rebuilt in ONE remote CGMutablePath in SpringBoard. 1 setPath per frame
//  (was 16) → ~5 remote calls/frame → ~20fps, no lag.
//
//  Window: scene-attached UIWindow + status UILabel, retained via
//  objc_setAssociatedObject. CFRelease for ObjC, remote malloc for point
//  buffers (never pass local pointers — that respringed before).
//
#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>

// Cyanide's statbar level (999999) — proven safe. 10,000,000 + makeKeyAndVisible
// crashed SpringBoard → respring right after overlay init. Still above every app.
#define SB_OVERLAY_WIN_LEVEL 999999.0

static BOOL g_sbOverlayOn = NO;
static uint64_t g_sbWin = 0;
static uint64_t g_sbShape = 0;      // single CAShapeLayer (Fl0rk geometry layer)
static uint64_t g_sbCanvas = 0;     // dedicated UIView hosting the shape layer
static uint64_t g_sbOldPath = 0;
static uint32_t g_sbPathHash = 0;
static int g_sbSettleWas = 50000;
static int g_sbMirrorCount = 0;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

// Fl0rk DrawView pattern: cached NSInvocation for the ONE setPath: call we
// make per sync. Built ONCE at init; every frame we only CGPathAddLines into
// the persistent path and re-invoke the cached invocation (via
// performSelectorOnMainThread). No per-frame NSInvocation build/release —
// that churn raced SB's main thread (SIGBUS 0x401 crashes).
static uint64_t g_sbSetPathInvocation = 0;

// Per-SB-session mirror state (forward declarations — SBoardStartOverlay
// resets these at the end of init; definitions live below).
static uint64_t g_sbPersistentPath = 0;
static uint64_t g_sbMirrorPtsBuf = 0;
static void sb_reset_mirror_state(void);
static uint64_t persistentPath(void);

static const char *kShapeKeys[16] = {
    "boxLayer", "boxBotLayer", "boxKnockedLayer",
    "boneLayer", "boneBotLayer", "boneKnockedLayer",
    "snaplineLayer", "snaplineBotLayer", "snaplineKnockedLayer",
    "hpFillGreenLayer", "hpFillOrangeLayer", "hpFillRedLayer",
    "bgFillBlackLayer", "alertLayer", "fovLayer", "aimAssistLayer"
};

// ---- helpers ----
static uint64_t dbl_bits(double d) { uint64_t v; memcpy(&v, &d, 8); return v; }

static uint64_t dlsym(const char *fn, uint64_t a0, uint64_t a1, uint64_t a2,
                      uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    return r_dlsym_call(R_TIMEOUT, fn, a0,a1,a2,a3,a4,a5,a6,a7);
}

// lara freakyperform: dispatch a 1-arg selector onto the SB MAIN THREAD.
// CoreAnimation in SpringBoard asserts all layer-tree mutations happen on
// the main thread (CA_ASSERT_MAIN_THREAD_TRANSACTIONS — the addSublayer
// crash). r_msg2_main + performOnMain is the only safe route.
static void sb_perform_main(uint64_t target, const char *selName, uint64_t arg) {
    if (!r_is_objc_ptr(target)) return;
    uint64_t sel = r_sel(selName);
    uint64_t performSel = r_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    if (!sel || !performSel) return;
    r_msg(target, performSel, sel, arg, 0, 0); // wait=0 — async, never blocks
}

// CGPathApply needs a C function pointer.
typedef struct { NSMutableData *data; } SerCtx;
static void serFunc(void *info, const CGPathElement *e) {
    SerCtx *ctx = (SerCtx *)info;
    if (e->type == kCGPathElementCloseSubpath) return;
    uint8_t op = (e->type == kCGPathElementMoveToPoint) ? 1 : 2;
    [ctx->data appendBytes:&op length:1];
    if (e->type == kCGPathElementMoveToPoint || e->type == kCGPathElementAddLineToPoint) {
        [ctx->data appendBytes:&e->points[0] length:16];
    } else {
        int n = (e->type == kCGPathElementAddQuadCurveToPoint) ? 1 : 2;
        [ctx->data appendBytes:&e->points[n] length:16];
    }
}

// Merge all ESP_View shape-layer paths into one serialized stream.
// Returns YES if content changed (FNV hash).
static BOOL mergePaths(UIView *espView, NSMutableData *d) {
    [d setLength:0];
    CGMutablePathRef merged = CGPathCreateMutable();
    if (!merged) return NO;
    for (int i = 0; i < 16; i++) {
        id val = [espView valueForKey:[NSString stringWithUTF8String:kShapeKeys[i]]];
        if ([val isKindOfClass:[CAShapeLayer class]]) {
            CGPathRef p = ((CAShapeLayer *)val).path;
            if (p && !CGPathIsEmpty(p)) CGPathAddPath(merged, NULL, p);
        }
    }
    if (CGPathIsEmpty(merged)) { CGPathRelease(merged); return NO; }
    SerCtx ctx = { .data = d };
    CGPathApply(merged, &ctx, serFunc);
    CGPathRelease(merged);

    uint32_t h = 2166136261u;
    for (NSUInteger i = 0; i < d.length; i++) {
        h ^= ((const uint8_t *)d.bytes)[i]; h *= 16777619u;
    }
    if (h == g_sbPathHash) return NO;
    g_sbPathHash = h;
    return YES;
}

// Replay ops into a remote CGMutablePath. Points buffer is REMOTE malloc.
static void replayRemote(uint64_t rp, const uint8_t *ops, size_t len) {
    uint64_t buf = dlsym("malloc", 4096, 0,0,0,0,0,0,0);
    if (!r_is_objc_ptr(buf)) return;
    double pts[256];
    size_t i = 0; int n = 0;
    while (i < len && n < 254) {
        uint8_t op = ops[i++];
        if (i + 16 > len) break;
        double x, y; memcpy(&x, ops+i, 8); memcpy(&y, ops+i+8, 8); i += 16;
        if (op == 1) {
            if (n > 0) {
                remote_write(buf, pts, n*16);
                dlsym("CGPathAddLines", rp, 0, buf, n, 0,0,0,0);
                n = 0;
            }
            dlsym("CGPathMoveToPoint", rp, 0, dbl_bits(x), dbl_bits(y), 0,0,0,0);
        } else {
            pts[n*2] = x; pts[n*2+1] = y; n++;
        }
    }
    if (n > 0) {
        remote_write(buf, pts, n*16);
        dlsym("CGPathAddLines", rp, 0, buf, n, 0,0,0,0);
    }
    dlsym("free", buf, 0,0,0,0,0,0,0);
}

// ======================== public ========================

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    if (!g_kexploit_ready) return -1;

    g_sbSettleWas = r_settle_us(5000); // 5ms per call — 10x faster than default 50ms, safe

    NSLog(@"[SBOverlay] init remote call into SpringBoard (15s timeout)...");
    // 15s: the MIG exception handshake with a busy SpringBoard can take >5s.
    // 5s was too aggressive → overlay init failed → always fell back to
    // DirectOverlay ("ESP only in-app"). Parallel startup keeps UI unblocked.
    // cyanide statbar uses init_remote_call("SpringBoard", false) — NO MIG
    // filter bypass. MIG bypass (true) injects extra threads + hijacks SB's
    // exception ports = deep intrusion = SpringBoard death → respring.
    // Plain init keeps the channel shallow and stable.
    int rc = init_remote_call("SpringBoard", false);
    if (rc != 0) return -1;
    uint64_t pid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    if (pid == 0) { destroy_remote_call(); return -1; }

    // ---- lara freakywindow pattern: NO new window! ----
    // lara (same kexploit family) draws its overlays by addSubview'ing into
    // the EXISTING SpringBoard keyWindow — the live render tree that already
    // composites 60fps. Every window we created ourselves failed to render
    // bare CAShapeLayers (no backing allocation for a fresh window we inject
    // into remotely). Subclass registration via remote also corrupts SB's
    // ObjC runtime (os_unfair_lock corrupt crash). Use the existing window.
    uint64_t app = r_msg2_main(r_class("UIApplication"), "sharedApplication", 0,0,0,0);
    if (!r_is_objc_ptr(app)) { destroy_remote_call(); return -1; }
    uint64_t win = r_msg2_main(app, "keyWindow", 0,0,0,0);
    if (!r_is_objc_ptr(win)) {
        uint64_t ws = r_msg2_main(app, "windows", 0,0,0,0);
        uint64_t n = r_is_objc_ptr(ws) ? r_msg2_main(ws, "count", 0,0,0,0) : 0;
        if (n > 0 && n < 64) win = r_msg2_main(ws, "objectAtIndex:", 0,0,0,0);
    }
    if (!r_is_objc_ptr(win)) { NSLog(@"[SBOverlay] no SB window found"); destroy_remote_call(); return -1; }
    NSLog(@"[SBOverlay] using EXISTING SB keyWindow (lara pattern)");

    double bounds[4] = {0,0,390,844};
    uint64_t clsScr = r_class("UIScreen");
    if (r_is_objc_ptr(clsScr)) {
        r_msg2_main_struct_ret(r_msg2_main(clsScr, "mainScreen", 0,0,0,0),
                               "bounds", bounds, 32, NULL,0,NULL,0,NULL,0,NULL,0);
    }
    uint64_t clsCol = r_class("UIColor");
    uint64_t clear = r_is_objc_ptr(clsCol) ? r_msg2_main(clsCol, "clearColor", 0,0,0,0) : 0;

    // ---- colors: SEPARATE UIColor vs CGColor — CRASH FIX ----
    // UILabel.setTextColor:/setBackgroundColor: take UIColor objects.
    // CAShapeLayer.setStrokeColor:/setFillColor: take CGColorRefs.
    // Passing a CGColor to setTextColor: → UILabel calls _isDynamic on
    // __NSCFType → NSInvalidArgumentException → SpringBoard abort → respring
    // ~1s after init (exactly the crash log: -[UILabel _resolveMaterialColor:]).
    uint64_t whiteUIColor = 0, whiteCGColor = 0; // blackUIColor removed với banner
    if (r_is_objc_ptr(clsCol)) {
        whiteUIColor = r_msg2_main(clsCol, "whiteColor", 0,0,0,0);
        if (r_is_objc_ptr(whiteUIColor)) whiteCGColor = r_msg2_main(whiteUIColor, "CGColor", 0,0,0,0);
    }
    // ---- container UIView (cyanide pattern: window MUST have a UIView
    //      subview to be composited; bare CALayers on window.layer are
    //      not guaranteed to render). ----
    uint64_t container = r_msg2_main_raw(r_msg2_main(r_class("UIView"), "alloc", 0,0,0,0),
                                         "initWithFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    if (!r_is_objc_ptr(container)) { destroy_remote_call(); return -1; }
    if (r_is_objc_ptr(clear)) r_msg2_main(container, "setBackgroundColor:", clear, 0,0,0);
    r_msg2_main(container, "setUserInteractionEnabled:", 0, 0,0,0);
    r_msg2_main(container, "setOpaque:", 0, 0,0,0);

    uint64_t shape = r_msg2_main(r_class("CAShapeLayer"), "layer", 0,0,0,0);
    if (!r_is_objc_ptr(shape)) { destroy_remote_call(); return -1; }
    r_msg2_main_raw(shape, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    if (r_is_objc_ptr(whiteCGColor)) r_msg2_main(shape, "setStrokeColor:", whiteCGColor, 0,0,0);
    r_msg2_main(shape, "setFillColor:", 0, 0,0,0);
    double lw = 1.5;
    r_msg2_main_raw(shape, "setLineWidth:", &lw, 8, NULL,0,NULL,0,NULL,0);
    r_msg2_main(shape, "setOpaque:", 0, 0,0,0);
    double z = 100;
    r_msg2_main_raw(shape, "setZPosition:", &z, 8, NULL,0,NULL,0,NULL,0);

    // ---- SELF-TEST line REMOVED (user: banner đen + V shape hiển thị trên màn) ----
    // Debug stroke này từng dùng để verify compositing; giờ mirror đã ổn nên bỏ.


    // ---- status UILabel: HOST-ONLY cho shape layer (user: xoá banner đen chữ) ----
    // Label vẫn cần để composite (bare CALayer trên window không đảm bảo render)
    // nhưng không chữ, không nền đen, không chặn touch.
    uint64_t label = r_msg2_main(r_msg2_main(r_class("UILabel"), "alloc", 0,0,0,0), "init", 0,0,0,0);
    if (r_is_objc_ptr(label)) {
        double lf[4] = {0, 0, bounds[2], 60};
        r_msg2_main_raw(label, "setFrame:", lf, 32, NULL,0,NULL,0,NULL,0);
        r_msg2_main(label, "setNumberOfLines:", 1, 0,0,0);
        r_msg2_main(label, "setTextAlignment:", 1, 0,0,0);
        if (r_is_objc_ptr(clear)) r_msg2_main(label, "setBackgroundColor:", clear, 0,0,0);
        sb_perform_main(container, "addSubview:", label);

        // VECTOR ATTEMPT 4: add the shape layer as a SUBLAYER OF THE BANNER
        // UILabel's layer — a view that DEFINITELY renders. If the V now
        // shows inside the banner area, shape layers render fine when
        // attached to a live-backed view → the fix is hosting geometry on
        // a rendering view, not on bare windows/containers.
        uint64_t labelLayer = r_msg2_main(label, "layer", 0,0,0,0);
        if (r_is_objc_ptr(labelLayer)) {
            double shf[4] = {0.0, 0.0, bounds[2], bounds[3]}; // extend beyond banner vertically
            r_msg2_main_raw(shape, "setFrame:", shf, 32, NULL,0,NULL,0,NULL,0);
            sb_perform_main(labelLayer, "addSublayer:", shape);
            r_msg2_main(shape, "setMasksToBounds:", 0, 0,0,0); // label doesn't clip
            NSLog(@"[SBOverlay] VECTOR ATTEMPT 4: shape attached to banner label layer");
        }
    }

    // ---- SELF-TEST #3 REMOVED (user: hình vuông đỏ hiển thị trên màn) ----
    // Debug UIImageView + red square từng dùng để verify image mirror; bỏ.

    // lara pattern: container onto the EXISTING SB keyWindow — but via
    // sb_perform_main (CA main-thread assertion!) — never direct.
    sb_perform_main(win, "addSubview:", container);
    sb_perform_main(win, "bringSubviewToFront:", container);
    g_sbShape = shape;

    // retain container via associated object on the app (lara keeps remote
    // refs alive the same way through its tag/lookup; ours needs a ref root)
    uint64_t key = r_sel("minhducSBOverlayWindow");
    if (r_is_objc_ptr(key)) dlsym("objc_setAssociatedObject", app, key, container, 1, 0,0,0,0);

    pthread_mutex_lock(&g_sbLock);
    g_sbWin = win;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    // RESET persistent mirror state — a NEW SpringBoard process means the
    // old remote path/point-buffer addresses are dangling pointers into a
    // dead address space (2nd boot: CGPathClear on stale addr = silent
    // mirror crash → banner visible but ESP never draws). Re-create lazily.
    g_sbPersistentPath = 0;
    sb_reset_mirror_state();

    // ---- Build the CACHED setPath: NSInvocation (Fl0rk
    // _gDrawViewGeometryPathInvocation). Built ONCE per SB session,
    // targeting the shape layer with the persistent path as argument.
    // Every mirror sync just re-fires it (performSelectorOnMainThread).
    {
        uint64_t rp = persistentPath();
        if (r_is_objc_ptr(rp) && r_is_objc_ptr(shape)) {
            uint64_t clsShape = r_class("CAShapeLayer");
            uint64_t sigSel = r_sel("methodSignatureForSelector:");
            uint64_t setPathSel = r_sel("setPath:");
            uint64_t sig = r_msg(clsShape, sigSel, setPathSel, 0, 0, 0);
            if (r_is_objc_ptr(sig)) {
                uint64_t clsInv = r_class("NSInvocation");
                uint64_t inv = r_msg2_main(clsInv, "invocationWithMethodSignature:", sig, 0,0,0);
                if (r_is_objc_ptr(inv)) {
                    r_msg2_main(inv, "setTarget:", shape, 0,0,0);
                    r_msg2_main(inv, "setSelector:", setPathSel, 0,0,0);
                    // argument 2 = the CGPathRef (persistent — lives as long
                    // as the session; retained by the layer on each invoke)
                    uint64_t argBuf = dlsym("malloc", 8, 0,0,0,0,0,0,0);
                    if (r_is_objc_ptr(argBuf)) {
                        remote_write64(argBuf, rp);
                        r_msg2_main(inv, "setArgument:atIndex:", argBuf, 2, 0,0);
                        dlsym("free", argBuf, 0,0,0,0,0,0,0);
                    }
                    r_msg2_main(inv, "retainArguments", 0,0,0,0);
                    g_sbSetPathInvocation = inv;
                }
            }
        }
    }

    NSLog(@"[SBOverlay] vector overlay ACTIVE (canvas %s, cached invocation %s)",
          r_is_objc_ptr(g_sbCanvas) ? "OK" : "NO",
          r_is_objc_ptr(g_sbSetPathInvocation) ? "OK" : "fallback");
    return 0;
}

// Persistent remote path — created ONCE per SB session, emptied per sync
// (CGPathClear), never destroyed. Fl0rk DrawView pattern. Invalidated on
// every SBoardStartOverlay (new SB process = new address space).

static uint64_t persistentPath(void) {
    if (r_is_objc_ptr(g_sbPersistentPath)) return g_sbPersistentPath;
    g_sbPersistentPath = dlsym("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
    return g_sbPersistentPath;
}

static void sb_reset_mirror_state(void) {
    // per-SB-session caches — stale across sessions (new SB = new addrs)
    g_sbPersistentPath = 0;
    g_sbMirrorPtsBuf = 0;
    g_sbPathHash = 0;
    g_sbMirrorCount = 0;
    g_sbSetPathInvocation = 0;
}

void SBRemotePushESPFrame(UIView *espView) {
    if (!g_sbOverlayOn || !espView) return;
    if (++g_sbMirrorCount % 6 != 0) return;

    static NSMutableData *ops = nil;
    if (!ops) ops = [NSMutableData dataWithCapacity:8192];

    if (!mergePaths(espView, ops)) return; // unchanged → 0 remote calls

    static int s_remoteBusy = 0;
    if (__sync_lock_test_and_set(&s_remoteBusy, 1)) {
        return; // Drop frame if previous remote call is still in flight (prevents 0x401 race)
    }

    NSData *frameBytes = [ops copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try {
            uint64_t rp = persistentPath();
            if (!r_is_objc_ptr(rp)) return;

            uint64_t ptsBuf = g_sbMirrorPtsBuf;
            if (!r_is_objc_ptr(ptsBuf)) {
                ptsBuf = dlsym("malloc", 65536, 0,0,0,0,0,0,0); // 4096 points
                if (!r_is_objc_ptr(ptsBuf)) return;
                g_sbMirrorPtsBuf = ptsBuf;
            }

            size_t len = frameBytes.length;
            const uint8_t *b = (const uint8_t *)frameBytes.bytes;

            double pts[4096];
            int n = 0;
            double lastX = 0, lastY = 0;
            BOOL haveLast = NO;
            BOOL havePrevEnd = NO;
            size_t i = 0;
            while (i < len && n < 4090) {
                uint8_t op = b[i++];
                if (i + 16 > len) break;
                double x, y; memcpy(&x, b+i, 8); memcpy(&y, b+i+8, 8); i += 16;
                if (op == 1) { // moveTo → sub-path break
                    if (n > 0 && havePrevEnd) {
                        pts[n++] = lastX; pts[n++] = lastY;
                    }
                    lastX = x; lastY = y; haveLast = YES;
                } else {       // lineTo from last point
                    if (!haveLast) { lastX = x; lastY = y; haveLast = YES; havePrevEnd = NO; continue; }
                    if (n == 0) {
                        pts[n++] = lastX; pts[n++] = lastY;
                    }
                    pts[n++] = x; pts[n++] = y;
                    lastX = x; lastY = y;
                    havePrevEnd = YES;
                }
            }

            if (n >= 2) {
                remote_write(ptsBuf, pts, n * 8);
                dlsym("CGPathClear", rp, 0,0,0,0,0,0,0);
                dlsym("CGPathAddLines", rp, 0, ptsBuf, n / 2, 0,0,0,0);
            }

            if (r_is_objc_ptr(g_sbSetPathInvocation)) {
                uint64_t performSel = r_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
                uint64_t invokeSel = r_sel("invoke");
                if (performSel && invokeSel) {
                    r_msg(g_sbSetPathInvocation, performSel, invokeSel, 0, 0, 0); // wait=0
                }
            } else {
                r_msg2_main_async(g_sbShape, "setPath:", rp, 0,0,0);
            }
        } @finally {
            __sync_lock_release(&s_remoteBusy);
        }
    });
}

void SBoardOverlaySetStatus(const char *utf8) { (void)utf8; }

void SBoardStopOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return; }
    if (r_is_objc_ptr(g_sbWin)) r_msg2_main(g_sbWin, "setHidden:", 1, 0,0,0);
    if (r_is_objc_ptr(g_sbOldPath)) dlsym("CGPathRelease", g_sbOldPath, 0,0,0,0,0,0,0);
    g_sbOverlayOn = NO;
    g_sbWin = 0;
    g_sbShape = 0;
    g_sbOldPath = 0;
    g_sbPathHash = 0;
    pthread_mutex_unlock(&g_sbLock);
    if (g_sbSettleWas) r_settle_us((uint32_t)g_sbSettleWas);
    destroy_remote_call();
}