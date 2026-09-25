// Auto-updated by scripts/update_offsets.py @ 2026-09-16 (FF MAX 2.132.1)
#pragma once

// ============================================================
// Free Fire MAX 2.132.1 — derived from FF-dumper-max_2.132.1 dump + DSGames FFMAX scanner/native getters
// Dumps: D:\Download\dump ff max\  +  D:\Download\dump ff thg\
// Pattern: Max ≈ TH + 0x8 on Player mid-fields; +0x18 on late fields
// ============================================================

// script.json TypeInfo
#define MAX_kGameFacadeTypeInfo 0xbe93418  // COW.GameFacade_TypeInfo
#define MAX_kTypeInfoStatics 0xb8
#define MAX_kCurrentGame 0x0
#define MAX_kCurrentMatchGame 0x8

// MatchGame / Match (EMKJHAJNPDH) — same layout as TH
#define MAX_kMatch 0x90
#define MAX_kMatchLocalPlayer 0xd8   // PDBGEOANOEP
#define MAX_kMatchGameSceneLoaded 0x140 // MatchGame.m_SceneLoaded
#define MAX_kCameraControllerManager 0xd8
#define MAX_kMainCamera 0x20
#define MAX_kCameraInner 0x10
#define MAX_kViewMatrixOff 0x80
#define MAX_kProjMatrixOff 0xc0
#define MAX_kBodyPartTransNode       0x10

// Bones = FFTH proven layout + 0x8 (Max player fields shifted)
#define MAX_kHeadNode 0x6a8
#define MAX_kHipNode 0x6b0
#define MAX_kLeftShoulderNode 0x6c8
#define MAX_kRightShoulderNode 0x6d0
#define MAX_kNeckNode 0x6b8    // TH 0x6B0 + 8
#define MAX_kChestNode 0x6c0   // TH 0x6B8 + 8
#define MAX_kSpineNode 0x6d8   // TH 0x6D0 + 8
#define MAX_kLeftAnkleNode 0x6e0
#define MAX_kRightAnkleNode 0x6e8
#define MAX_kLeftToeNode 0x6f0
#define MAX_kRightToeNode 0x6f8
#define MAX_kRightHandNode 0x720
#define MAX_kLeftHandNode 0x728
#define MAX_kRightElbowNode 0x730
#define MAX_kLeftElbowNode 0x738

// Identity (TH + 8)
#define MAX_kPlayerIDStruct 0x410
#define MAX_kPlayerID 0x410  // BMIGBNMBAJH
#define MAX_kUserID 0x400  // ulong before PlayerID
#define MAX_kIsClientBot 0x4A8 // FF 0x4A0 + 0x8 mid-field shift
#define MAX_kIsDead 0x7c
#define MAX_kEntityRecycled 0x28
#define MAX_kEntityNeedUpdate 0x20
#define MAX_kNickname 0x498  // MOKGDCJLJFI
#define MAX_kNicknameDisplay 0x4a0  // OriginalNickName
#define MAX_kStringFirstChar         0x14
#define MAX_kMainCameraTransform 0x3f0

// PRI pool field on Player still via getter; keep inner layout
#define MAX_kDataPool 0x70
#define MAX_kDataPoolInner           0x10
#define MAX_kDataPoolEntriesBase     0x20
#define MAX_kDataPoolEntryStride     0x8
#define MAX_kDataPoolValue           0x18

// Aim (confirmed)
#define MAX_kAimRotation 0x61c
#define MAX_kAimRotationAux 0x630
#define MAX_kCurrentAimRotation 0x1aa4
#define MAX_kCallSetAimRotationCount 0x818 // TH 0x810 + 8 mid-field shift (IsPrepareAttack 0x848→0x850)
#define MAX_kUserControlHandler 0x4D8 // TH 0x4D0 + 8 (Nickname 0x490→0x498, IsClientBot 0x4A0→0x4A8, prep 0x4C4→0x4CC all +8 — LBPGBNKABJE sits in same block)
#define MAX_kAimAssistTypeInfo 0xbe94a58  // COW.GamePlay.KBCJOEFJEFJ_TypeInfo
// GameVarDef TypeInfo — unverified MAX guess: FF GameFacade+GameVarDef delta = +0xA8
#define MAX_kGameVarDefTypeInfo 0xbe934c0 // MAX GameFacadeTypeInfo 0xbe93418 + 0xA8 (FF pattern)
#define MAX_kGvdEnableCheckBuf 0x458C
#define MAX_kGvdEnableAimInputSample 0x458D
#define MAX_kGvdAimInputSampleCount 0x4590
#define MAX_kGvdAimInputSampleIntervalTick 0x4594
#define MAX_kGvdEnableInternalSetRotation 0xE4 // GameVarDef statics early field — same as TH unless dump says otherwise
#define MAX_kGvdRotationPlan 0x380C // same as TH unless dump says otherwise
#define MAX_kAaStaticKnolgmjlcef 0x24
#define MAX_kAimAssistPtr 0x640
#define MAX_kAimAssistIceWallPtr 0x648
#define MAX_kEAimAssistMode 0x668
#define MAX_kPlayerAnimComponent 0x768
#define MAX_kPlayerAttributes 0x770  // Player.KDJHNBAECLM (TH 0x700 + 8)
#define MAX_kRunSpeedUpScale 0x2c0  // PlayerAttributes.RunSpeedUpScale
#define MAX_kAaStaticNfkcllpalej 0x28
#define MAX_kIsFiring 0x259 // Player.POPKKGFEMLJ StartFireState (TH 0x1BFC + 0x18)
#define MAX_kIsPrepareAttack 0x850  // <NNFKGNCILNK> get_IsPrepareAttack (MAX dump)
#define MAX_kLastFireBtnDownTime 0x1854 // TH 0x1758 + 0x18
#define MAX_kLastPlayBulletTrackEffectTime 0xe8c // TH 0xDFC + 8
#define MAX_kLastSmartFireTime 0xdf8  // TH 0xD68 + 8

// Visibility BitArrayBoolean (TH 0xA40 + 8)
#define MAX_kVisibleObj 0xad8
#define MAX_kVisibleObjFlags 0x10
#define MAX_kISVisibleCamera         0x1
#define MAX_kISVisibleDynamicPVS     0x100000
#define MAX_kISVisibleFPPMask        0xFFFBFFFF

// Knock / rescue / physx (TH + 0x18 on this region)
#define MAX_kKnocked 0x1270  // IsKnockedDownBleed (TH 0x11A0)
#define MAX_kBeingRescuredState 0x1cba  // FKGCAKMAGMF byte (TH 0x1ADA)
#define MAX_kMyPhysXData 0x1d60  // get_MyPhsXData IFGAOAHPNOC (TH 0x1B80)
#define MAX_kPhxNpeononogeo          0x20
#define MAX_kGhgState                0x10

// Match player dict — Dictionary<BHGGAEEHJCO,Player> @ 0x128 (NOT 0x148 which is byte key)
// BHGGAEEHJCO key size 0x18 => entry stride 0x28, Player* value @ 0x20
#define MAX_kMatchPlayerDict 0x128
#define MAX_kDictEntries             0x18
#define MAX_kDictCount               0x20
#define MAX_kIl2CppArrayMaxLength    0x18
#define MAX_kIl2CppArrayItems        0x20
#define MAX_kDictEntryStrideBytePlayer 0x28
#define MAX_kDictEntryValueOffByte   0x20

#define MAX_kTransformInner          0x10
#define MAX_kTransformMatrix 0x38
#define MAX_kTransformIndex 0x40
#define MAX_kMatrixList 0x18
#define MAX_kMatrixIndices 0x20

// Weapon (TH + 8 for player weapon pointers)
#define MAX_kActiveWeapon 0x608  // ActiveUISightingWeapon
#define MAX_kWeaponID                0x600
#define MAX_kWeaponCategory          0xC4
#define MAX_kWeaponHolder 0x748  // OMELKCOGCBK
#define MAX_kHolderActiveWeapon 0xa0
// Fast switch path on weapon object (same on TH/MAX from dump)
#define MAX_kWeaponRepItem 0x768  // FDAEPHMIEPC.UGCWeaponRepItem
#define MAX_kSwitchWeaponTime 0x284  // UGCWeaponRepItem.SwitchWeaponTime
#define MAX_kPreSwitchWeaponTime 0x288
#define MAX_kPostSwitchWeaponTime 0x28c

// Silent hit object CGKJLKPMGDJ (TH 0xE50/0xE58 + 8)
#define MAX_kHitObjectInfo 0xe58
#define MAX_kHitObjectInfoAlt 0xe60
#define MAX_kHitObjectDir 0x40
#define MAX_kHitObjectOrigin 0x4c
#define MAX_kFollowCameraObj 0x698 // FF 0x690 + 0x8
#define MAX_kFollowCameraDistance 0x70

// Vehicle / zipline (Player mid fields TH + 8)
// TH dump: VehicleIAmIn 0x8A8, LevelStropIAmOn 0x8C0, RootNode 0x630
#define MAX_kVehicleIAmIn 0x928
#define MAX_kLevelStropIAmOn 0x940
#define MAX_kRootNode 0x6a0
// Player.OKOLMFJKGEC Transform (TH 0x698 + 8)
#define MAX_kPlayerTransform 0x708
// Wall-off LOS last weapon target (TH 0xE68 + 8)
#define MAX_kLastAimingTargetFromWeapon 0xe70

// Instant consumable wrap — dump ff max
// Scene/timer field offs same as TH; PlayerNetwork prep block +0x18 vs TH
// Player.KBHMGGLIMLI @ 0x464 (TH 0x45C); curing flags after m_GetInVehicle @ 0x498
#define MAX_kBaseGameUIScene 0x10
#define MAX_kUIInGameScenePrepareCtrl 0x730
#define MAX_kUIInGameSceneQuickUseMedkit 0xa40
#define MAX_kPrepTimerStartTime 0xb0
#define MAX_kPrepTimerTotalTime 0xb4
#define MAX_kPrepTimerContextType 0xb8
#define MAX_kPrepTimerStage1Time 0xbc
#define MAX_kPrepTimerIsFinished 0x128
#define MAX_kPrepTimerProgressSpeed 0x148
#define MAX_kPrepTimerProgressRate 0x14c
#define MAX_kPlayerPrepTimerType 0x4cc
#define MAX_kPlayerNetPrepDuration 0x2528  // PNEEICGMOGG (TH 0x22E0 + 0x18)
#define MAX_kPlayerNetPrepType 0x252c  // JOJOJDCFNAK
#define MAX_kPlayerNetPrepFloatA 0x253c  // BBJCHDAJIBC
#define MAX_kPlayerNetPrepFloatB 0x2540  // JFOPDHIHIIC
#define MAX_kPlayerIsCuring 0x4f8
#define MAX_kPlayerIsPreparing 0x501
#define MAX_kPlayerIsEating 0x502
#define MAX_kPlayerIsRepairing 0x503
#define MAX_kPlayerNetPrepFloatC 0x2544  // JIABJHJGDKL (TH 0x22FC + 0x18)
#define MAX_kPlayerNetPrepFloatD 0x2550  // EJKGAPAHABD (TH 0x2308 + 0x18)
// OMDPILKGAJF consumable weapon layout same as TH
#define MAX_kWeaponConsumableCsv 0x68
#define MAX_kWeaponConsumableCsvFloatA 0x24
#define MAX_kWeaponConsumableCsvFloatB 0x28
#define MAX_kWeaponConsumableCsvFloatC 0x40
#define MAX_kWeaponRepairRepItem 0x78
#define MAX_kWeaponFirstAidRepItem 0x80
#define MAX_kWeaponInhalerRepItem 0x88
#define MAX_kUGCFirstAidDuration 0x34
#define MAX_kUGCFirstAidPretime 0x38
#define MAX_kUGCRepairPreTime 0x20

// ===== ĐẠN THẲNG + FPP RECOIL (MAX — clone TH tới khi có dump MAX riêng) =====
#define MAX_kRepFireInterval 0x1f8
#define MAX_kRepRepeatFireInterval 0x220
#define MAX_kRepScatterNum 0x214
#define MAX_kRepScatterMax 0x218
#define MAX_kRepScatterSpeed 0x260
#define MAX_kRepScatterRecoverSpeed 0x264
#define MAX_kRepScatterMove 0x26c
#define MAX_kAttrsBuffWeaponScatterScale 0x118
#define MAX_kAttrsBuffEcaWeaponScatterScale 0x120
#define MAX_kAttrsBuffEcaIgnoreWeaponScatter 0x350
#define MAX_kAttrsReloadNoConsumeAmmo 0xd8
#define MAX_kAttrsShootNoReload 0xd9
#define MAX_kAttrsFireIntervalScale 0x258
#define MAX_kAttrsFireIntervalScaleTwo 0x270
#define MAX_kAttrsFireIntervalScaleBuffECA 0x268
#define MAX_kScaleAccumA                  0x18
#define MAX_kScaleAccumB                  0x1C
#define MAX_kScaleAccumC                  0x20
#define MAX_kScaleAccumD                  0x24
#define MAX_kScaleAccumE                  0x28
#define MAX_kSafeRefHashSet               0x10
#define MAX_kHashSetBuckets               0x10
#define MAX_kHashSetSlots                 0x18
#define MAX_kHashSetCount                 0x20
#define MAX_kHashSetLastIndex             0x24
#define MAX_kHashSetFreeList              0x28
#define MAX_kFppGameModeEnable 0x829
#define MAX_kFppRecoil 0x870
#define MAX_kFppVibrateRotate 0x871
#define MAX_kFppVibrateRotateSpeed 0x874
#define MAX_kFppRecoilYCycleTime 0x880
#define MAX_kFppRecoilZCycleTime 0x884
#define MAX_kFppRecoilYFactor 0x888
#define MAX_kFppRecoilZFactor 0x88c
#define MAX_kFppRecoilBackwardX 0x890
#define MAX_kFppRecoilBackwardZ 0x894
#define MAX_kFppRecoilBackwardSpeed 0x898
#define MAX_kFppCameraMaxfireRotateAngle 0x8b4
#define MAX_kFppCameraFireRotateTime 0x8b8
#define MAX_kRuntimeWeapon 0x1800

