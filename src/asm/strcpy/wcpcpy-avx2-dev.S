#define	USE_AS_WCSCPY 1
#define	USE_AS_STPCPY 1
#define	STRCPY wcpcpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strcpy-avx2-dev.S"
