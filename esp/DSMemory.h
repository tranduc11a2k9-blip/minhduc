//
//  DSMemory.h — DarkSword-style memory provider for Free Fire
//  Reads another process's memory through kernel rw (kread64/kreadbuf).
//  No task port needed — works on jailed IPA.
//
//  Architecture:
//    app (this IPA)  --kernel rw-->  FF process vm_map entries
//    1. find FF proc by name (proc_find_by_name)
//    2. proc → proc_ro → pr_task → task → map
//    3. walk vm_map_entry list → find FF's module base (dyld text)
//    4. kread64/kreadbuf anywhere in FF's address space
//

#ifndef DSMemory_h
#define DSMemory_h

#import <Foundation/Foundation.h>
#import <stdint.h>
#import <mach/mach.h>

#ifdef __cplusplus
extern "C" {
#endif

// returns 0 on success; sets g_ff_proc, g_ff_task, g_ff_map, g_ff_base
int  ds_attach(void);
void ds_detach(void);

bool ds_attached(void);

// --- address space primitives (all through kernel rw) ---

// translate a FF user-space VA to kernel pointer (map entry lookup)
// caches last hit entry for speed
uint64_t ds_va_to_kaddr(uint64_t va);

// raw reads — take FF user-space VA directly
bool     ds_read(uint64_t va, void *buf, size_t len);
uint8_t  ds_read8 (uint64_t va);
uint16_t ds_read16(uint64_t va);
uint32_t ds_read32(uint64_t va);
uint64_t ds_read64(uint64_t va);
float    ds_readf (uint64_t va);

// pointer read + PAC strip (user-space, xpaci enough for arm64e userland)
uint64_t ds_readptr(uint64_t va);

bool     ds_read_str(uint64_t va, char *out, size_t maxlen);

// module base of FF main binary
uint64_t ds_base(void);
pid_t    ds_pid(void);
mach_port_t ds_task_port(void);

// DarkSword core: translate one user page to kernel physmap address
uint64_t ds_translate_page(uint64_t page_va);
bool     ds_write(uint64_t va, const void *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* DSMemory_h */
