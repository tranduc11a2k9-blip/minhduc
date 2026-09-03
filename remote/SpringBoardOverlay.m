//
//  SpringBoardOverlay.m — Fl0rk-style SpringBoard overlay
//  Uses remote_objc to create a UIWindow in SpringBoard's process.
//  Renders on top of EVERY app, no entitlement needed.
//
//  Bug fixes (cyanide statbar pattern):
//  - initWithWindowScene: (NOT initWithFrame: — windows without a scene
//    never appear on iOS 13+)
//  - UILabel subview added via addSubview: (the old version had NO subviews
//    → invisible window)
//  - CFRelease for ObjC objects (r_free = remote free() on ObjC = UAF crash)
//  - objc_setAssociatedObject to retain the window (no retain = released)
//  - Remote-call mutex: kernel r/w (early_kread64) runs in OUR process,
//    remote_objc calls SpringBoard. They don't conflict — the crash was
//    from the r_free UAF, not from "dual kernel access".
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
static NSString *g_sbLastText = nil;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

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
// (r_free = remote free() on an ObjC allocation). statbar does the same.
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

    // 30s first-exception timeout — if SpringBoard doesn't respond, abandon
    // instead of hanging the whole device.
    int rc = init_remote_call_with_first_exception_timeout("SpringBoard", true, 30000);
    if (rc != 0) {
        NSLog(@"[SBOverlay] init failed rc=%d", rc);
        return -1;
    }
    NSLog(@"[SBOverlay] remote call channel to SpringBoard established");

    // Verify channel
    uint64_t sbPid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    NSLog(@"[SBOverlay] SpringBoard pid=0x%llx", sbPid);
    if (sbPid == 0) {
        NSLog(@"[SBOverlay] getpid failed — abandoning");
        destroy_remote_call();
        return -1;
    }

    // ---- cyanide statbar pattern: window from windowScene, NOT initWithFrame ----
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
    if (!r_is_objc_ptr(clsUIWindow)) { NSLog(@"[SBOverlay] UIWindow missing"); destroy_remote_call(); return -1; }
    uint64_t winAlloc = r_msg2_main(clsUIWindow, "alloc", 0,0,0,0);
    if (!r_is_objc_ptr(winAlloc)) { NSLog(@"[SBOverlay] window alloc failed"); destroy_remote_call(); return -1; }
    uint64_t win = r_msg2_main(winAlloc, "initWithWindowScene:", scene, 0,0,0);
    if (!r_is_objc_ptr(win)) { NSLog(@"[SBOverlay] initWithWindowScene failed"); destroy_remote_call(); return -1; }
    NSLog(@"[SBOverlay] window=0x%llx (windowScene-attached)", win);

    // Full screen, above everything, passthrough
    uint64_t clsScreen = r_class("UIScreen");
    uint64_t screen = r_msg_main(clsScreen, r_sel("mainScreen"), 0,0,0,0);
    double bounds[4] = { 0, 0, 0, 0 };
    if (r_is_objc_ptr(screen)) {
        r_msg2_main_struct_ret(screen, "bounds", bounds, sizeof(bounds), NULL, 0, NULL, 0, NULL, 0, NULL, 0);
    }
    if (bounds[2] <= 0 || bounds[3] <= 0) { bounds[2] = 390; bounds[3] = 844; } // fallback
    sb_send_rect_main(win, "setFrame:", 0, 0, bounds[2], bounds[3]);
    sb_send_double_main(win, "setWindowLevel:", SB_OVERLAY_WIN_LEVEL);

    uint64_t clsColor = r_class("UIColor");
    if (r_is_objc_ptr(clsColor)) {
        uint64_t clear = r_msg2_main(clsColor, "clearColor", 0,0,0,0);
        if (r_is_objc_ptr(clear)) r_msg2_main(win, "setBackgroundColor:", clear, 0,0,0);
    }
    r_msg2_main(win, "setUserInteractionEnabled:", 0, 0,0,0); // passthrough
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // ---- content: UILabel subview (the old code had NONE → invisible) ----
    uint64_t clsLabel = r_class("UILabel");
    if (!r_is_objc_ptr(clsLabel)) { NSLog(@"[SBOverlay] UILabel missing"); destroy_remote_call(); return -1; }
    uint64_t labelAlloc = r_msg2_main(clsLabel, "alloc", 0,0,0,0);
    if (!r_is_objc_ptr(labelAlloc)) { NSLog(@"[SBOverlay] label alloc failed"); destroy_remote_call(); return -1; }
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
    r_msg2_main(win, "addSubview:", label, 0,0,0);
    r_msg2_main(win, "setHidden:", 0, 0,0,0);

    // ---- retain via associated object (cyanide pattern) ----
    uint64_t assocKey = r_sel("minhducSBOverlayWindow");
    if (r_is_objc_ptr(assocKey)) {
        r_dlsym_call(R_TIMEOUT, "objc_setAssociatedObject",
                     app, assocKey, win, 1, 0, 0, 0, 0);
    }

    pthread_mutex_lock(&g_sbLock);
    g_sbWindow = win;
    g_sbLabel = label;
    g_sbLastText = initText;
    g_sbOverlayOn = YES;
    pthread_mutex_unlock(&g_sbLock);

    NSLog(@"[SBOverlay] SpringBoard overlay window ACTIVE");
    return 0;
}

// Update the overlay text from the local process.
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
    g_sbOverlayOn = NO;
    g_sbWindow = 0;
    g_sbLabel = 0;
    g_sbLastText = nil;
    pthread_mutex_unlock(&g_sbLock);
    destroy_remote_call();
}