#ifndef _SRC__BENCH_STRNLEN_H_
#define _SRC__BENCH_STRNLEN_H_


#include "bench/bench-generator.h"

#define strnlen_bench_kernel_name(func, bench_conf)                            \
    CAT(bench_kernel_, func, _, bench_conf)

#define strnlen_make_bench_kernel(func, bench_conf)                            \
    CAT(make_ll_, bench_conf, _bench)                                          \
    (strnlen_bench_kernel_name(func, bench_conf), trials,                      \
     func((char const *)s0, sz1), uint8_t const * s0, uint32_t sz1,            \
     uint32_t trials)


#define strnlen_make_bench(func)                                               \
    strnlen_make_bench_kernel(func, tput);                                     \
    strnlen_make_bench_kernel(func, lat);                                      \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint32_t             _sz1       = bench_info->sz1;                     \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(                                      \
                strnlen_bench_kernel_name(func, lat)(_s0, _sz1, _trials / 4)); \
            return (void *)strnlen_bench_kernel_name(func, lat)(_s0, _sz1,     \
                                                                _trials);      \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(strnlen_bench_kernel_name(            \
                func, tput)(_s0, _sz1, _trials / 4));                          \
            return (void *)strnlen_bench_kernel_name(func, tput)(_s0, _sz1,    \
                                                                 _trials);     \
        }                                                                      \
    }


#endif
