#define	USE_AS_WCSCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY wcsncpy_avx2_dev
#define	STRCAT STRCPY
#include "core/strcpy-avx2-dev.S"
