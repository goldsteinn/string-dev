#define STRRCHR	wcsrchr_evex512_dev
#define USE_AS_WCSRCHR	1
#include "../libc-defs/libc-evex512-vecs.h"
#include "core/strrchr-evex512-final.S"
