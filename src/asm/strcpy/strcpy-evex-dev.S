#include "../libc-defs/libc-evex256-vecs.h"
#define	STRCPY strcpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
