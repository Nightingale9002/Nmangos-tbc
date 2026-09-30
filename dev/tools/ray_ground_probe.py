#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
以太鳐 22181「地面下沉」实测：
拿 creature 表里每个刷点的 DB position_z，跟该点所在 mmtile 的导航面高度对比，
算出「原点离地面多远」，再叠加模型偏移（NetherRay.mdx 下缘 -0.328 x 缩放 1.5 = -0.492 yd），
得到肉眼可见的下沉量。

用法: python ray_ground_probe.py [creatureEntry] [map]
"""
import os
import struct
import sys

MMAP_DIR = r"D:\Game\cmangos\x64_Debug\mmaps"
HERE = os.path.dirname(os.path.abspath(__file__))

MODEL_SINK = 0.492          # NetherRay.mdx: -GeoBox.minZ(0.328) * displayScale(1.5)


def load_tile(map_id, wow_x, wow_y):
    """按 cmangos 命名规则 <map><tileY><tileX> 找文件；两种顺序都试。"""
    ty = int(32 - wow_x / 533.33333)
    tx = int(32 - wow_y / 533.33333)
    for name in ("%u%02u%02u" % (map_id, ty, tx), "%u%02u%02u" % (map_id, tx, ty)):
        p = os.path.join(MMAP_DIR, name + ".mmtile")
        if os.path.exists(p):
            return p, name
    return None, "%u%02u%02u" % (map_id, ty, tx)


TILE_CACHE = {}


def parse_tile(path):
    if path in TILE_CACHE:
        return TILE_CACHE[path]
    data = open(path, "rb").read()
    magic, dtver, mmver, size, uses_liquids = struct.unpack_from("<5I", data, 0)
    assert magic == 0x4D4D4150, hex(magic)
    # dtMeshHeader @20: 15 x int32, bmin[3]f, bmax[3]f, bvQuantFactor f  (=100 B)
    h = struct.unpack_from("<15i", data, 20)
    (mmagic, mver, mx, my, layer, userId, polyCount, vertCount, maxLink, detailMeshCount,
     detailVertCount, detailTriCount, bvNodeCount, offMeshConCount, offMeshBase) = h
    bmin = struct.unpack_from("<3f", data, 20 + 60)
    bmax = struct.unpack_from("<3f", data, 20 + 72)
    voff = 20 + 100
    verts = [struct.unpack_from("<3f", data, voff + i * 12) for i in range(vertCount)]
    poff = voff + vertCount * 12
    polys = []
    for i in range(polyCount):
        rec = struct.unpack_from("<I6H6HHBB", data, poff + i * 32)
        vids = rec[1:7]
        vcount = rec[14]
        area = rec[15]
        flags = rec[13]
        if vcount < 3:
            continue
        pts = [verts[v] for v in vids[:vcount]]
        polys.append((i, pts, flags, area))
    TILE_CACHE[path] = (polys, bmin, bmax, offMeshBase, polyCount)
    return TILE_CACHE[path]


def point_in_poly(px, pz, pts2d):
    inside = False
    n = len(pts2d)
    x1, z1 = pts2d[0]
    for i in range(1, n + 1):
        x2, z2 = pts2d[i % n]
        if (z1 > pz) != (z2 > pz):
            xint = x1 + (pz - z1) * (x2 - x1) / (z2 - z1)
            if px < xint:
                inside = not inside
        x1, z1 = x2, z2
    return inside


def poly_height_at(px, pz, pts3d):
    """平面拟合求 (px, ., pz) 处的高度；退化时用三点平均。"""
    (x1, y1, z1), (x2, y2, z2), (x3, y3, z3) = pts3d[:3]
    u = (x2 - x1, y2 - y1, z2 - z1)
    v = (x3 - x1, y3 - y1, z3 - z1)
    nx = u[1] * v[2] - u[2] * v[1]
    ny = u[2] * v[0] - u[0] * v[2]
    nz = u[0] * v[1] - u[1] * v[0]
    if abs(ny) < 1e-9:
        return sum(p[1] for p in pts3d[:3]) / 3.0
    return (nx * (x1 - px) + nz * (z1 - pz)) / ny + y1


def main():
    entry = sys.argv[1] if len(sys.argv) > 1 else "22181"
    map_id = int(sys.argv[2]) if len(sys.argv) > 2 else 530
    rows = []
    with open(os.path.join(HERE, "ray%s_spawns.tsv" % entry), encoding="ascii", errors="replace") as f:
        f.readline()
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) < 6:
                continue
            rows.append((int(p[0]), float(p[1]), float(p[2]), float(p[3]), int(p[5])))

    print("刷点 %d 个（entry %s, map %d），模型偏移 = -%.3f yd" % (len(rows), entry, map_id, MODEL_SINK))
    print("%-8s %-10s %-10s %-9s %-9s %-9s %-8s %-9s %s"
          % ("guid", "x", "y", "dbZ", "地面Z", "dbZ-地面", "可见下沉", "tile", "备注"))
    stats = []
    for guid, x, y, z, mtype in rows:
        path, name = load_tile(map_id, x, y)
        if not path:
            print("%-8d %-10.2f %-10.2f %-9.2f %-9s %-9s %-8s %-9s %s" % (guid, x, y, z, "-", "-", "-", name, "缺 mmtile"))
            continue
        polys, bmin, bmax, offmesh_base, poly_count = parse_tile(path)
        rx, rz = y, x                      # recast x = wow y, recast z = wow x
        cands = []
        for idx, pts, flags, area in polys:
            xs = [p[0] for p in pts]
            zs = [p[2] for p in pts]
            if not (min(xs) <= rx <= max(xs) and min(zs) <= rz <= max(zs)):
                continue
            if point_in_poly(rx, rz, [(p[0], p[2]) for p in pts]):
                cands.append((poly_height_at(rx, rz, pts), idx, flags, area))
        if not cands:
            print("%-8d %-10.2f %-10.2f %-9.2f %-9s %-9s %-8s %-9s %s" % (guid, x, y, z, "-", "-", "-", name, "该点无导航面"))
            continue
        # 取不高于刷点 Z 的最高面（即怪脚下的地面），没有则取最低面
        below = [c for c in cands if c[0] <= z + 0.25]
        pick = max(below) if below else min(cands)
        gh = pick[0]
        dz = z - gh
        visible = dz + MODEL_SINK
        stats.append((guid, dz, visible, gh, pick[2], pick[3], name))
        note = ""
        if dz < -0.5:
            note = "★刷点在导航面【下方】(埋进地面)"
        elif abs(dz) <= 0.6:
            note = "原点基本贴地"
        elif dz > 1.0:
            note = "原点浮在地面上方"
        print("%-8d %-10.2f %-10.2f %-9.2f %-9.3f %-9.3f %-8.3f %-9s %s"
              % (guid, x, y, z, gh, dz, visible, name, note))

    if stats:
        ds = sorted(s[1] for s in stats)
        vs = sorted(s[2] for s in stats)
        print("\n原点离地面 dz：min %.3f  中位 %.3f  max %.3f" % (ds[0], ds[len(ds) // 2], ds[-1]))
        print("叠加模型偏移后的可见下沉：min %.3f  中位 %.3f  max %.3f" % (vs[0], vs[len(vs) // 2], vs[-1]))
        print("dz<-0.5（埋进地面）的点数：%d / %d" % (sum(1 for s in stats if s[1] < -0.5), len(stats)))


if __name__ == "__main__":
    main()
