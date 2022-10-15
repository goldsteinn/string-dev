#include "../libc-defs/libc-evex512-vecs.h"
#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_evex512_dev
#define	STRCAT STRCPY
#include "core/strncpy-evex-dev.S"
