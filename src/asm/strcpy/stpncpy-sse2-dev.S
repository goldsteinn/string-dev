#define	USE_AS_STPCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY stpncpy_sse2_dev
#define	STRCAT STRCPY
#include "core/strcpy-sse2-dev.S"
