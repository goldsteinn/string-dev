#define STRCMP	wcsncmp_evex512_dev
#define WCSNCMP	STRCMP
#define USE_AS_WCSCMP	1
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP	wcscmp_evex512_dev
#include "../libc-defs/libc-evex512-vecs.h"
#include "strncmp-evex512-dev.S"
