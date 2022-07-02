#define	USE_AS_STPCPY 1
#define	STRCPY stpcpy_avx2_glibc
#define	STRCAT STRCPY
#include "core/strcpy-avx2-glibc.S"
