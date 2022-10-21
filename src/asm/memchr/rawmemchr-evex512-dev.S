#define MEMCHR				rawmemchr_evex512_dev
#define RAWMEMCHR MEMCHR
#define USE_AS_RAWMEMCHR
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/rawmemchr-evex-submit.S"
