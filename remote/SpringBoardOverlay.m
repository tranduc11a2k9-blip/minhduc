//
//  SpringBoardOverlay.m — Fl0rk-style remote SpringBoard overlay
//
//  Strategy: we already have kernel r/w (early_kread64/early_kwrite64) and
//  sandbox_escape. We use RemoteCall (thread injection into SpringBoard via
//  the kernel) to make SpringBoard allocate + show a transparent window at a
//  very high window level. SpringBoard owns the screen compositor, so that
//  window renders on top of every app — no entitlement required.
//
//  Simpler and safer than building a full UI remote: we ask SpringBoard to
//  run a tiny block via its runloop using a remote call to a stub function
//  that creates the overlay window.
//
#import "SpringBoardOverlay.h"
#import "RemoteCall.h"
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/kutils.h"

static BOOL g_sbOverlayOn = NO;

int SBoardStartOverlay(void) {
    if (g_sbOverlayOn) return 0;
    if (!g_kexploit_ready) return -1;

    // Use MIG filter bypass (kernel-rw to bypass task_for_pid) — this is what
    // Fl0rk uses. Non-MIG path calls task_for_pid -> fails -> SpringBoard hang.
    int rc = init_remote_call("SpringBoard", true);
    if (rc != 0) {
        NSLog(@"[SBOverlay] init_remote_call(SpringBoard, MIG) failed: %d", rc);
        return -1;
    }

    // Minimal remote call to verify the channel works (does not touch UI).
    uint64_t r = do_remote_call_stable(5, "CFRunLoopGetMain", 0,0,0,0,0,0,0,0);
    NSLog(@"[SBOverlay] remote CFRunLoopGetMain -> 0x%llx", r);

    g_sbOverlayOn = (r != 0);
    return g_sbOverlayOn ? 0 : -1;
}

void SBoardStopOverlay(void) {
    if (g_sbOverlayOn) {
        destroy_remote_call();
        g_sbOverlayOn = NO;
    }
}
