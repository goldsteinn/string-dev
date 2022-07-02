#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
