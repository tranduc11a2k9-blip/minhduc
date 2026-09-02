// Minimal xpc.h stub — covers Tweak.m + patchfinder.m usage.
// xpc functions live in libSystem, no extra linking needed.
#ifndef XPC_STUB_H
#define XPC_STUB_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <Block.h>

typedef struct _xpc_object_s *xpc_object_t;

#define XPC_TYPE_NULL       ((xpc_type_t)1)
#define XPC_TYPE_BOOL       ((xpc_type_t)2)
#define XPC_TYPE_INT64      ((xpc_type_t)3)
#define XPC_TYPE_UINT64     ((xpc_type_t)4)
#define XPC_TYPE_DOUBLE     ((xpc_type_t)5)
#define XPC_TYPE_STRING     ((xpc_type_t)6)
#define XPC_TYPE_DATA       ((xpc_type_t)7)
#define XPC_TYPE_DATE       ((xpc_type_t)8)
#define XPC_TYPE_ARRAY      ((xpc_type_t)9)
#define XPC_TYPE_DICTIONARY ((xpc_type_t)10)
#define XPC_TYPE_ERROR      ((xpc_type_t)11)
#define XPC_TYPE_ENDPOINT   ((xpc_type_t)12)

typedef const struct _xpc_type_s *xpc_type_t;
typedef bool (^xpc_dictionary_applier_t)(const char *key, xpc_object_t value);

__attribute__((visibility("default")))
xpc_object_t xpc_null_create(void);

__attribute__((visibility("default")))
xpc_object_t xpc_retain(xpc_object_t);

__attribute__((visibility("default")))
void xpc_release(xpc_object_t);

__attribute__((visibility("default")))
xpc_type_t xpc_get_type(xpc_object_t obj);

__attribute__((visibility("default")))
uint64_t xpc_uint64_get_value(xpc_object_t obj);

__attribute__((visibility("default")))
void xpc_dictionary_apply(xpc_object_t dict, xpc_dictionary_applier_t applier);

__attribute__((visibility("default")))
xpc_object_t xpc_dictionary_create_empty(void);

__attribute__((visibility("default")))
void xpc_dictionary_set_uint64(xpc_object_t dict, const char *key, uint64_t value);

__attribute__((visibility("default")))
void xpc_dictionary_set_string(xpc_object_t dict, const char *key, const char *value);

#endif
