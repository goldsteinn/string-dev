#ifndef _SRC__BENCH_MEMCHR_H_
#define _SRC__BENCH_MEMCHR_H_


#include "bench/bench-common.h"
#include "string-bench-common.h"

#define memchr_bench_kernel_name(func, bench_conf)                             \
    CAT(bench_kernel_, func, _, bench_conf)


#define memchr_make_bench_kernel(func, bench_conf)                             \
    static BENCH_FUNC uint64_t memchr_bench_kernel_name(func, bench_conf)(     \
        uint8_t const * mem, uint32_t trials, uint32_t sz) {                   \
        ll_time_t start, end;                                                  \
        IMPOSSIBLE(!trials);                                                   \
        start = get_ll_time();                                                 \
        serialize_ooe();                                                       \
        for (; trials; --trials) {                                             \
            CAT(bench_, bench_conf)                                            \
            (func(CAST(get_type(*func(NULL, 0, 0)) const *, mem), 0x0, sz));   \
        }                                                                      \
        end = get_ll_time();                                                   \
        return get_ll_dif(end, start);                                         \
    }


#define memchr_make_bench(func)                                                \
    memchr_make_bench_kernel(func, tput);                                      \
    memchr_make_bench_kernel(func, lat);                                       \
    static void * bench_name(func)(void * arg) {                               \
        bench_info_t const * bench_info = (bench_info_t *)arg;                 \
        uint8_t const *      _s0        = bench_info->s0;                      \
        uint32_t             _sz0       = bench_info->sz0;                     \
        uint32_t             _trials    = bench_info->trials;                  \
        bench_todo_e         _todo      = bench_info->todo;                    \
        if (_todo & LAT) {                                                     \
            compiler_do_not_optimize_out(                                      \
                memchr_bench_kernel_name(func, lat)(_s0, _trials / 4, _sz0));  \
            return (void *)memchr_bench_kernel_name(func, lat)(_s0, _trials,   \
                                                               _sz0);          \
        }                                                                      \
        else {                                                                 \
            compiler_do_not_optimize_out(                                      \
                memchr_bench_kernel_name(func, tput)(_s0, _trials / 4, _sz0)); \
            return (void *)memchr_bench_kernel_name(func, tput)(_s0, _trials,  \
                                                                _sz0);         \
        }                                                                      \
    }


#define wmemchr_make_bench memchr_make_bench
#define memrchr_make_bench memchr_make_bench

#endif
