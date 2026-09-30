#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
验证 GO 烘焙：在世界坐标点处查导航面。
坐标约定（实测校准 2026-09-30）：
  · mmtile 文件名 = <map><tileY><tileX>，其中 tileY = 32 - floor(world_x/533.33)、
    tileX = 32 - floor(world_y/533.33)
  · mmtile 里的顶点空间 = (world_y, 高度, world_x)  —— 与生成器的 mesh 空间一致
用法: python check_go_bake.py <mapId> <x> <y> <z> <dirA> [dirB]
"""
import math
import os
import sys
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("rgp", os.path.join(HERE, "ray_ground_probe.py"))
rgp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rgp)

map_id = int(sys.argv[1])
x, y, z = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
dirs = sys.argv[5:]

ty = int(32 - x / 533.33333)
tx = int(32 - y / 533.33333)
name = "%u%02u%02u.mmtile" % (map_id, ty, tx)
print("世界点 (%.2f, %.2f, %.2f) → 文件 %s；查询空间 (%.2f, %.2f) = (world_y, world_x)"
      % (x, y, z, name, y, x))

for d in dirs:
    p = os.path.join(d, name)
    if not os.path.exists(p):
        print("  %-52s 文件不存在" % d)
        continue
    polys, bmin, bmax, offmesh, poly_count = rgp.parse_tile(p)
    rx, rz = y, x                       # (world_y, world_x)
    hits = []
    near = []
    for idx, pts, flags, area in polys:
        xs = [p2[0] for p2 in pts]
        zs = [p2[2] for p2 in pts]
        cx = sum(xs) / len(xs); cz = sum(zs) / len(zs)
        dist = math.hypot(cx - rx, cz - rz)
        if dist < 8.0:
            near.append((dist, rgp.poly_height_at(rx, rz, pts) if (min(xs) <= rx <= max(xs) and min(zs) <= rz <= max(zs)) else None, idx))
        if not (min(xs) <= rx <= max(xs) and min(zs) <= rz <= max(zs)):
            continue
        if rgp.point_in_poly(rx, rz, [(p2[0], p2[2]) for p2 in pts]):
            hits.append((idx, rgp.poly_height_at(rx, rz, pts), flags, area))
    print("  %-52s 文件大小=%7d 多边形=%4d 命中该点=%d %s"
          % (os.path.basename(d), os.path.getsize(p), poly_count, len(hits),
             ("高度=" + ", ".join("%.3f" % h for _, h, _, _ in hits)) if hits else ""))
    if near:
        near.sort()
        print("      8 码内的相邻面：%s" % ", ".join("idx%d/%.1f码%s" % (i, dd, "" if hh is None else "/h%.2f" % hh) for dd, hh, i in near[:6]))
