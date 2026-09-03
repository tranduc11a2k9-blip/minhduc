//
//  SpringBoardOverlay.h — Fl0rk-style SpringBoard overlay
//  cyanide statbar pattern: windowScene-attached UIWindow + UILabel subview,
//  retained via objc_setAssociatedObject. Renders on top of EVERY app.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Call AFTER kexploit_opa334(). Returns 0 on success.
int SBoardStartOverlay(void);
void SBoardStopOverlay(void);
// Update the overlay label text (statbar-style, safe from any thread).
void SBoardOverlaySetStatus(const char *utf8);

#ifdef __cplusplus
}
#endif
