#define	USE_AS_STPCPY 1
#define	STRCPY stpcpy_sse2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-sse2-glibc.S"
