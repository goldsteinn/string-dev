#include "../libc-defs/libc-evex-vecs.h"
#define	USE_AS_WCSCPY 1
#define	USE_AS_STRLCPY 1
#define	STRCPY wcslcpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
