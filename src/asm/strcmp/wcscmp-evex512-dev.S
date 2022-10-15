#define STRCMP	wcscmp_evex512_dev
#define WCSCMP	STRCMP
#define REG_WIDTH	32
#define USE_AS_WCSCMP	1
#include "../libc-defs/libc-evex512-vecs.h"
#include "strcmp-evex512-dev.S"
