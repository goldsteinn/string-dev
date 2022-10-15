#ifndef STRLEN
# define STRLEN	strnlen_evex_dev
#endif
#define STRNLEN	STRLEN
#define USE_AS_STRNLEN	1
#include "../libc-defs/libc-evex-vecs.h"
#include "core/strnlen-evex-final.S"
