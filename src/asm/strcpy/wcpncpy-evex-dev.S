#include "../libc-defs/libc-evex-vecs.h"
#define	USE_AS_WCSCPY 1
#define	USE_AS_STPCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY wcpncpy_evex_dev
#define	STRCAT STRCPY
#include "core/strncpy-evex-dev.S"
