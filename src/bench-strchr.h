#ifndef _SRC__BENCH_STRCHR_H_
#define _SRC__BENCH_STRCHR_H_

#include "bench/bench-common.h"
#include "string-bench-common.h"

#define strchr_bench_kernel_name(func, bench_conf)                             \
    CAT(bench_kernel_, func, _, bench_conf)

#define strchr_make_bench_kernel(func, bench_conf)                             \
    static BENCH_FUNC uint64_t strchr_bench_kernel_name(func, bench_conf)(     \
        uint8_t const * mem, uint32_t trials) {                                \
        const uint32_t search_c = 0x01010101;                                  \
        ll_time_t      start, end;                                             \
        IMPOSSIBLE(!trials);                                                   \
        start = get_ll_time();                                                 \
        serialize_ooe();                                                       \
        for (; trials; --trials) {                                             \
            CAT(bench_, bench_conf)                                            \
            (func(CAST(get_type(func(NULL, 0)) const *, mem),                  \
                  CAST(get_type(func(NULL, 0)), search_c)));                   \
        }                                                                      \
        end = get_ll_time();                                                   \
        return get_ll_dif(end, start);                                         \
    }

#define strchr_make_bench(func)                                                \
    strchr_make_bench_kernel(func, tput);                                      \
    strchr_make_bench_kernel(func, lat);                                       \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(                                      \
                strchr_bench_kernel_name(func, lat)(_s0, _trials / 4));        \
            return (void *)strchr_bench_kernel_name(func, lat)(_s0, _trials);  \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(                                      \
                strchr_bench_kernel_name(func, tput)(_s0, _trials / 4));       \
            return (void *)strchr_bench_kernel_name(func, tput)(_s0, _trials); \
        }                                                                      \
    }

#define strrchr_make_bench strchr_make_bench
#define wcsrchr_make_bench strchr_make_bench
#define strchrnul_make_bench strchr_make_bench

#endif
