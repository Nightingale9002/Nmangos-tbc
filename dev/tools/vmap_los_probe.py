#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VMAP LOS 探针：直接在 vmap 数据上算「两点之间有没有碰撞面」（等价服务端 Map::IsInLineOfSight）。

用法:
  python vmap_los_probe.py spawns <mapId>                      # 打印 <map>.vmtree 的模型 spawn 列表
  python vmap_los_probe.py ray <mapId> x1 y1 z1 x2 y2 z2       # 沿连线做 3D 射线求交

实现依据（src/game/vmap/）：
  MapTree.cpp   StaticMapTree::InitMap  -> magic(8) + tiled(1) + "NODE" + BIH + (non-tiled: ModelSpawn 列表到 EOF)
  BIH.cpp       readFromFile            -> lo(3f) hi(3f) treeSize(u32) tree[] count(u32) objects[]
  ModelInstance.cpp ModelSpawn::readFromFile -> flags(u32) adtId(u16) ID(u32) pos(3f) rot(3f) scale(f)
                                              [bound(6f) 仅当 flags & 0x4] nameLen(u32) name
  ModelInstance.cpp intersectRay        -> pLocal = iInvRot * (pWorld - iPos) / scale, dirLocal = iInvRot * dir
  WorldModel.cpp    IntersectRay        -> ignoreM2Model 为真时，flags & MOD_M2 的模型整体跳过
"""
import math
import os
import struct
import sys

VMAP_DIR = sys.argv[-1] if os.path.isdir(sys.argv[-1]) else r"D:\Game\cmangos\x64_Debug\vmaps"

MOD_M2 = 0x1
MOD_WORLDSPAWN = 0x2
MOD_HAS_BOUND = 0x4


def read_spawns(map_id):
    path = os.path.join(VMAP_DIR, "%03u.vmtree" % map_id)
    d = open(path, "rb").read()
    off = 0
    assert d[:8] == b"VMAP_7.0", d[:8]
    off = 8
    tiled = d[off]; off += 1
    assert d[off:off + 4] == b"NODE", d[off:off + 4]
    off += 4
    # BIH
    lo = struct.unpack_from("<3f", d, off); off += 12
    hi = struct.unpack_from("<3f", d, off); off += 12
    tree_size = struct.unpack_from("<I", d, off)[0]; off += 4 + 4 * tree_size
    count = struct.unpack_from("<I", d, off)[0]; off += 4 + 4 * count
    assert d[off:off + 4] == b"GOBJ", d[off:off + 4]
    off += 4
    spawns = []
    total = len(d)
    while off + 50 < total:
        flags = struct.unpack_from("<I", d, off)[0]; off += 4
        adt_id = struct.unpack_from("<H", d, off)[0]; off += 2
        mid = struct.unpack_from("<I", d, off)[0]; off += 4
        pos = struct.unpack_from("<3f", d, off); off += 12
        rot = struct.unpack_from("<3f", d, off); off += 12
        scale = struct.unpack_from("<f", d, off)[0]; off += 4
        bound = None
        if flags & MOD_HAS_BOUND:
            bound = struct.unpack_from("<6f", d, off); off += 24
        name_len = struct.unpack_from("<I", d, off)[0]; off += 4
        name = d[off:off + name_len].decode("ascii", "replace").rstrip("\x00"); off += name_len
        ref = struct.unpack_from("<I", d, off)[0]; off += 4
        spawns.append(dict(flags=flags, adt=adt_id, id=mid, pos=pos, rot=rot, scale=scale,
                           bound=bound, name=name, ref=ref))
    return path, tiled, (lo, hi), spawns


def euler_zyx(z_deg, y_deg, x_deg):
    """G3D Matrix3::fromEulerAnglesZYX(z, y, x) 的行主序 3x3（用 v * M 左乘行向量）。"""
    z, y, x = (math.radians(z_deg), math.radians(y_deg), math.radians(x_deg))
    cz, sz = math.cos(z), math.sin(z)
    cy, sy = math.cos(y), math.sin(y)
    cx, sx = math.cos(x), math.sin(x)
    # G3D: M = Rz * Ry * Rx （行向量约定下同标准列向量转置）
    rz = [[cz, sz, 0.0], [-sz, cz, 0.0], [0.0, 0.0, 1.0]]
    ry = [[cy, 0.0, -sy], [0.0, 1.0, 0.0], [sy, 0.0, cy]]
    rx = [[1.0, 0.0, 0.0], [0.0, cx, sx], [0.0, -sx, cx]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(rz, ry), rx)


def vmul(v, m):
    return (v[0] * m[0][0] + v[1] * m[1][0] + v[2] * m[2][0],
            v[0] * m[0][1] + v[1] * m[1][1] + v[2] * m[2][1],
            v[0] * m[0][2] + v[1] * m[1][2] + v[2] * m[2][2])


def inv_rot_matrix(rot):
    """iInvRot = fromEulerAnglesZYX(pi*rot.y, pi*rot.x, pi*rot.z).inverse()"""
    m = euler_zyx(rot[1], rot[0], rot[2])
    return [[m[j][i] for j in range(3)] for i in range(3)]


MESH_CACHE = {}


def load_mesh(name):
    if name in MESH_CACHE:
        return MESH_CACHE[name]
    path = os.path.join(VMAP_DIR, name + ".vmo")
    if not os.path.exists(path):
        path = os.path.join(VMAP_DIR, name)
    groups = []
    try:
        d = open(path, "rb").read()
    except OSError:
        MESH_CACHE[name] = groups
        return groups
    off = 8
    assert d[off:off + 4] == b"WMOD", (name, d[off:off + 4])
    off += 4 + 8                                   # chunkSize + RootWMOID
    if d[off:off + 4] != b"GMOD":
        MESH_CACHE[name] = groups
        return groups
    off += 4
    n = struct.unpack_from("<I", d, off)[0]; off += 4
    for _ in range(n):
        # GroupModel::readFromFile: AABox(6f) + mogpFlags(u32) + groupWMOID(u32)
        off += 24 + 4 + 4
        verts, tris = [], []
        for _seg in range(5):
            tag = d[off:off + 4]; off += 4
            if tag == b"VERT":
                _size, cnt = struct.unpack_from("<II", d, off); off += 8
                verts = [struct.unpack_from("<3f", d, off + i * 12) for i in range(cnt)]
                off += 12 * cnt
            elif tag == b"TRIM":
                _size, cnt = struct.unpack_from("<II", d, off); off += 8
                tris = [struct.unpack_from("<3I", d, off + i * 12) for i in range(cnt)]
                off += 12 * cnt
            elif tag == b"MBIH":
                off += 24
                ts = struct.unpack_from("<I", d, off)[0]; off += 4 + 4 * ts
                c2 = struct.unpack_from("<I", d, off)[0]; off += 4 + 4 * c2
            elif tag == b"LIQU":
                size = struct.unpack_from("<I", d, off)[0]; off += 4 + size
                break
            else:
                break
        if verts and tris:
            groups.append((verts, tris))
    MESH_CACHE[name] = groups
    return groups


def aabb_hit(lo, hi, p0, d, tmax):
    t0, t1 = 0.0, tmax
    for i in range(3):
        if abs(d[i]) < 1e-12:
            if p0[i] < lo[i] or p0[i] > hi[i]:
                return False
        else:
            ta = (lo[i] - p0[i]) / d[i]
            tb = (hi[i] - p0[i]) / d[i]
            if ta > tb:
                ta, tb = tb, ta
            t0 = max(t0, ta)
            t1 = min(t1, tb)
            if t0 > t1:
                return False
    return True


def ray_tri(p0, d, a, b, c):
    e1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    e2 = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    pv = (d[1] * e2[2] - d[2] * e2[1], d[2] * e2[0] - d[0] * e2[2], d[0] * e2[1] - d[1] * e2[0])
    det = e1[0] * pv[0] + e1[1] * pv[1] + e1[2] * pv[2]
    if -1e-9 < det < 1e-9:
        return None
    inv = 1.0 / det
    tv = (p0[0] - a[0], p0[1] - a[1], p0[2] - a[2])
    u = (tv[0] * pv[0] + tv[1] * pv[1] + tv[2] * pv[2]) * inv
    if u < -1e-6 or u > 1 + 1e-6:
        return None
    qv = (tv[1] * e1[2] - tv[2] * e1[1], tv[2] * e1[0] - tv[0] * e1[2], tv[0] * e1[1] - tv[1] * e1[0])
    v = (d[0] * qv[0] + d[1] * qv[1] + d[2] * qv[2]) * inv
    if v < -1e-6 or u + v > 1 + 1e-6:
        return None
    t = (e2[0] * qv[0] + e2[1] * qv[1] + e2[2] * qv[2]) * inv
    if t < 1e-4:
        return None
    return t


def trace(map_id, p0, p1, ignore_m2, verbose=False):
    _path, _tiled, _bounds, spawns = read_spawns(map_id)
    d = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
    length = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2)
    nd = (d[0] / length, d[1] / length, d[2] / length)
    hits = []
    for sp in spawns:
        if ignore_m2 and (sp["flags"] & MOD_M2):
            continue
        inv_rot = inv_rot_matrix(sp["rot"])
        scale = sp["scale"] or 1.0
        loc0 = vmul((p0[0] - sp["pos"][0], p0[1] - sp["pos"][1], p0[2] - sp["pos"][2]), inv_rot)
        loc0 = (loc0[0] / scale, loc0[1] / scale, loc0[2] / scale)
        locd = vmul(nd, inv_rot)
        for verts, tris in load_mesh(sp["name"]):
            xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
            # 世界尺度下的粗略 bbox 预筛（局部 bbox 按 scale 放大）
            r = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)) * scale
            cx = (max(xs) + min(xs)) / 2 * scale; cy = (max(ys) + min(ys)) / 2 * scale; cz = (max(zs) + min(zs)) / 2 * scale
            wc = (sp["pos"][0] + cx, sp["pos"][1] + cy, sp["pos"][2] + cz)
            mid = (p0[0] + d[0] / 2, p0[1] + d[1] / 2, p0[2] + d[2] / 2)
            if math.dist(mid, wc) > (length / 2 + r * 1.8):
                continue
            for tri in tris:
                a = verts[tri[0]]; b = verts[tri[1]]; c = verts[tri[2]]
                t = ray_tri(loc0, locd, a, b, c)
                if t is not None:
                    hits.append((t * scale / length, sp["name"], sp["flags"], sp["pos"], tri))
    hits.sort(key=lambda h: h[0])
    return length, hits


def to_internal(x, y, z):
    """VMapManager2::convertPositionToInternalRep: mid = 0.5*64*533.33333 = 17066.667"""
    mid = 0.5 * 64.0 * 533.33333333
    return (mid - x, mid - y, z)


def main():
    mode = sys.argv[1]
    map_id = int(sys.argv[2])
    if mode == "spawns":
        path, tiled, bounds, spawns = read_spawns(map_id)
        print("%s  tiled=%d  BIH bounds=%s" % (path, tiled, bounds))
        print("spawn 数 = %d" % len(spawns))
        for sp in spawns[:12]:
            print("flags=0x%-3X %s id=%-6d pos=(%.2f, %.2f, %.2f) rot=(%.2f, %.2f, %.2f) scale=%.3f name=%s"
                  % (sp["flags"], "M2 " if sp["flags"] & MOD_M2 else "WMO",
                     sp["id"], sp["pos"][0], sp["pos"][1], sp["pos"][2],
                     sp["rot"][0], sp["rot"][1], sp["rot"][2], sp["scale"], sp["name"]))
        print("模型文件示例:", ", ".join(sorted({sp['name'] for sp in spawns})[:5]))
        return
    p0g = tuple(float(v) for v in sys.argv[3:6])
    p1g = tuple(float(v) for v in sys.argv[6:9])
    eye = float(sys.argv[9]) if len(sys.argv) > 9 else 0.0
    eye2 = float(sys.argv[10]) if len(sys.argv) > 10 else eye
    p0 = to_internal(p0g[0], p0g[1], p0g[2] + eye)
    p1 = to_internal(p1g[0], p1g[1], p1g[2] + eye2)
    print("gamespace P0=(%.3f, %.3f, %.3f) P1=(%.3f, %.3f, %.3f)  eyeSrc=%.2f eyeDst=%.2f"
          % (p0g[0], p0g[1], p0g[2], p1g[0], p1g[1], p1g[2], eye, eye2))
    print("internal  P0=(%.2f, %.2f, %.2f) P1=(%.2f, %.2f, %.2f)" % (p0 + p1))
    for ignore_m2 in (False, True):
        length, hits = trace(map_id, p0, p1, ignore_m2)
        tag = "ignoreM2Model=TRUE (spells / melee / most gameplay checks)" if ignore_m2 \
            else "ignoreM2Model=FALSE (.los command 'Normal' column)"
        print("\n[%s]  dist=%.2f yd  hits=%d" % (tag, length, len(hits)))
        for t, name, flags, pos, tri in hits[:6]:
            hp = tuple(p0[i] + (p1[i] - p0[i]) * t for i in range(3))
            gp = (17066.66666667 - hp[0], 17066.66666667 - hp[1], hp[2])
            print("   t=%.3f  internal(%.2f, %.2f, %.2f) game(%.2f, %.2f, %.2f)  flags=0x%X %s  model=%s  tri=%s"
                  % (t, hp[0], hp[1], hp[2], gp[0], gp[1], gp[2], flags,
                     "M2" if flags & MOD_M2 else "WMO", name, tri))


if __name__ == "__main__":
    main()
