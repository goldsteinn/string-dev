#define STRLEN	wcsnlen_evex512_dev
#define WCSNLEN	STRLEN
#define USE_AS_WCSLEN	1
    #define USE_AS_STRNLEN	1
    #include "../libc-defs/libc-evex512-vecs.h"
#include "strnlen-evex512-dev.S"
