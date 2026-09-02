//
//  DirectOverlay.m — Starts full-screen system overlay in current app session
//  Registers HUDMainWindow with SBSAccessibilityWindowHostingController (Level 10000010.0)
//  so it stays on top of ALL APPS, HOME SCREEN, and GAME permanently.
//
#import "DirectOverlay.h"
#import "HUDMainWindow.h"
#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"
#import "../esp/esp.h"
#import "../esp/ESPPrefs.h"
#import "../esp/GameOffsets.h"
#import "../esp/menu.h"
#import "../esp/pid.h"
#import "UIView+SecureView.h"
#import "../../app/KeepAlive.h"
#import <objc/runtime.h>

static HUDMainWindow *g_systemWindow = nil;
static SBSAccessibilityWindowHostingController *g_hostingController = nil;

@interface DirectPassThroughView : UIView
@end
@implementation DirectPassThroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil;
    return hit;
}
@end

@interface DirectLandscapeVC : UIViewController
@end
@implementation DirectLandscapeVC
- (void)loadView {
    self.view = [[DirectPassThroughView alloc] initWithFrame:CGRectZero];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (BOOL)shouldAutorotate { return YES; }
@end

int StartDirectOverlay(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_systemWindow) return;

        // 1. Start audio background keepalive so overlay never sleeps
        [[KeepAlive shared] start];

        // 2. Load prefs
        ESPPrefsSync();
        ESPSyncFromPrefs();
        GameOffsetsReload();

        // 3. Build UI
        DirectLandscapeVC *vc = [[DirectLandscapeVC alloc] init];
        CGRect screen = [UIScreen mainScreen].bounds;

        ESP_View *espView = [[ESP_View alloc] initWithFrame:screen];
        espView.backgroundColor = [UIColor clearColor];
        espView.userInteractionEnabled = NO;
        [vc.view addSubview:espView];

        MenuView *menuView = [[MenuView alloc] initWithFrame:screen];
        menuView.userInteractionEnabled = YES;
        [vc.view addSubview:menuView];

        // 4. Create System Window (Level 10000010.0 -> above everything on iOS!)
        g_systemWindow = [[HUDMainWindow alloc] initWithFrame:screen];
        g_systemWindow.rootViewController = vc;
        g_systemWindow.backgroundColor = [UIColor clearColor];
        g_systemWindow.windowLevel = 10000010.0;
        g_systemWindow.hidden = NO;
        g_systemWindow.userInteractionEnabled = YES;
        [g_systemWindow makeKeyAndVisible];

        // 5. Register with SpringBoard Accessibility Window Hosting Controller
        Class hostingClass = objc_getClass("SBSAccessibilityWindowHostingController");
        g_hostingController = hostingClass ? [[hostingClass alloc] init] : nil;
        SEL registerSel = NSSelectorFromString(@"registerWindowWithContextID:atLevel:");
        SEL contextSel = NSSelectorFromString(@"_contextId");

        if (g_hostingController && [g_hostingController respondsToSelector:registerSel] && [g_systemWindow respondsToSelector:contextSel]) {
            unsigned int ctxId = 0;
            NSMethodSignature *sig = [g_systemWindow methodSignatureForSelector:contextSel];
            if (sig) {
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:g_systemWindow];
                [inv setSelector:contextSel];
                [inv invoke];
                [inv getReturnValue:&ctxId];
                if (ctxId != 0) {
                    double lvl = [g_systemWindow windowLevel];
                    NSMethodSignature *regSig = [g_hostingController methodSignatureForSelector:registerSel];
                    if (regSig) {
                        NSInvocation *regInv = [NSInvocation invocationWithMethodSignature:regSig];
                        [regInv setTarget:g_hostingController];
                        [regInv setSelector:registerSel];
                        [regInv setArgument:&ctxId atIndex:2];
                        [regInv setArgument:&lvl atIndex:3];
                        [regInv invoke];
                        NSLog(@"[Overlay] Registered context %u with SpringBoard Level %f", ctxId, lvl);
                    }
                }
            }
        }

        NSLog(@"[Overlay] Direct System Overlay started on full screen!");
    });
    return 0;
}
