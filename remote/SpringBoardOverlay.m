//
//  SpringBoardOverlay.m — Fl0rk DrawView-faithful SpringBoard ESP mirror
//
//  Verified against Fl0rkFF binary + fl0rk_drawview_symbols.txt:
//    DrawView.m is oxorany-stripped from release; symbols remain:
//      _drawview_start_esp_renderer_in_session
//      _gDrawViewWindow / _gDrawViewCanvas / _gDrawViewGeometryLayer
//      _gDrawViewGeometryPathInvocation   ← cached NSInvocation setPath:
//      _drawview_invoke_cached_main_raw   ← paint = re-fire that invocation
//      _drawview_passthrough_window_class
//      _drawview_line_point_buffer / _drawview_box_rect_buffer
//      _drawview_disable_line_layer_actions
//      _gDrawViewNextPlayerOverlayUS      ← us-rate limit
//      _gDrawViewSummarySkips/Updates
//    CADisplayLink (_displayLink) exists ONLY on Fl0rk's APP ViewController —
//    it drives local UI / publish loop. It is NOT installed inside SpringBoard.
//    Installing CADisplayLink in SB was our wrong invention.
//
//  Cyanide contributes the safe window host:
//    UIWindow initWithWindowScene: + level 999999.0 + userInteractionEnabled=NO
//    (NEVER keyWindow addSubview — Free Fire fullscreen → WATCHDOG 60s).
//
//  Paint path (Fl0rk):
//    1. Build dedicated pass-through window + CAShapeLayer once.
//    2. Build ONE NSInvocation for [shape setPath:] once; retain it.
//    3. Persist ONE remote CGMutablePath + remote point buffer.
//    4. App DisplayLink (ESP) calls SBRemotePushESPFrame:
//         merge paths → if hash unchanged SKIP (gDrawViewSummarySkips)
//         else CGPathClear+AddLines into persistent path
//         then invoke_cached_main_raw (performSelectorOnMainThread:invoke wait:NO)
//    5. Min interval ~33ms (~30fps). Atomic in-flight drop if previous IPC busy.
//

#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>
#import <mach/mach_time.h>

#define SB_OVERLAY_WIN_LEVEL 999999.0
// Fl0rk gDrawViewNextPlayerOverlayUS-style gate. 33ms ≈ 30fps publish.
#define SB_MIN_PUBLISH_INTERVAL_US 33000ULL

static BOOL g_sbOverlayOn = NO;
static uint64_t g_sbWin = 0;
static uint64_t g_sbShape = 0;       // gDrawViewGeometryLayer
static uint64_t g_sbCanvas = 0;      // gDrawViewCanvas

static uint64_t g_sbPersistentPath = 0;
static uint64_t g_sbMirrorPtsBuf = 0; // gDrawViewLinePointBuffer analogue
static uint32_t g_sbPathHash = 0;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

// Fl0rk: _gDrawViewGeometryPathInvocation + invoke_cached_main_raw
static uint64_t g_sbSetPathInv = 0;
static uint64_t g_sbSetPathArgBuf = 0;
static uint64_t g_sbPerformMainSel = 0;
static uint64_t g_sbInvokeSel = 0;

// Fl0rk summary counters
static uint64_t g_sbSummaryAttempts = 0;
static uint64_t g_sbSummarySkips = 0;
static uint64_t g_sbSummaryUpdates = 0;
static uint64_t g_sbNextPublishUS = 0;

static const char *kShapeKeys[16] = {
    "boxLayer", "boxBotLayer", "boxKnockedLayer",
    "boneLayer", "boneBotLayer", "boneKnockedLayer",
    "snaplineLayer", "snaplineBotLayer", "snaplineKnockedLayer",
    "hpFillGreenLayer", "hpFillOrangeLayer", "hpFillRedLayer",
    "bgFillBlackLayer", "alertLayer", "fovLayer", "aimAssistLayer"
};

static uint64_t dlsym_remote(const char *fn, uint64_t a0, uint64_t a1, uint64_t a2,
                             uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    return r_dlsym_call(R_TIMEOUT, fn, a0,a1,a2,a3,a4,a5,a6,a7);
}

static uint64_t now_us(void) {
    static mach_timebase_info_data_t tb;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mach_timebase_info(&tb); });
    uint64_t t = mach_absolute_time();
    return (t * tb.numer / tb.denom) / 1000ULL;
}

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

static uint64_t persistentPath(void) {
    if (g_sbPersistentPath) return g_sbPersistentPath;
    g_sbPersistentPath = dlsym_remote("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
    return g_sbPersistentPath;
}

static void sb_reset_mirror_state(void) {
    g_sbPersistentPath = 0;
    g_sbMirrorPtsBuf = 0;
    g_sbPathHash = 0;
    if (r_is_objc_ptr(g_sbSetPathInv)) r_msg2(g_sbSetPathInv, "release", 0,0,0,0);
    if (g_sbSetPathArgBuf) dlsym_remote("free", g_sbSetPathArgBuf, 0,0,0,0,0,0,0);
    g_sbSetPathInv = 0;
    g_sbSetPathArgBuf = 0;
    g_sbPerformMainSel = 0;
    g_sbInvokeSel = 0;
    g_sbNextPublishUS = 0;
}

// Fl0rk: _drawview_disable_line_layer_actions
static void sb_disable_layer_actions(uint64_t layer) {
    if (!r_is_objc_ptr(layer)) return;
    // actions = @{@"path": [NSNull null], @"strokeColor": null, ...} — simplest:
    // setActions: empty dict still allows implicit; setDelegate nil + disableActions
    // via CATransaction is local-only. Remote: setActions: with NSNull for "path".
    uint64_t NSMutableDictionary = r_class("NSMutableDictionary");
    uint64_t NSNullCls = r_class("NSNull");
    if (!r_is_objc_ptr(NSMutableDictionary) || !r_is_objc_ptr(NSNullCls)) return;
    uint64_t dict = r_msg2_main(NSMutableDictionary, "dictionary", 0,0,0,0);
    uint64_t nullObj = r_msg2_main(NSNullCls, "null", 0,0,0,0);
    uint64_t keyPath = r_nsstr_retained("path");
    if (r_is_objc_ptr(dict) && r_is_objc_ptr(nullObj) && r_is_objc_ptr(keyPath)) {
        r_msg2_main(dict, "setObject:forKey:", nullObj, keyPath, 0, 0);
        r_msg2_main(layer, "setActions:", dict, 0,0,0);
    }
}

// Fl0rk: build _gDrawViewGeometryPathInvocation once
static BOOL sb_ensure_setpath_invocation(void) {
    if (r_is_objc_ptr(g_sbSetPathInv) && g_sbSetPathArgBuf) return YES;
    if (!r_is_objc_ptr(g_sbShape)) return NO;

    uint64_t rp = persistentPath();
    if (!rp) return NO;

    uint64_t setPathSel = r_sel("setPath:");
    if (!setPathSel) return NO;

    uint64_t sigSel = r_sel("methodSignatureForSelector:");
    uint64_t sig = r_msg(g_sbShape, sigSel, setPathSel, 0, 0, 0);
    if (!r_is_objc_ptr(sig)) return NO;

    uint64_t NSInvocation = r_class("NSInvocation");
    if (!r_is_objc_ptr(NSInvocation)) return NO;

    uint64_t inv = r_msg(NSInvocation, r_sel("invocationWithMethodSignature:"), sig, 0, 0, 0);
    if (!r_is_objc_ptr(inv)) return NO;
    r_msg2(inv, "retain", 0, 0, 0, 0);

    r_msg2(inv, "setTarget:", g_sbShape, 0, 0, 0);
    r_msg2(inv, "setSelector:", setPathSel, 0, 0, 0);

    uint64_t argBuf = dlsym_remote("malloc", 8, 0,0,0,0,0,0,0);
    if (!argBuf) {
        r_msg2(inv, "release", 0, 0, 0, 0);
        return NO;
    }
    remote_write64(argBuf, rp);
    r_msg2(inv, "setArgument:atIndex:", argBuf, 2, 0, 0);
    r_msg2(inv, "retainArguments", 0, 0, 0, 0);

    g_sbSetPathInv = inv;
    g_sbSetPathArgBuf = argBuf;
    g_sbPerformMainSel = r_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    g_sbInvokeSel = r_sel("invoke");
    NSLog(@"[SBOverlay] Fl0rk GeometryPathInvocation=0x%llx path=0x%llx", inv, rp);
    return YES;
}

// Fl0rk: _drawview_invoke_cached_main_raw
static void sb_invoke_cached_main_raw(void) {
    if (!sb_ensure_setpath_invocation()) {
        uint64_t rp = persistentPath();
        if (rp) r_msg2_main_async(g_sbShape, "setPath:", rp, 0,0,0);
        return;
    }
    // Keep arg = current persistent path (may have been recreated after reset)
    remote_write64(g_sbSetPathArgBuf, persistentPath());
    r_msg2(g_sbSetPathInv, "setArgument:atIndex:", g_sbSetPathArgBuf, 2, 0, 0);
    // waitUntilDone:NO — never block SpringBoard / never block us waiting on SB
    if (g_sbPerformMainSel && g_sbInvokeSel) {
        r_msg(g_sbSetPathInv, g_sbPerformMainSel, g_sbInvokeSel, 0, 0, 0);
    }
}

// ======================== public ========================

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    if (!g_kexploit_ready) return -1;

    r_settle_us(5000);

    NSLog(@"[SBOverlay] Fl0rk DrawView session (originalThreadOnly)...");
    int rc = init_remote_call_original_thread_only_with_first_exception_timeout(
        "SpringBoard", false, 15000);
    if (rc != 0) {
        NSLog(@"[SBOverlay] originalThreadOnly failed rc=%d — fallback", rc);
        rc = init_remote_call_with_first_exception_timeout("SpringBoard", false, 15000);
    }
    if (rc != 0) return -1;

    uint64_t pid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    if (pid == 0) { destroy_remote_call(); return -1; }

    uint64_t app = r_msg2_main(r_class("UIApplication"), "sharedApplication", 0,0,0,0);
    if (!r_is_objc_ptr(app)) { destroy_remote_call(); return -1; }

    uint64_t keyWin = r_msg2_main(app, "keyWindow", 0,0,0,0);
    if (!r_is_objc_ptr(keyWin)) {
        uint64_t ws = r_msg2_main(app, "windows", 0,0,0,0);
        uint64_t n = r_is_objc_ptr(ws) ? r_msg2_main(ws, "count", 0,0,0,0) : 0;
        if (n > 0 && n < 64) keyWin = r_msg2_main(ws, "objectAtIndex:", 0,0,0,0);
    }
    if (!r_is_objc_ptr(keyWin)) {
        NSLog(@"[SBOverlay] no SB window");
        destroy_remote_call();
        return -1;
    }

    uint64_t scene = r_msg2_main(keyWin, "windowScene", 0,0,0,0);
    if (!r_is_objc_ptr(scene)) {
        NSLog(@"[SBOverlay] no UIWindowScene");
        destroy_remote_call();
        return -1;
    }

    double bounds[4] = {0, 0, 390, 844};
    uint64_t clsScr = r_class("UIScreen");
    if (r_is_objc_ptr(clsScr)) {
        r_msg2_main_struct_ret(r_msg2_main(clsScr, "mainScreen", 0,0,0,0),
                               "bounds", bounds, 32, NULL,0,NULL,0,NULL,0,NULL,0);
    }

    uint64_t clsCol = r_class("UIColor");
    uint64_t clear = r_is_objc_ptr(clsCol) ? r_msg2_main(clsCol, "clearColor", 0,0,0,0) : 0;
    uint64_t whiteColor = r_is_objc_ptr(clsCol) ? r_msg2_main(clsCol, "whiteColor", 0,0,0,0) : 0;
    uint64_t whiteCGColor = r_is_objc_ptr(whiteColor) ? r_msg2_main(whiteColor, "CGColor", 0,0,0,0) : 0;

    // Fl0rk passthrough window + Cyanide initWithWindowScene:
    uint64_t winAlloc = r_msg2_main(r_class("UIWindow"), "alloc", 0,0,0,0);
    if (!r_is_objc_ptr(winAlloc)) { destroy_remote_call(); return -1; }

    uint64_t win = r_msg2_main(winAlloc, "initWithWindowScene:", scene, 0,0,0);
    if (!r_is_objc_ptr(win)) {
        NSLog(@"[SBOverlay] initWithWindowScene failed");
        destroy_remote_call();
        return -1;
    }

    r_msg2_main_raw(win, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    double winLevel = SB_OVERLAY_WIN_LEVEL;
    r_msg2_main_raw(win, "setWindowLevel:", &winLevel, 8, NULL,0,NULL,0,NULL,0);
    r_msg2_main(win, "setUserInteractionEnabled:", 0, 0,0,0);
    if (r_is_objc_ptr(clear)) r_msg2_main(win, "setBackgroundColor:", clear, 0,0,0);

    // gDrawViewCanvas
    uint64_t container = r_msg2_main_raw(r_msg2_main(r_class("UIView"), "alloc", 0,0,0,0),
                                         "initWithFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    if (!r_is_objc_ptr(container)) { destroy_remote_call(); return -1; }
    if (r_is_objc_ptr(clear)) r_msg2_main(container, "setBackgroundColor:", clear, 0,0,0);
    r_msg2_main(container, "setUserInteractionEnabled:", 0, 0,0,0);
    r_msg2_main(container, "setOpaque:", 0, 0,0,0);
    r_msg2_main(win, "addSubview:", container, 0,0,0);

    // gDrawViewGeometryLayer
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
    sb_disable_layer_actions(shape);

    uint64_t cLayer = r_msg2_main(container, "layer", 0,0,0,0);
    if (r_is_objc_ptr(cLayer)) r_msg2_main(cLayer, "addSublayer:", shape, 0,0,0);

    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // Retain like Fl0rk associated-object window root
    uint64_t key = r_sel("fl0rkffESPMenuWindow");
    if (r_is_objc_ptr(key)) {
        dlsym_remote("objc_setAssociatedObject", app, key, win, 1, 0,0,0,0);
    }

    pthread_mutex_lock(&g_sbLock);
    g_sbWin = win;
    g_sbShape = shape;
    g_sbCanvas = container;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    sb_reset_mirror_state();
    (void)persistentPath();
    (void)sb_ensure_setpath_invocation();

    NSLog(@"[SBOverlay] Fl0rk DrawView ACTIVE win=0x%llx canvas=0x%llx geom=0x%llx inv=%s",
          win, container, shape, r_is_objc_ptr(g_sbSetPathInv) ? "OK" : "NO");
    return 0;
}

void SBRemotePushESPFrame(UIView *espView) {
    if (!g_sbOverlayOn || !espView) return;

    g_sbSummaryAttempts++;

    // Fl0rk gDrawViewNextPlayerOverlayUS gate
    uint64_t t = now_us();
    if (t < g_sbNextPublishUS) {
        g_sbSummarySkips++;
        return;
    }

    static NSMutableData *ops = nil;
    if (!ops) ops = [NSMutableData dataWithCapacity:8192];

    if (!mergePaths(espView, ops)) {
        g_sbSummarySkips++; // unchanged hash
        return;
    }

    static int s_remoteBusy = 0;
    if (__sync_lock_test_and_set(&s_remoteBusy, 1)) {
        g_sbSummarySkips++;
        return;
    }

    g_sbNextPublishUS = t + SB_MIN_PUBLISH_INTERVAL_US;
    NSData *frameBytes = [ops copy];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            uint64_t rp = persistentPath();
            if (!rp) return;

            uint64_t ptsBuf = g_sbMirrorPtsBuf;
            if (!ptsBuf) {
                ptsBuf = dlsym_remote("malloc", 65536, 0,0,0,0,0,0,0);
                if (!ptsBuf) return;
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
                if (op == 1) {
                    if (n > 0 && havePrevEnd) {
                        pts[n++] = lastX; pts[n++] = lastY;
                    }
                    lastX = x; lastY = y; haveLast = YES;
                } else {
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
                dlsym_remote("CGPathClear", rp, 0,0,0,0,0,0,0);
                dlsym_remote("CGPathAddLines", rp, 0, ptsBuf, n / 2, 0,0,0,0);
                // Fl0rk paint: invoke cached main raw (NOT SB DisplayLink)
                sb_invoke_cached_main_raw();
                g_sbSummaryUpdates++;
                if ((g_sbSummaryUpdates & 0x3f) == 0) {
                    NSLog(@"[SBOverlay] Fl0rk summary attempts=%llu skips=%llu updates=%llu",
                          g_sbSummaryAttempts, g_sbSummarySkips, g_sbSummaryUpdates);
                }
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
    if (g_sbPersistentPath) dlsym_remote("CGPathRelease", g_sbPersistentPath, 0,0,0,0,0,0,0);
    if (r_is_objc_ptr(g_sbSetPathInv)) r_msg2(g_sbSetPathInv, "release", 0,0,0,0);
    if (g_sbSetPathArgBuf) dlsym_remote("free", g_sbSetPathArgBuf, 0,0,0,0,0,0,0);
    g_sbOverlayOn = NO;
    g_sbWin = 0;
    g_sbShape = 0;
    g_sbCanvas = 0;
    g_sbPersistentPath = 0;
    g_sbPathHash = 0;
    g_sbSetPathInv = 0;
    g_sbSetPathArgBuf = 0;
    pthread_mutex_unlock(&g_sbLock);
    destroy_remote_call();
}
