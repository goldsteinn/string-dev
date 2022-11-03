#include "../libc-defs/libc-evex512-vecs.h"
#define	USE_AS_STPCPY 1
#define	STRCPY stpcpy_evex512_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-submit.S"
