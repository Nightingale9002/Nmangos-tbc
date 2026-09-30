#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
读一个 vmap 模型文件（*.vmo），打印每个 group 的顶点/三角形数量。
格式（WorldModel::writeToFile / readFile）：
  "VMAP_7.0"(8) "WMOD"(4) chunkSize(u32) RootWMOID(u32)
  "GMOD"(4) groupCount(u32) 然后 groupCount 个 group：
      flags(u32) bounds(6f) nameLen(u32) name(...)  "VERT"(4) size(u32) count(u32) verts(12B each)
      "TRIM"(4) size(u32) count(u32) tris(6B each) "MBIH"(4) ... "LIQU"(4) size(u32)... 
  最后 "GBIH"(4) + tree
用法: python vmo_probe.py <file.vmo> [...]
"""
import struct
import sys


def probe(path):
    d = open(path, "rb").read()
    off = 0
    assert d[:8] == b"VMAP_7.0", d[:8]
    off = 8
    assert d[off:off + 4] == b"WMOD", d[off:off + 4]
    off += 4
    chunk, rootid = struct.unpack_from("<II", d, off); off += 8
    print("%s  大小=%d  chunkSize=%d rootWMO=%d" % (path.split("\\")[-1], len(d), chunk, rootid))
    if d[off:off + 4] != b"GMOD":
        print("   没有 GMOD 段 → 无几何")
        return
    off += 4
    groups = struct.unpack_from("<I", d, off)[0]; off += 4
    print("   group 数 = %d" % groups)
    for gi in range(groups):
        flags = struct.unpack_from("<I", d, off)[0]; off += 4
        bounds = struct.unpack_from("<6f", d, off); off += 24
        nlen = struct.unpack_from("<I", d, off)[0]; off += 4
        name = d[off:off + nlen].decode("ascii", "replace"); off += nlen
        verts = tris = 0
        for _ in range(4):                      # VERT / TRIM / MBIH / LIQU 四段
            tag = d[off:off + 4]; off += 4
            if tag == b"VERT":
                size, cnt = struct.unpack_from("<II", d, off); off += 8 + size - 4
                verts = cnt
            elif tag == b"TRIM":
                size, cnt = struct.unpack_from("<II", d, off); off += 8 + size - 4
                tris = cnt
            elif tag == b"MBIH":
                # BIH: bounds(6f) + 2i + nodes
                b = struct.unpack_from("<6f", d, off); off += 24
                il, it = struct.unpack_from("<2i", d, off); off += 8
                off += 12 * it
            elif tag == b"LIQU":
                size = struct.unpack_from("<I", d, off)[0]; off += 4 + size
            else:
                print("   未知段 %r @%d" % (tag, off - 4))
                break
        print("   group[%d] flags=0x%X name=%s verts=%d tris=%d" % (gi, flags, name, verts, tris))


for p in sys.argv[1:]:
    probe(p)
