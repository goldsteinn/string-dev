#define MEMCMP	wmemcmp_sse2_dev
#define USE_AS_WMEMCMP
#include "core/memcmp-sse2-final.S"
