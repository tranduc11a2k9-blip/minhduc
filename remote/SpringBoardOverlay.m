//
//  SpringBoardOverlay.m — Fl0rk/Cyanide-style SpringBoard overlay
//
//  Architecture (proven stable across Fl0rkFF and Cyanide StatBar):
//    1. Dedicated UIWindow with -initWithWindowScene: (scene from keyWindow).
//       NEVER addSubview directly to keyWindow — that causes layout fighting
//       when fullscreen games (Free Fire) switch scenes, leading to WATCHDOG 60s.
//    2. Window level 999999.0 (statbar level — stays above all apps/games).
//    3. userInteractionEnabled = NO — passes all touches through to the game.
//    4. Dual ping-pong CGMutablePath (Path A / Path B) to eliminate render race:
//       background thread writes to alternate path, then async setPath: on main.
//    5. Non-blocking async queue with atomic in-flight guard (skips dropped frames).
//

#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>

#define SB_OVERLAY_WIN_LEVEL 999999.0

static BOOL g_sbOverlayOn = NO;
static uint64_t g_sbWin = 0;
static uint64_t g_sbShape = 0;
static uint64_t g_sbCanvas = 0;

static uint64_t g_sbPathA = 0;
static uint64_t g_sbPathB = 0;
static uint32_t g_sbPathIndex = 0;
static uint64_t g_sbMirrorPtsBuf = 0;
static uint32_t g_sbPathHash = 0;
static int g_sbMirrorCount = 0;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

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

// CGPath serialization
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

static void sb_reset_mirror_state(void) {
    g_sbPathA = 0;
    g_sbPathB = 0;
    g_sbPathIndex = 0;
    g_sbMirrorPtsBuf = 0;
    g_sbPathHash = 0;
    g_sbMirrorCount = 0;
}

// ======================== public ========================

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    if (!g_kexploit_ready) return -1;

    r_settle_us(5000);

    NSLog(@"[SBOverlay] Initializing SpringBoard overlay session (originalThreadOnly)...");
    int rc = init_remote_call_original_thread_only_with_first_exception_timeout(
        "SpringBoard", false, 15000);
    if (rc != 0) {
        NSLog(@"[SBOverlay] originalThreadOnly failed rc=%d — fallback plain init", rc);
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
        NSLog(@"[SBOverlay] No active SpringBoard window found");
        destroy_remote_call();
        return -1;
    }

    uint64_t scene = r_msg2_main(keyWin, "windowScene", 0,0,0,0);
    if (!r_is_objc_ptr(scene)) {
        NSLog(@"[SBOverlay] No active UIWindowScene found");
        destroy_remote_call();
        return -1;
    }

    // Screen bounds
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

    // ---- Cyanide / Fl0rk DEDICATED UIWindow pattern ----
    // Create dedicated UIWindow with windowScene. Never touch keyWindow.addSubview:
    uint64_t winAlloc = r_msg2_main(r_class("UIWindow"), "alloc", 0,0,0,0);
    if (!r_is_objc_ptr(winAlloc)) { destroy_remote_call(); return -1; }

    uint64_t win = r_msg2_main(winAlloc, "initWithWindowScene:", scene, 0,0,0);
    if (!r_is_objc_ptr(win)) {
        NSLog(@"[SBOverlay] Dedicated UIWindow alloc failed");
        destroy_remote_call();
        return -1;
    }

    r_msg2_main_raw(win, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    double winLevel = SB_OVERLAY_WIN_LEVEL;
    r_msg2_main_raw(win, "setWindowLevel:", &winLevel, 8, NULL,0,NULL,0,NULL,0);
    r_msg2_main(win, "setUserInteractionEnabled:", 0, 0,0,0);
    if (r_is_objc_ptr(clear)) r_msg2_main(win, "setBackgroundColor:", clear, 0,0,0);

    // Container UIView
    uint64_t container = r_msg2_main_raw(r_msg2_main(r_class("UIView"), "alloc", 0,0,0,0),
                                         "initWithFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    if (!r_is_objc_ptr(container)) { destroy_remote_call(); return -1; }
    if (r_is_objc_ptr(clear)) r_msg2_main(container, "setBackgroundColor:", clear, 0,0,0);
    r_msg2_main(container, "setUserInteractionEnabled:", 0, 0,0,0);
    r_msg2_main(container, "setOpaque:", 0, 0,0,0);
    r_msg2_main(win, "addSubview:", container, 0,0,0);

    // CAShapeLayer
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

    uint64_t cLayer = r_msg2_main(container, "layer", 0,0,0,0);
    if (r_is_objc_ptr(cLayer)) {
        r_msg2_main(cLayer, "addSublayer:", shape, 0,0,0);
    }

    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // Retain window via associated object on UIApplication
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

    // Reset mirror state & allocate dual ping-pong paths
    sb_reset_mirror_state();
    g_sbPathA = dlsym_remote("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
    g_sbPathB = dlsym_remote("CGPathCreateMutable", 0,0,0,0,0,0,0,0);

    NSLog(@"[SBOverlay] Dedicated pass-through window ACTIVE (win=0x%llx, shape=0x%llx, ping-pong OK)",
          win, shape);
    return 0;
}

void SBRemotePushESPFrame(UIView *espView) {
    if (!g_sbOverlayOn || !espView) return;

    // 60fps / 3 = ~20 FPS. Smooth, zero jitter, safe for SpringBoard main thread.
    if (++g_sbMirrorCount % 3 != 0) return;

    static NSMutableData *ops = nil;
    if (!ops) ops = [NSMutableData dataWithCapacity:8192];

    if (!mergePaths(espView, ops)) return; // unchanged → 0 remote calls

    static int s_remoteBusy = 0;
    if (__sync_lock_test_and_set(&s_remoteBusy, 1)) {
        return; // Drop frame if previous IPC still in flight (non-blocking skip)
    }

    NSData *frameBytes = [ops copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try {
            if (!g_sbPathA || !g_sbPathB) {
                g_sbPathA = dlsym_remote("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
                g_sbPathB = dlsym_remote("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
            }
            uint64_t activePath = (g_sbPathIndex++ & 1) ? g_sbPathB : g_sbPathA;
            if (!r_is_objc_ptr(activePath)) return;

            uint64_t ptsBuf = g_sbMirrorPtsBuf;
            if (!r_is_objc_ptr(ptsBuf)) {
                ptsBuf = dlsym_remote("malloc", 65536, 0,0,0,0,0,0,0);
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

            // Fill active ping-pong path in background worker
            if (n >= 2) {
                remote_write(ptsBuf, pts, n * 8);
                dlsym_remote("CGPathClear", activePath, 0,0,0,0,0,0,0);
                dlsym_remote("CGPathAddLines", activePath, 0, ptsBuf, n / 2, 0,0,0,0);
            }

            // Instant async swap on SpringBoard main thread (<0.01ms, non-blocking)
            r_msg2_main_async(g_sbShape, "setPath:", activePath, 0,0,0);
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
    if (r_is_objc_ptr(g_sbPathA)) dlsym_remote("CGPathRelease", g_sbPathA, 0,0,0,0,0,0,0);
    if (r_is_objc_ptr(g_sbPathB)) dlsym_remote("CGPathRelease", g_sbPathB, 0,0,0,0,0,0,0);
    g_sbOverlayOn = NO;
    g_sbWin = 0;
    g_sbShape = 0;
    g_sbCanvas = 0;
    g_sbPathHash = 0;
    pthread_mutex_unlock(&g_sbLock);
    destroy_remote_call();
}
