#define STRCMP	wcscmp_evex_glibc
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "core/strcmp-evex-glibc.S"

