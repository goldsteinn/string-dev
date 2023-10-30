#define	USE_AS_STRCAT 1
#define	USE_AS_STRNCAT 1
#define	STRCPY strncat_avx2_glibc
#define	STRCAT STRCPY
#define OVERFLOW_STRCAT strcat_avx2_glibc
#include "core/strncat-avx2-glibc.S"
