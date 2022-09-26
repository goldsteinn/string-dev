#define STRLEN	wcsnlen_evex_glibc
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1
#include "core/strlen-evex-glibc.S"

