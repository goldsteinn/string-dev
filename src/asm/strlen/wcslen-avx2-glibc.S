#define STRLEN	wcslen_avx2_glibc
#define WCSLEN	STRLEN
#define USE_AS_WCSLEN	1
#include "core/strlen-avx2-glibc.S"

