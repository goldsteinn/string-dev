#include "../libc-defs/libc-evex512-vecs.h"
#define	STRCPY strcpy_evex512_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
