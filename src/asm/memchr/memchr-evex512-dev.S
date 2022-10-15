#ifndef MEMCHR
# define MEMCHR	memchr_evex512_dev
#endif
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/memchr-evex-final.S"
