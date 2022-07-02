#define	USE_AS_STRCAT_ 1
#define	STRCPY strcat_sse2_dev
#define	STRCAT STRCPY
#include "core/strcat-sse2-dev.S"
