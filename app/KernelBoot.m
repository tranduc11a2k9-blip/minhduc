//
//  KernelBoot.m — Fl0rk-style kernel boot
//
//  Main app executes kexploit and hosts offscreen ESP data source.
//  SpringBoard hosts a dedicated pass-through UIWindow (level 999999.0)
//  with dual ping-pong CGPaths for 60fps-like 20 FPS smooth render over Free Fire.
//

#import "KernelBoot.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <unistd.h>
#import "../kexploit/kexploit_opa334.h"
#import "../kexploit/kutils.h"
#import "../sandbox_escape.h"
#import "../esp/DSMemory.h"
#import "../remote/SpringBoardOverlay.h"
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

void kernelBootStart(void) {
    if (g_booting) return;
    if (g_ready) {
        L(@"OK Already booted — re-establishing overlay.");
        [[KeepAlive shared] start];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            SBoardStartOverlay();
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            extern int StartDirectOverlay(void);
            StartDirectOverlay();
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

        uint64_t self_proc = proc_self();
        int sret = sandbox_escape(self_proc);
        L(sret == 0 ? @"OK Sandbox escaped (R+W filesystem)."
                    : @"WARN sandbox_escape returned %d", sret);

        L(@"RUN 4/6 Initializing Background KeepAlive");
        [[KeepAlive shared] start];
        L(@"OK KeepAlive started.");

        L(@"RUN 5/6 Opening SpringBoard dedicated overlay (staged)");
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            static const int delays[] = {3, 2, 3, 4}; // cumulative: 3s, 5s, 8s, 12s
            for (int attempt = 0; attempt < 4; attempt++) {
                sleep(delays[attempt]);
                int sbret = SBoardStartOverlay();
                if (sbret == 0) {
                    NSLog(@"[BOOT] SpringBoard dedicated overlay established on attempt %d", attempt + 1);
                    break;
                }
                NSLog(@"[BOOT] SpringBoard overlay attempt %d failed rc=%d", attempt + 1, sbret);
            }
        });
        L(@"OK SpringBoard session pending (background).");

        L(@"RUN 6/6 Starting ESP renderer (offscreen host)");
        dispatch_async(dispatch_get_main_queue(), ^{
            extern int StartDirectOverlay(void);
            StartDirectOverlay();
            dispatch_async(dispatch_get_main_queue(), ^{
                Class hudWinCls = objc_getClass("HUDMainWindow");
                for (UIWindow *w in [UIApplication sharedApplication].windows) {
                    if ([w isKindOfClass:hudWinCls]) {
                        w.alpha = 0.0;
                        w.hidden = NO;
                        w.userInteractionEnabled = NO;
                    }
                }
                NSLog(@"[BOOT] in-app host window hidden — ESP mirrors to SpringBoard");
            });
        });
        L(@"OK ESP active (mirroring to SpringBoard over all apps).");
        g_ready = YES;
        g_booting = NO;
    });
}

BOOL kernelBootReady(void) { return g_ready; }
