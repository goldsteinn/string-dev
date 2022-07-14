#define	USE_AS_WCSCPY 1
#define	STRCPY wcscpy_sse2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-sse2-glibc.S"
