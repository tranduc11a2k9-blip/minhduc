//
//  Il2CppMatch.h — resolve the current MatchGame via the il2cpp runtime API
//  (revision-proof: no hardcoded TypeInfo offsets).
//
//  Calls il2cpp_domain_get → assemblies → image → il2cpp_class_from_name
//  ("GameFacade") → static_fields → CurrentMatchGame, all through the
//  RemoteCall engine targeting the FreeFire process (same engine that drives
//  the SpringBoard overlay).
//
#import <Foundation/Foundation.h>
#import <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Returns the live MatchGame pointer, or 0.
// Requires a RemoteCall session into FreeFire (init_remote_call("FreeFire")).
uint64_t Il2CppResolveMatchGame(void);

#ifdef __cplusplus
}
#endif
