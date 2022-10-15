#include "../libc-defs/libc-evex512-vecs.h"
#define	USE_AS_STRLCPY 1
#define	STRCPY strlcpy_evex512_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
