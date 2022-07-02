#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRLCPY 1
#define	STRCPY strlcat_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcat-avx2-glibc.S"
