#pragma once
#import <Foundation/Foundation.h>

// Free Fire entity reader — dùng kread64 từ kexploit (kernel memory read)
// để đọc entity list từ process khác (Free Fire app)

@interface FFEntity : NSObject
@property (nonatomic, assign) uint64_t kaddr;   // kernel addr của proc struct
@property (nonatomic, assign) int   hp;
@property (nonatomic, assign) int   team;
@property (nonatomic, assign) float dist;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, assign) CGRect box;       // screen-space bounding box
@end

// cấu hình offsets FF (cập nhật theo version game)
typedef struct {
    // proc struct offsets (đã có sẵn trong offsets.m của exploit)
    uint32_t proc_p_list_le_next;
    uint32_t proc_p_pid;
    uint32_t proc_p_name;

    // task → vm_map → map entries để scan heap
    uint32_t task_map;
    uint32_t vm_map_hdr;
    uint32_t vm_map_header_nentries;
    uint32_t off_vm_map_entry_links_next;

    // entity list của game
    uint64_t entity_list_offset;     // base + offset trong VM của FF
    uint32_t entity_size;            // sizeof mỗi entity
    uint32_t entity_hp_offset;
    uint32_t entity_team_offset;
    uint32_t entity_pos_offset;
    uint32_t entity_bone_offset;
    uint32_t max_entities;
} FFConfig;

// main reader class
@interface FFReader : NSObject
+ (instancetype)shared;

// init sau khi exploit chạy xong
- (BOOL)setup;

// tìm proc "GarenaFreeFire" trong kernel process list
- (uint64_t)findFFProcess;

// đọc tất cả entity của FF, trả về mảng FFEntity
- (NSArray<FFEntity *> *)readEntities;

// loop polling — gọi từ thread riêng
- (void)startPolling:(float)hz;
- (void)stopPolling;

// config offsets (gọi trước setup)
@property (nonatomic, assign) FFConfig config;
@end
