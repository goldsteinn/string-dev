#define MEMCHR				wmemchr_evex512_glibc
#define USE_AS_WMEMCHR
#define USE_WIDE_CHAR	1
#include "memchr-evex512-glibc.S"
