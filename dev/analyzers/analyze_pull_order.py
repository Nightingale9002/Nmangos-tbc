#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""analyze_pull_order.py —— 根据拉怪日志分析副本拉怪波次顺序。

站长口径（2026-10-18）：
  "拉怪的顺序和结果也落到日志 …… 根据拉怪日志分析副本拉怪波次顺序。"

数据来源（两种都支持）：
  1) CSV（推荐：云端只做原始导出，分析一律在本地跑，符合 P0 数据库铁律）：
       mysql -N -e "SELECT map,instance_id,seq,ord,target_entry,started_at,duration_s,result,mobs_total,mobs_alive,deaths
                    FROM ai_playerbot_pull_log ORDER BY map,instance_id,seq" > pulls.tsv
     （默认按 TAB 分隔；也支持逗号）
  2) 本地库直连：--mysql-host/--mysql-user/--mysql-db（只跑一条 SELECT，不做聚合）

分析内容：
  * 每个 (map, instance_id) 的**实际拉怪顺序**（按 seq）：ord / 目标 / 结果 / 用时 / 剩余 / 死亡
  * 与路线表顺序对比（--route-csv：SELECT map,ord,COUNT(*) FROM ai_playerbot_dungeon_route WHERE ord>0 GROUP BY map,ord）：
      - 实际顺序是否"ord 单调递增"（不递增 = 引擎跳波/回头打）
      - 哪些 ord 从来没被拉过（漏波 / 被跳过）
      - 同一 ord 被拉了几次（一波没打完又拉）
  * 单图汇总：平均每轮拉几次、完成率（cleared/全部）、平均用时、平均死亡

用法：
  python dev/analyzers/analyze_pull_order.py --csv pulls.tsv
  python dev/analyzers/analyze_pull_order.py --csv pulls.tsv --map 556 --instance 12
  python dev/analyzers/analyze_pull_order.py --csv pulls.tsv --route-csv route.tsv --json out.json
"""

import argparse
import sys
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import csv
import json
import os
import subprocess
import sys
from collections import OrderedDict, defaultdict

COLS = ["map", "instance_id", "seq", "ord", "target_entry", "started_at",
        "duration_s", "result", "mobs_total", "mobs_alive", "deaths"]


def load_rows(args):
    rows = []
    if args.csv:
        with open(args.csv, "r", encoding="utf-8", errors="replace", newline="") as fh:
            sample = fh.read(4096)
            fh.seek(0)
            delim = "\t" if sample.count("\t") >= sample.count(",") else ","
            reader = csv.reader(fh, delimiter=delim)
            for rec in reader:
                if not rec or len(rec) < 8:
                    continue
                if rec[0].strip().lower() == "map":     # header
                    continue
                try:
                    rows.append(dict(
                        map=int(rec[0]), instance_id=int(rec[1]), seq=int(rec[2]), ord=int(rec[3]),
                        target_entry=int(rec[4]), started_at=int(float(rec[5])),
                        duration_s=int(float(rec[6])), result=rec[7].strip(),
                        mobs_total=int(float(rec[8])) if len(rec) > 8 and rec[8] else 0,
                        mobs_alive=int(float(rec[9])) if len(rec) > 9 and rec[9] else 0,
                        deaths=int(float(rec[10])) if len(rec) > 10 and rec[10] else 0,
                    ))
                except (ValueError, IndexError):
                    continue
        return rows

    if args.mysql_db:
        sql = ("SELECT map,instance_id,seq,ord,target_entry,started_at,duration_s,result,"
               "mobs_total,mobs_alive,deaths FROM ai_playerbot_pull_log "
               "ORDER BY map,instance_id,seq")
        cmd = ["mysql", "-N", "-B", "-h", args.mysql_host, "-u", args.mysql_user,
               "-p" + args.mysql_password, args.mysql_db, "-e", sql]
        out = subprocess.run(cmd, capture_output=True, text=True)
        if out.returncode != 0:
            sys.exit("mysql 查询失败：%s" % out.stderr.strip()[:300])
        args.csv = None
        for line in out.stdout.splitlines():
            rec = line.split("\t")
            if len(rec) < 8:
                continue
            rows.append(dict(map=int(rec[0]), instance_id=int(rec[1]), seq=int(rec[2]),
                             ord=int(rec[3]), target_entry=int(rec[4]),
                             started_at=int(float(rec[5])), duration_s=int(float(rec[6])),
                             result=rec[7].strip(),
                             mobs_total=int(rec[8]) if len(rec) > 8 else 0,
                             mobs_alive=int(rec[9]) if len(rec) > 9 else 0,
                             deaths=int(rec[10]) if len(rec) > 10 else 0))
        return rows

    sys.exit("需要 --csv 或 --mysql-db")


def load_route(path):
    """map -> [ord...]（升序）"""
    res = defaultdict(list)
    if not path:
        return res
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
        sample = fh.read(4096)
        fh.seek(0)
        delim = "\t" if sample.count("\t") >= sample.count(",") else ","
        for rec in csv.reader(fh, delimiter=delim):
            if not rec or len(rec) < 2:
                continue
            try:
                res[int(rec[0])].append(int(rec[1]))
            except ValueError:
                continue
    return {m: sorted(set(v)) for m, v in res.items()}


def fmt_run(run):
    seqs = sorted(run, key=lambda r: r["seq"])
    ords = [r["ord"] for r in seqs]
    uniq = []
    for o in ords:
        if not uniq or uniq[-1] != o:
            uniq.append(o)
    return seqs, ords, uniq


def main():
    ap = argparse.ArgumentParser(description="按拉怪日志分析副本波次顺序")
    ap.add_argument("--csv", help="拉怪日志 TSV/CSV（列见文件头注释）")
    ap.add_argument("--route-csv", help="路线表顺序导出（map,ord[,...]），用于对比漏波/乱序")
    ap.add_argument("--map", type=int, default=None)
    ap.add_argument("--instance", type=int, default=None)
    ap.add_argument("--json", default=None, help="把分析结果写成 JSON")
    ap.add_argument("--mysql-host", default="127.0.0.1")
    ap.add_argument("--mysql-user", default="root")
    ap.add_argument("--mysql-password", default="")
    ap.add_argument("--mysql-db", default=None)
    args = ap.parse_args()

    rows = load_rows(args)
    if not rows:
        sys.exit("没有数据（先确认 ai_playerbot_pull_log 有行，或 CSV 格式正确）")

    route = load_route(args.route_csv)

    runs = OrderedDict()
    for r in rows:
        if args.map is not None and r["map"] != args.map:
            continue
        if args.instance is not None and r["instance_id"] != args.instance:
            continue
        runs.setdefault((r["map"], r["instance_id"]), []).append(r)

    report = {"runs": [], "per_map": {}}

    print("=== 每一轮副本的拉怪顺序 ===")
    for (map_id, inst), run in runs.items():
        seqs, ords, uniq = fmt_run(run)
        monotonic = all(b >= a for a, b in zip(uniq, uniq[1:])) if len(uniq) > 1 else True
        cleared = sum(1 for r in seqs if r["result"] == "cleared")
        skipped = [r for r in seqs if r["result"] == "skipped"]
        died = sum(1 for r in seqs if r["result"] == "died")
        deaths = sum(r["deaths"] for r in seqs)
        total_s = sum(r["duration_s"] for r in seqs)

        print("\n-- map=%d inst=%d：拉怪 %d 次，cleared=%d，skipped=%d，died=%d，死亡合计=%d，用时合计=%ds"
              % (map_id, inst, len(seqs), cleared, len(skipped), died, deaths, total_s))
        if not monotonic:
            print("   [!] 实际顺序不是 ord 递增：%s" % " -> ".join(map(str, uniq)))

        print("   %-4s %-5s %-9s %-9s %-6s %-7s %s"
              % ("seq", "ord", "target", "result", "用时s", "剩余", "死亡"))
        for r in seqs:
            print("   %-4d %-5d %-9d %-9s %-6d %-7d %d"
                  % (r["seq"], r["ord"], r["target_entry"], r["result"],
                     r["duration_s"], r["mobs_alive"], r["deaths"]))

        entry = {
            "map": map_id, "instance_id": inst, "pulls": len(seqs),
            "ord_sequence": uniq, "ord_monotonic": monotonic,
            "cleared": cleared, "skipped": len(skipped), "died": died,
            "deaths": deaths, "duration_total_s": total_s,
        }

        if map_id in route:
            pulled = set(o for o in ords if o)
            missing = [o for o in route[map_id] if o not in pulled]
            if missing:
                print("   漏波（路线里存在但本轮没拉过）：%s" % missing)
            entry["missing_ords"] = missing
            entry["route_ords"] = route[map_id]

        report["runs"].append(entry)

    # 单图汇总
    by_map = defaultdict(list)
    for r in rows:
        by_map[r["map"]].append(r)

    print("\n=== 按图汇总 ===")
    print("%-6s %-8s %-8s %-10s %-10s %-8s" % ("map", "轮数", "拉怪总次", "完成率", "平均用时s", "总死亡"))
    for map_id, rs in sorted(by_map.items()):
        insts = set(r["instance_id"] for r in rs)
        cleared = sum(1 for r in rs if r["result"] == "cleared")
        total = len([r for r in rs if r["result"] != "pending"])
        rate = ("%.0f%%" % (100.0 * cleared / total)) if total else "-"
        avg_s = (sum(r["duration_s"] for r in rs) // max(1, len(rs)))
        print("%-6d %-8d %-8d %-10s %-10d %-8d"
              % (map_id, len(insts), len(rs), rate, avg_s, sum(r["deaths"] for r in rs)))
        report["per_map"][str(map_id)] = {
            "runs": len(insts), "pulls": len(rs), "clear_rate": rate,
            "avg_duration_s": avg_s, "deaths": sum(r["deaths"] for r in rs),
        }

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=2)
        print("\nJSON 已写入 %s" % args.json)


if __name__ == "__main__":
    main()
