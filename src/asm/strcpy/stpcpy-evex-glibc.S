#define	USE_AS_STPCPY 1
#define	STRCPY stpcpy_evex_glibc
#define	STRCAT STRCPY
#include "core/strcpy-evex-glibc.S"
