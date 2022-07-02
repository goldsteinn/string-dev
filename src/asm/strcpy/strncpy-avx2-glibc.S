#define	USE_AS_STRNCPY 1
#define	STRCPY strncpy_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-avx2-glibc.S"
