#ifndef _SRC__BENCH_RAWMEMCHR_H_
#define _SRC__BENCH_RAWMEMCHR_H_


#include "bench/bench-common.h"
#include "string-bench-common.h"

#define rawmemchr_bench_kernel_name(func, bench_conf)                          \
    CAT(bench_kernel_, func, _, bench_conf)


#define rawmemchr_make_bench_kernel(func, bench_conf)                          \
    static BENCH_FUNC uint64_t rawmemchr_bench_kernel_name(func, bench_conf)(  \
        uint8_t const * mem, uint32_t trials) {                                \
        ll_time_t start, end;                                                  \
        IMPOSSIBLE(!trials);                                                   \
        start = get_ll_time();                                                 \
        serialize_ooe();                                                       \
        for (; trials; --trials) {                                             \
            CAT(bench_, bench_conf)                                            \
            (func(CAST(get_type(*func(NULL, 0)) const *, mem), 0x0));       \
        }                                                                      \
        end = get_ll_time();                                                   \
        return get_ll_dif(end, start);                                         \
    }


#define rawmemchr_make_bench(func)                                             \
    rawmemchr_make_bench_kernel(func, tput);                                   \
    rawmemchr_make_bench_kernel(func, lat);                                    \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(                                      \
                rawmemchr_bench_kernel_name(func, lat)(_s0, _trials / 4));     \
            return (void *)rawmemchr_bench_kernel_name(func, lat)(_s0,         \
                                                                  _trials);    \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(                                      \
                rawmemchr_bench_kernel_name(func, tput)(_s0, _trials / 4));    \
            return (void *)rawmemchr_bench_kernel_name(func, tput)(_s0,        \
                                                                   _trials);   \
        }                                                                      \
    }


#endif
