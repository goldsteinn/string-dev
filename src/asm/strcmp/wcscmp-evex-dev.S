#define STRCMP	wcscmp_evex_dev
#define WCSCMP	STRCMP
#define USE_AS_WCSCMP	1
#include "../libc-defs/libc-evex256-vecs.h"
#include "strcmp-evex-dev.S"
