#ifndef _SRC__BENCH_MEMCMP_H_
#define _SRC__BENCH_MEMCMP_H_


#include "bench/bench-generator.h"

#define memcmp_bench_kernel_name(func, bench_conf)                             \
    CAT(bench_kernel_, func, _, bench_conf)

#define memcmp_make_bench_kernel(func, bench_conf)                             \
    CAT(make_ll_, bench_conf, _bench)                                          \
    (memcmp_bench_kernel_name(func, bench_conf), trials, func(s0, s1, sz),     \
     uint8_t const * restrict s0, uint8_t const const * restrict s1,           \
     uint32_t sz, uint32_t trials)


#define memcmp_make_bench(func)                                                \
    memcmp_make_bench_kernel(func, tput);                                      \
    memcmp_make_bench_kernel(func, lat);                                       \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint8_t const *      _s1        = bench_info->s1;                      \
        uint32_t             _sz0       = bench_info->sz0;                     \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(memcmp_bench_kernel_name(func, lat)(  \
                _s0, _s1, _sz0, _trials / 4));                                 \
            return (void *)memcmp_bench_kernel_name(func, lat)(_s0, _s1, _sz0, \
                                                               _trials);       \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(memcmp_bench_kernel_name(func, tput)( \
                _s0, _s1, _sz0, _trials / 4));                                 \
            return (void *)memcmp_bench_kernel_name(func, tput)(               \
                _s0, _s1, _sz0, _trials);                                      \
        }                                                                      \
    }

#define memcmpeq_make_bench memcmp_make_bench

#endif
