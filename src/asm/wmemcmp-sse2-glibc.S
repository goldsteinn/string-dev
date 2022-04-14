#define MEMCMP	wmemcmp_sse2_glibc
#define USE_AS_WMEMCMP
#include "core/memcmp-ssse3-glibc.S"
