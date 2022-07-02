#define	USE_AS_STRCAT 1
#define	USE_AS_STRNCAT 1
#define	STRCPY strncat_avx2_dev
#define	STRCAT STRCPY
#include "core/strncat-avx2-dev.S"
