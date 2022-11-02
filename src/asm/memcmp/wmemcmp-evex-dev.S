#define MEMCMP	wmemcmp_evex_dev
#define USE_AS_WMEMCMP
#include "../libc-defs/libc-evex256-vecs.h"
#include "core/memcmp-evex-dev.S"
