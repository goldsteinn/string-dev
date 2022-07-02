#ifndef _SRC__STRING_BENCH_INCLUDES_H_
#define _SRC__STRING_BENCH_INCLUDES_H_

#include "string-bench-common.h"


#define empty_make_bench(func)                                                 \
    static void * bench_name(func)(void * arg) {                               \
        (void)(arg);                                                           \
        fprintf(stderr, "No benchmark!\n");                                    \
        return NULL;                                                           \
    }

#define rawmemchr_make_bench empty_make_bench
#define wmemcmp_make_bench   empty_make_bench
#define wcslen_make_bench    empty_make_bench
#define wcsnlen_make_bench   empty_make_bench

#define strcpy_make_bench  empty_make_bench
#define strcat_make_bench  empty_make_bench
#define stpcpy_make_bench  empty_make_bench
#define strncpy_make_bench empty_make_bench
#define strncat_make_bench empty_make_bench
#define stpncpy_make_bench empty_make_bench
#define strlcpy_make_bench empty_make_bench
#define strlcat_make_bench empty_make_bench


#include "bench-memchr.h"
#include "bench-memcmp.h"
#include "bench-memcpy.h"
#include "bench-strchr.h"
#include "bench-strlen.h"
#include "bench-strnlen.h"
#endif
