#ifndef skynet_lua_alloc_h
#define skynet_lua_alloc_h

#include <stddef.h>

struct allocator;

struct allocator * snlua_allocator_new();
void snlua_allocator_delete(struct allocator *A);

void * snlua_skynet_lalloc(void *ud, void *ptr, size_t osize, size_t nsize);
void snlua_allocator_info(struct allocator *A);

#endif
