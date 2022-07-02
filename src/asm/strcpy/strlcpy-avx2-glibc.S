#define	USE_AS_STRLCPY 1
#define	STRCPY strlcpy_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-avx2-glibc.S"
