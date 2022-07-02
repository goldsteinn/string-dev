#define	USE_AS_STPCPY 1
#define	USE_AS_STRNCPY 1
#define	STRCPY stpncpy_evex_dev
#define	STRCAT STRCPY
#include "core/strcpy-evex-dev.S"
