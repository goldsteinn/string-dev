#define	USE_AS_STPCPY 1
#define	USE_AS_STRLCPY 1
#define	STRCPY stplcpy_sse2_dev
#define	STRCAT STRCPY
#include "core/strcpy-sse2-dev.S"
