#ifndef MEMCHR
# define MEMCHR	memchr_evex512_glibc
#endif
	
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/memchr-evex512-glibc.S"
