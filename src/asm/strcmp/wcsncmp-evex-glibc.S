#define STRCMP	wcsncmp_evex_glibc
#define WCSNCMP	STRCMP
#define USE_AS_WCSCMP	1
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP	wcscmp_evex_glibc
#include "core/strcmp-evex-glibc.S"
