#define STRCMP	wcscmp_sse42_glibc
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "core/strcmp-sse42-glibc.S"
