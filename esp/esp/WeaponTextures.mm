// WeaponTextures.mm — base64 PNG decode (IMAGE.h) + name lookup → UIImage.
// IMAGE.h must only be #imported here (NSString * const → duplicate symbols if included twice).

#import "WeaponTextures.h"
#import "Font/IMAGE.h"

#include <cstring>

NSMutableDictionary *gWeaponTextures = nil;

static void _WTAdd(int type, NSString *b64) {
    if (!b64 || b64.length == 0) return;
    NSData *d = [[NSData alloc] initWithBase64EncodedString:b64
                                                    options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!d) return;
    UIImage *img = [UIImage imageWithData:d];
    if (img) gWeaponTextures[@(type)] = img;
}

void InitWeaponTextures(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gWeaponTextures = [[NSMutableDictionary alloc] init];
        _WTAdd(0,   Icon_0_AK);
        _WTAdd(1,   Icon_1_Tay);
        _WTAdd(2,   Icon_2_M4A1);
        _WTAdd(3,   Icon_3_USP);
        _WTAdd(4,   Icon_4_AWM);
        _WTAdd(5,   Icon_5_M1014);
        _WTAdd(6,   Icon_6_AK47);
        _WTAdd(7,   Icon_7_UMP);
        _WTAdd(8,   Icon_8_MP5);
        _WTAdd(9,   Icon_9_DesertEagle);
        _WTAdd(10,  Icon_10_G18);
        _WTAdd(11,  Icon_11_M14);
        _WTAdd(12,  Icon_12_SCAR);
        _WTAdd(13,  Icon_13_VSS);
        _WTAdd(14,  Icon_14_GROZA);
        _WTAdd(15,  Icon_15_MP40);
        _WTAdd(16,  Icon_16_PAN);
        _WTAdd(17,  Icon_17_PARANG);
        _WTAdd(18,  Icon_18_SKS);
        _WTAdd(19,  Icon_19_M249);
        _WTAdd(20,  Icon_20_M1873);
        _WTAdd(21,  Icon_21_KAR98K);
        _WTAdd(24,  Icon_24_FAMAS);
        _WTAdd(25,  Icon_25_M500);
        _WTAdd(26,  Icon_26_SVD);
        _WTAdd(27,  Icon_27_BAT);
        _WTAdd(28,  Icon_28_XM8);
        _WTAdd(29,  Icon_29_SPAS12);
        _WTAdd(30,  Icon_30_M60);
        _WTAdd(32,  Icon_32_P90);
        _WTAdd(33,  Icon_33_AN94);
        _WTAdd(34,  Icon_34_KATANA);
        _WTAdd(35,  Icon_35_CG15);
        _WTAdd(39,  Icon_39_PLASMA);
        _WTAdd(41,  Icon_41_M1887);
        _WTAdd(43,  Icon_43_THOMPSON);
        _WTAdd(45,  Icon_45_M82B);
        _WTAdd(46,  Icon_46_AUG);
        _WTAdd(47,  Icon_47_PARAFAL);
        _WTAdd(48,  Icon_48_WOODPECKER);
        _WTAdd(49,  Icon_49_VECTOR);
        _WTAdd(50,  Icon_50_MAG7);
        _WTAdd(51,  Icon_51_SCYTHE);
        _WTAdd(54,  Icon_54_KORD);
        _WTAdd(55,  Icon_55_M1917);
        _WTAdd(56,  Icon_56_USP2);
        _WTAdd(57,  Icon_57_KINGFISHER);
        _WTAdd(58,  Icon_58_MINI_UZI);
        _WTAdd(60,  Icon_60_MP5_I);
        _WTAdd(61,  Icon_61_M60_I);
        _WTAdd(62,  Icon_62_VSS_I);
        _WTAdd(63,  Icon_63_M14_I);
        _WTAdd(64,  Icon_64_KAR98K_I);
        _WTAdd(65,  Icon_65_AWM_Y);
        _WTAdd(67,  Icon_67_FAMAS_I);
        _WTAdd(70,  Icon_70_GROZA_X);
        _WTAdd(71,  Icon_71_M249_X);
        _WTAdd(72,  Icon_72_SVD_Y);
        _WTAdd(73,  Icon_73_G36_ASSAULT);
        _WTAdd(74,  Icon_74_G36_RANGE);
        _WTAdd(75,  Icon_75_M24);
        _WTAdd(78,  Icon_78_HEALSNIPER);
        _WTAdd(80,  Icon_80_M4A1_I);
        _WTAdd(81,  Icon_81_M4A1_II);
        _WTAdd(82,  Icon_82_M4A1_III);
        _WTAdd(86,  Icon_86_CHARGE_BUSTER);
        _WTAdd(88,  Icon_88_MAC10);
        _WTAdd(89,  Icon_89_AC80);
        _WTAdd(93,  Icon_93_HEAL_PISTOL);
        _WTAdd(99,  Icon_99_SHIELD_GUN);
        _WTAdd(100, Icon_100_FLAMETHROWER);
        _WTAdd(119, Icon_119_M1887_X);
        _WTAdd(120, Icon_120_MP5_II);
        _WTAdd(121, Icon_121_MP5_III);
        _WTAdd(122, Icon_122_M60_II);
        _WTAdd(123, Icon_123_M60_III);
        _WTAdd(124, Icon_124_VSS_II);
        _WTAdd(125, Icon_125_VSS_III);
        _WTAdd(126, Icon_126_M14_II);
        _WTAdd(127, Icon_127_M14_III);
        _WTAdd(128, Icon_128_KAR98K_II);
        _WTAdd(129, Icon_129_KAR98K_III);
        _WTAdd(130, Icon_130_FAMAS_II);
        _WTAdd(131, Icon_131_FAMAS_III);
        _WTAdd(150, Icon_150_BIZON);
        _WTAdd(178, Icon_178_SCAR_I);
        _WTAdd(179, Icon_179_SCAR_II);
        _WTAdd(180, Icon_180_SCAR_III);
        _WTAdd(181, Icon_181_TROGON);
        _WTAdd(184, Icon_184_M1014_I);
        _WTAdd(185, Icon_185_M1014_II);
        _WTAdd(186, Icon_186_M1014_III);
        _WTAdd(193, Icon_193_AUG_I);
        _WTAdd(194, Icon_194_AUG_II);
        _WTAdd(195, Icon_195_AUG_III);
        _WTAdd(197, Icon_197_VSK94);
        _WTAdd(21001, Icon_21001_HEAL_PISTOL_Y);
        _WTAdd(21002, Icon_21002_M590);
        _WTAdd(228, Icon_228_MAC10_I);
        _WTAdd(229, Icon_229_MAC10_II);
        _WTAdd(230, Icon_230_MAC10_III);
        _WTAdd(1204, Icon_1204_Keo1);
        _WTAdd(601,  Icon_601_bom);
        _WTAdd(1001, Icon_1001_luatrai);
    });
}

namespace {

static void WeaponNameToUpperAscii(const char *in, char *out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = '\0';
    if (!in) return;
    size_t i = 0;
    for (; in[i] && i + 1 < cap; i++) {
        char c = in[i];
        if (c >= 'a' && c <= 'z') c = (char)(c - 32);
        out[i] = c;
    }
    out[i] = '\0';
}

static bool WeaponNameContains(const char *hayUpper, const char *needle) {
    if (!hayUpper || !needle || !needle[0]) return false;
    const size_t nlen = strlen(needle);
    for (const char *p = hayUpper; *p; p++) {
        if (strncmp(p, needle, nlen) == 0)
            return true;
    }
    return false;
}

static void WeaponCanonicalFromTxtItem(const char *txtUpper, char *out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = '\0';
    if (!txtUpper) return;

    const char *src = txtUpper;
    if (strncmp(txtUpper, "TXT_ITEM_", 9) == 0)
        src = txtUpper + 9;

    char temp[96] = {};
    strncpy(temp, src, sizeof(temp) - 1);

    char suffix[16] = {};
    struct { const char *from; const char *to; } sufmap[] = {
        {"_III", "-III"}, {"_II", "-II"}, {"_I", "-I"},
        {"_3", "-III"}, {"_2", "-II"}, {"_1", "-I"},
        {"_Y", "-Y"}, {"_X", "-X"},
    };
    for (const auto &s : sufmap) {
        const size_t bl = strlen(temp);
        const size_t sl = strlen(s.from);
        if (bl > sl && strcmp(temp + bl - sl, s.from) == 0) {
            temp[bl - sl] = '\0';
            if (strcmp(temp, "USP") == 0 && strcmp(s.from, "_2") == 0)
                strncpy(suffix, "-2", sizeof(suffix) - 1);
            else
                strncpy(suffix, s.to, sizeof(suffix) - 1);
            break;
        }
    }

    if (!suffix[0] && strncmp(temp, "USP", 3) == 0 && temp[3] >= '0' && temp[3] <= '9') {
        snprintf(out, cap, "USP-%s", temp + 3);
        return;
    }

    size_t j = 0;
    for (size_t i = 0; temp[i] && j + 1 < cap; i++) {
        char c = temp[i];
        if (c == '_') {
            if (temp[i + 1] >= '0' && temp[i + 1] <= '9' && j + 2 < cap) {
                out[j++] = '-';
                continue;
            }
            c = ' ';
        }
        out[j++] = c;
    }
    for (const char *p = suffix; *p && j + 1 < cap; p++)
        out[j++] = *p;
    out[j] = '\0';
}

static void WeaponCanonicalFromGameKey(const char *keyUpper, char *out, size_t cap) {
    if (!out || cap == 0) return;
    out[0] = '\0';
    if (!keyUpper || !keyUpper[0]) return;

    if (strncmp(keyUpper, "TXT_ITEM_", 9) == 0) {
        WeaponCanonicalFromTxtItem(keyUpper, out, cap);
        return;
    }

    const char *itemTag = strstr(keyUpper, "_ITEM_");
    if (itemTag) {
        char tmp[128] = {};
        snprintf(tmp, sizeof(tmp), "TXT_ITEM_%s", itemTag + 6);
        WeaponCanonicalFromTxtItem(tmp, out, cap);
        if (out[0]) return;
    }

    const char *wpnTag = strstr(keyUpper, "_WEAPON_");
    if (wpnTag) {
        wpnTag += 8;
        size_t j = 0;
        for (size_t i = 0; wpnTag[i] && j + 1 < cap; i++) {
            if (strncmp(wpnTag + i, "_NAME", 5) == 0) break;
            char c = wpnTag[i];
            if (c == '_') c = ' ';
            out[j++] = c;
        }
        out[j] = '\0';
        if (out[0]) return;
    }

    WeaponNameToUpperAscii(keyUpper, out, cap);
}

static int LookupWeaponIconType(const char *upperKey) {
    if (!upperKey || !upperKey[0]) return 1;

    struct { const char *key; int type; } map[] = {
        {"TXT_ITEM_M4A1", 2}, {"TXT_ITEM_AK", 6}, {"TXT_ITEM_SCAR", 12},
        {"TXT_ITEM_GROZA", 14}, {"T_32_YF_GOLD_GROZA_N", 70},
        {"TXT_ITEM_FAMAS", 24}, {"TXT_ITEM_XM8", 28},
        {"T_12_Q_ITEM_AN94", 33}, {"T_17_Q_SUPERHEAT", 39},
        {"T_23_U_AUG", 46}, {"T_24_U_PARAFAL", 47},
        {"T_28_YF_AR15", 2}, {"T_33_YF_G36_N", 73},
        {"T_20_U_SHIELD_GUN_NAME", 99},
        {"TXT_ITEM_SKS", 18}, {"TXT_ITEM_SVD", 26},
        {"T_32_YF_GOLD_SVD_N", 72}, {"T_24_U_M21A5", 48},
        {"T_29_HI_MINI14", 57}, {"TXT_ITEM_M14", 11},
        {"T_51_CJ_W_WINCHESTER", 45},
        {"TXT_ITEM_M249", 19}, {"T_32_YF_GOLD_M249_N", 71},
        {"TXT_OB10_HQW_ITEM_M60", 30}, {"T_27_U_KORD", 54},
        {"T_32_U_GOLD_M60_I", 61}, {"T_32_U_GOLD_M60_II", 122},
        {"T_32_U_GOLD_M60_III", 123},
        {"TXT_ITEM_UMP", 7}, {"TXT_ITEM_MP5", 8}, {"TXT_ITEM_VSS", 13},
        {"TXT_ITEM_MP40", 15}, {"TXT_OB11_HQW_ITEM_P90", 32},
        {"T_15_Q_ITEM_CG15", 35}, {"T_25_U_VECTOR", 49},
        {"T_31_YF_MAC10_N", 88}, {"T_35_YF_PP19_N", 150},
        {"T_21_U_WEAPON_THOMPSON_NAME", 43}, {"T_51_CJ_W_THOMPSON_X", 43},
        {"TXT_ITEM_M1014", 5}, {"TXT_ITEM_SPAS12", 29},
        {"T_18_U_WEAPON_M1887_NAME", 41}, {"T_32_RW_WEAPON_M1887TD_NAME", 119},
        {"T_25_U_MAG7", 50}, {"T_32_YF_CHARGESHOT_N", 86},
        {"T_37_JL_M1216_N", 5}, {"T_44_CJ_W_AIRBURST", 21002},
        {"TXT_ITEM_AWM", 4}, {"T_22_U_GOLD_AWM_N", 65},
        {"TXT_ITEM_KAR98K", 21}, {"T_22_C_BLT_NAME", 21},
        {"T_34_YF_M24_N", 75}, {"T_43_WT_W_VSK94", 197},
        {"T_30_YF_HEALINGGUN_SNIPER_N", 78},
        {"TXT_ITEM_USP", 3}, {"TXT_ITEM_EAGLE", 9},
        {"TXT_ITEM_G18", 10}, {"TXT_ITEM_M1873", 20},
        {"TXT_ITEM_M500", 25}, {"T_27_U_M1917", 55},
        {"T_27_U_WSP", 56}, {"T_28_HI_UZI", 58},
        {"T_12_Q_ITEM_TREATMENTGUN", 93},
        {"T_45_CJ_TREATMENTGUN_Y_N", 21001},
        {"T_24_C_FLAMETHROWER_NAME", 100},
        {"TXT_ITEM_CHANGUO", 16}, {"TXT_ITEM_MACHETE", 17},
        {"TXT_ITEM_BASEBALLPOLE", 27}, {"T_14_G_ITEM_KATANA", 34},
        {"T_25_U_SICKLE", 51},
        {"TXT_ITEM_FIST", 1},
        {"M4A1-III", 82}, {"M4A1-II", 81}, {"M4A1-I", 80},
        {"SCAR-III", 180}, {"SCAR-II", 179}, {"SCAR-I", 178},
        {"MP5-III", 121}, {"MP5-II", 120}, {"MP5-I", 60},
        {"M60-III", 123}, {"M60-II", 122}, {"M60-I", 61},
        {"VSS-III", 125}, {"VSS-II", 124}, {"VSS-I", 62},
        {"M14-III", 127}, {"M14-II", 126}, {"M14-I", 63},
        {"KAR98K-III", 129}, {"KAR98K-II", 128}, {"KAR98K-I", 64},
        {"FAMAS-III", 131}, {"FAMAS-II", 130}, {"FAMAS-I", 67},
        {"AUG-III", 195}, {"AUG-II", 194}, {"AUG-I", 193},
        {"M1014-III", 186}, {"M1014-II", 185}, {"M1014-I", 184},
        {"MAC10-III", 230}, {"MAC10-II", 229}, {"MAC10-I", 228},
        {"HEAL PISTOL-Y", 21001}, {"TREATMENT PISTOL-Y", 21001},
        {"DESERT EAGLE", 9}, {"MINI UZI", 58},
        {"CHARGE BUSTER", 86}, {"FLAMETHROWER", 100}, {"SHIELD GUN", 99},
        {"TREATMENT SNIPER", 78}, {"HEAL SNIPER", 78},
        {"TREATMENT PISTOL", 93}, {"HEAL PISTOL", 93},
        {"G36 ASSAULT", 73}, {"G36 RANGE", 74},
        {"WOODPECKER", 48}, {"KINGFISHER", 57}, {"KORD", 54},
        {"THOMPSON", 43}, {"THOMSON", 43},
        {"PARAFAL", 47}, {"VECTOR", 49},
        {"KAR98K", 21}, {"M1014", 5}, {"SPAS-12", 29}, {"SPAS12", 29}, {"SPAS 12", 29},
        {"M1887", 41}, {"MAG-7", 50}, {"MAG7", 50}, {"MAG 7", 50}, {"M590", 21002},
        {"TROGON", 181}, {"GROZA-X", 70}, {"GROZA", 14},
        {"FAMAS", 24}, {"M249-X", 71}, {"M249X", 71}, {"M249", 19},
        {"M1887-X", 119}, {"AWM-Y", 65}, {"SVD-Y", 72},
        {"M82B", 45}, {"M24", 75}, {"VSK94", 197},
        {"AC80", 89}, {"AN94", 33}, {"PLASMA", 39},
        {"CG15", 35}, {"MAC10", 88}, {"PP-19", 150}, {"PP19", 150}, {"PP 19", 150},
        {"BIZON", 150}, {"SCAR", 12}, {"AUG", 46}, {"AK47", 6},
        {"M4A1", 2}, {"XM8", 28}, {"UMP", 7}, {"MP5", 8},
        {"VSS", 13}, {"MP40", 15}, {"P90", 32}, {"M14", 11},
        {"M60", 30}, {"SVD", 26}, {"AWM", 4}, {"USP-2", 56}, {"USP", 3},
        {"G18", 10}, {"M1873", 20}, {"M500", 25}, {"M1917", 55},
        {"SKS", 18}, {"G36", 73},
        {"AR15", 2}, {"CHANGUO", 16}, {"BASEBALLPOLE", 27},
        {"MINI14", 57}, {"M1216", 5}, {"SUPERHEAT", 39},
        {"WINCHESTER", 45}, {"HEALINGGUN", 78}, {"SICKLE", 51},
        {"AIRBURST", 21002}, {"CHARGESHOT", 86}, {"THOMPSON-X", 43},
        {"GOLD GROZA", 70}, {"GOLD SVD", 72}, {"GOLD M249", 71}, {"GOLD AWM", 65},
        {"BASEBALL BAT", 27}, {"BAT", 27}, {"KATANA", 34},
        {"SCYTHE", 51}, {"PAN", 16}, {"PARANG", 17}, {"MACHETE", 17},
        {"FIST", 1},
    };

    for (const auto &e : map) {
        if (strcmp(upperKey, e.key) == 0) return e.type;
    }
    for (const auto &e : map) {
        if (WeaponNameContains(upperKey, e.key)) return e.type;
    }
    return 1;
}

static int IconTypeForWeaponName(const char *name) {
    if (!name || !name[0]) return 1;

    char upper[128] = {};
    WeaponNameToUpperAscii(name, upper, sizeof(upper));

    int type = LookupWeaponIconType(upper);
    if (type != 1) return type;

    char canon[128] = {};
    WeaponCanonicalFromGameKey(upper, canon, sizeof(canon));
    if (canon[0]) {
        type = LookupWeaponIconType(canon);
        if (type != 1) return type;
    }

    return 1;
}

} // namespace

UIImage *WeaponIconForName(const char *name) {
    InitWeaponTextures();

    if (!name || !name[0]) name = "TXT_ITEM_FIST";

    const int type = IconTypeForWeaponName(name);
    UIImage *img = gWeaponTextures[@(type)];
    if (!img)
        img = gWeaponTextures[@(1)];
    return img;
}
