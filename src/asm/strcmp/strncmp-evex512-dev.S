#ifndef STRCMP
# define STRCMP	strncmp_evex512_dev
#endif
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#ifndef OVERFLOW_STRCMP
# define OVERFLOW_STRCMP	strcmp_evex512_dev
#endif
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/strcmp-evex-dev.S"
