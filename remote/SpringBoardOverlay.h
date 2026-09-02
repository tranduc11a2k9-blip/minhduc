//
//  SpringBoardOverlay.h — remote SpringBoard overlay (Fl0rk-style)
//  Uses kernel rw + remote thread call to make SPRINGBOARD itself create a
//  full-screen overlay window. Because SpringBoard owns the compositor, the
//  window sits above EVERY app (Free Fire, Home, anything) permanently —
//  no entitlement needed, no child process needed.
//
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Call AFTER kexploit + sandbox_escape. Returns 0 on success.
int SBoardStartOverlay(void);
void SBoardStopOverlay(void);

#ifdef __cplusplus
}
#endif
