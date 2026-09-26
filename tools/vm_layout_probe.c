/*
 * Standalone measurement of remote/VM.h's struct vm_map_entry.
 * Mirrors the typedefs the real build gets:
 *   vm_offset_t      -> 64 bit.  Forced: `vm_offset_t vme_submap : 62` in
 *                       remote/VM.h does not compile against a 32-bit type, and
 *                       the real build compiles, so it must be 8 bytes.
 *   vm_map_offset_t  -> 64 bit.  Forced: vm_entry_get_range() reads
 *                       links.start / links.end as two 8-byte values at
 *                       vm_entry_ptr + 0x10 and + 0x18.
 * Run: clang -o /tmp/probe tools/vm_layout_probe.c && /tmp/probe
 */
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>

typedef uint64_t          vm_offset_t;
typedef uint64_t          vm_map_offset_t;

struct vm_map_links {
    uint64_t prev;
    uint64_t tnext;
    vm_map_offset_t start;
    vm_map_offset_t end;
};

struct vm_map_store {
    uint64_t rbe_left;
    uint64_t rbe_right;
    uint64_t rbe_parent;
};

struct vm_map_entry {
    struct vm_map_links links;
    struct vm_map_store store;
    union  {
        vm_offset_t vme_object_value;
        struct  {
            vm_offset_t vme_atomic : 1;
            vm_offset_t is_sub_map : 1;
            vm_offset_t vme_submap : 62;
        };
        struct  {
            uint32_t vme_ctx_atomic : 1;
            uint32_t vme_ctx_is_sub_map : 1;
            uint32_t vme_context : 30;
            union  {
                uint32_t vme_object_or_delta;
                uint32_t vme_tag_btref;
            };
        };
    };
    unsigned long long vme_alias : 12;
    unsigned long long vme_offset : 52;
    unsigned long long is_shared : 1;
    unsigned long long __unused1 : 1;
    unsigned long long in_transition : 1;
    unsigned long long needs_wakeup : 1;
    unsigned long long behavior : 2;
    unsigned long long needs_copy : 1;
    unsigned long long protection : 3;
    unsigned long long used_for_tpro : 1;
    unsigned long long max_protection : 4;
    unsigned long long inheritance : 2;
    unsigned long long use_pmap : 1;
    unsigned long long no_cache : 1;
    unsigned long long vme_permanent : 1;
    unsigned long long superpage_size : 1;
    unsigned long long map_aligned : 1;
    unsigned long long zero_wired_pages : 1;
    unsigned long long used_for_jit : 1;
    unsigned long long csm_associated : 1;
    unsigned long long iokit_acct : 1;
    unsigned long long vme_resilient_codesign : 1;
    unsigned long long vme_resilient_media : 1;
    unsigned long long vme_xnu_user_debug : 1;
    unsigned long long vme_no_copy_on_read : 1;
    unsigned long long translated_allow_execute : 1;
    unsigned long long vme_kernel_object : 1;
    unsigned short wired_count;
    unsigned short user_wired_count;
};

/* Faithful reproduction of kexploit/krw.m:kwrite_zone_element chunking,
 * with EARLY_KRW_LENGTH == 0x20 from kexploit_opa334.h. */
#define EARLY_KRW_LENGTH 0x20
static void chunk_trace(const char *label, uint64_t len)
{
    printf("%s: len=%llu (0x%llx) ->", label, (unsigned long long)len, (unsigned long long)len);
    uint64_t remaining = len, offset = 0;
    while (remaining != 0) {
        uint64_t writeSize = (remaining >= EARLY_KRW_LENGTH)
                           ? EARLY_KRW_LENGTH
                           : (remaining % EARLY_KRW_LENGTH);
        uint64_t writeDst = offset;
        if (writeSize != EARLY_KRW_LENGTH) {
            uint64_t adjust = EARLY_KRW_LENGTH - writeSize;
            writeDst -= adjust;
        }
        printf("  [dst+0x%02llx .. +0x%02llx)",
               (unsigned long long)writeDst,
               (unsigned long long)(writeDst + EARLY_KRW_LENGTH));
        remaining -= writeSize;
        offset    += writeSize;
    }
    printf("\n");
}

int main(void)
{
    printf("sizeof(vm_map_links)   = %zu (0x%zx)\n", sizeof(struct vm_map_links), sizeof(struct vm_map_links));
    printf("sizeof(vm_map_store)   = %zu (0x%zx)\n", sizeof(struct vm_map_store), sizeof(struct vm_map_store));
    printf("sizeof(vm_map_entry)   = %zu (0x%zx)   <-- the len passed to kwrite_zone_element\n",
           sizeof(struct vm_map_entry), sizeof(struct vm_map_entry));

    printf("\noffsetof(vm_map_entry, links)                = 0x%02zx\n", offsetof(struct vm_map_entry, links));
    printf("offsetof(vm_map_entry, links.start)          = 0x%02zx\n", offsetof(struct vm_map_entry, links.start));
    printf("offsetof(vm_map_entry, links.end)            = 0x%02zx\n", offsetof(struct vm_map_entry, links.end));
    printf("offsetof(vm_map_entry, store)                = 0x%02zx\n", offsetof(struct vm_map_entry, store));
    printf("offsetof(vm_map_entry, vme_object_or_delta)  = 0x%02zx  (4 bytes)  <-- the only field we patch\n", offsetof(struct vm_map_entry, vme_object_or_delta));
    printf("offsetof(vm_map_entry, wired_count)          = 0x%02zx\n", offsetof(struct vm_map_entry, wired_count));
    printf("(vme_alias / vme_offset is a bit-field so no offsetof; the union ends\n"
           " at 0x40, so the 8-byte word is at 0x40.)\n");

    printf("\n-- vs the 72-byte (0x48) 'VM map copies' zone element from the panic --\n");
    const uint64_t elem = 72;
    const uint64_t od   = offsetof(struct vm_map_entry, vme_object_or_delta);
    const uint64_t vmo  = (od & ~0x7ULL) + 8;   /* union ends, next 8-aligned word */
    printf("elem end (base + 0x48)                      = 0x%02llx\n", (unsigned long long)elem);
    printf("vme_object_or_delta tail  0x%02llx+4 = 0x%02llx  %s\n",
           (unsigned long long)od, (unsigned long long)(od + 4),
           (od + 4 <= elem) ? "IN BOUNDS" : "OVERFLOW");
    printf("vme_alias/vme_offset word  0x%02llx+8 = 0x%02llx  %s\n",
           (unsigned long long)vmo, (unsigned long long)(vmo + 8),
           (vmo + 8 <= elem) ? "IN BOUNDS" : "OVERFLOW");
    printf("32B block covering vme_object_or_delta = [0x%02llx,0x%02llx)  %s\n",
           (unsigned long long)(od & ~0x1FULL), (unsigned long long)((od & ~0x1FULL) + 0x20),
           (((od & ~0x1FULL) + 0x20) <= elem) ? "IN BOUNDS" : "OVERFLOW");
    printf("32B block covering the vme_offset word = [0x%02llx,0x%02llx)  %s  <-- why we cannot patch it\n",
           (unsigned long long)(vmo & ~0x1FULL), (unsigned long long)((vmo & ~0x1FULL) + 0x20),
           (((vmo & ~0x1FULL) + 0x20) <= elem) ? "IN BOUNDS" : "OVERFLOW");

    printf("\n");
    chunk_trace("kwrite_zone_element(whole struct)", sizeof(struct vm_map_entry));
    return 0;
}
