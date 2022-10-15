#include "../libc-defs/libc-evex-vecs.h"
#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRLCPY 1
#define	STRCPY strlcat_evex_dev
#define	STRCAT STRCPY
#include "core/strcat-evex-dev.S"
