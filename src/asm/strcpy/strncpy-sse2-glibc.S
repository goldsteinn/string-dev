#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_sse2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-sse2-glibc.S"
