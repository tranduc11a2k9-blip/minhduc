//
//  KernelBoot.m — Fl0rk-style kernel boot with HUD-subprocess architecture
//
//  OVERLAY ARCHITECTURE (why HUD process, not in-app / not SB-remote):
//  - In-app windows (DirectOverlay): iOS hides them the moment the app is
//    backgrounded → ESP never over the game. Dead end.
//  - SB-remote windows: every variant (JPEG/vector/single-layer) crashes
//    SpringBoard after init → respring. Dead end.
//  - HUD SUBPROCESS: a child spawned with "-hud" bootstraps its OWN
//    UIApplication at system level (GSInitialize + BKSDisplayServicesStart
//    in HUDApp.mm) → its windows render above EVERY app. The HUD runs the
//    kernel exploit itself (single process touching kernel), reads the game
//    via DSMemory, draws ESP at 60fps. No remote call, no SB crash.
//
//  The main app ONLY spawns the HUD. It never runs the exploit (which would
//  double-corrupt the socket zone → panic). Killing the main app is safe —
//  it holds no corrupted kernel state.
//

#import "KernelBoot.h"
#import "../esp/hud/HUDSpawn.h"
#import <QuartzCore/QuartzCore.h>

kernel_boot_log_fn kernelBootLog = NULL;

static BOOL  g_booting   = NO;
static BOOL  g_ready     = NO;

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
        L(@"OK HUD already running.");
        return;
    }
    g_booting = YES;

    L(@"RUN 1/2 Spawning HUD overlay process");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int rc = HUDSpawnChild();
        if (rc != 0) {
            L(@"ERR HUD spawn failed (%d)", rc);
            g_booting = NO;
            return;
        }
        L(@"OK HUD process spawned.");
        L(@"OK HUD runs exploit + ESP overlay over every app.");
        L(@"DONE Open the game — HUD draws ESP on top.");
        g_ready = YES;
        g_booting = NO;
    });
}

BOOL kernelBootReady(void) { return g_ready; }
