#define STRCMP	strncmp_sse2_glibc
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#include "core/strcmp-sse2-glibc.S"

