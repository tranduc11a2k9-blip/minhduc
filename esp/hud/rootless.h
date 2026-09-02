#ifndef ROOTLESS_H_JAILED
#define ROOTLESS_H_JAILED

#include <sys/syslimits.h>
#include <unistd.h>

// Jailed IPA: everything lives in the app sandbox + /var/mobile.
// HUD pid file + notify name are fixed paths, no jailbreak prefix needed.

#define ROOT_PATH(cPath)    cPath
#define ROOT_PATH_NS(path)  @path
#define ROOT_PATH_NS_VAR(path) @path
#define ROOT_PATH_VAR(path) path

#endif
