#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
以太鳐 22181「地面下沉」实测 / mmtile 解析库。

拿 creature 表里每个刷点的 DB position_z，跟该点所在 mmtile 的导航面高度对比，
算出「原点离地面多远」，再叠加模型偏移（NetherRay.mdx 下缘 -0.328 x 缩放 1.5 = -0.492 yd），
得到肉眼可见的下沉量。

本文件同时是 mmtile 解析库，被 check_go_bake.py 与 _agent_tmp/wp_scan.py import。

--- 2026-10-01 口径修正（两处 bug）---
1) mmtile 文件名必须把 mapId 零填充到 3 位。
   服务端：src/game/MotionGenerators/MoveMap.cpp:48
       constexpr char TILE_FILE_NAME_FORMAT[] = "mmaps/%03i%02i%02i.mmtile";
   调用点：MoveMap.cpp:250
       snprintf(fileName.get(), pathLen, (basePath + TILE_FILE_NAME_FORMAT).c_str(), mapId, x, y);
   两个 2 位域的来源：src/game/Chat/Level2.cpp:5141-5144
       int32 gy = 32 - GetPositionX() / SIZE_OF_GRIDS;   // 世界 X 在前
       int32 gx = 32 - GetPositionY() / SIZE_OF_GRIDS;   // 世界 Y 在后
       PSendSysMessage("%03u%02i%02i.mmtile", GetMapId(), gy, gx);
   生成器写文件处同样是零填充：contrib/mmap/src/MapBuilder.cpp:1225
       sprintf(fileName, "%s/mmaps/%03u%02i%02i.mmtile", m_workdir, mapID, tileY, tileX);
   旧代码用 "%u%02u%02u"（mapId 不填充），使 map 0/1/30/33/36/43/47/70/90 等
   mapId < 100 的地图全部找不到 mmtile，被误判成「该点无导航面」。

2) 取层不能再用 min/max 区间。
   旧 wp_scan.py 把落在该 (x,y) 的所有 poly 合成 [min, max]，只要 z 落进区间就算「贴地」，
   于是「悬在二层平台、而该 XZ 恰好还有一层高空平台」的点被漏掉。
   本文件改为 faces_at() + classify_z()：取离 z 最近的候选面，并把结果分为
   贴地 / 悬空 / 穿地 / 多层 / 无面 五档（见 classify_z 文档字符串）。
"""
import math
import os
import struct
import sys

MMAP_DIR = r"D:\Game\cmangos\x64_Debug\mmaps"
HERE = os.path.dirname(os.path.abspath(__file__))

MODEL_SINK = 0.492          # NetherRay.mdx: -GeoBox.minZ(0.328) * displayScale(1.5)

# 服务端/生成器一致的 mmtile 命名（mapId 零填充 3 位）
MMTILE_NAME_FORMAT = "%03u%02u%02u"

SIZE_OF_GRIDS = 533.33333

# dtPoly.areaAndType 高 2 位：0 = ground, 1 = offmesh connection
POLY_TYPE_OFFMESH = 1

# classify_z 的档位名（对外统一口径）
CLS_GROUND = "贴地"        # |z - 最近面| <= tol_ground
CLS_FLOATING = "悬空"      # z 高于该 XZ 所有候选面（下方无面）
CLS_SUNKEN = "穿地"        # z 低于该 XZ 所有候选面（上方有面）
CLS_MULTI = "多层"         # 该 XZ 有多个相距 > tol_layer 的面，且 z 夹在中间，需人工判断
CLS_NOFACE = "无面"        # 该 XZ 没有任何导航面
CLS_NOTILE = "缺tile"      # mmtile 文件本身不存在


def tile_indices(wow_x, wow_y):
    """世界坐标 -> mmtile 文件名里的两个 2 位域 (first, second)。

    依据 src/game/Chat/Level2.cpp:5141-5144：
        gy = 32 - world_x / 533.33   ← 文件名第 1 个 2 位域
        gx = 32 - world_y / 533.33   ← 文件名第 2 个 2 位域
    """
    first = int(32 - wow_x / SIZE_OF_GRIDS)
    second = int(32 - wow_y / SIZE_OF_GRIDS)
    return first, second


def tile_name(map_id, wow_x, wow_y):
    first, second = tile_indices(wow_x, wow_y)
    return MMTILE_NAME_FORMAT % (map_id, first, second)


def load_tile(map_id, wow_x, wow_y, mmap_dir=None):
    """按服务端命名规则找 mmtile；返回 (path|None, name)。

    mmap_dir 缺省用 MMAP_DIR（便于 cross-check 其它 mmaps 目录）。
    """
    d = mmap_dir or MMAP_DIR
    name = tile_name(map_id, wow_x, wow_y)
    p = os.path.join(d, name + ".mmtile")
    if os.path.exists(p):
        return p, name
    return None, name


def load_tile_by_index(map_id, first, second, mmap_dir=None):
    """直接按文件名的两个 2 位域取文件（给诊断用，不做任何顺序猜测）。"""
    d = mmap_dir or MMAP_DIR
    name = MMTILE_NAME_FORMAT % (map_id, first, second)
    p = os.path.join(d, name + ".mmtile")
    return (p if os.path.exists(p) else None), name


TILE_CACHE = {}


def parse_tile(path):
    """兼容旧调用方的入口：polys 元素仍是 (idx, pts, flags, area) 4 元组。"""
    polys, bmin, bmax, offmesh_base, poly_count = parse_tile_ex(path)
    return [p[:4] for p in polys], bmin, bmax, offmesh_base, poly_count


def parse_tile_ex(path):
    """完整解析 mmtile，polys 元素 = (idx, pts, flags, area, ptype)。

    ptype 取自 dtPoly.areaAndType 高 2 位（Generate navmesh 时 1 = offmesh connection）。
    返回 (polys, bmin, bmax, offMeshBase, polyCount)
    """
    if path in TILE_CACHE:
        return TILE_CACHE[path]
    with open(path, "rb") as f:
        data = f.read()
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
        # dtPoly: firstLink(u32) verts[6](u16) neis[6](u16) flags(u16) vertCount(u8) areaAndType(u8)
        rec = struct.unpack_from("<I6H6HHBB", data, poff + i * 32)
        vids = rec[1:7]
        vcount = rec[14]
        area_and_type = rec[15]
        area = area_and_type & 0x3F
        ptype = (area_and_type >> 6) & 0x3
        flags = rec[13]
        if vcount < 3:
            continue
        pts = [verts[v] for v in vids[:vcount]]
        polys.append((i, pts, flags, area, ptype))
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
    """平面拟合求 (px, ., pz) 处的高度；退化时用三点平均。（保留旧契约，见 poly_surface_at）"""
    return poly_surface_at(px, pz, pts3d)["h"]


def poly_surface_at(px, pz, pts3d, slack=0.5):
    """求导航面在 (px, pz) 处的表面高度，并对**退化多边形**做保护。

    背景（2026-10-01 实测）：recast 会产出退化/细长（sliver）多边形，其顶点近乎共线，
    u x v 的模非常小，法线的竖直分量 ny 也近乎 0。此时平面拟合 (…)/ny 会放大成
    ±1000~4800 码的荒谬高度，把「其实正好站在楼板上」的点判成「悬空几千码」。
    实测样例：map 530 guid 74317 pt2 z=265.61，多边形顶点 y 范围 [263.61, 267.08]（明显托得住
    该点），拟合高度却是 4811.72，|ny|/|n| = 0.003 ⇒ 上一版报告的「|dz|>300 疑似 XZ 错位」
    176 条基本都出自这里（详见 wp_scan_fixed/REPORT.md §1.3）。

    返回 dict：
      h          最终采用的高度 = 拟合值被 clamp 到 [y_min, y_max]
      fit        原始拟合值（保留用于诊断）
      y_min/y_max 多边形顶点的 y 范围
      degenerate True = 拟合值跑出顶点 y 范围（说明该多边形不可信）
      flat        |ny| / |n|，1.0 = 水平面、≈0 = 垂直/退化面
      area2       |u x v|（退化判定用）
    """
    n = len(pts3d)
    x1, y1, z1 = pts3d[0]
    # 用所有顶点的 y 范围作为物理约束
    ys = [p[1] for p in pts3d]
    y_min, y_max = min(ys), max(ys)
    # 用 Newell 法求法线（对非平面/退化多边形比取前三点更稳）
    nx = ny = nz = 0.0
    for i in range(n):
        ax, ay, az = pts3d[i]
        bx, by, bz = pts3d[(i + 1) % n]
        nx += (ay - by) * (az + bz)
        ny += (az - bz) * (ax + bx)
        nz += (ax - bx) * (ay + by)
    nlen = math.sqrt(nx * nx + ny * ny + nz * nz)
    flat = (abs(ny) / nlen) if nlen > 1e-12 else 0.0
    (ux, uy, uz) = (pts3d[1][0] - x1, pts3d[1][1] - y1, pts3d[1][2] - z1)
    (vx, vy, vz) = (pts3d[2][0] - x1, pts3d[2][1] - y1, pts3d[2][2] - z1)
    cx = uy * vz - uz * vy
    cy = uz * vx - ux * vz
    cz = ux * vy - uy * vx
    area2 = math.sqrt(cx * cx + cy * cy + cz * cz)
    if abs(ny) < 1e-9 or nlen < 1e-9:
        fit = sum(ys) / float(n)
    else:
        fit = (nx * (x1 - px) + nz * (z1 - pz)) / ny + y1
    h = fit
    degenerate = not (y_min - slack <= fit <= y_max + slack)
    if degenerate:
        h = min(max(fit, y_min), y_max)
    return dict(h=h, fit=fit, y_min=y_min, y_max=y_max, degenerate=degenerate,
                flat=flat, area2=area2)


# --------------------------------------------------------------------------
# 口径修正 2：按「离该点最近的面」比较，而不是 min/max 区间
# --------------------------------------------------------------------------
TILE_INDEX_CACHE = {}
BUCKET = 32.0          # 加速用空间网格边长（码）
MAX_POLY_CELLS = 256   # 单个面跨越的格子数超过它就丢进 oversized 列表（每查询都过一遍）


def _tile_index(path):
    """给一个 tile 建 (rx, rz) 平面的 32 码网格索引；纯加速，不改变判定语义。"""
    if path in TILE_INDEX_CACHE:
        return TILE_INDEX_CACHE[path]
    polys, _bmin, _bmax, _ob, _pc = parse_tile_ex(path)
    grid = {}
    oversized = []
    for k, (idx, pts, flags, area, ptype) in enumerate(polys):
        xs = [p[0] for p in pts]
        zs = [p[2] for p in pts]
        ix0, ix1 = int(min(xs) // BUCKET), int(max(xs) // BUCKET)
        iz0, iz1 = int(min(zs) // BUCKET), int(max(zs) // BUCKET)
        if (ix1 - ix0 + 1) * (iz1 - iz0 + 1) > MAX_POLY_CELLS:
            oversized.append(k)
            continue
        for ix in range(ix0, ix1 + 1):
            for iz in range(iz0, iz1 + 1):
                grid.setdefault((ix, iz), []).append(k)
    TILE_INDEX_CACHE[path] = (polys, grid, oversized)
    return TILE_INDEX_CACHE[path]


def faces_at(map_id, wow_x, wow_y, mmap_dir=None, include_offmesh=False, use_index=True):
    """返回该世界点 (x, y) 处所有覆盖它的导航面的高度。

    坐标变换依据 src/game/MotionGenerators/PathFinder.cpp:465
        float startPoint[VERTEX_SIZE] = {startPos.y, startPos.z, startPos.x};
    ⇒ recast 的 (x, z) 直接等于游戏的 (y, x)。

    返回 (faces, name, status)：
        faces  = [dict(h=高度, idx=多边形下标, flags=, area=, ptype=, offmesh=bool), ...]
        status = None 表示成功；否则是 CLS_NOTILE
    include_offmesh=False 时剔除 dtPolyType=OFFMESH_CONNECTION 的「连接面」（不是地板）。
    use_index=True 时用 32 码网格剪枝（语义与暴力扫描一致，回归脚本里有两者对拍）。
    """
    path, name = load_tile(map_id, wow_x, wow_y, mmap_dir)
    if not path:
        return None, name, CLS_NOTILE
    rx, rz = wow_y, wow_x                      # recast x = wow y, recast z = wow x
    if use_index:
        polys, grid, oversized = _tile_index(path)
        cand = grid.get((int(rx // BUCKET), int(rz // BUCKET)), [])
        if oversized:
            cand = list(cand) + oversized
    else:
        polys, _bmin, _bmax, _ob, _pc = parse_tile_ex(path)
        cand = range(len(polys))
    faces = []
    for k in cand:
        idx, pts, flags, area, ptype = polys[k]
        offmesh = (ptype == POLY_TYPE_OFFMESH)
        if offmesh and not include_offmesh:
            continue
        xs = [p[0] for p in pts]
        zs = [p[2] for p in pts]
        if not (min(xs) <= rx <= max(xs) and min(zs) <= rz <= max(zs)):
            continue
        if point_in_poly(rx, rz, [(p[0], p[2]) for p in pts]):
            s = poly_surface_at(rx, rz, pts)
            faces.append(dict(h=s["h"], fit=s["fit"], degenerate=s["degenerate"],
                              flat=s["flat"], area2=s["area2"],
                              idx=idx, flags=flags, area=area, ptype=ptype, offmesh=offmesh))
    faces.sort(key=lambda f: f["h"])
    return faces, name, None


def nearest_face(z, faces):
    """离 z 最近的候选面（并列时取更低的那个）。"""
    if not faces:
        return None
    return min(faces, key=lambda f: (abs(f["h"] - z), f["h"]))


def count_layers(faces, tol=2.0):
    """把面高度按 > tol 的间隙聚成层，返回层数与层高列表（升序）。"""
    if not faces:
        return 0, []
    hs = sorted(f["h"] for f in faces)
    layers = [hs[0]]
    for h in hs[1:]:
        if h - layers[-1] > tol:
            layers.append(h)
    return len(layers), layers


def classify_z(z, faces, tol_ground=2.0, tol_layer=2.0):
    """五档分类（口径修正 2 的核心）。

    判据（faces 为该 XZ 覆盖点的全部候选面）：
      · 无面   ：候选面为空
      · 贴地   ：|z - 最近面| <= tol_ground
      · 多层   ：该 XZ 有 >= 2 个相距 > tol_layer 的面（层），需人工判断
                 —— 此时**不**再断言悬空/穿地，只在 sub 里标注 z 相对层的位置
      · 悬空   ：只有 1 层，且 z > 该层 + tol_ground（下方无面）
      · 穿地   ：只有 1 层，且 z < 该层 - tol_ground（上方有面）

    多层优先于悬空/穿地，因为一列里有多层楼板时，「点错了」和「导航面缺了一层楼板」
    在 mmaps 单路证据下不可区分（实例：map 554 guid 5540059 pt2，vmap 实测该 XZ 有真实
    WMO 楼板 z≈0.027，而 mmtile 在该列只烘焙了 12.86/15.55/88.38 三层）。

    返回 dict：cls, sub, dz_near, h_near, h_lo, h_hi, dz_span, layers, layer_hs, n_faces,
              has_face_below, has_face_above
      sub     = on / above_all / below_all / between / none（z 相对层的位置）
      dz_near = z - 最近面高度            （主判据）
      dz_span = z 相对 [h_lo, h_hi] 的偏差（旧 min/max 口径，仅留作对照；在区间内为 0）

    旧 min/max 口径（z 落进 [h_lo, h_hi] 就算贴地）等价于只看 dz_span；本次扫描同时输出
    dz_span 以便与上一版结果逐条对比。
    """
    n = len(faces or ())
    out = dict(cls=None, sub="none", dz_near=None, h_near=None, h_lo=None, h_hi=None,
               dz_span=None, layers=0, layer_hs=[], n_faces=n,
               n_degenerate=0, near_degenerate=False,
               has_face_below=False, has_face_above=False)
    if n == 0:
        out["cls"] = CLS_NOFACE
        return out
    out["n_degenerate"] = sum(1 for f in faces if f.get("degenerate"))
    h_lo = min(f["h"] for f in faces)
    h_hi = max(f["h"] for f in faces)
    nf = nearest_face(z, faces)
    h_near = nf["h"]
    out["near_degenerate"] = bool(nf.get("degenerate"))
    dz_near = z - h_near
    layers, layer_hs = count_layers(faces, tol_layer)
    out.update(h_lo=h_lo, h_hi=h_hi, h_near=h_near, dz_near=dz_near,
               layers=layers, layer_hs=layer_hs,
               has_face_below=any(f["h"] <= z + tol_ground for f in faces),
               has_face_above=any(f["h"] >= z - tol_ground for f in faces))
    out["dz_span"] = z - h_hi if z > h_hi else (z - h_lo if z < h_lo else 0.0)
    if z > h_hi + tol_ground:
        out["sub"] = "above_all"
    elif z < h_lo - tol_ground:
        out["sub"] = "below_all"
    else:
        out["sub"] = "between"
    if abs(dz_near) <= tol_ground:
        out["cls"] = CLS_GROUND
        out["sub"] = "on"
    elif layers >= 2:
        out["cls"] = CLS_MULTI
    elif z > h_hi + tol_ground:
        out["cls"] = CLS_FLOATING
    else:
        out["cls"] = CLS_SUNKEN
    return out


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
    print("%-8s %-10s %-10s %-9s %-9s %-9s %-8s %-9s %-8s %s"
          % ("guid", "x", "y", "dbZ", "最近面Z", "dbZ-最近面", "可见下沉", "档位", "tile", "备注"))
    stats = []
    for guid, x, y, z, mtype in rows:
        faces, name, status = faces_at(map_id, x, y)
        if status:
            print("%-8d %-10.2f %-10.2f %-9.2f %-9s %-9s %-8s %-9s %-8s %s"
                  % (guid, x, y, z, "-", "-", "-", CLS_NOTILE, name, "缺 mmtile"))
            continue
        r = classify_z(z, faces)
        if r["cls"] == CLS_NOFACE:
            print("%-8d %-10.2f %-10.2f %-9.2f %-9s %-9s %-8s %-9s %-8s %s"
                  % (guid, x, y, z, "-", "-", "-", CLS_NOFACE, name, "该点无导航面"))
            continue
        dz = r["dz_near"]
        visible = dz + MODEL_SINK
        stats.append((guid, dz, visible, r["h_near"], r["cls"], name))
        note = ""
        if r["cls"] == CLS_GROUND:
            note = "原点基本贴地"
        elif r["cls"] == CLS_FLOATING:
            note = "★该 XZ 下方无面（悬空）"
        elif r["cls"] == CLS_SUNKEN:
            note = "★该 XZ 上方有面、脚下无面（穿地）"
        elif r["cls"] == CLS_MULTI:
            note = "多层地形（%d 层：%s），需人工判断" % (
                r["layers"], "/".join("%.2f" % h for h in r["layer_hs"]))
        print("%-8d %-10.2f %-10.2f %-9.2f %-9.3f %-9.3f %-8.3f %-9s %-8s %s"
              % (guid, x, y, z, r["h_near"], dz, visible, r["cls"], name, note))

    if stats:
        ds = sorted(s[1] for s in stats)
        vs = sorted(s[2] for s in stats)
        print("\n最近面 dz：min %.3f  中位 %.3f  max %.3f" % (ds[0], ds[len(ds) // 2], ds[-1]))
        print("叠加模型偏移后的可见下沉：min %.3f  中位 %.3f  max %.3f" % (vs[0], vs[len(vs) // 2], vs[-1]))
        print("档位分布：%s" % ", ".join(
            "%s=%d" % (c, sum(1 for s in stats if s[4] == c))
            for c in (CLS_GROUND, CLS_FLOATING, CLS_SUNKEN, CLS_MULTI)))


if __name__ == "__main__":
    main()
