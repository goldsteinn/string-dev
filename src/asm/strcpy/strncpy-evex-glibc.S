#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
