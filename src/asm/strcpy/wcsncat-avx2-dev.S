#define USE_AS_WCSCPY	1
#define USE_AS_STRCAT	1
#define USE_AS_STRNCAT	1
#define STRCPY	wcsncat_avx2_dev
#define STRCAT	STRCPY
#define OVERFLOW_STRCAT	wcscat_avx2_dev
#include "core/strncat-avx2-submit.S"
