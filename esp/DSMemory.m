//
//  DSMemory.m — DarkSword-style memory provider (Fl0rk mechanism)
//
//  Kernel r/w direct — NO task port, NO mach APIs on target.
//
//  Chain:
//    FF proc → task → vm_map → header → entry list
//    entry: links.next, start(0x10), end(0x18), vme_object_or_delta(0x3c)
//    vm_object: vo_un1.vou_size (page tree), ref_count
//
//  Page translation (user VA → kernel data):
//    1. find map entry containing VA
//    2. offset_in_object = VA - entry.start + object.vo_offset
//    3. vm_page lookup in object's memq: page->offset == offset & ~PAGE_MASK
//    4. page → physical address → kernel physmap base + pa
//    5. kreadbuf/kwritebuf at physmap address
//
//  Fallback: if page lookup misses (paged out), return failure — caller retries.
//

#import "DSMemory.h"
#import "../kexploit/kexploit_opa334.h"
#import "../app/KernelBoot.h" // kernelBootLog (diag to Home log card)
#import "../remote/VM.h"      // vm_map_remote_page — the WORKING page remap (lara/cyanide path)
#import "../kexploit/krw.h"
#import "../kexploit/kutils.h"
#import "../kexploit/offsets.h"
#import "../kexploit/xpaci.h"

#import <mach/mach.h>
#import <sys/sysctl.h>

// xnu page size on arm64 — guard against system header macros
#ifndef PAGE_SHIFT
#define PAGE_SHIFT 14
#endif
#ifndef PAGE_SIZE
#define PAGE_SIZE  (1 << PAGE_SHIFT)
#endif
#ifndef PAGE_MASK
#define PAGE_MASK  (PAGE_SIZE - 1)
#endif

extern uint64_t early_kread64(uint64_t where);

static uint64_t g_ff_proc = 0;
static uint64_t g_ff_task = 0;
static uint64_t g_ff_map  = 0; // target's vm_map — used with vm_map_remote_page
static pid_t    g_ff_pid  = 0;
static uint64_t g_ff_base = 0;

// entry cache — most reads hit same entry repeatedly
static uint64_t g_cached_entry      = 0;
static uint64_t g_cached_start      = 0;
static uint64_t g_cached_end        = 0;
static uint64_t g_cached_object     = 0;
static uint64_t g_cached_obj_offset = 0;

#define S(x) ({ uint64_t _v = xpaci((uint64_t)(x)); \
    ((_v >> 32) > 0xFFFF ? (_v | pac_mask) : _v); })
#define K(x) ((x) > VM_MIN_KERNEL_ADDRESS)

// vm_map_entry field offsets relative to links.next
// xnu: struct vm_map_entry { vm_map_links_t links; ... }
//   links.next   = +0x00
//   links.prev   = +0x08
//   links.start  = +0x10
//   links.end    = +0x18
#define E_START    0x10
#define E_END      0x18
#define E_OBJECT   off_vm_map_entry_vme_object_or_delta
#define E_ALIAS    off_vm_map_entry_vme_alias

// vm_object fields
//   memq.next   = +0x40 (list of resident pages) — per KDK, verify per version
//   vo_offset   = +0x60 — object offset base
//   ref_count   = off_vm_object_ref_count
#define O_MEMQ     0x40
#define O_OFFSET   0x68

// vm_page fields
//   listq.next  = +0x00
//   offset      = +0x18 (offset into object, page-aligned)
//   phys_page   = +0x30 (physical page frame number)
#define P_LISTQ    0x00
#define P_OFFSET   0x18
#define P_PHYS     0x30

// kernel physmap base — where physical memory is direct-mapped
// arm64 xnu: gPhysBase/gPhysSize → physmap window. Compute from kernel base.
static uint64_t g_physmap_base = 0;

static void init_physmap(void) {
    if (g_physmap_base) return;
    // arm64 xnu physmap: PHYSMAP_PTOB / base derived at boot.
    // Practical value on iOS 17-26 arm64: 0xFFFFFFF0F0000000 region.
    // Scan-free heuristic used by DS-class providers:
    //   read id_tprlo / T1SZ region — but the stable anchor is:
    //   kernel text base + fixed slide window.
    g_physmap_base = 0xFFFFFFF000000000ULL; // arm64 physmap base (all versions 17-26)
}

#pragma mark - attach

int ds_attach(void) {
    if (ds_attached()) return 0;
    if (!g_kexploit_ready) return -1;

    init_physmap();

    // DIAG: kernel read health check — read our own proc. If this returns
    // garbage, the kernel primitives are dead (post-panic) and every later
    // read is noise. Surface it instead of failing silently.
    uint64_t selfCheck = proc_self();
    bool kernelAlive = is_kaddr_valid(selfCheck);
    if (!kernelAlive) {
        static int s_deadLogged = 0;
        if (!s_deadLogged) {
            s_deadLogged = 1;
            NSLog(@"[DS] KERNEL READ DEAD — self proc readback invalid (0x%llx). Re-run the exploit.", selfCheck);
            kernel_boot_log_fn logFn = kernelBootLog;
            if (logFn) {
                NSString *line = @"[diag] kernel DEAD — bấm Bắt đầu lại";
                dispatch_async(dispatch_get_main_queue(), ^{ logFn(line); });
            }
        }
        return -1;
    }

    const char *names[] = { "FreeFire", "FreeFireMAX", "GarenaFreeFire", "Freefire", "freefire" };
    uint64_t p = 0;
    const char *foundName = NULL;
    for (int i = 0; i < 5; i++) {
        p = proc_find_by_name(names[i]);
        if (p && p != (uint64_t)-1 && K(p)) {
            foundName = names[i];
            break;
        }
    }
    if (!p) {
        static int s_notFoundLogged = 0;
        if (!s_notFoundLogged) {
            s_notFoundLogged = 1;
            NSLog(@"[DS] FF proc not found (kernel alive)");
            kernel_boot_log_fn logFn = kernelBootLog;
            if (logFn) {
                NSString *line = @"[diag] không thấy Free Fire — mở game rồi chờ";
                dispatch_async(dispatch_get_main_queue(), ^{ logFn(line); });
            }
        }
        return -1;
    }
    g_ff_proc = p;
    g_ff_pid  = (pid_t)kread32(p + off_proc_p_pid);
    NSLog(@"[DS] attached '%s' pid=%d", foundName ?: "?", g_ff_pid);

    g_ff_task = proc_task(g_ff_proc);
    if (!K(g_ff_task)) {
        NSLog(@"[DS] FF task invalid");
        return -1;
    }

    // module base: walk entries, pick the LARGEST Mach-O-backed region above
    // 4GB — the first-match heuristic kept grabbing small system frameworks
    // (0x10ddf7000) whose header IS a valid Mach-O, so the magic check passed
    // while base pointed at the wrong image (ti=nil downstream). UnityFramework
    // is by far the biggest mapped binary in the FF process.
    uint64_t map = kread_ptr(g_ff_task + off_task_map);
    g_ff_map = map; // saved for ds_read/ds_write remap path
    uint64_t hdr = map + off_vm_map_hdr;
    uint32_t nentries = kread32(hdr + off_vm_map_header_nentries);
    uint64_t e = kread_ptr(hdr + off_vm_map_header_links_next);

    uint64_t bestStart = 0, bestSize = 0;
    int mappedCount = 0, failCount = 0;
    for (uint32_t i = 0; i < nentries && K(e); i++) {
        uint64_t start = kread64(e + E_START);
        uint64_t end   = kread64(e + E_END);
        uint64_t size  = (end > start) ? (end - start) : 0;

        if (start >= 0x100000000 && size > 0x400000 && start < 0x800000000) {
            struct VMShmem page = vm_map_remote_page(map, start & ~0x3FFFULL);
            if (page.localAddress) {
                mappedCount++;
                uint32_t magic = *(uint32_t *)(uintptr_t)(page.localAddress + (start & 0x3FFFULL));
                if (magic == 0xFEEDFACF && size > bestSize) {
                    bestStart = start;
                    bestSize = size;
                }
            } else {
                if (failCount < 5) {
                    NSLog(@"[DS] remap FAIL region start=0x%llx size=0x%llx", start, size);
                }
                failCount++;
            }
        }
        e = kread_ptr(e + off_vm_map_entry_links_next);
    }
    NSLog(@"[DS] base walk: mapped=%d fail=%d best=0x%llx size=0x%llx",
          mappedCount, failCount, bestStart, bestSize);
    if (bestStart) {
        g_ff_base = bestStart;
    }

    if (!g_ff_base) {
        static int s_baseLogged = 0;
        if (!s_baseLogged) {
            s_baseLogged = 1;
            NSLog(@"[DS] module base not found (nentries walk failed)");
            kernel_boot_log_fn logFn = kernelBootLog;
            if (logFn) {
                NSString *line = @"[diag] thấy FF nhưng không đọc được memory (vm_map walk fail)";
                dispatch_async(dispatch_get_main_queue(), ^{ logFn(line); });
            }
        }
        return -1;
    }

    NSLog(@"[DS] attached: pid=%d proc=0x%llx task=0x%llx base=0x%llx",
          g_ff_pid, g_ff_proc, g_ff_task, g_ff_base);
    return 0;
}

#pragma mark - page translation (the DarkSword core)

// translate one page: user_va (page-aligned) → kernel physmap addr
uint64_t ds_translate_page(uint64_t page_va) {
    if (!K(g_ff_task)) return 0;
    page_va &= ~PAGE_MASK;

    // 1. find containing entry (use cache first)
    uint64_t entry = 0, start = 0, __attribute__((unused)) end = 0, object = 0, obj_offset = 0;

    if (g_cached_entry && page_va >= g_cached_start && page_va < g_cached_end) {
        entry = g_cached_entry;
        start = g_cached_start; end = g_cached_end;
        object = g_cached_object; obj_offset = g_cached_obj_offset;
    } else {
        uint64_t map = kread_ptr(g_ff_task + off_task_map);
        uint64_t hdr = map + off_vm_map_hdr;
        uint32_t nentries = kread32(hdr + off_vm_map_header_nentries);
        uint64_t e = kread_ptr(hdr + off_vm_map_header_links_next);

        for (uint32_t i = 0; i < nentries && K(e); i++) {
            uint64_t s = kread64(e + E_START);
            uint64_t t = kread64(e + E_END);
            if (page_va >= s && page_va < t) {
                entry = e; start = s; end = t;
                object = kread_ptr(e + E_OBJECT);
                // vme_object_or_delta: if alias==VM_MEMORY_REAL, object is real;
                // obj_offset stored in object->vo_offset
                obj_offset = object ? kread64(object + O_OFFSET) : 0;
                // cache
                g_cached_entry = entry; g_cached_start = s; g_cached_end = t;
                g_cached_object = object; g_cached_obj_offset = obj_offset;
                break;
            }
            e = kread_ptr(e + off_vm_map_entry_links_next);
        }
    }

    if (!K(entry) || !K(object)) return 0;

    // 2. offset into object
    uint64_t page_offset_in_object = (page_va - start) + obj_offset;
    uint64_t page_index = page_offset_in_object >> PAGE_SHIFT;

    // 3. walk object memq for page with matching offset
    uint64_t page = kread_ptr(object + O_MEMQ);
    // memq is a queue head; iterate listq
    uint64_t first = kread_ptr(object + O_MEMQ + 0x0);
    page = first;
    int steps = 0;
    while (K(page) && steps < 4096) {
        uint64_t poff = kread64(page + P_OFFSET);
        if ((poff & ~PAGE_MASK) == (page_offset_in_object & ~PAGE_MASK)) {
            // found resident page
            uint32_t phys = kread32(page + P_PHYS);
            if (!phys) return 0;
            uint64_t pa = ((uint64_t)phys << PAGE_SHIFT);
            return g_physmap_base + pa;
        }
        page = kread_ptr(page + P_LISTQ);
        steps++;
    }
    return 0; // paged out — caller retries
}

#pragma mark - read/write

// DIRECT kernel reads (lara/cyanide pattern): read the TARGET's USER memory
// through its vm_map's translation is what the old physmap walk tried and
// failed (guessed physmap base + hardcoded vm_object offsets never worked on
// 17.5.1/A15). The working path used by lara and cyanide: kernel addresses of
// the target's data CAN be reached with early_kread64 directly when we have
// the virtual kernel mapping — which early_kread64 operates on via the
// corrupted socket's kernel pointer. So: walk NOTHING, read the user-space
// address translated through arm64 TTBR0 by dereferencing with the kernel
// primitive is NOT possible — instead we use the SAME technique cyanide's
// krw uses for game memory: read through the target task's vm_map pages
// resolved ONCE per page via ds_translate_page, BUT with a working fallback:
// if translate fails, read via early_kread64 on the vm_map-entry-backed
// kernel alias. In practice on 17.5.1 the reliable route is a tight 8-byte
// PAGE REMAP reads (the lara/cyanide-proven path): remap the target's page
// into OUR address space via vm_map_remote_page (vm_get_object walk with
// proper xnu pointer unpacking + mach memory entry), then memcpy. NO
// physmap guessing, NO hardcoded vm_object offsets — VM.m does both
// correctly. Reads/writes are then plain memory access at native speed.
static bool ds_rw_remap(uint64_t va, void *buf, size_t len, bool isWrite) {
    if (!K(g_ff_map) || !va || !buf || !len) return false;

    uint8_t *p = (uint8_t *)buf;
    uint64_t cur = va;
    size_t remain = len;

    while (remain > 0) {
        uint64_t page_va  = cur & ~PAGE_MASK;
        uint64_t page_off = cur & PAGE_MASK;
        size_t chunk = PAGE_SIZE - page_off;
        if (chunk > remain) chunk = remain;

        struct VMShmem page = vm_map_remote_page(g_ff_map, page_va);
        if (!page.localAddress) return false;

        void *local = (void *)(uintptr_t)(page.localAddress + page_off);
        if (isWrite) memcpy(local, p, chunk);
        else         memcpy(p, local, chunk);

        p += chunk; cur += chunk; remain -= chunk;
    }
    return true;
}

bool ds_read(uint64_t va, void *buf, size_t len) {
    return ds_rw_remap(va, buf, len, false);
}

bool ds_write(uint64_t va, const void *buf, size_t len) {
    return ds_rw_remap(va, buf, len, true);
}

uint8_t  ds_read8(uint64_t va)  { uint8_t v=0;  ds_read(va,&v,1); return v; }
uint16_t ds_read16(uint64_t va) { uint16_t v=0; ds_read(va,&v,2); return v; }
uint32_t ds_read32(uint64_t va) { uint32_t v=0; ds_read(va,&v,4); return v; }
uint64_t ds_read64(uint64_t va) { uint64_t v=0; ds_read(va,&v,8); return v; }
float    ds_readf(uint64_t va)  { float v=0;    ds_read(va,&v,4); return v; }

uint64_t ds_readptr(uint64_t va) { return xpaci(ds_read64(va)); }

bool ds_read_str(uint64_t va, char *out, size_t maxlen) {
    if (!ds_read(va, out, maxlen)) return false;
    out[maxlen-1] = 0;
    return true;
}

#pragma mark - accessors

void ds_detach(void) {
    g_ff_proc = g_ff_task = g_ff_base = 0;
    g_ff_map = 0;
    g_ff_pid = 0;
    g_cached_entry = 0;
}

bool ds_attached(void) { return K(g_ff_task); }
uint64_t ds_base(void) { return g_ff_base; }
pid_t    ds_pid(void)  { return g_ff_pid; }
mach_port_t ds_task_port(void) { return MACH_PORT_NULL; } // unused in DS mode
