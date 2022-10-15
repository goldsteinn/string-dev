#define STRCMP	wcsncmp_evex_dev
#define WCSNCMP	STRCMP
#define USE_AS_WCSCMP	1
#define USE_AS_STRNCMP	1
#define OVERFLOW_STRCMP	wcscmp_evex_dev
#include "strncmp-evex-dev.S"
