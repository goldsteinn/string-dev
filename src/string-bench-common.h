#ifndef _SRC__STRING_BENCH_TYPES_H_
#define _SRC__STRING_BENCH_TYPES_H_

#include "bench-memcpy-init.h"
#include "util/error-util.h"
#include "util/random.h"
#include "util/types.h"

#include "string-bench-conf.h"

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


    void *   extra;
    uint32_t extra_sz;
} bench_info_t;

static bench_todo_e
bench_make_todo(uint32_t bench_lat, uint32_t bench_rand) {
    return (bench_lat ? LAT : TPUT) | (bench_rand ? RAND : 0);
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
strlen_bench_init(bench_info_t const * bench_info) {
    uint8_t * _s0;
    uint32_t  _sz0;
    die_assert(bench_info);

    _s0  = bench_info->s0;
    _sz0 = bench_info->sz0;


    die_assert(_s0);

    /* sz0 -> strlen */

    memset_c(_s0, -1, _sz0);
    memset_c(_s0 + _sz0, 0, 1);
}

static void
strnlen_bench_init(bench_info_t const * bench_info) {
    strlen_bench_init(bench_info);
}

static void
rawmemchr_bench_init(bench_info_t const * bench_info) {
    uint8_t * _s0;
    uint32_t  _sz0;
    die_assert(bench_info);

    _s0  = bench_info->s0;
    _sz0 = bench_info->sz0;

    die_assert(_s0);

    /*  sz0 -> position of CHAR */
    memset_c(_s0, -1, _sz0 | 4096);
    memset_c(_s0 + _sz0, 0x0, 1);
}

static void
memchr_bench_init_shared(bench_info_t const * bench_info,
                         const uint32_t       wsize) {
    uint8_t * _s0;
    uint32_t  _sz0, _sz1;
    die_assert(bench_info);

    _s0  = bench_info->s0;
    _sz0 = bench_info->sz0;
    _sz1 = bench_info->sz1;

    die_assert(_s0);

    /* sz0 -> len passed
       sz1 -> position of CHAR */

    memset_c(_s0, -1, _sz0 * wsize | 4096);
    memset_c(_s0 + _sz1 * wsize, 0x0, wsize);
}

static void
memrchr_bench_init(bench_info_t const * bench_info) {
    uint8_t * _s0;
    uint32_t  _sz0, _sz1, _align0;
    die_assert(bench_info);

    _s0  = bench_info->s0;
    _sz0 = bench_info->sz0;
    _sz1 = bench_info->sz1;

    _align0 = bench_info->align0;

    die_assert(_s0);
    /* sz0 -> len passed
       sz1 -> position of CHAR (backwards) */
    memset_c(_s0 - _align0, -1, (_sz0 + _align0) | 4096);
    if (_sz1 <= _sz0) {
        memset_c(_s0 + (_sz0 - _sz1), 0x0, 1);
    }
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
        memset_c(_s0, -1, _sz0 * wsize);
        memset_c(_s0 + _sz1 * wsize, 0x01010101, wsize);
    }
    memset_c(_s0 + _sz0 * wsize, 0x0, wsize);
}

static void
strrchr_bench_init(bench_info_t * bench_info) {
    strrchr_bench_init_shared(bench_info, 1);
}

static void
wcsrchr_bench_init(bench_info_t * bench_info) {
    strrchr_bench_init_shared(bench_info, 4);
}

static void
memcpy_bench_init(bench_info_t * bench_info) {
    die_assert(bench_info);
    die_assert(bench_info->s0);
    bench_info->extra = (void *)new_memcpy_confs(
        bench_info->todo, bench_info->sz0, bench_info->sz1,
        (bench_info->v1 | (bench_info->v0 << 1)));
    bench_info->extra_sz = NCONFS * sizeof(memcpy_conf_t);
}

static void
memcmp_bench_init(bench_info_t * bench_info) {
    die_assert(bench_info);
    die_assert(bench_info->s0);
    die_assert(bench_info->s1);

    uint8_t *_s0, *_s1;
    uint32_t _sz0, _sz1;

    _s0 = bench_info->s0;
    _s1 = bench_info->s1;

    _sz0 = bench_info->sz0;
    _sz1 = bench_info->sz1;

    memset_c(_s0, 0x01, _sz0);
    memset_c(_s1, 0x01, _sz0);

    memset_c(_s0 + _sz1, 0x02, 1);
}

static void
strchr_bench_init_shared(bench_info_t * bench_info, uint32_t wsize) {
    uint8_t *    _s0;
    uint32_t     _sz0, _sz1;
    bench_todo_e _todo;

    die_assert(bench_info);

    _s0   = bench_info->s0;
    _sz0  = bench_info->sz0;
    _sz1  = bench_info->sz1;
    _todo = bench_info->todo;

    die_assert(_s0);

    warn_assert(_sz0 != _sz1,
                "Null term and search CHAR at same position. "
                "search CHAR will be overwritten.\n");

    memset_c(_s0, -1, _sz0 * wsize);
    memset_c(_s0 + _sz1 * wsize, 0x01010101, wsize);

    memset_c(_s0 + _sz0 * wsize, 0x0, wsize);

    if (_todo & RAND) {
        uint8_t * _s1;
        uint32_t  i;
        _s1 = bench_info->s1;
        die_assert(_s1);
        for (i = 0; i < NCONFS; ++i) {
            uint64_t rval = true_rand64();
            if (rval & 1) {
                _s1[i] = 0x01;
            }
            else {
                _s1[i] = 0x02;
            }
        }
    }
}

static void
strchr_bench_init(bench_info_t * bench_info) {
    strchr_bench_init_shared(bench_info, 1);
}

static void
wcschr_bench_init(bench_info_t * bench_info) {
    strchr_bench_init_shared(bench_info, 4);
}

static void
strchrnul_bench_init(bench_info_t * bench_info) {
    strchr_bench_init_shared(bench_info, 1);
}

#define memcmpeq_bench_init memcmp_bench_init
#define wmemcmp_bench_init  empty_bench_init
#define wcslen_bench_init   empty_bench_init
#define wcsnlen_bench_init  empty_bench_init
static void
memchr_bench_init(bench_info_t * bench_info) {
    memchr_bench_init_shared(bench_info, 1);
}

static void
wmemchr_bench_init(bench_info_t * bench_info) {
    memchr_bench_init_shared(bench_info, 4);
}


#define strcpy_bench_init  empty_bench_init
#define strcat_bench_init  empty_bench_init
#define stpcpy_bench_init  empty_bench_init
#define strncpy_bench_init empty_bench_init
#define strncat_bench_init empty_bench_init
#define stpncpy_bench_init empty_bench_init
#define strlcpy_bench_init empty_bench_init
#define strlcat_bench_init empty_bench_init

#define wcscpy_bench_init  empty_bench_init
#define wcscat_bench_init  empty_bench_init
#define wcpcpy_bench_init  empty_bench_init
#define wcsncpy_bench_init empty_bench_init
#define wcsncat_bench_init empty_bench_init
#define wcpncpy_bench_init empty_bench_init
#define wcslcpy_bench_init empty_bench_init
#define wcslcat_bench_init empty_bench_init


#define strcmp_bench_init  empty_bench_init
#define strncmp_bench_init empty_bench_init
#define wcscmp_bench_init  empty_bench_init
#define wcsncmp_bench_init empty_bench_init

#define memset_bench_init empty_bench_init


#endif
