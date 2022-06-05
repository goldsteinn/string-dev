#ifndef _SRC__BENCH_STRLEN_H_
#define _SRC__BENCH_STRLEN_H_


#include "bench/bench-generator.h"

#define strlen_bench_kernel_name(func, bench_conf)                             \
    CAT(bench_kernel_, func, _, bench_conf)

#define strlen_make_bench_kernel(func, bench_conf)                             \
    CAT(make_ll_, bench_conf, _bench)                                          \
    (strlen_bench_kernel_name(func, bench_conf), trials,                       \
     func((char const *)s0), uint8_t const * s0, uint32_t trials)


#define strlen_make_bench(func)                                                \
    strlen_make_bench_kernel(func, tput);                                      \
    strlen_make_bench_kernel(func, lat);                                       \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(                                      \
                strlen_bench_kernel_name(func, lat)(_s0, _trials / 4));        \
            return (void *)strlen_bench_kernel_name(func, lat)(_s0, _trials);  \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(                                      \
                strlen_bench_kernel_name(func, tput)(_s0, _trials / 4));       \
            return (void *)strlen_bench_kernel_name(func, tput)(_s0, _trials); \
        }                                                                      \
    }


#endif
