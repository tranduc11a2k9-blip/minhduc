
#import "HUDMainWindow.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
// NOT secure — _isSecure=YES made iOS 17+ hide this window entirely
// (secure windows are only composited into the secure display path).
- (BOOL)_isSecure { return NO; }
- (BOOL)_shouldCreateContextAsSecure { return NO; }

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Pass through empty HUD chrome so game (other process / below) is not blocked
    // by full-screen transparent layers under CLEAR / player count text.
    if (!hit || hit == self) return nil;
    if (hit == self.rootViewController.view) return nil;
    return hit;
}

@end
