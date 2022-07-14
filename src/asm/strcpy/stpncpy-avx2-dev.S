#define	USE_AS_STPCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY stpncpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strncpy-avx2-dev.S"
