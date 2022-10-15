#include "../libc-defs/libc-evex512-vecs.h"
#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRLCPY 1
#define	STRCPY strlcat_evex512_dev
#define	STRCAT STRCPY
#include "core/strcat-evex-dev.S"
