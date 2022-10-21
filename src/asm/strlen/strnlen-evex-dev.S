#ifndef STRLEN
# define STRLEN	strnlen_evex_dev
#endif
#define STRNLEN	STRLEN
#include "../libc-defs/libc-evex256-vecs.h"
#include "core/strnlen-evex-submit.S"
