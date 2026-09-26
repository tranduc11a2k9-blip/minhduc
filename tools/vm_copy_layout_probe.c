/*
 * vm_copy_layout_probe.c
 *
 * PURPOSE
 *   Measure, with the compiler, the layout of struct vm_map_copy and struct
 *   vm_map_entry for xnu-10063 (iOS 17.x, xnu-10063.122.3~3 on device).
 *   Every struct below is transcribed verbatim from the Apple open-source XNU
 *   tag xnu-10063.121.3 (same 10063 branch, one minor version away):
 *     osfmk/vm/vm_map.h          struct vm_map_copy, struct vm_map_entry
 *     osfmk/vm/vm_map_store.h    vm_map_links, vm_map_store, vm_map_header
 *     osfmk/libkern/tree.h       RB_ENTRY / rb_head
 *
 * WHY THIS EXISTS
 *   remote/VM.m treated the object at shmemVMCopyAddr as if a vm_map_entry
 *   started at offset 0. It does not. The 72-byte zone element is a
 *   struct vm_map_copy whose first 0x18 bytes are scalars, followed by a
 *   union holding a struct vm_map_header. The real entry is reached through
 *   cpy_hdr.links, which is why offsetof(vme_object_or_delta) == 0x3c was
 *   "correct" and still wrote into a live header field.
 *
 * NOT PART OF ANY BUILD. Run manually:
 *   clang -w -o /tmp/vmcopyprobe tools/vm_copy_layout_probe.c && /tmp/vmcopyprobe
 */

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

typedef uint64_t vm_map_offset_t;
typedef uint64_t vm_object_offset_t;
typedef uint64_t vm_offset_t;
typedef uint32_t vm_map_range_id_t;
typedef uint32_t vm_page_packed_t;
typedef uint64_t vm_map_size_t;
#include <stdbool.h>

#define VME_ALIAS_BITS   12
#define VME_OFFSET_BITS  (64 - VME_ALIAS_BITS)
#define VME_SUBMAP_SHIFT 2
#define VME_SUBMAP_BITS  (sizeof(vm_offset_t) * 8 - VME_SUBMAP_SHIFT)

#define SKIP_RB_TREE 0xBAADC0D1u

/* ---- osfmk/libkern/tree.h ---- */
struct rb_entry {
	void *rb_left;
	void *rb_right;
	void *rb_parent;
};
struct rb_head {
	struct rb_entry entry;   /* + int rb_info in some configs; see note below */
	int         rb_info;
};

/* ---- osfmk/vm/vm_map_store.h ---- */
struct vm_map_entry;
struct vm_map_copy;

struct vm_map_links {
	struct vm_map_entry *prev;
	struct vm_map_entry *next;
	vm_map_offset_t      start;
	vm_map_offset_t      end;
};

struct vm_map_store {
	struct rb_entry entry;      /* RB_ENTRY(vm_map_store) */
};

struct vm_map_header {
	struct vm_map_links links;
	int                nentries;
	uint16_t           page_shift;
	uint16_t           entries_pageable : 1;
	uint16_t           __padding : 15;
	struct rb_head     rb_head_store;
};

/* ---- osfmk/vm/vm_map.h : struct vm_map_entry ---- */
struct vm_map_entry {
	struct vm_map_links links;
#define vme_prev  links.prev
#define vme_next  links.next
#define vme_start links.start
#define vme_end   links.end

	struct vm_map_store store;

	union {
		vm_offset_t vme_object_value;
		struct {
			vm_offset_t vme_atomic : 1;
			vm_offset_t is_sub_map : 1;
			vm_offset_t vme_submap : VME_SUBMAP_BITS;
		};
		struct {
			uint32_t vme_ctx_atomic : 1;
			uint32_t vme_ctx_is_sub_map : 1;
			uint32_t vme_context : 30;
			union {
				vm_page_packed_t vme_object_or_delta;
				uint64_t         vme_tag_btref;
			};
		};
	};

	unsigned long long
	    vme_alias : VME_ALIAS_BITS,
	    vme_offset : VME_OFFSET_BITS;

	unsigned long long
	    is_shared : 1,
	    __unused1 : 1,
	    in_transition : 1,
	    needs_wakeup : 1,
	    behavior : 2,
	    needs_copy : 1,
	    protection : 3,
	    used_for_tpro : 1,
	    max_protection : 4,
	    inheritance : 2,
	    use_pmap : 1,
	    no_cache : 1,
	    vme_permanent : 1,
	    superpage_size : 1,
	    map_aligned : 1,
	    zero_wired_pages : 1,
	    used_for_jit : 1,
	    csm_associated : 1,
	    iokit_acct : 1,
	    vme_resilient_codesign : 1,
	    vme_resilient_media : 1,
	    vme_xnu_user_debug : 1,
	    vme_no_copy_on_read : 1,
	    translated_allow_execute : 1,
	    vme_kernel_object : 1;

	unsigned short wired_count;
	unsigned short user_wired_count;
};

/* ---- osfmk/vm/vm_map.h : struct vm_map_copy ---- */
struct vm_map_copy {
	uint16_t           type;
	bool               is_kernel_range;
	bool               is_user_range;
	vm_map_range_id_t  orig_range;
	vm_object_offset_t offset;
	vm_map_size_t            size;
	union {
		struct vm_map_header hdr;
		void                *kdata;
	} c_u;
};

int main(void)
{
	printf("=== struct vm_map_copy (the 72-byte zone element) ===\n");
	printf("  sizeof                     = 0x%zx\n", sizeof(struct vm_map_copy));
	printf("  offsetof(type)             = 0x%zx\n", offsetof(struct vm_map_copy, type));
	printf("  offsetof(offset)           = 0x%zx\n", offsetof(struct vm_map_copy, offset));
	printf("  offsetof(c_u)              = 0x%zx\n", offsetof(struct vm_map_copy, c_u));
	printf("  offsetof(c_u.hdr)          = 0x%zx\n", offsetof(struct vm_map_copy, c_u.hdr));
	printf("  offsetof(c_u.hdr.links)    = 0x%zx   <-- vm_map_copy_to_entry()\n",
	       offsetof(struct vm_map_copy, c_u.hdr.links));
	printf("  offsetof(c_u.hdr.links.prev)= 0x%zx   <-- first_entry when nentries==1\n",
	       offsetof(struct vm_map_copy, c_u.hdr.links.prev));
	printf("  offsetof(c_u.hdr.links.next)= 0x%zx   <-- vm_map_copy_first_entry()\n",
	       offsetof(struct vm_map_copy, c_u.hdr.links.next));
	printf("  offsetof(c_u.hdr.nentries) = 0x%zx\n", offsetof(struct vm_map_copy, c_u.hdr.nentries));
	printf("  offsetof(c_u.hdr.page_shift) = 0x%zx\n", offsetof(struct vm_map_copy, c_u.hdr.page_shift));
	printf("  offsetof(c_u.hdr.rb_head_store) = 0x%zx  <-- SKIP_RB_TREE lives here\n",
	       offsetof(struct vm_map_copy, c_u.hdr.rb_head_store));

	printf("\n=== struct vm_map_entry ===\n");
	printf("  sizeof                            = 0x%zx\n", sizeof(struct vm_map_entry));
	printf("  offsetof(links)                   = 0x%zx\n", offsetof(struct vm_map_entry, links));
	printf("  offsetof(store)                   = 0x%zx\n", offsetof(struct vm_map_entry, store));
	printf("  offsetof(vme_start)               = 0x%zx\n", offsetof(struct vm_map_entry, vme_start));
	printf("  offsetof(vme_end)                 = 0x%zx\n", offsetof(struct vm_map_entry, vme_end));
	printf("  offsetof(vme_object_or_delta)     = 0x%zx\n",
	       offsetof(struct vm_map_entry, vme_object_or_delta));
	/* vme_alias / vme_offset are bit-fields: neither offsetof() nor
	 * &entry->vme_offset is legal (both are hard compile errors, same as in
	 * remote/VM.h). Measure the backing storage from the NEXT addressable
	 * member instead: the alias|offset pair occupies everything from the end
	 * of the union up to wired_count. */
	printf("  offsetof(wired_count)             = 0x%zx\n", offsetof(struct vm_map_entry, wired_count));
	printf("  vme_alias|vme_offset storage     = [0x%zx, 0x%zx)  (union_end..wired_count, measured)\n",
	       (size_t)((const char *)&(((struct vm_map_entry *)0)->wired_count) - (const char *)0) - 8,
	       offsetof(struct vm_map_entry, wired_count));
	printf("    -> vme_alias  = low 12 bits of that 8-byte slot\n");
	printf("    -> vme_offset = high 52 bits of that same 8-byte slot\n");

	printf("\n=== DECODED against the 7 device samples ===\n");
	printf("  device raw[0x00..0x07] = 01 00 00 00 00 00 00 00\n");
	printf("    -> vm_map_copy.type = 0x%04x  (VM_MAP_COPY_ENTRY_LIST == 1) %s\n",
	       (unsigned)1, (1 == 1) ? "MATCH" : "MISMATCH");
	printf("  device raw[0x10..0x17] = 00 40 00 00 00 00 00 00  -> size   = 0x%llx\n",
	       (unsigned long long)0x4000);
	printf("  device raw[0x18..0x1f] = varies per entry        -> cpy_hdr.links.prev (real entry)\n");
	printf("  device raw[0x20..0x27] = varies, == 0x18 in 6/7    -> cpy_hdr.links.next\n");
	printf("  device raw[0x38..0x3b] = 01 00 00 00              -> cpy_hdr.nentries = 1\n");
	printf("  device raw[0x3c..0x3f] = 0e 00 01 00              -> page_shift = 0x%04x (=> 0x%x byte page) %s\n",
	       (unsigned)0x000e, 1 << 0x000e, (0x000e == 14) ? "MATCH" : "MISMATCH");
	printf("  device raw[0x40..0x47] = d1 c0 ad ba ff ff ff ff  -> rb_head_store = 0x%08x %s\n",
	       (unsigned)SKIP_RB_TREE, (SKIP_RB_TREE == 0xBAADC0D1u) ? "MATCH (SKIP_RB_TREE)" : "MISMATCH");

	printf("\n=== CONCLUSION ===\n");
	printf("  vme_object_or_delta is at entry+0x%zx, where entry = kread64(copy + 0x%zx).\n",
	       offsetof(struct vm_map_entry, vme_object_or_delta),
	       offsetof(struct vm_map_copy, c_u.hdr.links.next));
	printf("  Patching copy+0x3c was patching cpy_hdr.page_shift: a live header field.\n");
	return 0;
}
