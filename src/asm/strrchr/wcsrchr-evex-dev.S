#define STRRCHR	wcsrchr_evex_dev
#define USE_AS_WCSRCHR	1
#include "../libc-defs/libc-evex256-vecs.h"
#include "core/strrchr-evex-final.S"
