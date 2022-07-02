#define	USE_AS_STRCAT_ 1
#define	STRCPY strcat_evex_glibc
#define	STRCAT STRCPY
#include "core/strcat-evex-glibc.S"
