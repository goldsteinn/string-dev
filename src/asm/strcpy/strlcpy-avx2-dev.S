#define	USE_AS_STRLCPY 1
#define	STRCPY strlcpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strcpy-avx2-dev.S"
