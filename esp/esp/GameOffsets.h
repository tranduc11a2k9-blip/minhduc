#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Runtime offset table selected by Home "Lựa chọn phiên bản".
// Edit FF values in GameOffsets.mm (kOffsetsFF).
// Edit Max values in offsetmax.h (included by GameOffsets.mm).

typedef struct GameOffsets {
    uint64_t GameFacadeTypeInfo;
    uint64_t TypeInfoStatics;
    uint64_t CurrentGame;
    uint64_t CurrentMatchGame;
    uint64_t Match;
    uint64_t MatchLocalPlayer;
    uint64_t CameraControllerManager;
    uint64_t MainCamera;
    uint64_t CameraInner;
    uint64_t ViewMatrixOff;
    uint64_t ProjMatrixOff;
    uint64_t BodyPartTransNode;
    uint64_t HeadNode;
    uint64_t HipNode;
    uint64_t LeftAnkleNode;
    uint64_t RightAnkleNode;
    uint64_t RightToeNode;
    uint64_t LeftToeNode;
    uint64_t LeftShoulderNode;
    uint64_t RightShoulderNode;
    uint64_t LeftHandNode;
    uint64_t RightHandNode;
    uint64_t LeftElbowNode;
    uint64_t RightElbowNode;
    uint64_t PlayerIDStruct;
    uint64_t PlayerID;
    uint64_t UserID;
    uint64_t IsClientBot;
    uint64_t DataPool;
    uint64_t DataPoolInner;
    uint64_t DataPoolEntriesBase;
    uint64_t DataPoolEntryStride;
    uint64_t DataPoolValue;
    uint64_t AimRotation;
    uint64_t AimRotationAux;
    uint64_t CurrentAimRotation;
    uint64_t AimAssistTypeInfo;
    uint64_t AaStaticKnolgmjlcef;
    uint64_t AaStaticNfkcllpalej;
    // Game default aim-assist (chest magnet). Dump: EAimAssist AllOff=2
    uint64_t AimAssistPtr;          // Player.m_AimAssist
    uint64_t AimAssistIceWallPtr;   // Player.m_AimAssistForIceWall
    uint64_t EAimAssistMode;        // Player.FGEAKHHPKCC (EAimAssist)
    uint64_t PlayerAnimComponent;   // NewPlayerAnimationSystemComponent
    uint64_t PlayerAttributes;      // Player.KDJHNBAECLM (PlayerAttributes)
    uint64_t RunSpeedUpScale;       // PlayerAttributes.RunSpeedUpScale
    uint64_t IsFiring;              // legacy StartFireState (NMCBIHOOFFF) — backup only
    uint64_t IsPrepareAttack;     // Player.get_IsPrepareAttack bool (primary fire hold)
    uint64_t LastFireBtnDownTime; // Player.LastFireBtnDownTime (hipfire press)
    uint64_t LastPlayBulletTrackEffectTime; // updates per shot
    uint64_t LastSmartFireTime;
    uint64_t VisibleObj;
    uint64_t VisibleObjFlags;
    uint64_t ISVisibleCamera;
    uint64_t ISVisibleDynamicPVS;
    uint64_t ISVisibleFPPMask;
    uint64_t MainCameraTransform;
    uint64_t MyPhysXData;
    uint64_t PhxNpeononogeo;
    uint64_t GhgState;
    uint64_t Knocked;
    uint64_t BeingRescuredState;
    uint64_t MatchPlayerDict;
    uint64_t DictEntries;
    uint64_t DictCount;
    uint64_t Il2CppArrayMaxLength;
    uint64_t Il2CppArrayItems;
    uint64_t DictEntryStrideBytePlayer;
    uint64_t DictEntryValueOffByte;
    uint64_t TransformInner;
    uint64_t TransformMatrix;
    uint64_t TransformIndex;
    uint64_t MatrixList;
    uint64_t MatrixIndices;
    uint64_t Nickname;
    uint64_t StringFirstChar;
    uint64_t ActiveWeapon;
    uint64_t WeaponID;
    uint64_t WeaponCategory;
    uint64_t WeaponHolder;
    uint64_t HolderActiveWeapon;
    // Fast weapon switch (dump-confirmed path):
    // ActiveWeapon(FDAEPHMIEPC) -> UGCWeaponRepItem @ WeaponRepItem
    //   SwitchWeaponTime / PreSwitchWeaponTime / PostSwitchWeaponTime
    uint64_t WeaponRepItem;          // FDAEPHMIEPC.UGCWeaponRepItem
    uint64_t SwitchWeaponTime;       // UGCWeaponRepItem._SwitchWeaponTime
    uint64_t PreSwitchWeaponTime;    // UGCWeaponRepItem._PreSwitchWeaponTime
    uint64_t PostSwitchWeaponTime;   // UGCWeaponRepItem._PostSwitchWeaponTime
    uint64_t NicknameDisplay;
    uint64_t HitObjectInfo;    // player + off → primary bullet hit object (silent)
    uint64_t HitObjectInfoAlt; // secondary GMPGMPFNMFP (often +8)
    // Vehicle / zipline (cable) — dump Player fields (ESP/aim when skinned bones zero).
    // TH: Vehicle IIPDHPKBDBA @ 0x8A8, LevelStrop JCGPLBAPOLO @ 0x8C0, root bone @ 0x630
    // MAX: +0x8 on these Player mid fields (0x8B0 / 0x8C8 / 0x638)
    uint64_t VehicleIAmIn;     // Player.VehicleIAmIn / GetVehicleIAmIn pointer
    uint64_t LevelStropIAmOn;  // Player.GetStropIAmOn / LevelStrop (cable/zipline)
    uint64_t RootNode;         // Player first ITransformNode (spine/root, not head)
    uint64_t PlayerTransform;  // Player.OKOLMFJKGEC Unity Transform* (TH 0x698) — key for vehicle ESP
    // Wall-off LOS: last weapon raycast attackable target (OKEAMEELLBB*)
    // TH dump: <OHPFIIKIOPJ>k__BackingField @ 0xDE0; MAX @ 0xDE8
    uint64_t LastAimingTargetFromWeapon;
    // Instant consumable wrap (medkit / repair / inhaler / PED / shield):
    // UI path (display + client sim): BaseGame.m_UIScene → PrepareCtrl / QuickUseMedkit
    // Player path (authority-ish client state): Player.KBHMGGLIMLI + PlayerNetwork duration
    // TH≈MAX for scene/timer field offsets; Player prep fields differ (TH 0x45C / MAX 0x464).
    uint64_t BaseGameUIScene;              // BaseGame.m_UIScene (0x10)
    uint64_t UIInGameScenePrepareCtrl;     // UIInGameScene.m_PrepareCtrl (0x698)
    uint64_t UIInGameSceneQuickUseMedkit;  // UIInGameScene.m_UIHudQuickUseMedkitController (0x978)
    uint64_t PrepTimerStartTime;           // UIHudPreparationTimerController.m_StartTime (0xA0)
    uint64_t PrepTimerTotalTime;           // m_TotalTime (0xA4)
    uint64_t PrepTimerContextType;         // m_ContextType EPreparationTimerType (0xA8)
    uint64_t PrepTimerStage1Time;          // m_Stage1Time (0xAC)
    uint64_t PrepTimerIsFinished;          // m_IsPrepareFinished (0x118)
    uint64_t PrepTimerProgressSpeed;       // m_CurrentProgressSpeed (0x138)
    uint64_t PrepTimerProgressRate;        // m_CurrentProgressRate (0x13C)
    uint64_t PlayerPrepTimerType;          // Player.KBHMGGLIMLI EPreparationTimerType
    // PlayerNetwork (local Player subclass) — dump-confirmed next to prep type:
    // TH: PNEEICGMOGG 0x22E0, JOJOJDCFNAK 0x22E4, BBJCHDAJIBC 0x22F4, JFOPDHIHIIC 0x22F8
    // MAX: +0x18 on this block (0x22F8 / 0x22FC / 0x230C / 0x2310)
    uint64_t PlayerNetPrepDuration;        // float next to prep type (likely total / remaining)
    uint64_t PlayerNetPrepType;            // PlayerNetwork.JOJOJDCFNAK EPreparationTimerType
    uint64_t PlayerNetPrepFloatA;          // float after type+uids (start/elapsed candidate)
    uint64_t PlayerNetPrepFloatB;          // second float (progress/remaining candidate)
    // Player curing flags (CompilerGenerated after m_GetInVehicle):
    // TH 0x491..0x494 / MAX 0x499..0x49C — IsCuring, IsPreparing, IsEating, IsRepairing
    uint64_t PlayerIsCuring;
    uint64_t PlayerIsPreparing;
    uint64_t PlayerIsEating;
    uint64_t PlayerIsRepairing;
    // Extra PlayerNetwork floats next to prep block (elapsed/aux candidates).
    // TH: JIABJHJGDKL 0x22FC, EJKGAPAHABD 0x2308; MAX +0x18.
    uint64_t PlayerNetPrepFloatC;
    uint64_t PlayerNetPrepFloatD;
    // Weapon-side consumable duration (OMDPILKGAJF : NAELPAAELNO) — same TH/MAX.
    // Active weapon / holder active may be medkit/repair while curing.
    uint64_t WeaponConsumableCsv;          // OMDPILKGAJF.LFEEICKEBGH @ 0x68
    uint64_t WeaponConsumableCsvFloatA;    // LFEEICKEBGH float @ 0x24 (use/pre candidate)
    uint64_t WeaponConsumableCsvFloatB;    // LFEEICKEBGH float @ 0x28
    uint64_t WeaponConsumableCsvFloatC;    // LFEEICKEBGH float @ 0x40
    uint64_t WeaponRepairRepItem;          // UGCRepairArmorKitRepItem* @ 0x78
    uint64_t WeaponFirstAidRepItem;        // UGCFirstAidKitRepItem* @ 0x80
    uint64_t WeaponInhalerRepItem;         // UGCInhalerRepItem* @ 0x88
    uint64_t UGCFirstAidDuration;          // int Duration @ 0x34 (likely ms)
    uint64_t UGCFirstAidPretime;           // int Pretime @ 0x38 (likely ms)
    uint64_t UGCRepairPreTime;             // float PreTime @ 0x20
} GameOffsets;

/** Active offset table for selected game (never NULL). */
const GameOffsets *GameOffsetsCurrent(void);

/** Re-read SelectedGameId prefs and switch table + process name. Call on Home select and HUD/ESP start. */
void GameOffsetsReload(void);

/** "ff" or "ffmax" (default "ff"). */
#ifdef __OBJC__
NSString *GameTargetSelectedId(void);
void GameTargetSetSelectedId(NSString *gameId);
#endif

/** Process p_comm: FreeFire | FreeFireMAX */
const char *GameTargetProcessName(void);
bool GameTargetIsMax(void);
bool GameTargetIsRunning(void);
int GameTargetProcessPid(void);
uintptr_t GameTargetModuleBase(void);

#ifdef __cplusplus
}
#endif

// Compatibility macros: existing code keeps using kFoo.
// Each expands to the active table field.
#define kGameFacadeTypeInfo           (GameOffsetsCurrent()->GameFacadeTypeInfo)
#define kTypeInfoStatics              (GameOffsetsCurrent()->TypeInfoStatics)
#define kCurrentGame                  (GameOffsetsCurrent()->CurrentGame)
#define kCurrentMatchGame             (GameOffsetsCurrent()->CurrentMatchGame)
#define kMatch                        (GameOffsetsCurrent()->Match)
#define kMatchLocalPlayer             (GameOffsetsCurrent()->MatchLocalPlayer)
#define kCameraControllerManager      (GameOffsetsCurrent()->CameraControllerManager)
#define kMainCamera                   (GameOffsetsCurrent()->MainCamera)
#define kCameraInner                  (GameOffsetsCurrent()->CameraInner)
#define kViewMatrixOff                (GameOffsetsCurrent()->ViewMatrixOff)
#define kProjMatrixOff                (GameOffsetsCurrent()->ProjMatrixOff)
#define kBodyPartTransNode            (GameOffsetsCurrent()->BodyPartTransNode)
#define kHeadNode                     (GameOffsetsCurrent()->HeadNode)
#define kHipNode                      (GameOffsetsCurrent()->HipNode)
#define kLeftAnkleNode                (GameOffsetsCurrent()->LeftAnkleNode)
#define kRightAnkleNode               (GameOffsetsCurrent()->RightAnkleNode)
#define kRightToeNode                 (GameOffsetsCurrent()->RightToeNode)
#define kLeftToeNode                  (GameOffsetsCurrent()->LeftToeNode)
#define kLeftShoulderNode             (GameOffsetsCurrent()->LeftShoulderNode)
#define kRightShoulderNode            (GameOffsetsCurrent()->RightShoulderNode)
#define kLeftHandNode                 (GameOffsetsCurrent()->LeftHandNode)
#define kRightHandNode                (GameOffsetsCurrent()->RightHandNode)
#define kLeftElbowNode                (GameOffsetsCurrent()->LeftElbowNode)
#define kRightElbowNode               (GameOffsetsCurrent()->RightElbowNode)
#define kPlayerIDStruct               (GameOffsetsCurrent()->PlayerIDStruct)
#define kPlayerID                     (GameOffsetsCurrent()->PlayerID)
#define kUserID                       (GameOffsetsCurrent()->UserID)
#define kIsClientBot                  (GameOffsetsCurrent()->IsClientBot)
#define kDataPool                     (GameOffsetsCurrent()->DataPool)
#define kDataPoolInner                (GameOffsetsCurrent()->DataPoolInner)
#define kDataPoolEntriesBase          (GameOffsetsCurrent()->DataPoolEntriesBase)
#define kDataPoolEntryStride          (GameOffsetsCurrent()->DataPoolEntryStride)
#define kDataPoolValue                (GameOffsetsCurrent()->DataPoolValue)
#define kAimRotation                  (GameOffsetsCurrent()->AimRotation)
#define kAimRotationAux               (GameOffsetsCurrent()->AimRotationAux)
#define kCurrentAimRotation           (GameOffsetsCurrent()->CurrentAimRotation)
#define kAimAssistTypeInfo            (GameOffsetsCurrent()->AimAssistTypeInfo)
#define kAaStaticKnolgmjlcef          (GameOffsetsCurrent()->AaStaticKnolgmjlcef)
#define kAaStaticNfkcllpalej          (GameOffsetsCurrent()->AaStaticNfkcllpalej)
#define kAimAssistPtr                 (GameOffsetsCurrent()->AimAssistPtr)
#define kAimAssistIceWallPtr          (GameOffsetsCurrent()->AimAssistIceWallPtr)
#define kEAimAssistMode               (GameOffsetsCurrent()->EAimAssistMode)
#define kPlayerAnimComponent          (GameOffsetsCurrent()->PlayerAnimComponent)
#define kPlayerAttributes             (GameOffsetsCurrent()->PlayerAttributes)
#define kRunSpeedUpScale              (GameOffsetsCurrent()->RunSpeedUpScale)
#define kIsFiring                     (GameOffsetsCurrent()->IsFiring)
#define kIsPrepareAttack              (GameOffsetsCurrent()->IsPrepareAttack)
#define kLastFireBtnDownTime          (GameOffsetsCurrent()->LastFireBtnDownTime)
#define kLastPlayBulletTrackEffectTime (GameOffsetsCurrent()->LastPlayBulletTrackEffectTime)
#define kLastSmartFireTime            (GameOffsetsCurrent()->LastSmartFireTime)
#define kVisibleObj                   (GameOffsetsCurrent()->VisibleObj)
#define kVisibleObjFlags              (GameOffsetsCurrent()->VisibleObjFlags)
#define kISVisibleCamera              (GameOffsetsCurrent()->ISVisibleCamera)
#define kISVisibleDynamicPVS          (GameOffsetsCurrent()->ISVisibleDynamicPVS)
#define kISVisibleFPPMask             (GameOffsetsCurrent()->ISVisibleFPPMask)
#define kMainCameraTransform          (GameOffsetsCurrent()->MainCameraTransform)
#define kMyPhysXData                  (GameOffsetsCurrent()->MyPhysXData)
#define kPhxNpeononogeo               (GameOffsetsCurrent()->PhxNpeononogeo)
#define kGhgState                     (GameOffsetsCurrent()->GhgState)
#define kKnocked                      (GameOffsetsCurrent()->Knocked)
#define kBeingRescuredState           (GameOffsetsCurrent()->BeingRescuredState)
#define kMatchPlayerDict              (GameOffsetsCurrent()->MatchPlayerDict)
#define kDictEntries                  (GameOffsetsCurrent()->DictEntries)
#define kDictCount                    (GameOffsetsCurrent()->DictCount)
#define kIl2CppArrayMaxLength         (GameOffsetsCurrent()->Il2CppArrayMaxLength)
#define kIl2CppArrayItems             (GameOffsetsCurrent()->Il2CppArrayItems)
#define kDictEntryStrideBytePlayer    (GameOffsetsCurrent()->DictEntryStrideBytePlayer)
#define kDictEntryValueOffByte        (GameOffsetsCurrent()->DictEntryValueOffByte)
#define kTransformInner               (GameOffsetsCurrent()->TransformInner)
#define kTransformMatrix              (GameOffsetsCurrent()->TransformMatrix)
#define kTransformIndex               (GameOffsetsCurrent()->TransformIndex)
#define kMatrixList                   (GameOffsetsCurrent()->MatrixList)
#define kMatrixIndices                (GameOffsetsCurrent()->MatrixIndices)
#define kNickname                     (GameOffsetsCurrent()->Nickname)
#define kStringFirstChar              (GameOffsetsCurrent()->StringFirstChar)
#define kActiveWeapon                 (GameOffsetsCurrent()->ActiveWeapon)
#define kWeaponID                     (GameOffsetsCurrent()->WeaponID)
#define kWeaponCategory               (GameOffsetsCurrent()->WeaponCategory)
#define kWeaponHolder                 (GameOffsetsCurrent()->WeaponHolder)
#define kHolderActiveWeapon           (GameOffsetsCurrent()->HolderActiveWeapon)
#define kWeaponRepItem                (GameOffsetsCurrent()->WeaponRepItem)
#define kSwitchWeaponTime             (GameOffsetsCurrent()->SwitchWeaponTime)
#define kPreSwitchWeaponTime          (GameOffsetsCurrent()->PreSwitchWeaponTime)
#define kPostSwitchWeaponTime         (GameOffsetsCurrent()->PostSwitchWeaponTime)
#define kNicknameDisplay              (GameOffsetsCurrent()->NicknameDisplay)
#define kHitObjectInfo                (GameOffsetsCurrent()->HitObjectInfo)
#define kHitObjectInfoAlt             (GameOffsetsCurrent()->HitObjectInfoAlt)
#define kVehicleIAmIn                 (GameOffsetsCurrent()->VehicleIAmIn)
#define kLevelStropIAmOn              (GameOffsetsCurrent()->LevelStropIAmOn)
#define kRootNode                     (GameOffsetsCurrent()->RootNode)
#define kPlayerTransform              (GameOffsetsCurrent()->PlayerTransform)
#define kLastAimingTargetFromWeapon   (GameOffsetsCurrent()->LastAimingTargetFromWeapon)
#define kBaseGameUIScene              (GameOffsetsCurrent()->BaseGameUIScene)
#define kUIInGameScenePrepareCtrl     (GameOffsetsCurrent()->UIInGameScenePrepareCtrl)
#define kUIInGameSceneQuickUseMedkit  (GameOffsetsCurrent()->UIInGameSceneQuickUseMedkit)
#define kPrepTimerStartTime           (GameOffsetsCurrent()->PrepTimerStartTime)
#define kPrepTimerTotalTime           (GameOffsetsCurrent()->PrepTimerTotalTime)
#define kPrepTimerContextType         (GameOffsetsCurrent()->PrepTimerContextType)
#define kPrepTimerStage1Time          (GameOffsetsCurrent()->PrepTimerStage1Time)
#define kPrepTimerIsFinished          (GameOffsetsCurrent()->PrepTimerIsFinished)
#define kPrepTimerProgressSpeed       (GameOffsetsCurrent()->PrepTimerProgressSpeed)
#define kPrepTimerProgressRate        (GameOffsetsCurrent()->PrepTimerProgressRate)
#define kPlayerPrepTimerType          (GameOffsetsCurrent()->PlayerPrepTimerType)
#define kPlayerNetPrepDuration        (GameOffsetsCurrent()->PlayerNetPrepDuration)
#define kPlayerNetPrepType            (GameOffsetsCurrent()->PlayerNetPrepType)
#define kPlayerNetPrepFloatA          (GameOffsetsCurrent()->PlayerNetPrepFloatA)
#define kPlayerNetPrepFloatB          (GameOffsetsCurrent()->PlayerNetPrepFloatB)
#define kPlayerIsCuring               (GameOffsetsCurrent()->PlayerIsCuring)
#define kPlayerIsPreparing            (GameOffsetsCurrent()->PlayerIsPreparing)
#define kPlayerIsEating               (GameOffsetsCurrent()->PlayerIsEating)
#define kPlayerIsRepairing            (GameOffsetsCurrent()->PlayerIsRepairing)
#define kPlayerNetPrepFloatC          (GameOffsetsCurrent()->PlayerNetPrepFloatC)
#define kPlayerNetPrepFloatD          (GameOffsetsCurrent()->PlayerNetPrepFloatD)
#define kWeaponConsumableCsv          (GameOffsetsCurrent()->WeaponConsumableCsv)
#define kWeaponConsumableCsvFloatA    (GameOffsetsCurrent()->WeaponConsumableCsvFloatA)
#define kWeaponConsumableCsvFloatB    (GameOffsetsCurrent()->WeaponConsumableCsvFloatB)
#define kWeaponConsumableCsvFloatC    (GameOffsetsCurrent()->WeaponConsumableCsvFloatC)
#define kWeaponRepairRepItem          (GameOffsetsCurrent()->WeaponRepairRepItem)
#define kWeaponFirstAidRepItem        (GameOffsetsCurrent()->WeaponFirstAidRepItem)
#define kWeaponInhalerRepItem         (GameOffsetsCurrent()->WeaponInhalerRepItem)
#define kUGCFirstAidDuration          (GameOffsetsCurrent()->UGCFirstAidDuration)
#define kUGCFirstAidPretime           (GameOffsetsCurrent()->UGCFirstAidPretime)
#define kUGCRepairPreTime             (GameOffsetsCurrent()->UGCRepairPreTime)

// Layout inside Vehicle / LevelStrop (stable MonoBehaviour-ish fields from dump).
// Vehicle: Rigidbody @ 0x128, cached pos candidates @ 0x178/0x184/0x190, LevelVehicle @ 0x120
// LevelStrop: StartPoint Transform @ 0x138, EndPoint @ 0x140 (BaseLevelObject GameObject @ 0x98)
#define kVehicleRigidBody             0x128
#define kVehicleCachedPosA            0x178
#define kVehicleCachedPosB            0x184
#define kVehicleCachedPosC            0x190
#define kVehicleLevelVehicle          0x120
#define kLevelStropStartPoint         0x138
#define kLevelStropEndPoint           0x140
#define kBaseLevelObjectGameObject    0x98
