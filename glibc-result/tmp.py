import sys

f0 = sys.argv[1]
f1 = sys.argv[2]

f0_l = []
for lines in open(f0):
    if "," not in lines:
        continue
    lines = lines.rstrip().lstrip()
    f0_l.append(lines.split(","))

f1_l = []
for lines in open(f1):
    if "," not in lines:
        continue
    lines = lines.rstrip().lstrip()
    f1_l.append(lines.split(","))

assert len(f1_l) == len(f0_l)

for i in range(0, len(f0_l)):
    f0_l[i].append(f1_l[i][-1])
    f0_l[i] = ",".join(f0_l[i])

print("\n".join(f0_l))
