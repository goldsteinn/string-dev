#define STRCMP	strncmp_avx2_glibc
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP strcmp_avx2_dev
#include "core/strcmp-avx2-glibc.S"

