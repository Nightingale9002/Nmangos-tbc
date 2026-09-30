#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
解析 <map>.vmtree（VMAP_7.0）：
  8B magic "VMAP_7.0" + 1B tiled + "NODE" + BIH(tree) + "GOBJ" + 全局模型 spawn 列表
  （non-tiled map 通常只有 1 个全局 WMO；tiled map 走 .vmtile）
输出：是否 tiled、BIH 规模、GOBJ 里的模型文件名 + 位置/包围盒。
用法: python vmtree_probe.py <mapId> [vmaps目录]
"""
import os
import struct
import sys

MAPID = int(sys.argv[1]) if len(sys.argv) > 1 else 556
VMAP_DIR = sys.argv[2] if len(sys.argv) > 2 else r"D:\Game\cmangos\x64_Debug\vmaps"

path = os.path.join(VMAP_DIR, "%03u.vmtree" % MAPID)
data = open(path, "rb").read()
print("文件: %s  大小: %d B" % (path, len(data)))

off = 0
magic = data[off:off + 8]; off += 8
print("magic:", magic)
tiled = data[off]; off += 1
print("tiled:", tiled)
print("chunk@%d: %s" % (off, data[off:off + 4])); off += 4

# BIH: bounds(6f) + 2i + nodes...
bx0, by0, bz0, bx1, by1, bz1 = struct.unpack_from("<6f", data, off); off += 24
il, it = struct.unpack_from("<2i", data, off); off += 8
print("BIH bounds: (%.1f,%.1f,%.1f) - (%.1f,%.1f,%.1f)  nodes=%d prims=%d" % (bx0, by0, bz0, bx1, by1, bz1, il, it))
# BIH node tree: 4*it bytes (each node 2 int16 + 2 int32? 实际: 每个节点 2*(int16)+2*(uint32) 变长)
# cmangos 的 BIH: for i in range(it): 读 int16[2] + uint32[2]  共 12B
off += 12 * it
print("chunk@%d: %s" % (off, data[off:off + 4]))
if data[off:off + 4] != b"GOBJ":
    print("!! 未找到 GOBJ，偏移可能不对（后续解析跳过）")
    sys.exit(0)
off += 4

# GOBJ 段: uint32 count，然后每个 ModelSpawn:
#   uint32 flags, char name[500], uint32 adtId, float pos[3], float rot[3], float scale,
#   float bounds[6]   （见 ModelSpawn::readFromFile）
count = struct.unpack_from("<I", data, off)[0]; off += 4
print("GOBJ 全局 spawn 数:", count)
for i in range(count):
    flags = struct.unpack_from("<I", data, off)[0]; off += 4
    name = data[off:off + 500].split(b"\x00")[0].decode("ascii", "replace"); off += 500
    adtId = struct.unpack_from("<I", data, off)[0]; off += 4
    pos = struct.unpack_from("<3f", data, off); off += 12
    rot = struct.unpack_from("<3f", data, off); off += 12
    scale = struct.unpack_from("<f", data, off)[0]; off += 4
    bnd = struct.unpack_from("<6f", data, off); off += 24
    print("  [%d] flags=0x%X adt=%u scale=%.3f pos=(%.1f,%.1f,%.1f) rot=(%.1f,%.1f,%.1f)" % (i, flags, adtId, scale, pos[0], pos[1], pos[2], rot[0], rot[1], rot[2]))
    print("       name=%s" % name)
    print("       bounds=(%.1f,%.1f,%.1f)-(%.1f,%.1f,%.1f)" % tuple(bnd))
print("剩余字节:", len(data) - off)
