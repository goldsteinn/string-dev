#define MEMCMP				wmemcmp_evex512_dev
#define USE_AS_WMEMCMP
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/memcmp-evex-dev.S"
