#include "../libc-defs/libc-evex512-vecs.h"
#define	USE_AS_WCSCPY 1
#define	STRCPY wcscpy_evex512_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-submit.S"
