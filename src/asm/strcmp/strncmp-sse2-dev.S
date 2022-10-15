#define STRCMP	strncmp_sse2_dev
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#include "core/strcmp-sse2-dev.S"
