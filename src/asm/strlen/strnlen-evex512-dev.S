#ifndef STRLEN
# define STRLEN	strnlen_evex512_dev
#endif
#define STRNLEN	STRLEN
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/strnlen-evex-submit.S"
