#define STRLEN	wcslen_evex_dev
#define WCSLEN	STRLEN
#define USE_AS_WCSLEN	1
#include "../libc-defs/libc-evex256-vecs.h"
#include "strlen-evex-dev.S"
