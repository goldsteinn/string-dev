#include <wchar.h>

#include "util/func-decl-generator.h"
#include "util/macro.h"
#include "util/types.h"

#include "string-bench-common.h"
#include "string-bench-includes.h"
#include "string-decl-helpers.h"
#include "string-func-info.h"

#define decl_strcpy(func)                                                      \
    extern char * func(char * restrict, char const * restrict);
#define decl_strncpy(func)                                                     \
    extern char * func(char * restrict, char const * restrict, size_t);

#define decl_memcpy(func)                                                      \
    extern void * func(void * restrict, void const * restrict, size_t);
#define decl_strchr(func) extern char func(char const *, uint8_t)
#define decl_wcschr(func) extern wchar_t func(wchar_t const *, uint32_t)
#define decl_memcmp(func) extern int func(void const *, void const *, size_t)
#define decl_wmemcmp(func)                                                     \
    extern int func(wchar_t const *, wchar_t const *, size_t)
#define decl_memchr(func) extern void * func(void const *, int, size_t)
#define decl_wmemchr(func)                                                     \
    extern wchar_t * func(wchar_t const *, wchar_t, size_t);
#define decl_strlen(func)  extern size_t func(char const *)
#define decl_strnlen(func) extern size_t func(char const *, size_t)
#define decl_wcslen(func)  extern size_t func(wchar_t const *)
#define decl_wcsnlen(func) extern size_t func(wchar_t const *, size_t)

#define STRRCHR_IMPLS expand_impls(strrchr_evex, strrchr_avx2, strrchr_sse2)
#define WCSRCHR_IMPLS expand_impls(wcsrchr_evex, wcsrchr_avx2, wcsrchr_sse2)
#define MEMCPY_IMPLS  expand_impls(memcpy_ssse3)
#define MEMCMP_IMPLS                                                           \
    expand_impls(memcmp_ssse3, memcmp_sse2, memcmp_sse4, memcmp_avx2,          \
                 memcmp_evex),                                                 \
        memcmp_evex512_dev
#define WMEMCMP_IMPLS                                                          \
    expand_impls(wmemcmp_sse2, wmemcmp_sse4, wmemcmp_avx2, wmemcmp_evex),      \
        wmemcmp_evex512_dev
#define MEMCMPEQ_IMPLS                                                         \
    expand_impls(memcmpeq_ssse3, memcmpeq_sse2, memcmpeq_sse4, memcmpeq_evex), \
        memcmpeq_evex512_dev
#define MEMRCHR_IMPLS   expand_impls(memrchr_avx2, memrchr_evex, memrchr_sse2)
#define MEMCHR_IMPLS    expand_impls(memchr_sse2, memchr_evex, memchr_avx2)
#define RAWMEMCHR_IMPLS rawmemchr_evex_dev, rawmemchr_avx2_dev
#define WMEMCHR_IMPLS                                                          \
    expand_impls(wmemchr_sse2), wmemchr_evex_dev, wmemchr_avx2_dev
#define STRLEN_IMPLS  expand_impls(strlen_evex), strlen_evex512_dev
#define STRNLEN_IMPLS expand_impls(strnlen_evex), strnlen_evex512_dev
#define WCSLEN_IMPLS  expand_impls(wcslen_evex), wcslen_evex512_dev
#define WCSNLEN_IMPLS expand_impls(wcsnlen_evex), wcsnlen_evex512_dev
#define STRCPY_IMPLS  expand_impls(strcpy_sse2, strcpy_avx2, strcpy_evex)
#define STRCAT_IMPLS  expand_impls(strcat_sse2, strcat_avx2, strcat_evex)
#define STPCPY_IMPLS  expand_impls(stpcpy_sse2, stpcpy_avx2, stpcpy_evex)
#define STRNCPY_IMPLS expand_impls(strncpy_sse2, strncpy_avx2, strncpy_evex)
#define STRNCAT_IMPLS expand_impls(strncat_sse2, strncat_avx2, strncat_evex)
#define STPNCPY_IMPLS expand_impls(stpncpy_sse2, stpncpy_avx2, stpncpy_evex)
#define STRLCPY_IMPLS expand_impls(strlcpy_sse2, strlcpy_avx2, strlcpy_evex)
#define STRLCAT_IMPLS expand_impls(strlcat_sse2, strlcat_avx2, strlcat_evex)


#define STRING_IMPLS                                                           \
    STRRCHR_IMPLS, WCSRCHR_IMPLS, MEMCPY_IMPLS, MEMCMP_IMPLS, WMEMCMP_IMPLS,   \
        MEMCMPEQ_IMPLS, MEMRCHR_IMPLS, MEMCHR_IMPLS, WMEMCHR_IMPLS,            \
        STRLEN_IMPLS, WCSLEN_IMPLS, WCSNLEN_IMPLS, RAWMEMCHR_IMPLS,            \
        STRNLEN_IMPLS, STRCPY_IMPLS, STRCAT_IMPLS, STPCPY_IMPLS,               \
        STRNCPY_IMPLS, STRNCAT_IMPLS, STPNCPY_IMPLS, STRLCPY_IMPLS,            \
        STRLCAT_IMPLS


decl_func(memcpy, decl_memcpy, MEMCPY_IMPLS);
decl_func(memcmp, decl_memcmp, MEMCMP_IMPLS);
decl_func(wmemcmp, decl_wmemcmp, WMEMCMP_IMPLS);
decl_func(memcmpeq, decl_memcmp, MEMCMPEQ_IMPLS);
decl_func(strrchr, decl_strchr, STRRCHR_IMPLS);
decl_func(wcsrchr, decl_wcschr, WCSRCHR_IMPLS);
decl_func(memrchr, decl_memchr, MEMRCHR_IMPLS);
decl_func(memchr, decl_memchr, MEMCHR_IMPLS);
decl_func(rawmemchr, decl_strchr, RAWMEMCHR_IMPLS);
decl_func(wmemchr, decl_wmemchr, WMEMCHR_IMPLS);
decl_func(strlen, decl_strlen, STRLEN_IMPLS);
decl_func(strnlen, decl_strnlen, STRNLEN_IMPLS);
decl_func(wcslen, decl_wcslen, WCSLEN_IMPLS);
decl_func(wcsnlen, decl_wcsnlen, WCSNLEN_IMPLS);
decl_func(strcpy, decl_strcpy, STRCPY_IMPLS);
decl_func(strcat, decl_strcpy, STRCAT_IMPLS);
decl_func(stpcpy, decl_strcpy, STPCPY_IMPLS);
decl_func(strncpy, decl_strncpy, STRNCPY_IMPLS);
decl_func(strncat, decl_strncpy, STRNCAT_IMPLS);
decl_func(stpncpy, decl_strncpy, STPNCPY_IMPLS);
decl_func(strlcpy, decl_strncpy, STRLCPY_IMPLS);
decl_func(strlcat, decl_strncpy, STRLCAT_IMPLS);


custom_make_decls(decl_list_t,
                  string_decls,
                  make_string_decl,
                  EAT,
                  STRING_IMPLS);
