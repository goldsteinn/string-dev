#ifndef STRCMP
# define STRCMP	strncmp_evex_dev
#endif
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#ifndef OVERFLOW_STRCMP
# define OVERFLOW_STRCMP	strcmp_evex_dev
#endif
#include "../libc-defs/libc-evex-vecs.h"
#include "core/strcmp-evex-dev.S"
