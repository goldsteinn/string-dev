#include "../libc-defs/libc-evex256-vecs.h"
#define	USE_AS_WCSCPY 1
#define	USE_AS_STRCAT 1
#define	STRCPY wcscat_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-submit.S"
