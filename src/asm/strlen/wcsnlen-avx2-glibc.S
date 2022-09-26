#define STRLEN	wcsnlen_avx2_glibc
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
#define USE_AS_STRNLEN	1
#include "core/strlen-avx2-glibc.S"

