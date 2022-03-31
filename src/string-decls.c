#include <wchar.h>

#include "util/func-decl-generator.h"
#include "util/macro.h"
#include "util/types.h"

#include "string-bench-common.h"
#include "string-bench-includes.h"
#include "string-decl-helpers.h"
#include "string-func-info.h"

#define decl_strchr(func) extern char func(char const *, uint8_t)
#define decl_wcschr(func) extern wchar_t func(wchar_t const *, uint32_t)

#define STRRCHR_IMPLS expand_impls(strrchr_evex, strrchr_avx2, strrchr_sse2)
#define WCSRCHR_IMPLS expand_impls(wcsrchr_evex, wcsrchr_avx2, wcsrchr_sse2)


#define STRING_IMPLS STRRCHR_IMPLS, WCSRCHR_IMPLS

decl_func(strrchr, decl_strchr, STRRCHR_IMPLS);
decl_func(wcsrchr, decl_wcschr, WCSRCHR_IMPLS);

custom_make_decls(decl_list_t,
                  string_decls,
                  make_string_decl,
                  EAT,
                  STRING_IMPLS);
