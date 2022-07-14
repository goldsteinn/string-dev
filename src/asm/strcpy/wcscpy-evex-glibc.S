#define	USE_AS_WCSCPY 1
#define	STRCPY wcscpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
