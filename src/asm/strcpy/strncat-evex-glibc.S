#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRNCAT 1
#define	STRCPY strncat_evex_glibc
#define	STRCAT STRCPY
#include "core/strcat-evex-glibc.S"
