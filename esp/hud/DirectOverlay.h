//
//  DirectOverlay.h — kept filename for Makefile; now ESP offscreen host only.
//  No SBSAccessibility / no in-app all-apps overlay. Drawing goes to SpringBoard.
//
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

// Starts a HIDDEN local ESP_View host (GCD timer + SBRemotePushESPFrame).
// Does NOT register SBSAccessibility. Does NOT show over other apps itself.
int StartESPHost(void);

// Deprecated alias — maps to StartESPHost. Do not use for "direct overlay".
int StartDirectOverlay(void);

#ifdef __cplusplus
}
#endif
