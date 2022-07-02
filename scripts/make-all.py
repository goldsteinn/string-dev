import sys
import os
from common_util import (in_arr_ele, die_assert, ez_write, ez_open, ez_close)

assert len(sys.argv) > 2

DIR = sys.argv[1]
BASENAME = sys.argv[2]


def define(name, val="1"):
    return "#define\t{} {}\n".format(name, val)


def include(name):
    return "#include \"{}\"\n".format(name)


class Strcpy_Namer():

    def func_name(self, use_as):
        prefix = "st"
        pcpy = "r"
        ncpy = ""
        postfix = "cpy"

        if in_arr_ele("WCS", use_as):
            prefix = "wc"
        if in_arr_ele("STP", use_as):
            pcpy = "p"
        if in_arr_ele("STRN", use_as):
            ncpy = "n"
        if in_arr_ele("STRL", use_as):
            assert ncpy != "n"
            ncpy = "l"

        if in_arr_ele("CAT", use_as):
            postfix = "cat"

        return "{}{}{}{}".format(prefix, pcpy, ncpy, postfix)

    def defs(self, f):
        die_assert(not ez_write(f, define("STRCAT", "STRCPY")))

    def inc_name(self, use_as):
        if in_arr_ele("CAT", use_as):
            return "strcat"
        return "strcpy"


class Builder():

    def __init__(self, ext, use_as, who, namer):
        self.ext = ext
        self.use_as = use_as
        self.who = who
        self.namer = namer

    def build(self):
        global DIR
        global BASENAME
        basename = self.namer.func_name(self.use_as)

        filename = os.path.realpath("{}/{}-{}-{}.S".format(
            DIR, basename, self.ext, self.who))
        incname = "core/{}-{}-{}.S".format(self.namer.inc_name(self.use_as),
                                           self.ext, self.who)
        funcname = "{}_{}_{}".format(basename, self.ext, self.who)

        f = ez_open(filename, "w+")
        die_assert(f, "Unable to open: {}".format(filename))
        for use in self.use_as:
            if use == "":
                continue
            die_assert(not ez_write(f, define(use)))

        die_assert(not ez_write(f, define(BASENAME.upper(), funcname)))
        self.namer.defs(f)

        die_assert(not ez_write(f, include(incname)))
        die_assert(not ez_close(f))


builders = []
text = []
for who in ["dev", "glibc"]:
    for ext in ["sse2", "avx2", "evex"]:
        for impl_type in ["", "USE_AS_STPCPY", "USE_AS_STRCAT_"]:
            for impl_len in ["", "USE_AS_STRNCPY", "USE_AS_STRLCPY"]:
                if "NCPY" in impl_len and "CAT" in impl_type:
                    impl_len = "USE_AS_STRNCAT"
                builders.append(
                    Builder(ext, [impl_type, impl_len], who, Strcpy_Namer()))

for builder in builders:
    builder.build()
