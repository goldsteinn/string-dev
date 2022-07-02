#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRNCAT 1
#define	STRCPY strncat_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcat-avx2-glibc.S"
