#define STRLEN	wcslen_sse2_glibc
#define WCSLEN	STRLEN
#define USE_AS_WCSLEN	1
#include "core/wcslen-sse2-glibc.S"

