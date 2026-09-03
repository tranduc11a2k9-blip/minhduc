
#import "HUDMainWindow.h"

@implementation HUDMainWindow

// All overrides REMOVED (was _isSystemWindow=YES/_isWindowServerHostingManaged=NO):
// on a sideloaded app those flags made the window server skip rendering the
// window entirely — ESP was invisible even in the app's own foreground.
// A plain UIWindow with a high windowLevel renders fine while foregrounded.

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Pass through empty HUD chrome so game (other process / below) is not blocked
    // by full-screen transparent layers under CLEAR / player count text.
    if (!hit || hit == self) return nil;
    if (hit == self.rootViewController.view) return nil;
    return hit;
}

@end
