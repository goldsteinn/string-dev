#ifndef _SRC__BENCH_MEMCPY_INIT_H_
#define _SRC__BENCH_MEMCPY_INIT_H_
#include "util/types.h"

#include "string-bench-conf.h"

typedef struct memcpy_conf {
    uint16_t al_src;
    uint16_t al_dst;
    uint32_t sz;
} memcpy_conf_t;

memcpy_conf_t * new_memcpy_confs(bench_todo_e todo,
                                 uint32_t     min_sz,
                                 uint32_t     max_sz,
                                 uint32_t     dgs);
void            destroy_memcpy_confs(memcpy_conf_t * confs);

#endif
