#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
逐条对比两个 DBC 文件，列出记录数差异与字段级差异（用于判断“我们改过 vs 客户端原版”）。
用法: python dbc_diff.py <A.dbc> <B.dbc> [最多打印条数]
"""
import struct
import sys


def load(path):
    d = open(path, "rb").read()
    magic, recs, fields, rsize, ssize = struct.unpack_from("<4sIIII", d, 0)
    assert magic == b"WDBC", path
    soff = 20 + recs * rsize
    strs = d[soff:soff + ssize]

    def get(off):
        if off == 0:
            return ""
        end = strs.find(b"\x00", off)
        return strs[off:end].decode("utf-8", "replace")

    out = {}
    order = []
    for i in range(recs):
        r = list(struct.unpack_from("<%dI" % fields, d, 20 + i * rsize))
        out[r[0]] = (r, get)
        order.append(r[0])
    return out, fields, order


a, afields, aorder = load(sys.argv[1])
b, bfields, border = load(sys.argv[2])
limit = int(sys.argv[3]) if len(sys.argv) > 3 else 20

print("A=%s 记录=%d 字段=%d" % (sys.argv[1], len(aorder), afields))
print("B=%s 记录=%d 字段=%d" % (sys.argv[2], len(border), bfields))

only_a = [i for i in aorder if i not in b]
only_b = [i for i in border if i not in a]
print("只在 A 的 id: %d %s" % (len(only_a), only_a[:10]))
print("只在 B 的 id: %d %s" % (len(only_b), only_b[:10]))

changed = []
for i in aorder:
    if i not in b:
        continue
    ra, _ = a[i]
    rb, _ = b[i]
    if ra != rb:
        diffs = [(k, ra[k], rb[k]) for k in range(min(len(ra), len(rb))) if ra[k] != rb[k]]
        changed.append((i, diffs))
print("同 id 但内容不同的记录: %d" % len(changed))
for i, diffs in changed[:limit]:
    print("  id=%d 差异字段 %s" % (i, ", ".join("#%d A=%s B=%s" % (k, x, y) for k, x, y in diffs[:8])))
