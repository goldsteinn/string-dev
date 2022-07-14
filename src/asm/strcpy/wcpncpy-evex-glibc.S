#define	USE_AS_WCSCPY 1
#define	USE_AS_STPCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY wcpncpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
