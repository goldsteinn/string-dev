#include "../libc-defs/libc-evex256-vecs.h"
#define	USE_AS_STPCPY 1
#define	STRCPY stpcpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
