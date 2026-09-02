//
//  KernelBoot.h — Fl0rk-style 6-step kernel boot, callable from UI
//
#import <Foundation/Foundation.h>

// UI log callback — set this before calling kernelBootStart.
// Called on main thread with each log line ( Fl0rk console style).
typedef void (*kernel_boot_log_fn)(NSString *line);
extern kernel_boot_log_fn kernelBootLog;

// Returns immediately; runs boot on background queue.
// Stages logged: 1/6..6/6 like Fl0rk.
#ifdef __cplusplus
extern "C" {
#endif
void kernelBootStart(void);
BOOL kernelBootReady(void);
#ifdef __cplusplus
}
#endif
