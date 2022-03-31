#ifndef _SRC__STRING_FUNC_INFO_H_
#define _SRC__STRING_FUNC_INFO_H_

/* For func pointer typdefs. */
#include "util/func-decl-types.h"

#include "string-bench-common.h"

typedef struct func_info {
    void const * const _func_ptr;
    test_f const       _test_func_ptr;
    bench_f const      _bench_func_ptr;
    init_f const       _bench_init_func_ptr;
} func_info_t;

#endif
