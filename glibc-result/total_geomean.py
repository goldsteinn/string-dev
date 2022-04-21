#! /usr/bin/env python3

import sys
import statistics

assert len(sys.argv) > 2


def gm(f, sf):
    start = False
    T = []
    for line in open(f):
        if sf in line:
            start = True
            continue
        if not start:
            continue

        line = line.split(",")
        T.append(float(line[-1]))

    return statistics.geometric_mean(T)


sf = sys.argv[1]
for f in sys.argv[2:]:
    print(gm(f, sf))
