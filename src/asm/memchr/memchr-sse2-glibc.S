#ifndef MEMCHR
# define MEMCHR	memchr_sse2_glibc
#endif
#ifdef USE_AS_RAWMEMCHR
# include "core/rawmemchr-sse2-glibc.S"
#else
# include "core/memchr-sse2-glibc.S"
#endif
