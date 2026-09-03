//
//  SpringBoardOverlay.m — SpringBoard-hosted overlay, NO remote call.
//
//  Team feedback: drawing in SpringBoard via remote_objc WHILE the cheat
//  reads/writes kernel memory crashes (dual kernel access) and lags
//  (waiting for remote-call responses).
//
//  So SBoardStartOverlay() now IS StartDirectOverlay(): the in-app system
//  window (HUDMainWindow at level 10000010.0) registered with
//  SBSAccessibilityWindowHostingController renders above EVERY app
//  (including games) with NO remote call into SpringBoard. All rendering
//  (ESP_View) and kernel r/w (DSMemory) stay in OUR process.
//
//  This API name is kept for compatibility with KernelBoot's boot log
//  ("SpringBoard remote overlay") — the mechanism is fully local now.
//
#import "SpringBoardOverlay.h"
#import "../esp/hud/DirectOverlay.h"
#import <pthread.h>

#define SB_OVERLAY_WIN_LEVEL 10000010.0

static BOOL g_sbOverlayOn = NO;
static pthread_mutex_t g_sbLock = PTHREAD_MUTEX_INITIALIZER;

int SBoardStartOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    if (g_sbOverlayOn) { pthread_mutex_unlock(&g_sbLock); return 0; }
    pthread_mutex_unlock(&g_sbLock);

    // Local in-app system overlay: HUDMainWindow (level 10000010.0) +
    // SBSAccessibilityWindowHostingController registration. Stays above the
    // game, passthrough touches, ESP renders locally via kernel r/w.
    // (DirectOverlay.h also declares a local StartDirectOverlay() — this
    //  wrapper keeps the SBoard* API surface stable for KernelBoot.)
    int ret = StartDirectOverlay();

    pthread_mutex_lock(&g_sbLock);
    g_sbOverlayOn = (ret == 0);
    pthread_mutex_unlock(&g_sbLock);

    NSLog(@"[SBOverlay] SpringBoard-hosted overlay %@ (local render)",
          g_sbOverlayOn ? @"ACTIVE" : @"FAILED");
    return ret;
}

// No remote text updates — ESP_View renders locally. Kept for API compat.
void SBoardOverlaySetStatus(const char *utf8) {
    (void)utf8;
}

void SBoardStopOverlay(void) {
    pthread_mutex_lock(&g_sbLock);
    g_sbOverlayOn = NO;
    pthread_mutex_unlock(&g_sbLock);
}
