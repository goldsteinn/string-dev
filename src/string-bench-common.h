#ifndef _SRC__STRING_BENCH_TYPES_H_
#define _SRC__STRING_BENCH_TYPES_H_

#include "util/error-util.h"
#include "util/types.h"

#define bench_tput(to_run) compiler_do_not_optimize_out(to_run)
#define bench_lat(to_run)                                                      \
    compiler_do_not_optimize_out(to_run);                                      \
    serialize_ooe();
#define bench_name(func) CAT(bench_, func)

typedef enum bench_todo { TPUT, LAT } bench_todo_e;

typedef struct bench_info {
    uint8_t * s0_base;
    uint8_t * s1_base;

    uint8_t * s0;
    uint8_t * s1;

    uint32_t v0;
    uint32_t v1;

    uint32_t align0;
    uint32_t align1;

    uint32_t sz0;
    uint32_t sz1;

    uint32_t trials;

    bench_todo_e todo;
} bench_info_t;

static bench_todo_e
bench_make_todo(uint32_t bench_lat) {
    return bench_lat ? LAT : TPUT;
}

void bench_init_common(bench_info_t * bench_info,
                       uint32_t       _v0,
                       uint32_t       _v1,
                       uint32_t       _align0,
                       uint32_t       _align1,
                       uint32_t       _sz0,
                       uint32_t       _sz1,
                       uint32_t       _trials,
                       bench_todo_e   _todo);
void bench_free_common(bench_info_t const * bench_info);


/********************************************************************/
/* Init functions that are per function.  */

typedef void (*init_f)(bench_info_t const *);

static void
empty_bench_init(bench_info_t const * unused) {
    (void)(unused);
    return;
}


static void
strrchr_bench_init_shared(bench_info_t const * bench_info,
                          const uint32_t       wsize) {
    uint8_t * _s0;
    uint32_t  _sz0, _sz1;
    die_assert(bench_info);

    _s0  = bench_info->s0;
    _sz0 = bench_info->sz0;
    _sz1 = bench_info->sz1;

    die_assert(_s0);

    /* sz0 -> null term.
       sz1 -> position of CHAR, -1 == fill till null term */

    warn_assert(_sz0 != _sz1,
                "Null term and search CHAR at same position. "
                "search CHAR will be overwritten.\n");

    if (_sz1 == -1U) {
        memset_c(_s0, 0x01010101, _sz0 * wsize);
    }
    else {
        memset_c(_s0, 0xffffffff, _sz0 * wsize);
        memset_c(_s0 + _sz1 + wsize, 0x01010101, wsize);
    }
    memset_c(_s0 + _sz0 + wsize, 0x0, wsize);
}

static void
strrchr_bench_init(bench_info_t const * bench_info) {
    strrchr_bench_init_shared(bench_info, 1);
}

static void
wcsrchr_bench_init(bench_info_t const * bench_info) {
    strrchr_bench_init_shared(bench_info, 4);
}

#endif
