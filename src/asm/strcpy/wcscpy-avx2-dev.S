#define	USE_AS_WCSCPY 1
#define	STRCPY wcscpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strcpy-avx2-submit.S"
