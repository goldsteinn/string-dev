#define MEMCHR				rawmemchr_evex_dev
#define RAWMEMCHR MEMCHR
#define USE_AS_RAWMEMCHR
#include "../libc-defs/libc-evex256-vecs.h"
#include "core/rawmemchr-evex-submit.S"
