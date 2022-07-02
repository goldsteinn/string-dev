#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strncpy-avx2-dev.S"
