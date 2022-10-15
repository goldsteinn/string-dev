#define STRCMP	strncmp_evex_glibc
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP	strcmp_evex_glibc
#include "core/strcmp-evex-glibc.S"
