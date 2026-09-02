//
//  platformize.h — self-platformization via kernel rw
//  Swap our AMFI cred slot (l_perpolicy[0]) with launchd's →
//  proc gets platform-application + full mach-lookup privileges
//  without any entitlements on the binary.
//
#ifndef platformize_h
#define platformize_h

#import <Foundation/Foundation.h>

// Returns 0 on success. Call AFTER sandbox_elevate_to_root() succeeded
// (we need to write launchd's slot into ours).
int platformize_self(uint64_t self_proc);

#endif /* platformize_h */
