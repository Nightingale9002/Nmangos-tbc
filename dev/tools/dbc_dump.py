#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
打印 DBC 指定记录的字段；对指向字符串块的值自动解出文本。
用法: python dbc_dump.py <file.dbc> <id> [<id> ...]
"""
import struct
import sys

path = sys.argv[1]
ids = [int(x) for x in sys.argv[2:]]
d = open(path, "rb").read()
magic, recs, fields, rsize, ssize = struct.unpack_from("<4sIIII", d, 0)
soff = 20 + recs * rsize
strs = d[soff:soff + ssize]
print("%s  记录=%d 字段=%d" % (path.split("\\")[-1], recs, fields))


def get(off):
    if off <= 0 or off >= len(strs):
        return None
    end = strs.find(b"\x00", off)
    if end < 0:
        return None
    raw = strs[off:end]
    if len(raw) < 2:
        return None
    try:
        txt = raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if all(32 <= ord(c) < 127 or ord(c) > 127 for c in txt) and any(c.isalpha() for c in txt):
        return txt
    return None


for i in range(recs):
    r = struct.unpack_from("<%dI" % fields, d, 20 + i * rsize)
    if r[0] in ids:
        print("\n=== id %d ===" % r[0])
        for k, v in enumerate(r):
            if k == 0:
                continue
            txt = get(v)
            fv = struct.unpack("<f", struct.pack("<I", v))[0]
            line = "  [%2d] %12d" % (k, v)
            if txt:
                line += "   str: %s" % txt
            elif abs(fv) > 1e-6 and abs(fv) < 1e6 and fv == fv:
                line += "   float: %.4f" % fv
            print(line)
