#define	USE_AS_STRCAT 1
#define	STRCPY strcat_avx2_dev
#define	STRCAT STRCPY
#include "core/strcpy-avx2-submit.S"
