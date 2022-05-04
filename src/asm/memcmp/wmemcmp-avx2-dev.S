#define MEMCMP	wmemcmp_avx2_dev
#define USE_AS_WMEMCMP
#include "core/memcmp-avx2-final.S"
