#ifndef _SRC__STRING_FUNC_SWITCHES_H_
#define _SRC__STRING_FUNC_SWITCHES_H_

#include <string.h>

#include "util/macro.h"
#include "util/types.h"

#define add_func(func) FUNC_T(func) CAT(run_, func)

typedef union func_switch {
    add_func(memchr);
    add_func(memcmp);
    add_func(memcpy);
    add_func(memmove);
    add_func(memrchr);
    add_func(memset);
    add_func(rawmemchr);
    add_func(stpcpy);
    add_func(stpncpy);
    add_func(strcat);
    add_func(strchr);
    add_func(strchrnul);
    add_func(strcmp);
    add_func(strcpy);
    add_func(strlen);
    add_func(strncat);
    add_func(strncmp);
    add_func(strncpy);
    add_func(strnlen);
    add_func(strrchr);
    add_func(wcpcpy);
    add_func(wcpncpy);
    add_func(wcscat);
    add_func(wcschr);
    add_func(wcschrnul);
    add_func(wcscmp);
    add_func(wcscpy);
    add_func(wcslen);
    add_func(wcsncat);
    add_func(wcsncmp);
    add_func(wcsncpy);
    add_func(wcsnlen);
    add_func(wcsrchr);
    add_func(wmemchr);
    add_func(wmemcmp);
    add_func(wmemcpy);
    add_func(wmemmove);
    add_func(wmemset);
} func_switch_t;


#endif
