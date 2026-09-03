//
//  SpringBoardOverlay.m — Fl0rk-style SpringBoard overlay
//  Uses init_remote_call_with_first_exception_timeout (avoids hang/watchdog)
//  + remote_objc to create a UIWindow inside SpringBoard's own process.
//  Renders on top of EVERY app, no entitlement needed.
//
#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "../../kexploit/kexploit_opa334.h"
#import "../../kexploit/kutils.h"
#import <UIKit/UIKit.h>
#import <pthread.h>
#import <string.h>

static BOOL g_sbOverlayOn = NO;

int SBoardStartOverlay(void) {
    if (g_sbOverlayOn) return 0;
    if (!g_kexploit_ready) return -1;

    NSLog(@"[SBOverlay] init remote call into SpringBoard (30s timeout)...");

    // 30s first-exception timeout — if SpringBoard doesn't respond, abandon
    // instead of hanging the whole device (this was the watchdog panic cause).
    int rc = init_remote_call_with_first_exception_timeout("SpringBoard", true, 30000);
    if (rc != 0) {
        NSLog(@"[SBOverlay] init failed rc=%d", rc);
        return -1;
    }
    NSLog(@"[SBOverlay] remote call channel to SpringBoard established");

    // Verify channel: getpid() remote call must return SpringBoard's pid.
    uint64_t sbPid = do_remote_call_stable(5000, "getpid", 0,0,0,0,0,0,0,0);
    NSLog(@"[SBOverlay] SpringBoard pid=0x%llx", sbPid);
    if (sbPid == 0) {
        NSLog(@"[SBOverlay] getpid failed — abandoning");
        destroy_remote_call();
        return -1;
    }

    // Create a UIWindow in SpringBoard's process at the highest level.
    // remote_objc: [[UIWindow alloc] initWithFrame:mainScreen.bounds]
    uint64_t clsUIWindow  = r_class("UIWindow");
    uint64_t clsUIScreen  = r_class("UIScreen");
    uint64_t selMainScreen = r_sel("mainScreen");
    uint64_t selAlloc     = r_sel("alloc");
    uint64_t selInitWithFrame = r_sel("initWithFrame:");
    uint64_t selSetWindowLevel = r_sel("setWindowLevel:");
    uint64_t selSetHidden  = r_sel("setHidden:");
    uint64_t selMakeKeyAndVisible = r_sel("makeKeyAndVisible");
    uint64_t selSetUserInteractionEnabled = r_sel("setUserInteractionEnabled:");
    uint64_t selSetBackgroundColor = r_sel("setBackgroundColor:");

    uint64_t screen = r_msg_main(clsUIScreen, selMainScreen, 0,0,0,0);
    uint64_t bounds[4];
    if (!r_msg2_main_struct_ret(screen, "bounds", bounds, sizeof(bounds), 0,0,0,0,0,0,0,0)) {
        NSLog(@"[SBOverlay] bounds failed");
        destroy_remote_call();
        return -1;
    }

    uint64_t win = r_msg_main(clsUIWindow, selAlloc, 0,0,0,0);
    win = r_msg_main(win, selInitWithFrame, (uint64_t)bounds, (uint64_t)bounds+8, (uint64_t)bounds+16, (uint64_t)bounds+24);
    NSLog(@"[SBOverlay] window=0x%llx", win);

    // windowLevel = 10000000.0f (above everything)
    uint64_t levelBits;
    double level = 10000000.0;
    memcpy(&levelBits, &level, 8);
    r_msg_main(win, selSetWindowLevel, levelBits, 0,0,0);
    r_msg_main(win, selSetHidden, 0, 0,0,0); // hidden = NO
    r_msg_main(win, selSetUserInteractionEnabled, 0, 0,0,0); // NO — passthrough
    r_msg_main(win, selSetBackgroundColor, 0, 0,0,0); // clear
    r_msg_main(win, selMakeKeyAndVisible, 0,0,0,0);

    g_sbOverlayOn = (win != 0);
    NSLog(@"[SBOverlay] SpringBoard overlay window %@", g_sbOverlayOn ? @"ACTIVE" : @"FAILED");
    return g_sbOverlayOn ? 0 : -1;
}

void SBoardStopOverlay(void) {
    if (g_sbOverlayOn) {
        destroy_remote_call();
        g_sbOverlayOn = NO;
    }
}
