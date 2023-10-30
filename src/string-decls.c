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

#define decl_wcscpy(func)                                                      \
    extern wchar_t * func(wchar_t * restrict, wchar_t const * restrict);
#define decl_wcsncpy(func)                                                     \
    extern wchar_t * func(wchar_t * restrict, wchar_t const * restrict, size_t);

#define decl_memcpy(func)                                                      \
    extern void * func(void * restrict, void const * restrict, size_t);
#define decl_strchr(func)    extern char func(char const *, uint8_t)
#define decl_rawmemchr(func) extern uint8_t * func(uint8_t const *, uint8_t)
#define decl_wcschr(func)    extern wchar_t func(wchar_t const *, uint32_t)
#define decl_memcmp(func)    extern int func(void const *, void const *, size_t)
#define decl_wmemcmp(func)                                                     \
    extern int func(wchar_t const *, wchar_t const *, size_t)
#define decl_memchr(func) extern void * func(void const *, int, size_t)
#define decl_wmemchr(func)                                                     \
    extern wchar_t * func(wchar_t const *, wchar_t, size_t);
#define decl_strlen(func)  extern size_t func(char const *)
#define decl_strnlen(func) extern size_t func(char const *, size_t)
#define decl_wcslen(func)  extern size_t func(wchar_t const *)
#define decl_wcsnlen(func) extern size_t func(wchar_t const *, size_t)
#define decl_memset(func)  extern void func(void const *, int, size_t)
#define decl_strcmp(func)  extern int func(char const *, char const *)
#define decl_strncmp(func) extern int func(char const *, char const *, size_t)
#define decl_wcscmp(func)  extern int func(wchar_t const *, wchar_t const *)
#define decl_wcsncmp(func)                                                     \
    extern int func(wchar_t const *, wchar_t const *, size_t)

#define STRRCHR_IMPLS expand_impls(strrchr, evex512, evex)
#define WCSRCHR_IMPLS expand_impls(wcsrchr, evex512, evex, avx2, sse2)
#define MEMCPY_IMPLS                                                           \
    expand_impls(memcpy, ssse3), memcpy_avx2_folly, memcpy_avx2_dev
#define MEMCMP_IMPLS                                                           \
    expand_impls(memcmp, ssse3, sse2, sse4, avx2, evex), memcmp_evex512_dev
#define WMEMCMP_IMPLS                                                          \
    expand_impls(wmemcmp, sse2, sse4, avx2, evex), wmemcmp_evex512_dev
#define MEMCMPEQ_IMPLS                                                         \
    expand_impls(memcmpeq, ssse3, sse2, sse4, evex), memcmpeq_evex512_dev
#define MEMRCHR_IMPLS                                                          \
    expand_impls(memrchr, avx2, evex, sse2), memrchr_evex512_dev
#define MEMCHR_IMPLS    expand_impls(memchr, sse2, evex, avx2, evex512)
#define RAWMEMCHR_IMPLS expand_impls(rawmemchr, sse2, evex, avx2, evex512)
#define WMEMCHR_IMPLS   expand_impls(wmemchr, sse2, evex, avx2, evex512)
#define STRLEN_IMPLS    expand_impls(strlen, sse2, avx2, evex, evex512)
#define STRNLEN_IMPLS   expand_impls(strnlen, sse2, avx2, evex, evex512)
#define WCSLEN_IMPLS    expand_impls(wcslen, sse2, avx2, evex, evex512)
#define WCSNLEN_IMPLS   expand_impls(wcsnlen, sse2, avx2, evex, evex512)
#define STRCPY_IMPLS    expand_impls(strcpy, sse2, avx2, evex), strcpy_evex512_dev
#define STRCAT_IMPLS    expand_impls(strcat, sse2, avx2, evex), strcat_evex512_dev
#define STPCPY_IMPLS    expand_impls(stpcpy, sse2, avx2, evex), stpcpy_evex512_dev
#define STRNCPY_IMPLS                                                          \
    expand_impls(strncpy, sse2, avx2, evex), strncpy_evex512_dev
#define STRNCAT_IMPLS                                                          \
    expand_impls(strncat, sse2, avx2, evex), strncat_evex512_dev
#define STPNCPY_IMPLS                                                          \
    expand_impls(stpncpy, sse2, avx2, evex), stpncpy_evex512_dev

#define WCSCPY_IMPLS expand_impls(wcscpy, sse2, avx2, evex), wcscpy_evex512_dev
#define WCSCAT_IMPLS expand_impls(wcscat, sse2, avx2, evex), wcscat_evex512_dev
#define WCPCPY_IMPLS expand_impls(wcpcpy, sse2, avx2, evex), wcpcpy_evex512_dev
#define WCSNCPY_IMPLS                                                          \
    expand_impls(wcsncpy, sse2, avx2, evex), wcsncpy_evex512_dev
#define WCSNCAT_IMPLS                                                          \
    wcsncat_evex512_dev  // expand_impls(wcsncat, sse2, avx2, evex),
                         // wcsncat_evex512_dev

#define WCPNCPY_IMPLS                                                          \
    wcpncpy_evex512_dev  // expand_impls(wcpncpy, sse2, avx2, evex),
                         // wcpncpy_evex512_dev

#define STRCHR_IMPLS    expand_impls(strchr, sse2, avx2, evex, evex512)
#define STRCHRNUL_IMPLS expand_impls(strchrnul, sse2, avx2, evex, evex512)
#define WCSCHR_IMPLS    expand_impls(wcschr, sse2, avx2, evex, evex512)

#define MEMSET_IMPLS                                                           \
    memset_sse2_erms_dev, memset_avx2_erms_dev, memset_avx512_erms_dev,        \
        memset_evex_erms_dev, memset_sse2_erms_glibc, memset_avx2_erms_glibc,  \
        memset_avx512_erms_glibc, memset_evex_erms_glibc


#define STRCMP_IMPLS                                                           \
    expand_impls(strcmp, sse2, sse2_unaligned, sse42, avx2, evex),             \
        strcmp_evex512_dev
#define STRNCMP_IMPLS                                                          \
    expand_impls(strncmp, sse2, sse2_unaligned, sse42, avx2, evex),            \
        strncmp_evex512_dev
#define WCSCMP_IMPLS expand_impls(wcscmp, sse42, avx2, evex), wcscmp_evex512_dev
#define WCSNCMP_IMPLS                                                          \
    expand_impls(wcsncmp, sse42, avx2, evex), wcsncmp_evex512_dev

#define STRING_IMPLS                                                           \
    STRRCHR_IMPLS, WCSRCHR_IMPLS, MEMCPY_IMPLS, MEMCMP_IMPLS, WMEMCMP_IMPLS,   \
        MEMCMPEQ_IMPLS, MEMRCHR_IMPLS, MEMCHR_IMPLS, WMEMCHR_IMPLS,            \
        STRLEN_IMPLS, WCSLEN_IMPLS, WCSNLEN_IMPLS, RAWMEMCHR_IMPLS,            \
        STRNLEN_IMPLS, STRCPY_IMPLS, STRCAT_IMPLS, STPCPY_IMPLS,               \
        STRNCPY_IMPLS, STRNCAT_IMPLS, STPNCPY_IMPLS, MEMSET_IMPLS,             \
        WCSCPY_IMPLS, WCSCAT_IMPLS, WCPCPY_IMPLS, WCSNCPY_IMPLS,               \
        WCSNCAT_IMPLS, WCPNCPY_IMPLS, STRCHR_IMPLS, STRCHRNUL_IMPLS,           \
        WCSCHR_IMPLS, STRCMP_IMPLS, STRNCMP_IMPLS, WCSCMP_IMPLS, WCSNCMP_IMPLS

decl_func(memcpy, decl_memcpy, MEMCPY_IMPLS);
decl_func(memcmp, decl_memcmp, MEMCMP_IMPLS);
decl_func(wmemcmp, decl_wmemcmp, WMEMCMP_IMPLS);
decl_func(memcmpeq, decl_memcmp, MEMCMPEQ_IMPLS);
decl_func(strrchr, decl_strchr, STRRCHR_IMPLS);
decl_func(wcsrchr, decl_wcschr, WCSRCHR_IMPLS);
decl_func(memrchr, decl_memchr, MEMRCHR_IMPLS);
decl_func(memchr, decl_memchr, MEMCHR_IMPLS);
decl_func(rawmemchr, decl_rawmemchr, RAWMEMCHR_IMPLS);
decl_func(wmemchr, decl_wmemchr, WMEMCHR_IMPLS);
decl_func(strlen, decl_strlen, STRLEN_IMPLS);
decl_func(strnlen, decl_strnlen, STRNLEN_IMPLS);
decl_func(wcslen, decl_wcslen, WCSLEN_IMPLS);
decl_func(wcsnlen, decl_wcsnlen, WCSNLEN_IMPLS);
decl_func(memset, decl_memset, MEMSET_IMPLS);
decl_func(strcpy, decl_strcpy, STRCPY_IMPLS);
decl_func(strcat, decl_strcpy, STRCAT_IMPLS);
decl_func(stpcpy, decl_strcpy, STPCPY_IMPLS);
decl_func(strncpy, decl_strncpy, STRNCPY_IMPLS);
decl_func(strncat, decl_strncpy, STRNCAT_IMPLS);
decl_func(stpncpy, decl_strncpy, STPNCPY_IMPLS);
decl_func(wcscpy, decl_wcscpy, WCSCPY_IMPLS);
decl_func(wcscat, decl_wcscpy, WCSCAT_IMPLS);
decl_func(wcpcpy, decl_wcscpy, WCPCPY_IMPLS);
decl_func(wcsncpy, decl_wcsncpy, WCSNCPY_IMPLS);
decl_func(wcsncat, decl_wcsncpy, WCSNCAT_IMPLS);
decl_func(wcpncpy, decl_wcsncpy, WCPNCPY_IMPLS);

decl_func(strchr, decl_strchr, STRCHR_IMPLS);
decl_func(strchrnul, decl_strchr, STRCHRNUL_IMPLS);
decl_func(wcschr, decl_wcschr, WCSCHR_IMPLS);

decl_func(strcmp, decl_strcmp, STRCMP_IMPLS);
decl_func(strncmp, decl_strncmp, STRNCMP_IMPLS);
decl_func(wcscmp, decl_wcscmp, WCSCMP_IMPLS);
decl_func(wcsncmp, decl_wcsncmp, WCSNCMP_IMPLS);


custom_make_decls(decl_list_t,
                  string_decls,
                  make_string_decl,
                  EAT,
                  STRING_IMPLS);
