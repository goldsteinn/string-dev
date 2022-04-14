#include <wchar.h>

#include "util/func-decl-generator.h"
#include "util/macro.h"
#include "util/types.h"

#include "string-bench-common.h"
#include "string-bench-includes.h"
#include "string-decl-helpers.h"
#include "string-func-info.h"

#define decl_memcpy(func)                                                      \
    extern void * func(void * restrict, void const * restrict, uint64_t);
#define decl_strchr(func) extern char func(char const *, uint8_t)
#define decl_wcschr(func) extern wchar_t func(wchar_t const *, uint32_t)
#define decl_memcmp(func) extern int func(void const *, void const *, uint64_t)
#define decl_wmemcmp(func)                                                     \
    extern int func(wchar_t const *, wchar_t const *, uint64_t)

#define STRRCHR_IMPLS expand_impls(strrchr_evex, strrchr_avx2, strrchr_sse2)
#define WCSRCHR_IMPLS expand_impls(wcsrchr_evex, wcsrchr_avx2, wcsrchr_sse2)
#define MEMCPY_IMPLS  expand_impls(memcpy_ssse3)
#define MEMCMP_IMPLS  expand_impls(memcmp_ssse3, memcmp_sse2, memcmp_sse4, memcmp_avx2)
#define WMEMCMP_IMPLS expand_impls(wmemcmp_sse2, wmemcmp_sse4, wmemcmp_avx2)
#define MEMCMPEQ_IMPLS                                                         \
    expand_impls(memcmpeq_ssse3, memcmpeq_sse2, memcmpeq_sse4)

#define STRING_IMPLS                                                           \
    STRRCHR_IMPLS, WCSRCHR_IMPLS, MEMCPY_IMPLS, MEMCMP_IMPLS, WMEMCMP_IMPLS,   \
        MEMCMPEQ_IMPLS


decl_func(memcpy, decl_memcpy, MEMCPY_IMPLS);
decl_func(memcmp, decl_memcmp, MEMCMP_IMPLS);
decl_func(wmemcmp, decl_wmemcmp, WMEMCMP_IMPLS);
decl_func(memcmpeq, decl_memcmp, MEMCMPEQ_IMPLS);
decl_func(strrchr, decl_strchr, STRRCHR_IMPLS);
decl_func(wcsrchr, decl_wcschr, WCSRCHR_IMPLS);


custom_make_decls(decl_list_t,
                  string_decls,
                  make_string_decl,
                  EAT,
                  STRING_IMPLS);
