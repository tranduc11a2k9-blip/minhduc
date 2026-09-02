// Auto-updated by scripts/update_offsets.py @ 2026-08-05T23:29:03
#pragma once

// ============================================================
// Free Fire MAX — mapped from dump.cs vs FF THG season dump
// Dumps: D:\Download\dump ff max\  +  D:\Download\dump ff thg\
// Pattern: Max ≈ TH + 0x8 on Player mid-fields; +0x18 on late fields
// ============================================================

// script.json TypeInfo
#define MAX_kGameFacadeTypeInfo      0xC361EB0  // COW.GameFacade_TypeInfo
#define MAX_kTypeInfoStatics         0xB8
#define MAX_kCurrentGame             0x0
#define MAX_kCurrentMatchGame        0x8

// MatchGame / Match (EMKJHAJNPDH) — same layout as TH
#define MAX_kMatch                   0x90
#define MAX_kMatchLocalPlayer        0xD8   // PDBGEOANOEP
#define MAX_kCameraControllerManager 0xD8
#define MAX_kMainCamera              0x20
#define MAX_kCameraInner             0x10
#define MAX_kViewMatrixOff           0x80
#define MAX_kProjMatrixOff           0xC0
#define MAX_kBodyPartTransNode       0x10

// Bones = FFTH proven layout + 0x8 (Max player fields shifted)
#define MAX_kHeadNode                0x640
#define MAX_kHipNode                 0x648
#define MAX_kLeftShoulderNode        0x660
#define MAX_kRightShoulderNode       0x668
#define MAX_kLeftAnkleNode           0x678
#define MAX_kRightAnkleNode          0x680
#define MAX_kLeftToeNode             0x688
#define MAX_kRightToeNode            0x690
#define MAX_kRightHandNode           0x6B8
#define MAX_kLeftHandNode            0x6C0
#define MAX_kRightElbowNode          0x6C8
#define MAX_kLeftElbowNode           0x6D0

// Identity (TH + 8)
#define MAX_kPlayerIDStruct          0x3A8
#define MAX_kPlayerID                0x3A8  // BMIGBNMBAJH
#define MAX_kUserID                  0x398  // ulong before PlayerID
#define MAX_kIsClientBot             0x440
#define MAX_kNickname                0x430  // MOKGDCJLJFI
#define MAX_kNicknameDisplay         0x438  // OriginalNickName
#define MAX_kStringFirstChar         0x14
#define MAX_kMainCameraTransform     0x388

// PRI pool field on Player still via getter; keep inner layout
#define MAX_kDataPool                0x70
#define MAX_kDataPoolInner           0x10
#define MAX_kDataPoolEntriesBase     0x20
#define MAX_kDataPoolEntryStride     0x8
#define MAX_kDataPoolValue           0x18

// Aim (confirmed)
#define MAX_kAimRotation             0x5B4
#define MAX_kAimRotationAux          0x5C4
#define MAX_kCurrentAimRotation      0x19A4
#define MAX_kAimAssistTypeInfo       0xC3651F8  // COW.GamePlay.KBCJOEFJEFJ_TypeInfo
#define MAX_kAaStaticKnolgmjlcef     0x24
#define MAX_kAimAssistPtr             0x5D8
#define MAX_kAimAssistIceWallPtr      0x5E0
#define MAX_kEAimAssistMode           0x600
#define MAX_kPlayerAnimComponent      0x700
#define MAX_kPlayerAttributes         0x708  // Player.KDJHNBAECLM (TH 0x700 + 8)
#define MAX_kRunSpeedUpScale          0x270  // PlayerAttributes.RunSpeedUpScale
#define MAX_kAaStaticNfkcllpalej     0x28
#define MAX_kIsFiring                0x1C14 // Player.POPKKGFEMLJ StartFireState (TH 0x1BFC + 0x18)
#define MAX_kIsPrepareAttack         0x7D8  // <NNFKGNCILNK> get_IsPrepareAttack (MAX dump)
#define MAX_kLastFireBtnDownTime     0x1770 // TH 0x1758 + 0x18
#define MAX_kLastPlayBulletTrackEffectTime 0xE04 // TH 0xDFC + 8
#define MAX_kLastSmartFireTime       0xD70  // TH 0xD68 + 8

// Visibility BitArrayBoolean (TH 0xA40 + 8)
#define MAX_kVisibleObj              0xA48
#define MAX_kVisibleObjFlags         0x10
#define MAX_kISVisibleCamera         0x1
#define MAX_kISVisibleDynamicPVS     0x100000
#define MAX_kISVisibleFPPMask        0xFFFBFFFF

// Knock / rescue / physx (TH + 0x18 on this region)
#define MAX_kKnocked                 0x11B8  // IsKnockedDownBleed (TH 0x11A0)
#define MAX_kBeingRescuredState      0x1AF2  // FKGCAKMAGMF byte (TH 0x1ADA)
#define MAX_kMyPhysXData             0x1B98  // get_MyPhsXData IFGAOAHPNOC (TH 0x1B80)
#define MAX_kPhxNpeononogeo          0x20
#define MAX_kGhgState                0x10

// Match player dict — Dictionary<BHGGAEEHJCO,Player> @ 0x128 (NOT 0x148 which is byte key)
// BHGGAEEHJCO key size 0x18 => entry stride 0x28, Player* value @ 0x20
#define MAX_kMatchPlayerDict         0x128
#define MAX_kDictEntries             0x18
#define MAX_kDictCount               0x20
#define MAX_kIl2CppArrayMaxLength    0x18
#define MAX_kIl2CppArrayItems        0x20
#define MAX_kDictEntryStrideBytePlayer 0x28
#define MAX_kDictEntryValueOffByte   0x20

#define MAX_kTransformInner          0x10
#define MAX_kTransformMatrix         0x38
#define MAX_kTransformIndex          0x40
#define MAX_kMatrixList              0x18
#define MAX_kMatrixIndices           0x20

// Weapon (TH + 8 for player weapon pointers)
#define MAX_kActiveWeapon            0x5A0  // ActiveUISightingWeapon
#define MAX_kWeaponID                0x600
#define MAX_kWeaponCategory          0xC4
#define MAX_kWeaponHolder            0x6E0  // OMELKCOGCBK
#define MAX_kHolderActiveWeapon      0xA0
// Fast switch path on weapon object (same on TH/MAX from dump)
#define MAX_kWeaponRepItem           0x710  // FDAEPHMIEPC.UGCWeaponRepItem
#define MAX_kSwitchWeaponTime        0x204  // UGCWeaponRepItem.SwitchWeaponTime
#define MAX_kPreSwitchWeaponTime     0x208
#define MAX_kPostSwitchWeaponTime    0x20C

// Silent hit object GMPGMPFNMFP (TH 0xDC8/0xDD0 + 8)
#define MAX_kHitObjectInfo           0xDD0
#define MAX_kHitObjectInfoAlt        0xDD8

// Vehicle / zipline (Player mid fields TH + 8)
// TH dump: VehicleIAmIn 0x8A8, LevelStropIAmOn 0x8C0, RootNode 0x630
#define MAX_kVehicleIAmIn            0x8B0
#define MAX_kLevelStropIAmOn         0x8C8
#define MAX_kRootNode                0x638
// Player.OKOLMFJKGEC Transform (TH 0x698 + 8)
#define MAX_kPlayerTransform         0x6A0
// Wall-off LOS last weapon target (TH 0xDE0 + 8)
#define MAX_kLastAimingTargetFromWeapon 0xDE8

// Instant consumable wrap — dump ff max
// Scene/timer field offs same as TH; PlayerNetwork prep block +0x18 vs TH
// Player.KBHMGGLIMLI @ 0x464 (TH 0x45C); curing flags after m_GetInVehicle @ 0x498
#define MAX_kBaseGameUIScene            0x10
#define MAX_kUIInGameScenePrepareCtrl   0x698
#define MAX_kUIInGameSceneQuickUseMedkit 0x978
#define MAX_kPrepTimerStartTime         0xA0
#define MAX_kPrepTimerTotalTime         0xA4
#define MAX_kPrepTimerContextType       0xA8
#define MAX_kPrepTimerStage1Time        0xAC
#define MAX_kPrepTimerIsFinished        0x118
#define MAX_kPrepTimerProgressSpeed     0x138
#define MAX_kPrepTimerProgressRate      0x13C
#define MAX_kPlayerPrepTimerType        0x464
#define MAX_kPlayerNetPrepDuration      0x22F8  // PNEEICGMOGG (TH 0x22E0 + 0x18)
#define MAX_kPlayerNetPrepType          0x22FC  // JOJOJDCFNAK
#define MAX_kPlayerNetPrepFloatA        0x230C  // BBJCHDAJIBC
#define MAX_kPlayerNetPrepFloatB        0x2310  // JFOPDHIHIIC
#define MAX_kPlayerIsCuring             0x499
#define MAX_kPlayerIsPreparing          0x49A
#define MAX_kPlayerIsEating             0x49B
#define MAX_kPlayerIsRepairing          0x49C
#define MAX_kPlayerNetPrepFloatC        0x2314  // JIABJHJGDKL (TH 0x22FC + 0x18)
#define MAX_kPlayerNetPrepFloatD        0x2320  // EJKGAPAHABD (TH 0x2308 + 0x18)
// OMDPILKGAJF consumable weapon layout same as TH
#define MAX_kWeaponConsumableCsv          0x68
#define MAX_kWeaponConsumableCsvFloatA    0x24
#define MAX_kWeaponConsumableCsvFloatB    0x28
#define MAX_kWeaponConsumableCsvFloatC    0x40
#define MAX_kWeaponRepairRepItem          0x78
#define MAX_kWeaponFirstAidRepItem        0x80
#define MAX_kWeaponInhalerRepItem         0x88
#define MAX_kUGCFirstAidDuration          0x34
#define MAX_kUGCFirstAidPretime           0x38
#define MAX_kUGCRepairPreTime             0x20

