import sys
import os
import statistics

fmt = sys.argv[1]

files = []
i = 0
while True:
    if os.path.isfile(fmt.format(i)):
        files.append(fmt.format(i))
    else:
        break

    i += 1

idx_sse = -1
idx_generic = -1

times = []

for f in files:
    for line in open(f):
        if "_sse2" in line and "_sse2_unaligned" in line:
            line = line.split()
            for i in range(0, len(line)):
                if line[i].endswith("_sse2_unaligned"):
                    idx_sse = i
                elif line[i].endswith("_sse2"):
                    idx_generic = i
            assert idx_sse != -1
            assert idx_generic != -1
            continue
        assert idx_sse != -1
        assert idx_generic != -1

        assert line.count(":") == 1
        pos = line.find(":")

        line = line[pos + 1:]
        line = line.split()

        t_sse = float(line[idx_sse])
        t_generic = float(line[idx_generic])

        times.append(t_sse / t_generic)

print("{}".format(round(statistics.geometric_mean(times), 4)))
