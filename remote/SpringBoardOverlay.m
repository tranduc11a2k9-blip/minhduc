//
//  SpringBoardOverlay.m — vector ESP mirror into SpringBoard
//
//  NO JPEG. Local ESP_View renders at 60fps (source of truth). Each frame
//  we serialize its CAShapeLayer paths → 1 remote_write → rebuild
//  CGMutablePath in SpringBoard → setPath. Per-layer FNV hash skips
//  unchanged layers (idle scene ≈ 0 remote calls).
//
//  Key fixes vs old JPEG approach:
//  - Vector shapes (no blur, native resolution)
//  - ~20fps sync (60fps timer / 3)
//  - Per-layer hash: idle scene ≈ 0 cost
//  - STRICT color scheme: force white stroke + no fill to avoid creating
//    remote CGColorRef (which crashes via r_msg2_main). ESP colors are
//    cosmetic — white on black is always readable.
//  - r_settle_us(500) instead of default 50ms (was 100x slower!)
//
#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>

#define SB_OVERLAY_WIN_LEVEL 10000000.0
#define SB_MAX_TEXT_SLOTS 24

static BOOL g_sbOverlayOn = NO;
static uint64_t g_sbWin = 0;
static uint64_t g_sbRoot = 0; // root UIView
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;
static int g_sbMirrorCount = 0;
static int g_sbSettleWas = 50000;

// 16 shape layers + 24 text layers
static uint64_t g_shape[16];
static uint64_t g_oldPath[16];
static uint32_t g_shapeHash[16];
static uint64_t g_text[SB_MAX_TEXT_SLOTS];
static uint32_t g_textHash[SB_MAX_TEXT_SLOTS];
static uint64_t g_oldTextObj[SB_MAX_TEXT_SLOTS];

static const char *kShapeKeys[16] = {
    "boxLayer", "boxBotLayer", "boxKnockedLayer",
    "boneLayer", "boneBotLayer", "boneKnockedLayer",
    "snaplineLayer", "snaplineBotLayer", "snaplineKnockedLayer",
    "hpFillGreenLayer", "hpFillOrangeLayer", "hpFillRedLayer",
    "bgFillBlackLayer", "alertLayer", "fovLayer", "aimAssistLayer"
};

// ---- helpers ----
static void dblCpy(double *d, const void *s) { memcpy(d, s, 8); }

static uint64_t dbl_bits(double d) { uint64_t v; memcpy(&v, &d, 8); return v; }

static uint64_t dlsym(const char *fn, uint64_t a0, uint64_t a1, uint64_t a2,
                      uint64_t a3, uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7) {
    return r_dlsym_call(R_TIMEOUT, fn, a0,a1,a2,a3,a4,a5,a6,a7);
}

// Simple FNV-1a
static uint32_t hsh(const void *p, size_t n) {
    uint32_t h = 2166136261u;
    const uint8_t *b = (const uint8_t *)p;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 16777619u; }
    return h;
}

// CGPathApply requires a C function pointer (not a block).
typedef struct {
    NSMutableData *data;
} PathSerCtx;

static void pathSerFunc(void *info, const CGPathElement *e) {
    PathSerCtx *ctx = (PathSerCtx *)info;
    NSMutableData *dd = ctx->data;
    if (e->type == kCGPathElementCloseSubpath) return;
    uint8_t op = (e->type == kCGPathElementMoveToPoint) ? 1 : 2;
    [dd appendBytes:&op length:1];
    if (e->type == kCGPathElementMoveToPoint || e->type == kCGPathElementAddLineToPoint) {
        [dd appendBytes:&e->points[0] length:16];
    } else {
        int n = (e->type == kCGPathElementAddQuadCurveToPoint) ? 1 : 2;
        [dd appendBytes:&e->points[n] length:16];
    }
}

// Serialize a CGPath as byte stream: for each element, [op:1][data].
// ops: 1=moveTo(2d), 2=lineTo(2d)
static void serializePath(CGPathRef p, NSMutableData *d) {
    [d setLength:0];
    if (!p || CGPathIsEmpty(p)) return;
    PathSerCtx ctx = { .data = d };
    CGPathApply(p, &ctx, pathSerFunc);
}

// Replay ops into a remote CGMutablePath.
// CRITICAL: points array must be allocated in SpringBoard's address space
// (remote malloc). Passing a local stack pointer crashes SpringBoard.
static void replayOps(uint64_t rp, const uint8_t *ops, size_t len) {
    size_t i = 0;
    // Allocate remote buffer for batch points (max 256 points = 4096 bytes)
    uint64_t remotePts = dlsym("malloc", 4096, 0,0,0,0,0,0,0);
    if (!r_is_objc_ptr(remotePts)) return;
    double localPts[256];
    int n = 0;
    while (i < len && n < 254) {
        uint8_t op = ops[i++];
        if (i + 16 > len) break;
        double x, y;
        memcpy(&x, ops+i, 8); memcpy(&y, ops+i+8, 8);
        i += 16;
        if (op == 1) {
            if (n > 0) {
                // write batch to remote buffer, then call CGPathAddLines
                remote_write(remotePts, localPts, n * 16);
                dlsym("CGPathAddLines", rp, 0, remotePts, n, 0,0,0,0);
                n = 0;
            }
            dlsym("CGPathMoveToPoint", rp, 0, dbl_bits(x), dbl_bits(y), 0,0,0,0);
        } else {
            localPts[n*2] = x; localPts[n*2+1] = y;
            n++;
        }
    }
    if (n > 0) {
        remote_write(remotePts, localPts, n * 16);
        dlsym("CGPathAddLines", rp, 0, remotePts, n, 0,0,0,0);
    }
    dlsym("free", remotePts, 0,0,0,0,0,0,0);
}

static void syncShapeLayer(int idx, CAShapeLayer *local, NSMutableData *ops) {
    if (idx < 0 || idx >= 16) return;
    uint64_t remote = g_shape[idx];
    if (!r_is_objc_ptr(remote) || !local) return;

    // hash: path + lineWidth
    serializePath(local.path, ops);
    float lw = (float)local.lineWidth;
    [ops appendBytes:&lw length:4];
    uint32_t h = hsh(ops.bytes, ops.length);
    if (h == g_shapeHash[idx]) return;
    g_shapeHash[idx] = h;

    // set lineWidth (CGFloat = 8 bytes)
    double lw64 = local.lineWidth;
    r_msg2_main_raw(remote, "setLineWidth:", &lw64, 8, NULL,0, NULL,0, NULL,0);

    // rebuild remote path
    uint64_t old = g_oldPath[idx];
    if (local.path == nil || CGPathIsEmpty(local.path)) {
        r_msg2_main(remote, "setPath:", 0, 0,0,0);
        if (r_is_objc_ptr(old)) { dlsym("CGPathRelease", old,0,0,0,0,0,0,0); g_oldPath[idx] = 0; }
        return;
    }
    uint64_t rp = dlsym("CGPathCreateMutable", 0,0,0,0,0,0,0,0);
    if (!r_is_objc_ptr(rp)) return;
    replayOps(rp, (const uint8_t *)ops.bytes, ops.length - 4); // exclude lw
    r_msg2_main(remote, "setPath:", rp, 0,0,0);
    if (r_is_objc_ptr(old)) dlsym("CGPathRelease", old,0,0,0,0,0,0,0);
    g_oldPath[idx] = rp;
}

static void syncTextLayer(int slot, CATextLayer *local) {
    if (slot < 0 || slot >= SB_MAX_TEXT_SLOTS) return;
    uint64_t remote = g_text[slot];
    if (!r_is_objc_ptr(remote) || !local) return;

    NSString *s = local.string;
    uint32_t h = hsh(s.UTF8String, s.UTF8String ? strlen(s.UTF8String) : 0);
    if (h == g_textHash[slot]) return;
    g_textHash[slot] = h;

    // release old NSString
    if (r_is_objc_ptr(g_oldTextObj[slot])) {
        dlsym("CFRelease", g_oldTextObj[slot], 0,0,0,0,0,0,0);
        g_oldTextObj[slot] = 0;
    }
    if (!s || s.length == 0) { r_msg2_main(remote, "setString:", 0,0,0,0); return; }

    // create remote NSString
    uint64_t buf = r_alloc_str(s.UTF8String);
    if (!buf) return;
    uint64_t cls = r_class("NSString");
    uint64_t alloc = r_msg2_main(cls, "alloc", 0,0,0,0);
    uint64_t ns = r_is_objc_ptr(alloc) ? r_msg2_main(alloc, "initWithUTF8String:", buf,0,0,0) : 0;
    r_free(buf);
    if (!r_is_objc_ptr(ns)) return;
    r_msg2_main(remote, "setString:", ns, 0,0,0);
    g_oldTextObj[slot] = ns;
}

// ======================== public ========================

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    if (!g_kexploit_ready) return -1;

    // CRITICAL: default r_settle_us is 50000 (50ms) — every remote call
    // waits 50ms! Per-frame sync would be ~2fps. Set to 500us (0.5ms).
    g_sbSettleWas = r_settle_us(500);

    NSLog(@"[SBOverlay] init remote call into SpringBoard...");
    int rc = init_remote_call_with_first_exception_timeout("SpringBoard", true, 5000);
    if (rc != 0) return -1;

    uint64_t pid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    if (pid == 0) { destroy_remote_call(); return -1; }

    // ---- window ----
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

    uint64_t clsWin = r_class("UIWindow");
    uint64_t win = r_msg2_main(r_msg2_main(clsWin, "alloc", 0,0,0,0),
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

    // ---- root UIView (passthrough, clear) ----
    uint64_t root = r_msg2_main_raw(r_msg2_main(r_class("UIView"), "alloc", 0,0,0,0),
                                    "initWithFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
    if (!r_is_objc_ptr(root)) { destroy_remote_call(); return -1; }
    r_msg2_main(root, "setUserInteractionEnabled:", 0, 0,0,0);
    if (r_is_objc_ptr(clear)) r_msg2_main(root, "setBackgroundColor:", clear, 0,0,0);
    g_sbRoot = root;

    // ---- pre-create 16 CAShapeLayers (white stroke, no fill) ----
    uint64_t white = 0;
    if (r_is_objc_ptr(clsCol)) {
        white = r_msg2_main(clsCol, "whiteColor", 0,0,0,0);
        // CAShapeLayer.setStrokeColor: takes CGColorRef — we need [UIColor CGColor]
        // r_msg2_main returns the CGColorRef as uint64_t (works via NSInvocation).
        if (r_is_objc_ptr(white)) white = r_msg2_main(white, "CGColor", 0,0,0,0);
    }
    uint64_t clsShape = r_class("CAShapeLayer");
    for (int i = 0; i < 16; i++) {
        uint64_t layer = r_msg2_main(clsShape, "layer", 0,0,0,0);
        if (!r_is_objc_ptr(layer)) continue;
        r_msg2_main_raw(layer, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
        r_msg2_main(layer, "setOpaque:", 0, 0,0,0);
        double z = 10.0 + i;
        r_msg2_main_raw(layer, "setZPosition:", &z, 8, NULL,0,NULL,0,NULL,0);
        // fixed white stroke, no fill — good enough for ESP
        if (r_is_objc_ptr(white)) r_msg2_main(layer, "setStrokeColor:", white, 0,0,0);
        r_msg2_main(layer, "setFillColor:", 0, 0,0,0);
        r_msg2_main(root, "addSublayer:", layer, 0,0,0);
        g_shape[i] = layer;
    }

    // ---- pre-create 24 CATextLayers ----
    uint64_t clsText = r_class("CATextLayer");
    for (int i = 0; i < SB_MAX_TEXT_SLOTS; i++) {
        uint64_t tl = r_msg2_main(clsText, "layer", 0,0,0,0);
        if (!r_is_objc_ptr(tl)) continue;
        r_msg2_main_raw(tl, "setFrame:", bounds, 32, NULL,0,NULL,0,NULL,0);
        r_msg2_main(tl, "setOpaque:", 0, 0,0,0);
        double z = 200.0 + i;
        r_msg2_main_raw(tl, "setZPosition:", &z, 8, NULL,0,NULL,0,NULL,0);
        // white foreground, clear background
        if (r_is_objc_ptr(white)) r_msg2_main(tl, "setForegroundColor:", white, 0,0,0);
        r_msg2_main(root, "addSublayer:", tl, 0,0,0);
        g_text[i] = tl;
    }

    r_msg2_main(win, "addSubview:", root, 0,0,0);
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // retain
    uint64_t key = r_sel("minhducSBOverlayWindow");
    if (r_is_objc_ptr(key))
        dlsym("objc_setAssociatedObject", app, key, win, 1, 0,0,0,0);

    pthread_mutex_lock(&g_sbLock);
    g_sbWin = win;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    NSLog(@"[SBOverlay] vector overlay ACTIVE (16 shape + 24 text layers)");
    return 0;
}

void SBRemotePushESPFrame(UIView *espView) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn || !espView) { pthread_mutex_unlock(&g_sbLock); return; }
    pthread_mutex_unlock(&g_sbLock);

    if (++g_sbMirrorCount % 3 != 0) return; // 60fps÷3 = 20fps

    static NSMutableData *ops = nil;
    if (!ops) ops = [NSMutableData dataWithCapacity:8192];

    // Sync shape layers
    for (int i = 0; i < 16; i++) {
        id val = [espView valueForKey:[NSString stringWithUTF8String:kShapeKeys[i]]];
        if ([val isKindOfClass:[CAShapeLayer class]])
            syncShapeLayer(i, val, ops);
    }

    // Sync text: statusLayer + textLayerPool
    id status = [espView valueForKey:@"statusLayer"];
    if ([status isKindOfClass:[CATextLayer class]])
        syncTextLayer(0, status);

    id pool = [espView valueForKey:@"textLayerPool"];
    if ([pool isKindOfClass:[NSArray class]]) {
        int n = (int)[(NSArray *)pool count];
        if (n > SB_MAX_TEXT_SLOTS - 1) n = SB_MAX_TEXT_SLOTS - 1;
        for (int i = 0; i < n; i++) {
            id obj = [(NSArray *)pool objectAtIndex:i];
            if ([obj isKindOfClass:[CATextLayer class]])
                syncTextLayer(i + 1, obj);
        }
    }
}

void SBoardOverlaySetStatus(const char *utf8) { (void)utf8; }

void SBoardStopOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return; }
    if (r_is_objc_ptr(g_sbWin)) r_msg2_main(g_sbWin, "setHidden:", 1, 0,0,0);
    for (int i = 0; i < 16; i++) {
        if (r_is_objc_ptr(g_oldPath[i])) dlsym("CGPathRelease", g_oldPath[i], 0,0,0,0,0,0,0);
        g_oldPath[i] = 0;
    }
    for (int i = 0; i < SB_MAX_TEXT_SLOTS; i++) {
        if (r_is_objc_ptr(g_oldTextObj[i])) dlsym("CFRelease", g_oldTextObj[i], 0,0,0,0,0,0,0);
        g_oldTextObj[i] = 0;
    }
    memset(g_shapeHash, 0, sizeof(g_shapeHash));
    memset(g_textHash, 0, sizeof(g_textHash));
    g_sbOverlayOn = NO;
    g_sbWin = 0;
    g_sbRoot = 0;
    pthread_mutex_unlock(&g_sbLock);
    r_settle_us((uint32_t)g_sbSettleWas);
    destroy_remote_call();
}