#define	USE_AS_STPCPY 1
#define	USE_AS_STRLCPY 1
#define	STRCPY stplcpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
