#define	USE_AS_WCSCPY 1
#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRNCAT 1
#define	STRCPY wcsncat_sse2_glibc
#define	STRCAT STRCPY
#include "core/strcat-sse2-glibc.S"
