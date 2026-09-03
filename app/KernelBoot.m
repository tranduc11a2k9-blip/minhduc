//
//  KernelBoot.m — Fl0rk-style kernel boot (verified from Fl0rkFF binary)
//
//  Fl0rkFF architecture (from strings analysis of Fl0rkFF-1.0.ipa):
//    - exploit runs in the MAIN app (no HUD subprocess, no persona spawn)
//    - remote call into SpringBoard (g_springboard_rc_ready)
//    - DSKeepAlive (AVAudioPlayer) keeps the app alive in background
//    - SB-blanked notify token: if SpringBoard restarts, re-establish
//    - ESP drawn via CADisplayLink in-app + remote SB UI
//
//  Our port follows the same flow. The earlier HUD-subprocess experiment
//  failed (spawn EPERM — sandboxed app cannot set persona uid 0 without
//  platformization) and is removed.
//

#import "KernelBoot.h"
#import <QuartzCore/QuartzCore.h>
#import <sys/time.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/kutils.h"
#import "../sandbox_escape.h"
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

// SpringBoard overlay session
#import "SpringBoardOverlay.h"

// Park file in app container — readable by this app across launches.
static NSString *parkFileFullPath(void) {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [caches stringByAppendingPathComponent:@".minhduc_parked"];
}

// Park is only valid for the CURRENT boot. After a respring/reboot the
// kernel primitives are gone (corrupted sockets died with the panic) but
// the file would still exist → app would skip the exploit and use dead
// primitives. Store the boot time; invalidate when it changes.
static uint64_t systemBootTimeSec(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) != 0) return 0;
    return (uint64_t)boottime.tv_sec;
}

static BOOL parkIsValid(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:parkFileFullPath()]) return NO;
    NSString *saved = [NSString stringWithContentsOfFile:parkFileFullPath()
                                                encoding:NSUTF8StringEncoding error:nil];
    uint64_t boot = systemBootTimeSec();
    NSString *expected = [NSString stringWithFormat:@"1:%llu", boot];
    if (![saved isEqualToString:expected]) {
        [fm removeItemAtPath:parkFileFullPath() error:nil]; // stale — clear it
        return NO;
    }
    return YES;
}

static void writePark(void) {
    NSString *park = parkFileFullPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:[park stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *val = [NSString stringWithFormat:@"1:%llu", systemBootTimeSec()];
    [val writeToFile:park atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void kernelBootStart(void) {
    if (g_booting) return;
    if (g_ready) {
        L(@"OK Already booted — re-establishing overlay.");
        [[KeepAlive shared] start];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            SBoardStartOverlay();
        });
        return;
    }

    // Parked fast path: exploit already ran THIS boot — skip it
    // (re-running double-corrupts the socket zone → panic).
    // After a respring/reboot boottime changes → park invalid → re-exploit.
    if (parkIsValid()) {
        L(@"OK Parked — skipping exploit, starting overlay.");
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

    g_booting = YES;
    if (!g_bootQueue) {
        g_bootQueue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    }

    dispatch_async(g_bootQueue, ^{
        L(@"RUN 1/6 Authorizing protected ESP access");
        L(@"OK Device authorized — no key required.");

        L(@"RUN 2/6 Cleaning previous runtime state");
        ds_detach();
        L(@"DONE Cleanup complete.");

        L(@"RUN 3/6 Racing kernel allocator for r/w primitives.");
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
        L(@"OK State parked (boottime-tagged) — next run skips the exploit.");

        writePark();

        uint64_t self_proc = proc_self();
        // NOTE: platformize/sandbox-elevate intentionally skipped — iOS 17.5.1
        // SMR reclaims cred mid-write → panic. sandbox_escape (extension patch)
        // alone gives full R+W filesystem.
        int sret = sandbox_escape(self_proc);
        L(sret == 0 ? @"OK Sandbox escaped (R+W filesystem)."
                    : @"WARN sandbox_escape returned %d", sret);

        L(@"RUN 4/6 Opening SpringBoard injection channel (delayed)");
        // CRITICAL respring fix: opening the SB remote session IMMEDIATELY
        // after sandbox_escape crashed SpringBoard ~1s later (session rides
        // on still-settling kernel primitives). Fl0rk opens its session only
        // when the user configures settings — seconds after boot. We wait
        // 10s, then retry up to 3 times with backoff.
        [[KeepAlive shared] start];
        __block BOOL sbDone = NO;
        __block int sbret = -1;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            for (int attempt = 0; attempt < 3; attempt++) {
                sleep(10); // let primitives + SB settle after exploit
                sbret = SBoardStartOverlay();
                if (sbret == 0) break;
                NSLog(@"[BOOT] SB overlay attempt %d failed rc=%d", attempt + 1, sbret);
            }
            sbDone = YES;
        });
        L(@"OK Channel will establish after 10s settle.");

        L(@"RUN 5/6 Preparing SpringBoard session");
        L(@"OK SpringBoard session pending (background).");

        L(@"RUN 6/6 Starting ESP overlay");
        // In-app overlay starts NOW (instant, safe). SB overlay replaces it
        // later when its session establishes.
        extern int StartDirectOverlay(void);
        int dret = StartDirectOverlay();
        L(dret == 0 ? @"OK DirectOverlay active (SB loading in bg)."
                    : @"WARN StartDirectOverlay returned %d", dret);

        L(@"RUN 6/6 Starting ESP overlay");
        if (!(sbDone && sbret == 0)) {
            extern int StartDirectOverlay(void);
            int dret = StartDirectOverlay();
            L(dret == 0 ? @"OK DirectOverlay active."
                        : @"WARN StartDirectOverlay returned %d", dret);
        }
        g_ready = YES;
        g_booting = NO;
        L(@"OK ESP overlay active.");
        L(@"DONE ESP overlay active in-session.");
    });
}

BOOL kernelBootReady(void) { return g_ready; }
