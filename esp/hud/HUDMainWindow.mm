
#import "HUDMainWindow.h"

@implementation HUDMainWindow

+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)_isSecure { return YES; }
- (BOOL)_shouldCreateContextAsSecure { return YES; }

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Pass through empty HUD chrome so game (other process / below) is not blocked
    // by full-screen transparent layers under CLEAR / player count text.
    if (!hit || hit == self) return nil;
    if (hit == self.rootViewController.view) return nil;
    return hit;
}

@end
