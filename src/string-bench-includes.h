#ifndef _SRC__STRING_BENCH_INCLUDES_H_
#define _SRC__STRING_BENCH_INCLUDES_H_

#include "string-bench-common.h"

#define empty_make_bench(func)                                                 \
    static void const * const bench_name(func) = NULL;


#include "strchr-bench.h"

#endif
