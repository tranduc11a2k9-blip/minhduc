//
//  HUDSpawn.h
//
#ifndef HUDSpawn_h
#define HUDSpawn_h

#ifdef __cplusplus
extern "C" {
#endif

// Spawn self with "-hud" → system-level overlay process (GSInitialize +
// BKSDisplayServicesStart). Returns 0 on success, errno-ish on failure.
int HUDSpawnChild(void);

#ifdef __cplusplus
}
#endif

#endif
