#ifndef _SRC__BENCH_MEMCPY_H_
#define _SRC__BENCH_MEMCPY_H_

#include "bench-memcpy-init.h"
#include "bench/bench-generator.h"

#define memcpy_bench_kernel_name(func, bench_conf)                             \
    CAT(bench_kernel_, func, _, bench_conf)

#define memcpy_bench_rand_kernel_name(func, bench_conf)                        \
    CAT(bench_rand_kernel_, func, _, bench_conf)

#define memcpy_make_bench_kernel(func, bench_conf)                             \
    CAT(make_ll_, bench_conf, _bench)                                          \
    (memcpy_bench_kernel_name(func, bench_conf), trials, func(dst, src, sz),   \
     uint8_t * restrict dst, uint8_t const * restrict src, uint32_t sz,        \
     uint32_t trials)


#define memcpy_make_rand_bench_kernel(func, bench_conf)                        \
    static uint64_t memcpy_bench_rand_kernel_name(func, bench_conf)(           \
        uint8_t * restrict mem, memcpy_conf_t const * restrict confs,          \
        uint32_t trials) {                                                     \
        ll_time_t start, end;                                                  \
        start = get_ll_time();                                                 \
        compiler_barrier();                                                    \
        serialize_ooe();                                                       \
        for (; trials; --trials) {                                             \
            for (uint32_t conf_idx = NCONFS; conf_idx;) {                      \
                --conf_idx;                                                    \
                uint32_t _al_src = confs[conf_idx].al_src;                     \
                uint32_t _al_dst = confs[conf_idx].al_dst;                     \
                uint32_t _sz     = confs[conf_idx].sz;                         \
                compiler_do_not_optimize_out(                                  \
                    func(mem + _al_dst, mem + _al_src, _sz));                  \
            }                                                                  \
        }                                                                      \
        serialize_ooe();                                                       \
        compiler_barrier();                                                    \
        end = get_ll_time();                                                   \
        return get_ll_dif(end, start);                                         \
    }

#define memcpy_make_bench(func)                                                  \
    memcpy_make_bench_kernel(func, tput);                                        \
    memcpy_make_bench_kernel(func, lat);                                         \
    memcpy_make_rand_bench_kernel(func, tput);                                   \
    memcpy_make_rand_bench_kernel(func, lat);                                    \
    static void * bench_name(func)(void * arg) {                                 \
        bench_info_t const *  bench_info = (bench_info_t *)arg;                  \
        uint8_t *             _s0        = bench_info->s0;                       \
        uint8_t const *       _s1        = bench_info->s1;                       \
        uint32_t              _sz0       = bench_info->sz0;                      \
        uint32_t              _trials    = bench_info->trials;                   \
        bench_todo_e          _todo      = bench_info->todo;                     \
        memcpy_conf_t const * _confs     = (memcpy_conf_t *)(bench_info->extra); \
        if (_todo & LAT) {                                                       \
            if (_todo & RAND) {                                                  \
                compiler_do_not_optimize_out(memcpy_bench_rand_kernel_name(      \
                    func, lat)(_s0, _confs, _trials / 4));                       \
                return (void *)memcpy_bench_rand_kernel_name(func, lat)(         \
                    _s0, _confs, _trials);                                       \
            }                                                                    \
            else {                                                               \
                compiler_do_not_optimize_out(memcpy_bench_kernel_name(           \
                    func, lat)(_s0, _s1, _sz0, _trials / 4));                    \
                return (void *)memcpy_bench_kernel_name(func, lat)(              \
                    _s0, _s1, _sz0, _trials);                                    \
            }                                                                    \
        }                                                                        \
        else {                                                                   \
            if (_todo & RAND) {                                                  \
                compiler_do_not_optimize_out(memcpy_bench_rand_kernel_name(      \
                    func, tput)(_s0, _confs, _trials / 4));                      \
                return (void *)memcpy_bench_rand_kernel_name(func, tput)(        \
                    _s0, _confs, _trials);                                       \
            }                                                                    \
            else {                                                               \
                compiler_do_not_optimize_out(memcpy_bench_kernel_name(           \
                    func, tput)(_s0, _s1, _sz0, _trials / 4));                   \
                return (void *)memcpy_bench_kernel_name(func, tput)(             \
                    _s0, _s1, _sz0, _trials);                                    \
            }                                                                    \
        }                                                                        \
    }


#endif
