#define	USE_AS_STRCAT_ 1
#define	STRCPY strcat_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcat-avx2-glibc.S"
