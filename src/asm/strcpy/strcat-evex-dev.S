#include "../libc-defs/libc-evex256-vecs.h"
#define	USE_AS_STRCAT 1
#define	STRCPY strcat_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
