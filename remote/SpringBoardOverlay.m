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
static uint64_t g_sbShape = 0;      // single CAShapeLayer
static uint64_t g_sbOldPath = 0;
static uint32_t g_sbPathHash = 0;
static int g_sbSettleWas = 50000;
static int g_sbMirrorCount = 0;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

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

    // ---- window (scene-attached) ----
    uint64_t app = r_msg2_main(r_class("UIApplication"), "sharedApplication", 0,0,0,0);
    if (!r_is_objc_ptr(app)) { destroy_remote_call(); return -1; }
    uint64_t kw = r_msg2_main(app, "keyWindow", 0,0,0,0);
    if (!r_is_objc_ptr(kw)) {
        uint64_t ws = r_msg2_main(app, "windows", 0,0,0,0);
        uint64_t n = r_is_objc_ptr(ws) ? r_msg2_main(ws, "count", 0,0,0,0) : 0;
        if (n > 0 && n < 64) kw = r_msg2_main(ws, "objectAtIndex:", 0,0,0,0);
    }
    if (!r_is_objc_ptr(kw)) { destroy_remote_call(); return -1; }
    uint64_t scene = r_msg2_main(kw, "windowScene", 0,0,0,0);
    if (!r_is_objc_ptr(scene)) { destroy_remote_call(); return -1; }

    uint64_t win = r_msg2_main(r_msg2_main(r_class("UIWindow"), "alloc", 0,0,0,0),
                               "initWithWindowScene:", scene, 0,0,0);
    if (!r_is_objc_ptr(win)) { destroy_remote_call(); return -1; }

    double bounds[4] = {0,0,390,844};
    uint64_t clsScr = r_class("UIScreen");
    if (r_is_objc_ptr(clsScr)) {
        r_msg2_main_struct_ret(r_msg2_main(clsScr, "mainScreen", 0,0,0,0),
                               "bounds", bounds, 32, NULL,0,NULL,0,NULL,0,NULL,0);
    }
    r_msg2_main_raw(win, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    double lvl = SB_OVERLAY_WIN_LEVEL;
    r_msg2_main_raw(win, "setWindowLevel:", &lvl, 8, NULL,0,NULL,0,NULL,0);
    uint64_t clsCol = r_class("UIColor");
    uint64_t clear = r_is_objc_ptr(clsCol) ? r_msg2_main(clsCol, "clearColor", 0,0,0,0) : 0;
    if (r_is_objc_ptr(clear)) r_msg2_main(win, "setBackgroundColor:", clear, 0,0,0);
    r_msg2_main(win, "setUserInteractionEnabled:", 0, 0,0,0);
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // ---- colors: SEPARATE UIColor vs CGColor — CRASH FIX ----
    // UILabel.setTextColor:/setBackgroundColor: take UIColor objects.
    // CAShapeLayer.setStrokeColor:/setFillColor: take CGColorRefs.
    // Passing a CGColor to setTextColor: → UILabel calls _isDynamic on
    // __NSCFType → NSInvalidArgumentException → SpringBoard abort → respring
    // ~1s after init (exactly the crash log: -[UILabel _resolveMaterialColor:]).
    uint64_t whiteUIColor = 0, blackUIColor = 0, whiteCGColor = 0;
    if (r_is_objc_ptr(clsCol)) {
        whiteUIColor = r_msg2_main(clsCol, "whiteColor", 0,0,0,0);
        blackUIColor = r_msg2_main(clsCol, "blackColor", 0,0,0,0);
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

    // ---- status UILabel ----
    uint64_t label = r_msg2_main(r_msg2_main(r_class("UILabel"), "alloc", 0,0,0,0), "init", 0,0,0,0);
    if (r_is_objc_ptr(label)) {
        double lf[4] = {0, 0, bounds[2], 60};
        r_msg2_main_raw(label, "setFrame:", lf, 32, NULL,0,NULL,0,NULL,0);
        r_msg2_main(label, "setNumberOfLines:", 1, 0,0,0);
        r_msg2_main(label, "setTextAlignment:", 1, 0,0,0);
        if (r_is_objc_ptr(whiteUIColor)) r_msg2_main(label, "setTextColor:", whiteUIColor, 0,0,0);
        if (r_is_objc_ptr(blackUIColor)) r_msg2_main(label, "setBackgroundColor:", blackUIColor, 0,0,0);
        uint64_t buf = r_alloc_str("MINHDUC ESP ACTIVE");
        if (buf) {
            uint64_t ns = r_msg2_main(r_msg2_main(r_class("NSString"), "alloc", 0,0,0,0),
                                      "initWithUTF8String:", buf, 0,0,0);
            r_free(buf);
            if (r_is_objc_ptr(ns)) {
                r_msg2_main(label, "setText:", ns, 0,0,0);
                dlsym("CFRelease", ns, 0,0,0,0,0,0,0);
            }
        }
        r_msg2_main(container, "addSubview:", label, 0,0,0);
    }

    // shape layer onto container's layer
    uint64_t containerLayer = r_msg2_main(container, "layer", 0,0,0,0);
    if (r_is_objc_ptr(containerLayer)) r_msg2_main(containerLayer, "addSublayer:", shape, 0,0,0);

    // container onto window — setHidden:NO is enough; makeKeyAndVisible on a
    // 999999-level window changed SB's key window → crash → respring.
    r_msg2_main(win, "addSubview:", container, 0,0,0);
    r_msg2_main(win, "setHidden:", 0, 0,0,0);
    g_sbShape = shape;

    // retain
    uint64_t key = r_sel("minhducSBOverlayWindow");
    if (r_is_objc_ptr(key)) dlsym("objc_setAssociatedObject", app, key, win, 1, 0,0,0,0);

    pthread_mutex_lock(&g_sbLock);
    g_sbWin = win;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    NSLog(@"[SBOverlay] single-layer vector overlay ACTIVE");
    return 0;
}

// Persistent remote path — created ONCE, emptied per sync (CGPathClear),
// never destroyed. Fl0rk DrawView pattern.
static uint64_t g_sbPersistentPath = 0;

static uint64_t persistentPath(void) {
    if (r_is_objc_ptr(g_sbPersistentPath)) return g_sbPersistentPath;
    g_sbPersistentPath = dlsym("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
    return g_sbPersistentPath;
}

void SBRemotePushESPFrame(UIView *espView) {
    if (!g_sbOverlayOn || !espView) return;
    // 60fps / 6 = ~10fps mirror. The 20fps rate crashed SpringBoard's
    // main thread (NSInvocation retain race on the performSelector path —
    // crash thread 32286: dead in objc retain inside NSInvocation setup).
    // 10fps keeps ESP readable and the remote channel calm.
    if (++g_sbMirrorCount % 6 != 0) return;
    uint64_t rp = persistentPath();
    if (!r_is_objc_ptr(rp)) return;

    // Fl0rk DrawView pattern: ONE persistent remote point buffer (allocated
    // once, never freed) + ONE batched CGPathAddLines per sync. No per-frame
    // malloc/free in SpringBoard — that churn is what killed SB.
    static uint64_t ptsBuf = 0;
    if (!r_is_objc_ptr(ptsBuf)) {
        ptsBuf = dlsym("malloc", 65536, 0,0,0,0,0,0,0); // 4096 points
        if (!r_is_objc_ptr(ptsBuf)) return;
    }

    static NSMutableData *ops = nil;
    if (!ops) ops = [NSMutableData dataWithCapacity:8192];

    if (!mergePaths(espView, ops)) return; // unchanged → 0 remote calls

    // Reset path, then write points into the persistent buffer and batch.
    dlsym("CGPathClear", rp, 0,0,0,0,0,0,0);
    size_t len = ops.length;
    const uint8_t *b = (const uint8_t *)ops.bytes;
    double pts[4096];
    int n = 0;
    size_t i = 0;
    while (i < len && n < 4090) {
        uint8_t op = b[i++];
        if (i + 16 > len) break;
        double x, y; memcpy(&x, b+i, 8); memcpy(&y, b+i+8, 8); i += 16;
        if (op == 1) { // moveTo
            if (n > 0) {
                remote_write(ptsBuf, pts, n*16);
                dlsym("CGPathAddLines", rp, 0, ptsBuf, n, 0,0,0,0);
                n = 0;
            }
            dlsym("CGPathMoveToPoint", rp, 0, dbl_bits(x), dbl_bits(y), 0,0,0,0);
        } else {
            pts[n*2] = x; pts[n*2+1] = y; n++;
        }
    }
    if (n > 0) {
        remote_write(ptsBuf, pts, n*16);
        dlsym("CGPathAddLines", rp, 0, ptsBuf, n, 0,0,0,0);
    }

    // ONE setPath per sync — layer retains the persistent path.
    r_msg2_main(g_sbShape, "setPath:", rp, 0,0,0);
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