//
//  PlatformPatch.h — self-platformize via kernel rw (no cred, no SMR panic)
//  Patches proc_ro.csflags to set CS_PLATFORM_BINARY, making our process
//  appear as a system process. This unlocks ALL private APIs:
//  SBSAccessibilityWindowHostingController, CAWindowServer, etc.
//  No entitlement needed, no cred object touched, no SMR reclaim panic.
//
#ifndef PlatformPatch_h
#define PlatformPatch_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Call AFTER kexploit_opa334() succeeds. Returns 0 on success.
int platform_patch_self(void);

// After successful patch, call this to create a system-level overlay window.
// This window renders on top of ALL apps, including the home screen.
int platform_overlay_start(void);

#ifdef __cplusplus
}
#endif
#endif