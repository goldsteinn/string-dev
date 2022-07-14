#define	USE_AS_WCSCPY 1
#define	USE_AS_STRCAT_ 1
#define	USE_AS_STRLCPY 1
#define	STRCPY wcslcat_evex_glibc
#define	STRCAT STRCPY
#include "core/strcat-evex-glibc.S"
