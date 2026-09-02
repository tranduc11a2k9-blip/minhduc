#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "pid.h"
#include "offset.h"

#include <cstring>

extern NSMutableDictionary *gWeaponTextures;

void InitWeaponTextures(void);
UIImage *WeaponIconForName(const char *name);

/** FFTH: inv@kWeaponHolder → weapon@kHolderActiveWeapon */
inline uint64_t GetWeaponOnHand(uint64_t player) {
    if (!isVaildPtr(player)) return 0;

    uint64_t inv = ReadAddr<uint64_t>(player + kWeaponHolder);
    if (!isVaildPtr(inv)) return 0;

    uint64_t weapon = ReadAddr<uint64_t>(inv + kHolderActiveWeapon);
    return isVaildPtr(weapon) ? weapon : 0;
}

/** FFTH: holder chain, fallback Player::EABOMEAANJM (esp/imguidraw/esp.mm). */
inline uint64_t ResolveWeaponForEsp(uint64_t player) {
    if (!isVaildPtr(player)) return 0;

    uint64_t weapon = GetWeaponOnHand(player);
    if (isVaildPtr(weapon)) return weapon;

    weapon = ReadAddr<uint64_t>(player + kActiveWeapon);
    return isVaildPtr(weapon) ? weapon : 0;
}

/** Il2CppString → UTF-8 (giống ffexternal Il2CppString_ToUTF8, thử 0x14/0x18). */
inline bool ReadIl2CppStringUtf8(uint64_t strPtr, char *out, size_t cap) {
    if (!out || cap < 2) return false;
    out[0] = '\0';
    if (!isVaildPtr(strPtr)) return false;

    const int len = ReadAddr<int>(strPtr + 0x10u);
    if (len <= 0 || len > 127) return false;

    const size_t n = (size_t)len < cap - 1 ? (size_t)len : cap - 1;
    uint16_t u16[128] = {};
    bool ok = false;
    const uint32_t strOffs[] = { (uint32_t)kStringFirstChar, 0x18u };
    for (int oi = 0; oi < 2 && !ok; oi++) {
        if (!_read((long)(strPtr + strOffs[oi]), u16, (int)(n * (int)sizeof(uint16_t))))
            continue;
        ok = true;
    }
    if (!ok) return false;

    @autoreleasepool {
        NSString *ns = [[NSString alloc] initWithBytes:u16
                                                  length:n * sizeof(uint16_t)
                                                encoding:NSUTF16LittleEndianStringEncoding];
        if (!ns || ns.length == 0) return false;
        const char *utf8 = [ns UTF8String];
        if (!utf8 || !utf8[0]) return false;
        strncpy(out, utf8, cap - 1);
        out[cap - 1] = '\0';
        return true;
    }
}

/** ffexternal WpnData — ob54 FDAEPHMIEPC::DJMMOHAJFPB @ 0x98 (ff dùng 0x90). */
inline uint64_t GetWeaponData(uint64_t weapon) {
    if (!isVaildPtr(weapon)) return 0;
    uint64_t wdata = ReadAddr<uint64_t>(weapon + 0x98u);
    return isVaildPtr(wdata) ? wdata : 0;
}

/** LGMNCCAPNHJ::HOACBHMDLFI → HENEHAGJCLI (CSV item config). */
inline uint64_t GetItemConfigData(uint64_t item) {
    if (!isVaildPtr(item)) return 0;
    const uint64_t cfg = ReadAddr<uint64_t>(item + 0x28u);
    return isVaildPtr(cfg) ? cfg : 0;
}

/** Mọi string name có thể gắn với 1 inventory item (không chỉ TXT_ITEM_). */
struct ItemNameFields {
    char raw[128];
    char cfg[128];
    char cfgAlt1[128];
    char cfgAlt2[128];
    char wpnData[128];
    char wpnCfg[128];
};

inline void ReadItemAllNameFields(uint64_t item, ItemNameFields *out) {
    if (!out) return;
    memset(out, 0, sizeof(*out));
    if (!isVaildPtr(item)) return;

    ReadIl2CppStringUtf8(ReadAddr<uint64_t>(item + 0x18u), out->raw, sizeof(out->raw));

    const uint64_t cfg = GetItemConfigData(item);
    if (isVaildPtr(cfg)) {
        ReadIl2CppStringUtf8(ReadAddr<uint64_t>(cfg + 0x10u), out->cfg, sizeof(out->cfg));
        ReadIl2CppStringUtf8(ReadAddr<uint64_t>(cfg + 0x20u), out->cfgAlt1, sizeof(out->cfgAlt1));
        ReadIl2CppStringUtf8(ReadAddr<uint64_t>(cfg + 0x28u), out->cfgAlt2, sizeof(out->cfgAlt2));
    }

    const uint64_t wdata = GetWeaponData(item);
    if (isVaildPtr(wdata)) {
        ReadIl2CppStringUtf8(ReadAddr<uint64_t>(wdata + 0x10u), out->wpnData, sizeof(out->wpnData));
        const uint64_t wcfg = ReadAddr<uint64_t>(wdata + 0xE0u);
        if (isVaildPtr(wcfg))
            ReadIl2CppStringUtf8(ReadAddr<uint64_t>(wcfg + 0x10u), out->wpnCfg, sizeof(out->wpnCfg));
    }
}

/** Chọn tên hiển thị — thử lần lượt mọi field, không ưu tiên TXT_ITEM_. */
inline bool GetInventoryItemNameUtf8(uint64_t item, char *out, size_t cap) {
    if (!out || cap < 2) return false;
    out[0] = '\0';

    ItemNameFields names = {};
    ReadItemAllNameFields(item, &names);

    const char *candidates[] = {
        names.wpnCfg, names.cfg, names.wpnData, names.raw,
        names.cfgAlt1, names.cfgAlt2,
    };
    for (const char *c : candidates) {
        if (c && c[0]) {
            strncpy(out, c, cap - 1);
            out[cap - 1] = '\0';
            return true;
        }
    }
    return false;
}

/** Tên item/súng — thử mọi field (wcfg, cfg, wdata, raw…), không chỉ TXT_ITEM_. */
inline bool GetWeaponNameUtf8(uint64_t weapon, char *out, size_t cap) {
    return GetInventoryItemNameUtf8(weapon, out, cap);
}
