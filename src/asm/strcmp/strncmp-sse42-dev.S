#define STRCMP	strncmp_sse42_dev
#define STRNCMP	STRCMP
#define USE_AS_STRNCMP	1
#include "core/strcmp-sse42-dev.S"
