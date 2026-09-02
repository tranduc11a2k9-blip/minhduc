#import <Foundation/Foundation.h>
#import "GameOffsets.h"
#import "ESPPrefs.h"
#import "offsetmax.h"
#import "pid.h"

#include <string.h>

static NSString *const kSelectedGameIdKey = @"SelectedGameId";
static NSString *const kGameIdFF = @"ff";
static NSString *const kGameIdFFMax = @"ffmax";

// Free Fire THG — from D:\Download\dump ff thg (current season)
// TypeInfo (script.json): GameFacade 0xC012848, KBCJOEFJEFJ(AimAssist) 0xC015B80
// NOTE: field offsets often stay same across hotfixes; TypeInfo almost always moves.
static const GameOffsets kOffsetsFF = {
    .GameFacadeTypeInfo = 0xC012848,
    .TypeInfoStatics = 0xB8,
    .CurrentGame = 0x0,
    .CurrentMatchGame = 0x8,
    .Match = 0x90,
    .MatchLocalPlayer = 0xD8,
    .CameraControllerManager = 0xD8,
    .MainCamera = 0x20,
    .CameraInner = 0x10,
    .ViewMatrixOff = 0x80,
    .ProjMatrixOff = 0xC0,
    .BodyPartTransNode = 0x10,
    // Bones — restored proven FFTH layout (0x630 is NOT head; head is 0x638).
    // Dump field order starts ITransformNode at 0x630 (often spine/root), head @ 0x638.
    .HeadNode = 0x638,
    .HipNode = 0x640,
    .LeftAnkleNode = 0x670,
    .RightAnkleNode = 0x678,
    .RightToeNode = 0x688,
    .LeftToeNode = 0x680,
    .LeftShoulderNode = 0x658,
    .RightShoulderNode = 0x660,
    .LeftHandNode = 0x6B8,
    .RightHandNode = 0x6B0,
    .LeftElbowNode = 0x6C8,
    .RightElbowNode = 0x6C0,
    .PlayerIDStruct = 0x3A0,
    .PlayerID = 0x3A0,
    .UserID = 0x390,
    .IsClientBot = 0x438,
    .DataPool = 0x70,
    .DataPoolInner = 0x10,
    .DataPoolEntriesBase = 0x20,
    .DataPoolEntryStride = 0x8,
    .DataPoolValue = 0x18,
    .AimRotation = 0x5AC,
    .AimRotationAux = 0x5BC,
    .CurrentAimRotation = 0x198C,
    .AimAssistTypeInfo = 0xC015B80,
    .AaStaticKnolgmjlcef = 0x24,
    .AaStaticNfkcllpalej = 0x28,
    .AimAssistPtr = 0x5D0,            // m_AimAssist
    .AimAssistIceWallPtr = 0x5D8,     // m_AimAssistForIceWall
    .EAimAssistMode = 0x5F8,          // EAimAssist FGEAKHHPKCC (AllOff=2)
    .PlayerAnimComponent = 0x6F8,     // NewPlayerAnimationSystemComponent
    .PlayerAttributes = 0x700,        // Player.KDJHNBAECLM PlayerAttributes
    .RunSpeedUpScale = 0x270,         // PlayerAttributes.RunSpeedUpScale
    .IsFiring = 0x1BFC, // Player.POPKKGFEMLJ NMCBIHOOFFF StartFireState (backup)
    .IsPrepareAttack = 0x7D0, // <NNFKGNCILNK> get_IsPrepareAttack (FF dump)
    .LastFireBtnDownTime = 0x1758,
    .LastPlayBulletTrackEffectTime = 0xDFC,
    .LastSmartFireTime = 0xD68,
    .VisibleObj = 0xA40,
    .VisibleObjFlags = 0x10,
    .ISVisibleCamera = 0x1,
    .ISVisibleDynamicPVS = 0x100000,
    .ISVisibleFPPMask = 0xFFFBFFFF,
    .MainCameraTransform = 0x380,
    .MyPhysXData = 0x1B80,           // get_MyPhsXData
    .PhxNpeononogeo = 0x20,
    .GhgState = 0x10,
    .Knocked = 0x11A0,               // IsKnockedDownBleed
    .BeingRescuredState = 0x1ADA,    // FKGCAKMAGMF
    // Dictionary<BHGGAEEHJCO,Player> — NOT 0x148 (that is Dictionary<byte,Player>)
    // Entry: hash(4)+next(4)+key(0x18)+value(8) => stride 0x28, value @ 0x20
    // (old 24/16 assumed tiny key and only found ~half the players)
    .MatchPlayerDict = 0x128,
    .DictEntries = 0x18,
    .DictCount = 0x20,
    .Il2CppArrayMaxLength = 0x18,
    .Il2CppArrayItems = 0x20,
    .DictEntryStrideBytePlayer = 0x28,
    .DictEntryValueOffByte = 0x20,
    .TransformInner = 0x10,
    .TransformMatrix = 0x38,
    .TransformIndex = 0x40,
    .MatrixList = 0x18,
    .MatrixIndices = 0x20,
    .Nickname = 0x428,               // MOKGDCJLJFI
    .StringFirstChar = 0x14,
    .ActiveWeapon = 0x598,           // Player.ActiveUISightingWeapon
    .WeaponID = 0x600,
    .WeaponCategory = 0xC4,
    .WeaponHolder = 0x6D8,           // OMELKCOGCBK inventory
    .HolderActiveWeapon = 0xA0,
    // FDAEPHMIEPC.UGCWeaponRepItem MDAMCGCCLLM @ 0x710 (TH=MAX same)
    // UGCWeaponRepItem: SwitchWeaponTime 0x204 / Pre 0x208 / Post 0x20C
    .WeaponRepItem = 0x710,
    .SwitchWeaponTime = 0x204,
    .PreSwitchWeaponTime = 0x208,
    .PostSwitchWeaponTime = 0x20C,
    .NicknameDisplay = 0x430,        // OriginalNickName
    .HitObjectInfo = 0xDC8,          // AKFLHNOIHED GMPGMPFNMFP
    .HitObjectInfoAlt = 0xDD0,       // PJGMLPMAMGN
    // dump.cs Player: Vehicle IIPDHPKBDBA, LevelStrop JCGPLBAPOLO, root ITransformNode GOLAIKOPNJK
    .VehicleIAmIn = 0x8A8,
    .LevelStropIAmOn = 0x8C0,
    .RootNode = 0x630,
    .PlayerTransform = 0x698, // dump: protected Transform OKOLMFJKGEC
    .LastAimingTargetFromWeapon = 0xDE0, // <OHPFIIKIOPJ>k__BackingField OKEAMEELLBB*
    // Instant heal/repair wrap — dump ff thg UI + PlayerNetwork
    .BaseGameUIScene = 0x10,
    .UIInGameScenePrepareCtrl = 0x698, // UIInGameScene.m_PrepareCtrl (not PlayerTransform)
    .UIInGameSceneQuickUseMedkit = 0x978, // m_UIHudQuickUseMedkitController
    .PrepTimerStartTime = 0xA0,
    .PrepTimerTotalTime = 0xA4,
    .PrepTimerContextType = 0xA8,
    .PrepTimerStage1Time = 0xAC,
    .PrepTimerIsFinished = 0x118,
    .PrepTimerProgressSpeed = 0x138,
    .PrepTimerProgressRate = 0x13C,
    .PlayerPrepTimerType = 0x45C, // Player.KBHMGGLIMLI
    .PlayerNetPrepDuration = 0x22E0, // PlayerNetwork.PNEEICGMOGG
    .PlayerNetPrepType = 0x22E4,     // PlayerNetwork.JOJOJDCFNAK
    .PlayerNetPrepFloatA = 0x22F4,   // BBJCHDAJIBC
    .PlayerNetPrepFloatB = 0x22F8,   // JFOPDHIHIIC
    .PlayerIsCuring = 0x491,
    .PlayerIsPreparing = 0x492,
    .PlayerIsEating = 0x493,
    .PlayerIsRepairing = 0x494,
    .PlayerNetPrepFloatC = 0x22FC, // JIABJHJGDKL
    .PlayerNetPrepFloatD = 0x2308, // EJKGAPAHABD
    // OMDPILKGAJF consumable weapon layout (TH=MAX)
    .WeaponConsumableCsv = 0x68,
    .WeaponConsumableCsvFloatA = 0x24,
    .WeaponConsumableCsvFloatB = 0x28,
    .WeaponConsumableCsvFloatC = 0x40,
    .WeaponRepairRepItem = 0x78,
    .WeaponFirstAidRepItem = 0x80,
    .WeaponInhalerRepItem = 0x88,
    .UGCFirstAidDuration = 0x34,
    .UGCFirstAidPretime = 0x38,
    .UGCRepairPreTime = 0x20,
};

// Free Fire MAX — values from offsetmax.h (clone of FF until user patches)
static const GameOffsets kOffsetsFFMax = {
    .GameFacadeTypeInfo = MAX_kGameFacadeTypeInfo,
    .TypeInfoStatics = MAX_kTypeInfoStatics,
    .CurrentGame = MAX_kCurrentGame,
    .CurrentMatchGame = MAX_kCurrentMatchGame,
    .Match = MAX_kMatch,
    .MatchLocalPlayer = MAX_kMatchLocalPlayer,
    .CameraControllerManager = MAX_kCameraControllerManager,
    .MainCamera = MAX_kMainCamera,
    .CameraInner = MAX_kCameraInner,
    .ViewMatrixOff = MAX_kViewMatrixOff,
    .ProjMatrixOff = MAX_kProjMatrixOff,
    .BodyPartTransNode = MAX_kBodyPartTransNode,
    .HeadNode = MAX_kHeadNode,
    .HipNode = MAX_kHipNode,
    .LeftAnkleNode = MAX_kLeftAnkleNode,
    .RightAnkleNode = MAX_kRightAnkleNode,
    .RightToeNode = MAX_kRightToeNode,
    .LeftToeNode = MAX_kLeftToeNode,
    .LeftShoulderNode = MAX_kLeftShoulderNode,
    .RightShoulderNode = MAX_kRightShoulderNode,
    .LeftHandNode = MAX_kLeftHandNode,
    .RightHandNode = MAX_kRightHandNode,
    .LeftElbowNode = MAX_kLeftElbowNode,
    .RightElbowNode = MAX_kRightElbowNode,
    .PlayerIDStruct = MAX_kPlayerIDStruct,
    .PlayerID = MAX_kPlayerID,
    .UserID = MAX_kUserID,
    .IsClientBot = MAX_kIsClientBot,
    .DataPool = MAX_kDataPool,
    .DataPoolInner = MAX_kDataPoolInner,
    .DataPoolEntriesBase = MAX_kDataPoolEntriesBase,
    .DataPoolEntryStride = MAX_kDataPoolEntryStride,
    .DataPoolValue = MAX_kDataPoolValue,
    .AimRotation = MAX_kAimRotation,
    .AimRotationAux = MAX_kAimRotationAux,
    .CurrentAimRotation = MAX_kCurrentAimRotation,
    .AimAssistTypeInfo = MAX_kAimAssistTypeInfo,
    .AaStaticKnolgmjlcef = MAX_kAaStaticKnolgmjlcef,
    .AaStaticNfkcllpalej = MAX_kAaStaticNfkcllpalej,
    .AimAssistPtr = MAX_kAimAssistPtr,
    .AimAssistIceWallPtr = MAX_kAimAssistIceWallPtr,
    .EAimAssistMode = MAX_kEAimAssistMode,
    .PlayerAnimComponent = MAX_kPlayerAnimComponent,
    .PlayerAttributes = MAX_kPlayerAttributes,
    .RunSpeedUpScale = MAX_kRunSpeedUpScale,
    .IsFiring = MAX_kIsFiring,
    .IsPrepareAttack = MAX_kIsPrepareAttack,
    .LastFireBtnDownTime = MAX_kLastFireBtnDownTime,
    .LastPlayBulletTrackEffectTime = MAX_kLastPlayBulletTrackEffectTime,
    .LastSmartFireTime = MAX_kLastSmartFireTime,
    .VisibleObj = MAX_kVisibleObj,
    .VisibleObjFlags = MAX_kVisibleObjFlags,
    .ISVisibleCamera = MAX_kISVisibleCamera,
    .ISVisibleDynamicPVS = MAX_kISVisibleDynamicPVS,
    .ISVisibleFPPMask = MAX_kISVisibleFPPMask,
    .MainCameraTransform = MAX_kMainCameraTransform,
    .MyPhysXData = MAX_kMyPhysXData,
    .PhxNpeononogeo = MAX_kPhxNpeononogeo,
    .GhgState = MAX_kGhgState,
    .Knocked = MAX_kKnocked,
    .BeingRescuredState = MAX_kBeingRescuredState,
    .MatchPlayerDict = MAX_kMatchPlayerDict,
    .DictEntries = MAX_kDictEntries,
    .DictCount = MAX_kDictCount,
    .Il2CppArrayMaxLength = MAX_kIl2CppArrayMaxLength,
    .Il2CppArrayItems = MAX_kIl2CppArrayItems,
    .DictEntryStrideBytePlayer = MAX_kDictEntryStrideBytePlayer,
    .DictEntryValueOffByte = MAX_kDictEntryValueOffByte,
    .TransformInner = MAX_kTransformInner,
    .TransformMatrix = MAX_kTransformMatrix,
    .TransformIndex = MAX_kTransformIndex,
    .MatrixList = MAX_kMatrixList,
    .MatrixIndices = MAX_kMatrixIndices,
    .Nickname = MAX_kNickname,
    .StringFirstChar = MAX_kStringFirstChar,
    .ActiveWeapon = MAX_kActiveWeapon,
    .WeaponID = MAX_kWeaponID,
    .WeaponCategory = MAX_kWeaponCategory,
    .WeaponHolder = MAX_kWeaponHolder,
    .HolderActiveWeapon = MAX_kHolderActiveWeapon,
    .WeaponRepItem = MAX_kWeaponRepItem,
    .SwitchWeaponTime = MAX_kSwitchWeaponTime,
    .PreSwitchWeaponTime = MAX_kPreSwitchWeaponTime,
    .PostSwitchWeaponTime = MAX_kPostSwitchWeaponTime,
    .NicknameDisplay = MAX_kNicknameDisplay,
    .HitObjectInfo = MAX_kHitObjectInfo,
    .HitObjectInfoAlt = MAX_kHitObjectInfoAlt,
    .VehicleIAmIn = MAX_kVehicleIAmIn,
    .LevelStropIAmOn = MAX_kLevelStropIAmOn,
    .RootNode = MAX_kRootNode,
    .PlayerTransform = MAX_kPlayerTransform,
    .LastAimingTargetFromWeapon = MAX_kLastAimingTargetFromWeapon,
    .BaseGameUIScene = MAX_kBaseGameUIScene,
    .UIInGameScenePrepareCtrl = MAX_kUIInGameScenePrepareCtrl,
    .UIInGameSceneQuickUseMedkit = MAX_kUIInGameSceneQuickUseMedkit,
    .PrepTimerStartTime = MAX_kPrepTimerStartTime,
    .PrepTimerTotalTime = MAX_kPrepTimerTotalTime,
    .PrepTimerContextType = MAX_kPrepTimerContextType,
    .PrepTimerStage1Time = MAX_kPrepTimerStage1Time,
    .PrepTimerIsFinished = MAX_kPrepTimerIsFinished,
    .PrepTimerProgressSpeed = MAX_kPrepTimerProgressSpeed,
    .PrepTimerProgressRate = MAX_kPrepTimerProgressRate,
    .PlayerPrepTimerType = MAX_kPlayerPrepTimerType,
    .PlayerNetPrepDuration = MAX_kPlayerNetPrepDuration,
    .PlayerNetPrepType = MAX_kPlayerNetPrepType,
    .PlayerNetPrepFloatA = MAX_kPlayerNetPrepFloatA,
    .PlayerNetPrepFloatB = MAX_kPlayerNetPrepFloatB,
    .PlayerIsCuring = MAX_kPlayerIsCuring,
    .PlayerIsPreparing = MAX_kPlayerIsPreparing,
    .PlayerIsEating = MAX_kPlayerIsEating,
    .PlayerIsRepairing = MAX_kPlayerIsRepairing,
    .PlayerNetPrepFloatC = MAX_kPlayerNetPrepFloatC,
    .PlayerNetPrepFloatD = MAX_kPlayerNetPrepFloatD,
    .WeaponConsumableCsv = MAX_kWeaponConsumableCsv,
    .WeaponConsumableCsvFloatA = MAX_kWeaponConsumableCsvFloatA,
    .WeaponConsumableCsvFloatB = MAX_kWeaponConsumableCsvFloatB,
    .WeaponConsumableCsvFloatC = MAX_kWeaponConsumableCsvFloatC,
    .WeaponRepairRepItem = MAX_kWeaponRepairRepItem,
    .WeaponFirstAidRepItem = MAX_kWeaponFirstAidRepItem,
    .WeaponInhalerRepItem = MAX_kWeaponInhalerRepItem,
    .UGCFirstAidDuration = MAX_kUGCFirstAidDuration,
    .UGCFirstAidPretime = MAX_kUGCFirstAidPretime,
    .UGCRepairPreTime = MAX_kUGCRepairPreTime,
};

static const GameOffsets *gActiveOffsets = &kOffsetsFF;
static bool gIsMax = false;

static bool GameIdIsMax(NSString *gameId) {
    if (![gameId isKindOfClass:[NSString class]]) return false;
    NSString *normalized = gameId.lowercaseString;
    return [normalized isEqualToString:kGameIdFFMax] ||
           [normalized isEqualToString:@"max"] ||
           [normalized isEqualToString:@"freefiremax"];
}

NSString *GameTargetSelectedId(void) {
    id raw = AppSettingsObjectForKey(kSelectedGameIdKey);
    if ([raw isKindOfClass:[NSString class]] && [(NSString *)raw length] > 0) {
        return GameIdIsMax((NSString *)raw) ? kGameIdFFMax : kGameIdFF;
    }
    return kGameIdFF;
}

void GameTargetSetSelectedId(NSString *gameId) {
    NSString *resolved = GameIdIsMax(gameId) ? kGameIdFFMax : kGameIdFF;
    AppSettingsSetObject(kSelectedGameIdKey, resolved);
    GameOffsetsReload();
}

void GameOffsetsReload(void) {
    gIsMax = GameIdIsMax(GameTargetSelectedId());
    gActiveOffsets = gIsMax ? &kOffsetsFFMax : &kOffsetsFF;
}

const GameOffsets *GameOffsetsCurrent(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        GameOffsetsReload();
    });
    if (!gActiveOffsets) {
        gActiveOffsets = &kOffsetsFF;
    }
    return gActiveOffsets;
}

bool GameTargetIsMax(void) {
    (void)GameOffsetsCurrent();
    return gIsMax;
}

const char *GameTargetProcessName(void) {
    return GameTargetIsMax() ? "FreeFireMAX" : "FreeFire";
}

// Jailed IPA path: kernel-rw provider instead of task_for_pid.
// DSMemory handles attach + module base + reads, all through kexploit.
#import "../DSMemory.h"
#import "pid.h"

int GameTargetProcessPid(void) {
    if (ds_attached()) {
        return ds_pid();
    }
    return -1;
}

bool GameTargetIsRunning(void) {
    // KHÔNG probe attach ở đây — probe gây crash/nút xám vì nó chạy kernel reads
    // trong viewDidLoad/poll timer trước khi exploit chạy.
    // Attach chỉ xảy ra khi ESP loop gọi GameTargetModuleBase().
    return ds_attached();
}

uintptr_t GameTargetModuleBase(void) {
    if (!ds_attached() && ds_attach() != 0) return 0;
    return (uintptr_t)ds_base();
}
