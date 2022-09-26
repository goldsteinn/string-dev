#! /usr/bin/env python3

import json
import sys
import statistics
import os
import re
import copy

version_dirs = []

for version in sys.argv[1].split(","):
    if "STAR" in version:
        last_piece = version.split("/")[len(version.split("/")) - 1]
        dir_path = version.replace(last_piece, "")
        last_piece = last_piece.replace("STAR", "")
        for d in os.listdir(dir_path):
            if last_piece in d:
                version_dirs.append(dir_path + d)
        version_dirs.sort()
    else:
        version_dirs.append(version)

benchmarks = []
for benchmark in sys.argv[2].split(","):
    if benchmark != "":
        benchmarks.append(benchmark)

cmp_impls = [sys.argv[3].split(",")]

score_cmp = None
if len(sys.argv) > 4:
    score_cmp = sys.argv[4]

bench_fmt = "/bench-{}.out"
cmp_files = []
for benchmark in benchmarks:
    cmp_files.append(bench_fmt.format(benchmark + "{}"))

time_offset = 4


def get_key(length, align1, align2, dgs, wfs, sz):
    return str(length) + "-" + str(align1) + "-" + str(align2) + "-" + str(
        dgs) + "-" + str(wfs) + "-" + str(sz)


def get_stat(times):
    #return min(times)
    tmp = copy.deepcopy(times)
    tmp.sort()

    return statistics.geometric_mean(tmp[0:20])
    #return min(times)#statistics.median(times)


def csv_add(s, field):
    if field is None:
        return s
    if s != "":
        s += ","
    return s + str(field)


def set_if_exists(json_map, field, field_val, fields):
    if field in json_map:
        new_val = str(json_map[field]).lstrip().rstrip()
        fields[field] = new_val
        return new_val, fields

    return field_val, fields


def dgs_to_str(dgs):
    if dgs is None:
        return dgs
    return dgs
    if dgs == "0":
        return "Forward"
    if dgs == "1":
        return "Backward"
    if dgs == "-1":
        return "Bidirectional"
    return dgs


def add_offset(out):
    global time_offset
    while out.count(',') < time_offset:
        out += ","
    return out


class Displayable():

    def __init__(self, hdr, times, cmp_idx):
        self.hdr = hdr
        self.times = times
        self.cmp_idx = cmp_idx

    def out(self):
        if len(self.times) > 2:
            if self.cmp_idx is None:
                return self.out_list()
            elif self.cmp_idx == -1:
                return self.out_cmp_many()
            else:

                return self.out_list_score()
        return self.out_cmp()

    def out_list_score(self):
        out = self.hdr
        out = add_offset(out)
        out = csv_add(out, str(round(self.times[self.cmp_idx], 3)))
        for i in range(0, len(self.times)):
            if i == self.cmp_idx:
                continue
            score = round((self.times[i] / self.times[self.cmp_idx]), 3)
            out = csv_add(out, str(score))
        return out + "\n"

    def out_list(self):
        out = self.hdr
        out = add_offset(out)
        for time in self.times:
            out = csv_add(out, str(round(time, 3)))
        return out + "\n"

    def get_cmp_score(self, t0, t1):
        return str(round(t0, 3)), str(round(t1, 3)), str(round(t0 / t1, 3))

    def out_cmp_many(self):
        out = self.hdr
        out = add_offset(out)
        for i in range(0, int(len(self.times) / 2)):
            t0, t1, score = self.get_cmp_score(self.times[2 * i],
                                               self.times[2 * i + 1])
            out = csv_add(out, t0)
            out = csv_add(out, t1)
            out = csv_add(out, score)
            if i != int(len(self.times) / 2) - 1:
                out += ","
        return out + "\n"

    def out_cmp(self):
        out = self.hdr
        #out = add_offset(out)
        #out = csv_add(self.hdr, str(round(self.times[0], 3)))
        if self.times[1] is not None:
            t0, t1, score = self.get_cmp_score(self.times[0],
                                               self.times[1])            
            #out = csv_add(out, str(round(self.times[1], 3)))
            out = csv_add(out, t0)
            out = csv_add(out, t1)
            out = csv_add(out, str(score))
        return out + "\n"


class Result():

    def __init__(self, ifuncs, fields, length, align1, align2, dgs, wfs, sz):
        self.ifuncs = ifuncs
        self.fields = fields
        self.length = length
        self.align1 = align1
        self.align2 = align2
        self.dgs = dgs
        self.wfs = wfs
        self.sz = sz
        self.timings = {}
        for ifunc in ifuncs:
            self.timings[ifunc] = []

    def add_times(self, times):
        if len(times) != len(self.ifuncs):
            assert len(times) + 1 == len(self.ifuncs)
            assert "__strnlen_evex" in self.ifuncs
            idx = self.ifuncs.index("__strnlen_evex")
            times.insert(idx, 0.0)
        assert len(times) == len(self.ifuncs), "{} != {}".format(times, self.ifuncs)
        for i in range(0, len(self.ifuncs)):
            #            if int(self.length) == 8192 and int(self.align1) == 0 and int(self.align2) == 0:
            #                print("{} -> {}".format(self.ifuncs[i], times[i]))
            self.timings[self.ifuncs[i]].append(float(times[i]))

    def get_stat(self, ifunc):
        if ifunc not in self.timings and "fsrm" in ifunc:
            return get_stat(self.timings[ifunc.replace("fsrm", "erms")])

        return get_stat(self.timings[ifunc])

    def get_hdr(self):
        out = ""
        for f in self.fields:
            out = csv_add(out, self.fields[f])
        return out
        out = csv_add("", self.length)
        out = csv_add(out, self.align1)
        out = csv_add(out, self.align2)
        out = csv_add(out, dgs_to_str(self.dgs))
        out = csv_add(out, self.wfs)
        if self.wfs is not None:
            out = csv_add(out, str(self.sz))
        else:
            out = csv_add(out, self.sz)
        return out

    def result_key(self):
        return get_key(self.length, self.align1, self.align2, self.dgs,
                       self.wfs, self.sz)


class JsonFile():

    def __init__(self, file_fmt):
        self.file_fmt = file_fmt
        self.key_order = []
        self.ifuncs = None
        self.all_results = {}
        self.bench_func = ""
        self.fields = {}

    def name(self, impl):
        global score_cmp
        if score_cmp is None:
            return impl
        ret = ""
        if score_cmp not in self.file_fmt:
            ret = "New"
        if score_cmp in self.file_fmt:
            ret = "Cur"
        return ret + "-" + impl

    def out_fields(self):
        out = ""
        for field in self.fields:
            out = csv_add(out, field)
        return out

    def func_hdr(self):

        bench = self.file_fmt[self.file_fmt.find("bench-") +
                              len("bench-"):self.file_fmt.find("{}")]
        return "\nResults For: {}".format(bench)

    def csv_hdr(self, other, impls):
        out = self.out_fields()
        out = add_offset(out)
        for i in range(0, len(impls)):
            out = csv_add(out, self.name(impls[i]))
            if other is not None:
                out = csv_add(out, other.name(impls[i]))
                out = csv_add(out, "Score-{}".format(impls[i]))
            if i != len(impls) - 1:
                out += ","

        return out

    def find_ifunc(self, impl):
        impl_pattern = "^" + impl.replace("*", ".*") + "$"
        for ifunc in self.ifuncs:
            if re.match(impl_pattern, ifunc) is not None:
                return ifunc
        assert False, "No ifunc for: {} \n{}".format(impl, self.ifuncs)

    def fmt_ifunc(self, impl):
        impl_pieces = impl.split("-")
        postfix = "_unaligned"
        prefix = "__"
        if "str" in self.get_bench_func() or "wcs" in self.get_bench_func(
        ) or ("mem" in self.get_bench_func()
              and "chr" in self.get_bench_func()):
            postfix = ""
        elif self.get_bench_func() == "memcmp" or self.get_bench_func(
        ) == "bcmp" or self.get_bench_func() == "__memcmpeq":
            if self.get_bench_func() == "memcmp" and (impl == "avx2"
                                                      or impl == "evex"):
                postfix = "_movbe"
            else:
                postfix = ""

        if self.get_bench_func()[0:2] == "__":

            prefix = ""
        out = "{}{}_{}{}".format(prefix, self.get_bench_func(), impl_pieces[0],
                                 postfix)
        if len(impl_pieces) > 1:
            out += "_" + impl_pieces[1]
        return out

    def load_file(self, fname):
        if os.access(fname, os.R_OK) is False:
            return None
        print(fname)
        with open(fname) as json_file:
            return json.load(json_file)

    def get_bench_func(self):
        return self.bench_func

    def eq_bench_func(self, other):
        scmp = self.bench_func
        ocmp = other.bench_func
        return ocmp == scmp

    def set_bench_func(self, k):
        if self.bench_func == "":
            self.bench_func = k
        assert self.bench_func == k

    def get_results2(self, json_obj):
        results = json_obj["functions"]
        for func in results:
            if self.get_bench_func() not in func:
                continue
            key = get_key(func, None, None, None, None, None)
            if key not in self.all_results:
                self.key_order.append(key)
                self.all_results[key] = Result(self.get_bench_func(),
                                               self.fields, func, None, None,
                                               None, None, None)
            self.all_results[key].add_times([results["mean"]])

    def get_results(self, json_obj):
        for k in json_obj["functions"]:
            self.set_bench_func(k)
        results = json_obj["functions"][self.get_bench_func()]["results"]
        ifuncs = json_obj["functions"][self.get_bench_func()]["ifuncs"]

        for result in results:
            length = None
            pos = None
            align1 = None
            align2 = None
            dgs = None
            wfs = None
            sz = None
            rand = None
            perc_zero = None
            branch = None
            seek_char = None
            max_char = None
            length, self.fields = set_if_exists(result, "length", length,
                                                self.fields)
            length, self.fields = set_if_exists(result, "len_haystack", length,
                                                self.fields)            
            length, self.fields = set_if_exists(result, "max-alignment",
                                                length, self.fields)
            length, self.fields = set_if_exists(result, "len", length,
                                                self.fields)
            length, self.fields = set_if_exists(result, "region-size", length,
                                                self.fields)
            align1, self.fields = set_if_exists(result, "align1", align1,
                                                self.fields)
            align1, self.fields = set_if_exists(result, "align_haystack", align1,
                                                self.fields)            
            align1, self.fields = set_if_exists(result, "alignment", align1,
                                                self.fields)
            align1, self.fields = set_if_exists(result, "align", align1,
                                                self.fields)
            align2, self.fields = set_if_exists(result, "align2", align2,
                                                self.fields)
            align2, self.fields = set_if_exists(result, "align_needle", align2,
                                                self.fields)            
            dgs, self.fields = set_if_exists(result, "dst > src", dgs,
                                             self.fields)
            dgs, self.fields = set_if_exists(result, "fail", dgs,
                                             self.fields)            
            dgs, self.fields = set_if_exists(result, "lat", dgs, self.fields)

            wfs, self.fields = set_if_exists(result, "with-fixed-size", wfs,
                                             self.fields)
            align2, self.fields = set_if_exists(result, "pos", pos,
                                                self.fields)
            rand, self.fields = set_if_exists(result, "rand", rand,
                                              self.fields)
            perc_zero, self.fields = set_if_exists(result, "perc-zero",
                                                   perc_zero, self.fields)
            branch, self.fields = set_if_exists(result, "branch", branch,
                                                self.fields)
            dgs, self.fields = set_if_exists(result, "seek_char", dgs,
                                             self.fields)
            dgs, self.fields = set_if_exists(result, "seek", dgs, self.fields)
            wfs, self.fields = set_if_exists(result, "max_char", wfs,
                                             self.fields)
            sz, self.fields = set_if_exists(result, "invert_pos", sz,
                                            self.fields)
            sz, self.fields = set_if_exists(result, "len_needle", sz,
                                            self.fields)            

            sz, self.fields = set_if_exists(result, "overlap", sz, self.fields)
            sz, self.fields = set_if_exists(result, "size", sz, self.fields)
            sz, self.fields = set_if_exists(result, "result", sz, self.fields)
            sz, self.fields = set_if_exists(result, "char", sz, self.fields)
            sz, self.fields = set_if_exists(result, "freq", sz, self.fields)
            sz, self.fields = set_if_exists(result, "maxlen", sz, self.fields)
            sz, self.fields = set_if_exists(result, "n", sz, self.fields)
            sz, self.fields = set_if_exists(result, "strlen", sz, self.fields)
            if int(sz) == 8192:
                continue
            key = get_key(length, align1, align2, dgs, wfs, sz)
            if self.ifuncs is None:
                self.ifuncs = ifuncs

            assert self.ifuncs == ifuncs
            if key not in self.all_results:
                self.key_order.append(key)
                self.all_results[key] = Result(ifuncs, copy.deepcopy(self.fields), length,
                                               align1, align2, dgs, wfs, sz)
            self.all_results[key].add_times(result["timings"])

    def parse_all_files(self):
        for i in range(0, 20):
            file_path = self.file_fmt.format(i)
            json_obj = self.load_file(file_path)
            if json_obj is None:
                json_obj = self.load_file(file_path)
                if json_obj is None:
                    continue
            self.get_results(json_obj)

    def show_results(self, impls, others, cmp_s):
        if len(others) == 0:
            self.show_results_cmp_impls(impls)
        elif len(others) == 1:
            self.show_results_cmp_other(impls, others[0])
        else:
            if cmp_s is None or cmp_s == "":
                self.show_results_cmp_others(impls, others)
            else:
                self.show_result_scores(impls, others, cmp_s)

    def show_results_cmp_impls(self, impls):
        disps = []
        assert isinstance(impls, list)
        impls = impls[0]
        assert isinstance(impls, list)

        impl_ifuncs = []
        for impl in impls:
            impl_ifuncs.append(self.find_ifunc(impl))

        #print(str(impls))
        #print(str(impl_ifuncs))

        assert len(impls) == len(impl_ifuncs)
        print(self.func_hdr())
        print(self.out_fields())
        for key in self.key_order:
            hdr = self.all_results[key].get_hdr()
            times = []
            for i in range(0, len(impls)):
                times.append(self.all_results[key].get_stat(impl_ifuncs[i]))
            disps.append(Displayable(hdr, times, 0))
        for disp in disps:
            print(disp.out(), end="")

    def show_results_cmp_other(self, impls, other):
        disps = []
        print(self.func_hdr())
        print(self.csv_hdr(other, impls))
        for key in self.key_order:
            times = []
            hdr = self.all_results[key].get_hdr()

            assert key in other.all_results
            assert other.all_results[key].get_hdr() == hdr
            assert self.eq_bench_func(other)
            for impl in impls:
                times.append(self.all_results[key].get_stat(
                    self.fmt_ifunc(impl)))
                times.append(other.all_results[key].get_stat(
                    other.fmt_ifunc(impl)))

            disps.append(Displayable(hdr, times, -1))
        for disp in disps:
            print(disp.out(), end="")

    def show_result_scores(self, impl, others, cmp_s):
        disps = []
        print(self.func_hdr())
        print(self.out_fields())
        impl = impl[0]
        for key in self.key_order:
            times = [self.all_results[key].get_stat(self.fmt_ifunc(impl))]
            hdr = self.all_results[key].get_hdr()
            cmp_idx = None
            if cmp_s in self.file_fmt:
                cmp_idx = 0
            for i in range(0, len(others)):
                other = others[i]
                if cmp_s in other.file_fmt:
                    assert cmp_idx is None
                    cmp_idx = i + 1


#                print("{} -> {} [{}]".format(key, other.file_fmt, key in other.all_results))
                assert key in other.all_results
                assert other.all_results[key].get_hdr() == hdr
                assert other.get_bench_func() == self.get_bench_func()

                times.append(other.all_results[key].get_stat(
                    self.fmt_ifunc(impl)))
            disps.append(Displayable(hdr, times, cmp_idx))
        for disp in disps:
            print(disp.out(), end="")

    def show_results_cmp_others(self, impl, others):
        disps = []
        print(self.func_hdr())
        print(self.out_fields())
        for key in self.key_order:
            times = [self.all_results[key].get_stat(self.fmt_ifunc(impl))]

            hdr = self.all_results[key].get_hdr()
            for other in others:
                assert key in other.all_results
                assert other.all_results[key].get_hdr() == hdr
                assert other.get_bench_func() == self.get_bench_func()

                times.append(other.all_results[key].get_stat(
                    self.fmt_ifunc(impl)))

            disps.append(Displayable(hdr, times, None))
        for disp in disps:
            print(disp.out(), end="")

all_json_files = []
for i in range(0, len(version_dirs)):

    all_json_files.append([])
    for cmp_file in cmp_files:

        res = JsonFile(version_dirs[i] + cmp_file)
        res.parse_all_files()
        all_json_files[i].append(res)

if len(version_dirs) == 1:
    for res in all_json_files[0]:
        res.show_results_cmp_impls(cmp_impls)
else:

    for cmp_impl in cmp_impls:
        for i in range(0, len(all_json_files[0])):
            jsons_to_cmp = []
            for json_lists in all_json_files[1:]:
                jsons_to_cmp.append(json_lists[i])

            all_json_files[0][i].show_results(cmp_impl, jsons_to_cmp,
                                              score_cmp)
