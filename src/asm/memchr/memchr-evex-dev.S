#ifndef MEMCHR
# define MEMCHR	memchr_evex_dev
#endif
#include "../libc-defs/libc-evex256-vecs.h"
#include "core/memchr-evex-final.S"
