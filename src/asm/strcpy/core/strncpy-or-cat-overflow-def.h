#ifndef _STRNCPY_OR_CAT_OVERFLOW_DEF_H_
#define _STRNCPY_OR_CAT_OVERFLOW_DEF_H_ 1

#if defined USE_MULTIARCH && IS_IN(libc)
#  define UNDERSCORES __
#  ifdef USE_WITH_SSE2
#    define ISA_EXT _sse2
#  elif defined USE_WITH_AVX
#    ifdef USE_WITH_RTM
#      define ISA_EXT _avx_rtm
#    else
#      define ISA_EXT _avx
#    endif
#  elif defined USE_WITH_AVX2
#    ifdef USE_WITH_RTM
#      define ISA_EXT _avx2_rtm
#    else
#      define ISA_EXT _avx2
#    endif

#  elif defined USE_WITH_EVEX256
#    define ISA_EXT _evex
#  elif defined USE_WITH_EVEX512
#    define ISA_EXT _evex512
#  endif
#else
#  define UNDERSCORES
#  define ISA_EXT
#endif

#ifdef USE_AS_WCSCPY
#  define STRCPY_PREFIX wc
#  define STRCAT_PREFIX wcs
#  ifdef USE_AS_STPCPY
#    define STRCPY_POSTFIX pcpy
#  else
#    define STRCPY_POSTFIX scpy
#  endif
#else
#  define STRCPY_PREFIX st
#  define STRCAT_PREFIX str
#  ifdef USE_AS_STPCPY
#    define STRCPY_POSTFIX pcpy
#  else
#    define STRCPY_POSTFIX rcpy
#  endif
#endif
#define STRCAT_POSTFIX cat

#define PRIMITIVE_OF_NAMER(underscores, prefix, postfix, ext)                 \
  underscores##prefix##postfix##ext

#define OF_NAMER(...) PRIMITIVE_OF_NAMER (__VA_ARGS__)

#ifndef OVERFLOW_STRCPY
#  define OVERFLOW_STRCPY                                                     \
    OF_NAMER (UNDERSCORES, STRCPY_PREFIX, STRCPY_POSTFIX, ISA_EXT)
#endif

#ifndef OVERFLOW_STRCAT
#  define OVERFLOW_STRCAT                                                     \
    OF_NAMER (UNDERSCORES, STRCAT_PREFIX, STRCAT_POSTFIX, ISA_EXT)
#endif

#endif
