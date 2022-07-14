#define	USE_AS_WCSCPY 1
#define	USE_AS_STPCPY 1
#define	STRCPY wcpcpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
