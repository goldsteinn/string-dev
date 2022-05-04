#define MEMCMP	wmemcmp_avx2_glibc
#define USE_AS_WMEMCMP
#include "core/memcmp-avx2-glibc.S"
