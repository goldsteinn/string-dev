#include "../libc-defs/libc-evex512-vecs.h"
#define USE_AS_STRCAT_	1
#define USE_AS_STRNCAT	1
#define STRCPY	strncat_evex512_dev
#define STRCAT	STRCPY
#define OVERFLOW_STRCAT	strcat_evex512_dev
#include "core/strncat-evex-submit.S"
