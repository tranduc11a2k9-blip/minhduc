//
//  SpringBoardOverlay.m — Fl0rk-style SpringBoard overlay
//  remote_objc creates a fullscreen UIImageView inside SpringBoard's
//  process. Every ~10 frames the local ESP_View (box/bone/line/hp/name/
//  distance/weapon/fov/aim) is rendered offscreen and the JPEG is uploaded
//  into the remote image view → full ESP renders above EVERY app.
//
//  Bug fixes vs the first attempt:
//  - initWithWindowScene: (NOT initWithFrame: — no scene = never on screen)
//  - UIImageView subview added via addSubview: (had NO subviews → invisible)
//  - CFRelease for ObjC objects (r_free = remote free() on ObjC = crash)
//  - objc_setAssociatedObject retains the window
//  - Remote temps kept in a small ring and released 3 frames later so the
//    async setImage: never touches freed memory (UAF crash)
//
#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import "../../kexploit/kutils.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>

#define SB_OVERLAY_WIN_LEVEL 10000000.0
#define SB_OVERLAY_TAG 0x4D48 // "MH"

static BOOL g_sbOverlayOn = NO;
static uint64_t g_sbWindow = 0;
static uint64_t g_sbLabel = 0;
static uint64_t g_sbImgView = 0;
static NSString *g_sbLastText = nil;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

// Ring of remotely-retained temp UIImage/NSData for async setImage:.
// Released 3 frames after use so the queued async call has already run.
#define SB_PENDING_CAP 3
static uint64_t g_sbPending[SB_PENDING_CAP] = {0, 0, 0};
static int g_sbPendingIdx = 0;
static int g_sbMirrorCount = 0;

// --- helpers (statbar-style) ---

static void sb_send_rect_main(uint64_t obj, const char *selName,
                              double x, double y, double w, double h)
{
    if (!r_is_objc_ptr(obj)) return;
    double rect[4] = { x, y, w, h };
    r_msg2_main_raw(obj, selName,
                    &rect, sizeof(rect),
                    NULL, 0, NULL, 0, NULL, 0);
}

static void sb_send_double_main(uint64_t obj, const char *selName, double d)
{
    if (!r_is_objc_ptr(obj)) return;
    r_msg2_main_raw(obj, selName,
                    &d, sizeof(d),
                    NULL, 0, NULL, 0, NULL, 0);
}

// ObjC objects must be released via remote CFRelease, NEVER r_free
// (r_free = remote free() on an ObjC allocation).
static void sb_release_remote_obj(uint64_t obj)
{
    if (!r_is_objc_ptr(obj)) return;
    r_dlsym_call(R_TIMEOUT, "CFRelease", obj, 0, 0, 0, 0, 0, 0, 0);
}

// [[NSString alloc] initWithUTF8String:] → +1 owned. Caller CFReleases.
static uint64_t sb_nsstring_utf8(const char *cstr)
{
    if (!cstr) return 0;
    uint64_t buf = r_alloc_str(cstr);
    if (!buf) return 0;
    uint64_t clsNSString = r_class("NSString");
    uint64_t selAlloc = r_sel("alloc");
    uint64_t selInit = r_sel("initWithUTF8String:");
    if (!r_is_objc_ptr(clsNSString) || !selAlloc || !selInit) { r_free(buf); return 0; }
    uint64_t allocated = r_msg(clsNSString, selAlloc, 0, 0, 0, 0);
    uint64_t ns = r_is_objc_ptr(allocated)
                  ? r_msg(allocated, selInit, buf, 0, 0, 0) : 0;
    r_free(buf); // buf is malloc'd — r_free IS correct here
    return ns;
}

// --- public API ---

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    if (!g_kexploit_ready) return -1;

    NSLog(@"[SBOverlay] init remote call into SpringBoard...");

    int rc = init_remote_call_with_first_exception_timeout("SpringBoard", true, 30000);
    if (rc != 0) {
        NSLog(@"[SBOverlay] init failed rc=%d", rc);
        return -1;
    }
    NSLog(@"[SBOverlay] remote call channel established");

    uint64_t sbPid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    NSLog(@"[SBOverlay] SpringBoard pid=0x%llx", sbPid);
    if (sbPid == 0) {
        NSLog(@"[SBOverlay] getpid failed — abandoning");
        destroy_remote_call();
        return -1;
    }

    // ---- window from windowScene (NOT initWithFrame — no scene = hidden) ----
    uint64_t clsApp = r_class("UIApplication");
    if (!r_is_objc_ptr(clsApp)) { NSLog(@"[SBOverlay] UIApplication missing"); destroy_remote_call(); return -1; }
    uint64_t app = r_msg2_main(clsApp, "sharedApplication", 0,0,0,0);
    if (!r_is_objc_ptr(app)) { NSLog(@"[SBOverlay] sharedApplication nil"); destroy_remote_call(); return -1; }

    uint64_t keyWin = r_msg2_main(app, "keyWindow", 0,0,0,0);
    if (!r_is_objc_ptr(keyWin)) {
        uint64_t windows = r_msg2_main(app, "windows", 0,0,0,0);
        uint64_t count = r_is_objc_ptr(windows) ? r_msg2_main(windows, "count", 0,0,0,0) : 0;
        if (count > 0 && count < 64) keyWin = r_msg2_main(windows, "objectAtIndex:", 0,0,0,0);
    }
    if (!r_is_objc_ptr(keyWin)) { NSLog(@"[SBOverlay] keyWindow nil"); destroy_remote_call(); return -1; }

    uint64_t scene = r_msg2_main(keyWin, "windowScene", 0,0,0,0);
    if (!r_is_objc_ptr(scene)) { NSLog(@"[SBOverlay] windowScene nil"); destroy_remote_call(); return -1; }

    uint64_t clsUIWindow = r_class("UIWindow");
    uint64_t winAlloc = r_msg2_main(clsUIWindow, "alloc", 0,0,0,0);
    uint64_t win = r_msg2_main(winAlloc, "initWithWindowScene:", scene, 0,0,0);
    if (!r_is_objc_ptr(win)) { NSLog(@"[SBOverlay] initWithWindowScene failed"); destroy_remote_call(); return -1; }
    NSLog(@"[SBOverlay] window=0x%llx", win);

    // Full screen, above everything, passthrough
    uint64_t clsScreen = r_class("UIScreen");
    uint64_t screen = r_msg_main(clsScreen, r_sel("mainScreen"), 0,0,0,0);
    double bounds[4] = { 0, 0, 0, 0 };
    if (r_is_objc_ptr(screen)) {
        r_msg2_main_struct_ret(screen, "bounds", bounds, sizeof(bounds), NULL, 0, NULL, 0, NULL, 0, NULL, 0);
    }
    if (bounds[2] <= 0 || bounds[3] <= 0) { bounds[2] = 390; bounds[3] = 844; }
    sb_send_rect_main(win, "setFrame:", 0, 0, bounds[2], bounds[3]);
    sb_send_double_main(win, "setWindowLevel:", SB_OVERLAY_WIN_LEVEL);

    uint64_t clsColor = r_class("UIColor");
    if (r_is_objc_ptr(clsColor)) {
        uint64_t clear = r_msg2_main(clsColor, "clearColor", 0,0,0,0);
        if (r_is_objc_ptr(clear)) r_msg2_main(win, "setBackgroundColor:", clear, 0,0,0);
    }
    r_msg2_main(win, "setUserInteractionEnabled:", 0, 0,0,0); // passthrough
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // ---- status banner (top) ----
    uint64_t clsLabel = r_class("UILabel");
    uint64_t labelAlloc = r_msg2_main(clsLabel, "alloc", 0,0,0,0);
    uint64_t label = r_msg2_main(labelAlloc, "init", 0,0,0,0);
    if (!r_is_objc_ptr(label)) { NSLog(@"[SBOverlay] label init failed"); destroy_remote_call(); return -1; }
    sb_send_rect_main(label, "setFrame:", 0, 0, bounds[2], 60);
    r_msg2_main(label, "setTag:", SB_OVERLAY_TAG, 0,0,0);
    r_msg2_main(label, "setNumberOfLines:", 1, 0,0,0);
    r_msg2_main(label, "setTextAlignment:", 1, 0,0,0); // center
    uint64_t clsFont = r_class("UIFont");
    if (r_is_objc_ptr(clsFont)) {
        double size = 18.0;
        uint64_t font = r_msg2_main_raw(clsFont, "boldSystemFontOfSize:",
                                        &size, sizeof(size),
                                        NULL, 0, NULL, 0, NULL, 0);
        if (r_is_objc_ptr(font)) r_msg2_main(label, "setFont:", font, 0,0,0);
    }
    if (r_is_objc_ptr(clsColor)) {
        uint64_t white = r_msg2_main(clsColor, "whiteColor", 0,0,0,0);
        if (r_is_objc_ptr(white)) r_msg2_main(label, "setTextColor:", white, 0,0,0);
        uint64_t black = r_msg2_main(clsColor, "blackColor", 0,0,0,0);
        if (r_is_objc_ptr(black)) r_msg2_main(label, "setBackgroundColor:", black, 0,0,0);
    }
    NSString *initText = @"MINHDUC ESP ACTIVE";
    uint64_t textObj = sb_nsstring_utf8(initText.UTF8String);
    if (r_is_objc_ptr(textObj)) {
        r_msg2_main(label, "setText:", textObj, 0,0,0);
        sb_release_remote_obj(textObj);
    }

    // ---- fullscreen UIImageView — receives the mirrored ESP frames ----
    uint64_t clsImgView = r_class("UIImageView");
    uint64_t ivAlloc = r_msg2_main(clsImgView, "alloc", 0,0,0,0);
    double full[4] = { 0, 0, bounds[2], bounds[3] };
    uint64_t imgView = r_msg2_main_raw(ivAlloc, "initWithFrame:",
                                       &full, sizeof(full),
                                       NULL, 0, NULL, 0, NULL, 0);
    if (!r_is_objc_ptr(imgView)) { NSLog(@"[SBOverlay] imageView init failed"); destroy_remote_call(); return -1; }
    r_msg2_main(imgView, "setContentMode:", 0, 0,0,0); // scaleToFill
    r_msg2_main(imgView, "setUserInteractionEnabled:", 0, 0,0,0);

    r_msg2_main(win, "addSubview:", label, 0,0,0);
    r_msg2_main(win, "addSubview:", imgView, 0,0,0);
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // ---- retain via associated object ----
    uint64_t assocKey = r_sel("minhducSBOverlayWindow");
    if (r_is_objc_ptr(assocKey)) {
        r_dlsym_call(R_TIMEOUT, "objc_setAssociatedObject",
                     app, assocKey, win, 1, 0, 0, 0, 0);
    }

    pthread_mutex_lock(&g_sbLock);
    g_sbWindow = win;
    g_sbLabel = label;
    g_sbImgView = imgView;
    g_sbLastText = initText;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    NSLog(@"[SBOverlay] SpringBoard overlay window ACTIVE");
    return 0;
}

// Mirror one ESP_View frame into the SB-hosted UIImageView (~10fps).
// Renders the LOCAL view offscreen (CALayer renderInContext works even when
// our app is backgrounded), JPEG-compresses, uploads, async setImage:.
void SBRemotePushESPFrame(UIView *espView) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn || !r_is_objc_ptr(g_sbImgView) || !espView) {
        pthread_mutex_unlock(&g_sbLock);
        return;
    }
    pthread_mutex_unlock(&g_sbLock);

    if (++g_sbMirrorCount % 6 != 0) return; // 60fps timer → ~10fps mirror

    CGRect b = espView.bounds;
    if (b.size.width < 1 || b.size.height < 1) return;

    // Release the temp image from 3 frames ago — its async setImage: ran.
    uint64_t oldImg = g_sbPending[g_sbPendingIdx];
    if (r_is_objc_ptr(oldImg)) sb_release_remote_obj(oldImg);
    g_sbPending[g_sbPendingIdx] = 0;

    // 1. Offscreen render of the ESP_View layer tree (no render server).
    UIGraphicsBeginImageContextWithOptions(b.size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return; }
    [espView.layer renderInContext:ctx];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!img) return;

    NSData *jpg = UIImageJPEGRepresentation(img, 0.5f);
    if (!jpg || jpg.length == 0) return;

    // 2. Upload JPEG bytes into SpringBoard.
    uint64_t buf = r_dlsym_call(R_TIMEOUT, "malloc", jpg.length, 0,0,0,0,0,0,0);
    if (!buf) return;
    if (!remote_write(buf, jpg.bytes, jpg.length)) {
        r_dlsym_call(R_TIMEOUT, "free", buf, 0,0,0,0,0,0,0);
        return;
    }

    // 3. [NSData dataWithBytes:length:]
    uint64_t clsNSData = r_class("NSData");
    uint64_t dalloc = r_msg2_main(clsNSData, "alloc", 0,0,0,0);
    uint64_t data = r_is_objc_ptr(dalloc)
                    ? r_msg2_main(dalloc, "initWithBytes:length:", buf, jpg.length, 0, 0) : 0;
    r_dlsym_call(R_TIMEOUT, "free", buf, 0,0,0,0,0,0,0);
    if (!r_is_objc_ptr(data)) return;

    // 4. [UIImage imageWithData:]
    uint64_t clsUIImage = r_class("UIImage");
    uint64_t uiImg = r_is_objc_ptr(clsUIImage)
                     ? r_msg2_main(clsUIImage, "imageWithData:", data, 0,0,0) : 0;
    sb_release_remote_obj(data);
    if (!r_is_objc_ptr(uiImg)) return;

    // 5. Async setImage: (fire-and-forget). The invocation retains the
    //    image; our ring keeps our +1 until 3 frames later.
    r_msg2_main_async(g_sbImgView, "setImage:", uiImg, 0,0,0);
    g_sbPending[g_sbPendingIdx] = uiImg;
    g_sbPendingIdx = (g_sbPendingIdx + 1) % SB_PENDING_CAP;
}

void SBoardOverlaySetStatus(const char *utf8) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn || !r_is_objc_ptr(g_sbLabel)) {
        pthread_mutex_unlock(&g_sbLock);
        return;
    }
    NSString *text = utf8 ? [NSString stringWithUTF8String:utf8] : @"";
    if ([text isEqualToString:g_sbLastText]) {
        pthread_mutex_unlock(&g_sbLock);
        return;
    }
    g_sbLastText = [text copy];
    pthread_mutex_unlock(&g_sbLock);

    uint64_t textObj = sb_nsstring_utf8(text.UTF8String);
    if (r_is_objc_ptr(textObj)) {
        r_msg2_main(g_sbLabel, "setText:", textObj, 0,0,0);
        sb_release_remote_obj(textObj);
    }
}

void SBoardStopOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (!g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return; }
    if (r_is_objc_ptr(g_sbWindow)) {
        r_msg2_main(g_sbWindow, "setHidden:", 1, 0,0,0);
    }
    // release any still-retained pending images
    for (int i = 0; i < SB_PENDING_CAP; i++) {
        if (r_is_objc_ptr(g_sbPending[i])) sb_release_remote_obj(g_sbPending[i]);
        g_sbPending[i] = 0;
    }
    g_sbPendingIdx = 0;
    g_sbOverlayOn = NO;
    g_sbWindow = 0;
    g_sbLabel = 0;
    g_sbImgView = 0;
    g_sbLastText = nil;
    pthread_mutex_unlock(&g_sbLock);
    destroy_remote_call();
}
