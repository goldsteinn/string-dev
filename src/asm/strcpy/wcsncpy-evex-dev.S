#include "../libc-defs/libc-evex256-vecs.h"
#define	USE_AS_WCSCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY wcsncpy_evex_dev
#define	STRCAT STRCPY
#include "core/strncpy-evex-submit.S"
