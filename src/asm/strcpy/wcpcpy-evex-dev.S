#include "../libc-defs/libc-evex-vecs.h"
#define	USE_AS_WCSCPY 1
#define	USE_AS_STPCPY 1
#define	STRCPY wcpcpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
