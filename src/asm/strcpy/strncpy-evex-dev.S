#include "../libc-defs/libc-evex-vecs.h"
#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_evex_dev
#define	STRCAT STRCPY
#include "core/strncpy-evex-dev.S"
