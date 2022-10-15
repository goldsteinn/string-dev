#define STRCMP	wcscmp_avx2_glibc
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "core/strcmp-avx2-glibc.S"

