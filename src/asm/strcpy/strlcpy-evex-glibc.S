#define	USE_AS_STRLCPY 1
#define	STRCPY strlcpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
