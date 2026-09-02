// Minimal fileport.h stub — only what kexploit_opa334.m uses.
// fileport functions live in libSystem/kernel, no extra linking needed.
#ifndef FILEPORT_STUB_H
#define FILEPORT_STUB_H

#include <stdint.h>
#include <mach/mach.h>

typedef mach_port_t fileport_t;

__attribute__((visibility("default")))
int fileport_makeport(int fd, fileport_t *fileport);

__attribute__((visibility("default")))
int fileport_makefd(fileport_t fileport);

#endif
