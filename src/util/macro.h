#ifndef _SRC__UTIL__MACRO_H_
#define _SRC__UTIL__MACRO_H_


/* This file contains helper macros for using __VA_ARGS__. Currently
   these macros are written so that 64 arguments is the maximum
   allowed. The formats are clear so expanding them to accept more
   argument should be simply enough.
*/


/******************************************************************************/

#ifndef __FILENAME__
#define __FILENAME__                                                           \
    (__builtin_strrchr(__FILE__, '/') ? __builtin_strrchr(__FILE__, '/') + 1   \
                                      : __FILE__)
#endif
#define ERR_ARGS __FILENAME__, __func__, __LINE__
/******************************************************************************/
#define I__CAT_BASE(x, y) x##y
#define CAT_BASE(x, y)    I__CAT_BASE(x, y)
#define CAT(...)          APPLY_RECURSE(CAT_BASE, __VA_ARGS__)

#define I__V_TO_STR(X) #X
#define V_TO_STR(X)    I__V_TO_STR(X)
/******************************************************************************/

/* For comma chaing of elements. Useful for initialization.  */
#define EMPTY()
#define DEFER(id)  id EMPTY()
#define I__COMMA() ,
#define COMMA      DEFER(I__COMMA)()

/* Take advatage of fact that macro(,) has two arguments but
   macro(OP_THATS_NOT_COMMA) only has one. */
#define FWD_TOKEN(...)                                                         \
    CAT_BASE(REMAKE_COMMA_, NOT_ONE_NARG(__VA_ARGS__))(__VA_ARGS__)
#define REMAKE_COMMA_ONE(...)  __VA_ARGS__
#define REMAKE_COMMA_MANY(...) COMMA

#define DEPAREN_NOTHING_DEPAREN_EXTRACT
#define DEPAREN_PASTE(x, ...)            x##__VA_ARGS__
#define DEPAREN_EVALUATING_PASTE(x, ...) DEPAREN_PASTE(x, __VA_ARGS__)
#define DEPAREN_EXTRACT(...)             DEPAREN_EXTRACT __VA_ARGS__
#define DEPAREN(...)                                                           \
    DEPAREN_EVALUATING_PASTE(DEPAREN_NOTHING_, DEPAREN_EXTRACT __VA_ARGS__)

#define I__ADD_ARG0(...)    __VA_ARGS__
#define I__ADD_ARG1(x, ...) x
#define ADD_ARG_FRONT(x, ...)                                                  \
    CAT_BASE(I__ADD_ARG, IS_EMPTY(__VA_ARGS__))(x, __VA_ARGS__)

#define I_REMOVE_FIRST(first, ...) __VA_ARGS__
#define REMOVE_FIRST(...)          I_REMOVE_FIRST(__VA_ARGS__)

#define FORWARD(...) __VA_ARGS__
#define EAT(...)

#ifdef __clang_analyzer__
#define NOANALYZE(expr, backup) backup
#else
#define NOANALYZE(expr, ...) expr
#endif

#define I_ARR_ARG_1(...)   NULL, 0
#define I_ARR_ARG_1_T(...) NULL, 0

#define I_ARR_ARG_0_T(type, ...)                                               \
    (type const[]){ __VA_ARGS__ }, PP_NARG(__VA_ARGS__)
#define I_ARR_ARG_0(first, ...)                                                \
    I_ARR_ARG_0_T(get_type(first), first, ##__VA_ARGS__)

#define ARR_ARG(...) CAT(I_ARR_ARG_, IS_EMPTY(__VA_ARGS__))(__VA_ARGS__)
#define ARR_ARG_T(type, ...)                                                   \
    CAT(I_ARR_ARG_, IS_EMPTY(__VA_ARGS__), _T)(type, __VA_ARGS__)


#include "internal/generated-macro.h"
/* API:
 *
 *   - PP_NARG(...)
 *       - Gets number of arguments in __VA_ARGS__
 *   - NOT_ONE_NARG(...)
 *       - Will return 'ONE' if PP_NARG(__VA_ARGS) <= 1, otherwise 'MANY'
 *   - IS_EMPTY(...)
 *       - Will return '1' __VA_ARGS__ is empty, otherwise '0'
 *   - APPLY_RECURSE(macro, ...)
 *       - Will apply 2-argument macro (say MIN/MAX) on all __VA_ARGS__
 *   - APPLY(macro, OP, ...)
 *       - Will apply 1-argument macro on all __VA_ARGS__ (seperated = OP)
 *   - APPLY_TOO(macro, OP, ...)
 *       - Same as 'APPLY' (so that you can nest 'APPLY' essentially)
 *   - ARGP_APPLY(argp, OP, ...)
 *       - Will apply all __VA_ARGS__ as macros on 'argp'
 *   - APPLY_PACKR(argp, ...)
 *       - Will transform __VA_ARG__ in list of (arg0, argp), (arg1, argp), ...
 * (argN, argp)
 *   - APPLY_PACKL(argp, ...)
 *       - Will transform __VA_ARG__ in list of (argp, arg0), (argp, arg1), ...
 * (argp, argN)
 */

#endif
