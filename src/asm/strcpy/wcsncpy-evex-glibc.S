#define	USE_AS_WCSCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY wcsncpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
