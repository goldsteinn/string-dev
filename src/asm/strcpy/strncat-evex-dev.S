#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRNCAT 1
#define	STRCPY strncat_evex_dev
#define	STRCAT STRCPY
#include "core/strcat-evex-dev.S"
