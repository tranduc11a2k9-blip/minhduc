//
//  SpringBoardOverlay.h — Fl0rk-style SpringBoard overlay
//  Uses init_remote_call_with_first_exception_timeout + remote_objc to create
//  a UIWindow inside SpringBoard's process — renders on top of EVERY app.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Call AFTER kexploit_opa334(). Returns 0 on success.
int SBoardStartOverlay(void);
void SBoardStopOverlay(void);

#ifdef __cplusplus
}
#endif
