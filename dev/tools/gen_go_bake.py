#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 MoveMapGen --gameObjectInput 的输入文件：把库里的 gameobject 刷点按
"模型 + 变换" 列出来，让导航网格把 GO 碰撞当静态几何烘进去。

流程：
  1. 读 _agent_tmp/go_spawns.tsv（gameobject JOIN gameobject_template，已导出）
  2. displayId -> GameObjectDisplayInfo.dbc -> 模型路径（World\\Goober\\G_Cage02.mdx）
     -> vmaps 里的模型文件名（去路径 + .mdx/.m2 -> .m2 + ".vmo"）
  3. 只保留 vmaps 里**真有碰撞几何**的模型（文件存在）
  4. 旋转：优先用 rotation0..3 四元数 -> 欧拉角；为 0 时退回 orientation（弧度, Z 轴）
  5. 输出 `<model> <mapId> <x> <y> <z> <rotXdeg> <rotYdeg> <rotZdeg> <scale>`

用法: python gen_go_bake.py [outfile] [onlyMap|-]
"""
import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DBC = r"D:\Game\cmangos\x64_Debug\dbc\GameObjectDisplayInfo.dbc"
VMAPS = r"D:\Game\cmangos\x64_Debug\vmaps"

outfile = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "go_bake.txt")
only_map = sys.argv[2] if len(sys.argv) > 2 else "-"


def load_display_info():
    d = open(DBC, "rb").read()
    magic, recs, fields, rsize, ssize = struct.unpack_from("<4sIIII", d, 0)
    assert magic == b"WDBC"
    soff = 20 + recs * rsize
    strs = d[soff:soff + ssize]

    def get(off):
        if off == 0:
            return ""
        end = strs.find(b"\x00", off)
        return strs[off:end].decode("utf-8", "replace")

    out = {}
    for i in range(recs):
        r = struct.unpack_from("<%dI" % fields, d, 20 + i * rsize)
        out[r[0]] = get(r[1])
    return out


def vmap_model_name(model_path):
    """World\\Goober\\G_Cage02.mdx -> G_Cage02.m2.vmo（在 vmaps 里真实存在的那个名字）"""
    base = model_path.replace("/", "\\").split("\\")[-1]
    low = base.lower()
    for ext in (".mdx", ".mdl", ".m2", ".wmo"):
        if low.endswith(ext):
            base = base[: -len(ext)]
            kind = ".wmo" if ext == ".wmo" else ".m2"
            return base + kind + ".vmo"
    return base + ".vmo"


def quat_to_euler_deg(qx, qy, qz, qw):
    """四元数 -> 欧拉角(度)，采用 ZYX 顺序，返回 (rotX, rotY, rotZ) 与 vmap 里 iRot 同义"""
    n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    if n == 0:
        return None
    qx, qy, qz, qw = qx / n, qy / n, qz / n, qw / n
    # roll (x), pitch (y), yaw (z)
    sinr = 2.0 * (qw * qx + qy * qz)
    cosr = 1.0 - 2.0 * (qx * qx + qy * qy)
    roll = math.atan2(sinr, cosr)
    sinp = 2.0 * (qw * qy - qz * qx)
    pitch = math.copysign(math.pi / 2, sinp) if abs(sinp) >= 1 else math.asin(sinp)
    siny = 2.0 * (qw * qz + qx * qy)
    cosy = 1.0 - 2.0 * (qy * qy + qz * qz)
    yaw = math.atan2(siny, cosy)
    return (math.degrees(roll), math.degrees(pitch), math.degrees(yaw))


def main():
    displays = load_display_info()
    files = {f.lower(): f for f in os.listdir(VMAPS)}

    total = kept = no_display = no_model = no_geometry = 0
    per_map = {}
    lines = []

    with open(os.path.join(HERE, "go_spawns.tsv"), encoding="ascii") as f:
        f.readline()
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) < 11:
                continue
            total += 1
            mapid = int(p[0])
            if only_map != "-" and mapid != int(only_map):
                continue
            x, y, z = float(p[1]), float(p[2]), float(p[3])
            ori = float(p[4])
            q = [float(p[5]), float(p[6]), float(p[7]), float(p[8])]
            did = int(p[9])
            size = float(p[10])

            model_path = displays.get(did)
            if not model_path:
                no_display += 1
                continue
            name = vmap_model_name(model_path)
            real = files.get(name.lower())
            if not real:
                no_model += 1
                continue

            if any(abs(v) > 1e-6 for v in q):
                rot = quat_to_euler_deg(q[0], q[1], q[2], q[3])
                if rot is None:
                    rot = (0.0, 0.0, math.degrees(ori))
            else:
                rot = (0.0, 0.0, math.degrees(ori))
            if size <= 0:
                size = 1.0

            lines.append("%s %u %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n"
                         % (real, mapid, x, y, z, rot[0], rot[1], rot[2], size))
            kept += 1
            per_map[mapid] = per_map.get(mapid, 0) + 1

    with open(outfile, "w", encoding="utf-8", newline="\n") as f:
        f.write("# gameobject collision baked into the navmesh: model mapId x y z rotX rotY rotZ scale\n")
        f.writelines(lines)

    print("GO 刷点 %d 个 -> 写出 %d 行" % (total, kept))
    print("  跳过：displayId 无模型 %d、模型不在 vmaps %d" % (no_display, no_model))
    print("  文件: %s" % outfile)
    top = sorted(per_map.items(), key=lambda kv: -kv[1])[:8]
    print("  刷点最多的地图: %s" % ", ".join("map%d=%d" % kv for kv in top))
    if only_map != "-":
        print("  （只导出了 map %s）" % only_map)


if __name__ == "__main__":
    main()
