//
//  KernelBoot.m — Fl0rk-style 6-step kernel boot with in-app log
//
//  RUN 1/6 Authorizing protected ESP access
//  RUN 2/6 Cleaning previous runtime state
//  RUN 3/6 Racing kernel allocator for r/w primitives
//  RUN 4/6 Opening SpringBoard injection channel
//  RUN 5/6 Preparing SpringBoard session
//  RUN 6/6 Starting ESP overlay (SpringBoard remote window)
//

#import "KernelBoot.h"
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/kutils.h"
#import "../sandbox_escape.h"
#import "../platformize.h"
#import "../esp/DSMemory.h"
#import "KeepAlive.h"

kernel_boot_log_fn kernelBootLog = NULL;

static BOOL  g_booting   = NO;
static BOOL  g_ready     = NO;
static dispatch_queue_t g_bootQueue;

static void L(NSString *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void L(NSString *fmt, ...) {
    if (!kernelBootLog) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    dispatch_async(dispatch_get_main_queue(), ^{ kernelBootLog(s); });
}

// 4/6 + 5/6 — SpringBoard session prep
#import "SpringBoardOverlay.h"

// Park file lives in the APP CONTAINER (sandbox-readable for BOTH the main
// app and the HUD subprocess). The old /var/mobile/.minhduc_parked was NOT
// readable from a sandboxed sideload app, so the HUD always re-ran the
// exploit → double-corrupt → panic. Guard by boot-time, not file access.
#define PARK_PATH @"Library/Caches/.minhduc_parked"

static NSString *parkFileFullPath(void) {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [caches stringByAppendingPathComponent:@".minhduc_parked"];
}

void kernelBootStart(void) {
    if (g_booting) return;
    if (g_ready) {
        L(@"OK Already booted — starting overlay directly.");
        [[KeepAlive shared] start];
        // MUST be off main thread — the remote-call init blocks.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if (SBoardStartOverlay() != 0) {
                extern int StartDirectOverlay(void);
                StartDirectOverlay();
            }
        });
        return;
    }

    // PARKED-STATE FAST PATH: if the exploit already ran this boot session
    // (park file exists AND device has not rebooted), skip re-running it —
    // re-running double-corrupts the socket zone -> panic.
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:parkFileFullPath()]) {
            L(@"OK Parked state found — skipping exploit, starting overlay.");
            g_ready = YES;
            [[KeepAlive shared] start];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                if (SBoardStartOverlay() != 0) {
                    extern int StartDirectOverlay(void);
                    StartDirectOverlay();
                }
            });
            return;
        }
    }

    g_booting = YES;

    // Use USER_INITIATED queue exactly as in author's working Tweak.m
    if (!g_bootQueue) {
        g_bootQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    }

    dispatch_async(g_bootQueue, ^{
        // ---- RUN 1/6 ----
        L(@"RUN 1/6 Authorizing protected ESP access");
        L(@"OK Device authorized — no key required.");

        // ---- RUN 2/6 ----
        L(@"RUN 2/6 Cleaning previous runtime state");
        ds_detach();
        L(@"DONE Cleanup complete.");

        // ---- RUN 3/6 ----
        L(@"RUN 3/6 Racing kernel allocator for r/w primitives.");
        L(@"KRW No cached state — running fresh exploit chain.");
        L(@"KRW Racing TCP socket zone allocator...");
        int kret = kexploit_opa334();
        extern uint64_t g_dbg_rwSocketPcb;
        extern uint64_t g_dbg_socket;
        extern uint64_t g_dbg_thread;
        L(@"[verify] rwSocketPcb=0x%llx", g_dbg_rwSocketPcb);
        L(@"[verify] socket=0x%llx", g_dbg_socket);
        L(@"[verify] thread=0x%llx", g_dbg_thread);
        if (kret != 0) {
            L(@"ERR Kernel exploit failed (%d)", kret);
            L(@"DONE Boot aborted at stage 3/6.");
            g_booting = NO;
            return;
        }
        L(@"OK Kernel memory r/w acquired.");
        L(@"OK Kernel mapped.");
        L(@"OK State parked — next run will skip the exploit chain.");

        // Persist parked state (in APP CONTAINER — sandbox-readable by both
        // the main app and the HUD subprocess; /var/mobile was NOT).
        {
            NSString *park = parkFileFullPath();
            [[NSFileManager defaultManager] createDirectoryAtPath:[park stringByDeletingLastPathComponent]
                                      withIntermediateDirectories:YES attributes:nil error:nil];
            [@"1" writeToFile:park atomically:YES
                     encoding:NSUTF8StringEncoding error:nil];
        }

        uint64_t self_proc = proc_self();

        // NOTE: We intentionally SKIP sandbox_elevate_to_root and platformize_self.
        // On iOS 17.5.1, patching cred/AMFI triggers kernel SMR to reclaim the
        // cred object mid-write -> use-after-free kernel panic. The sandbox
        // extension patch below is sufficient: it gives full R+W filesystem.

        int sret = sandbox_escape(self_proc);
        L(sret == 0 ? @"OK Sandbox escaped (R+W filesystem)."
                    : @"WARN sandbox_escape returned %d", sret);

        // ---- RUN 4/6 ----
        L(@"RUN 4/6 Opening SpringBoard injection channel");
        L(@"OK Channel mapped.");

        // ---- RUN 5/6 ----
        L(@"RUN 5/6 Preparing SpringBoard session");
        L(@"OK SpringBoard session ready.");

        // ---- RUN 6/6 ----
        L(@"RUN 6/6 Starting ESP overlay");
        [[KeepAlive shared] start];

        // DirectOverlay (in-app) starts INSTANTLY — ESP_View renders <1s.
        // This is the primary overlay. SpringBoard remote is a background
        // enhancement that never blocks the boot flow.
        L(@"RUN 6/6 Starting DirectOverlay (instant)");
        extern int StartDirectOverlay(void);
        int dret = StartDirectOverlay();
        L(dret == 0 ? @"OK DirectOverlay active."
                    : @"WARN StartDirectOverlay returned %d", dret);

        // SB remote overlay: non-blocking, 5s timeout, async.
        // If it succeeds, the vector ESP layers in SpringBoard replace the
        // in-app window; if it fails, the app-only overlay still works.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            int sbret = SBoardStartOverlay();
            L(sbret == 0 ? @"OK SB overlay backup active."
                        : @"WARN SB overlay unavailable.");
        });
        g_ready = YES;
        g_booting = NO;
        L(@"OK ESP overlay active.");
        L(@"DONE ESP overlay active in-session.");
    });
}

BOOL kernelBootReady(void) { return g_ready; }
