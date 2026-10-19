#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
analyze_combatlog.py —— 读服务端战斗日志（combatlog_instances.csv），还原副本战斗。

日志来自核心 `combatlog::*`（见 src/game/Combat/CombatLogRecorder.*）：
一行一个事件（与客户端 CombatLog 同口径）：
  ts,map,inst,event,src_guid,src_name,src_entry,src_type,src_bot,
  dst_guid,dst_name,dst_entry,dst_type,dst_bot,spell,amount,school,cast_ms

用法（把云端日志先 scp 到本地，离线跑；不要在云端做分析）：
  scp root@39.96.90.39:/opt/mangos/logs/combatlog_instances.csv .
  python3 dev/analyzers/analyze_combatlog.py combatlog_instances.csv
  python3 dev/analyzers/analyze_combatlog.py x.csv --real-only --json out.json

口径：
  - 一次「拉怪」= 同一 (map, instance) 内"怪→玩家"的伤害/读条事件，事件间隔 > --gap 秒即切分；
  - 结果：cluster 内出现过玩家/队伍死亡 ⇒ died，否则 cleared（只作粗分，细节看表格）；
  - 敌方读条（src_type=C, event=SPELL_CAST_START）列成"读条清单"，用于补威胁等级表 / BOSS 技能表；
  - --real-only：只保留至少一方是真人的事件（*_bot=0），这是"采集真玩家数据"的默认口径。
"""

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone


def is_player(row, prefix):
    return row.get(prefix + "_type") == "P"


def is_bot(row, prefix):
    try:
        return int(row.get(prefix + "_bot") or 0) != 0
    except ValueError:
        return False


def real_involved(row):
    for prefix in ("src", "dst"):
        if is_player(row, prefix) and not is_bot(row, prefix):
            return True
    return False


def parse_ts(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def fmt_ts(ts):
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def load_rows(path, real_only):
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
        reader = csv.DictReader(fh)
        rows = []
        for row in reader:
            if not row.get("event"):
                continue
            if real_only and not real_involved(row):
                continue
            rows.append(row)
    rows.sort(key=parse_ts)
    return rows


def split_clusters(rows, gap_sec):
    # 只看"怪 → 玩家"的迹象作为拉怪锚点，避免把玩家之间/怪之间的事件算进去
    clusters = []
    current = []
    last_anchor = 0
    for row in rows:
        anchor = row["src_type"] == "C" and row["dst_type"] == "P"
        ts = parse_ts(row["ts"])
        if anchor and current and ts - last_anchor > gap_sec:
            clusters.append(current)
            current = []
        current.append(row)
        if anchor:
            last_anchor = ts
    if current:
        clusters.append(current)
    return clusters


def cluster_report(rows, index, map_id, inst_id):
    ts_list = [parse_ts(r["ts"]) for r in rows]
    start, end = min(ts_list), max(ts_list)

    mobs = {}
    kills = set()
    deaths = set()
    enemy_casts = Counter()
    enemy_cast_names = {}
    player_damage = Counter()
    player_heal = Counter()
    damage_taken = Counter()
    players = set()

    for row in rows:
        event = row["event"]
        src_type, dst_type = row["src_type"], row["dst_type"]

        if src_type == "P" and not is_bot(row, "src"):
            players.add(row["src_name"])
        if dst_type == "P" and not is_bot(row, "dst"):
            players.add(row["dst_name"])

        if src_type == "C":
            mobs[row["src_guid"]] = row["src_name"] or row["src_entry"]
        if dst_type == "C":
            mobs[row["dst_guid"]] = row["dst_name"] or row["dst_entry"]

        if event in ("SWING_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE"):
            amount = int(row["amount"] or 0)
            if src_type == "P" and not is_bot(row, "src"):
                player_damage[row["src_name"]] += amount
            if dst_type == "P":
                damage_taken[row["dst_name"]] += amount
        elif event == "SPELL_HEAL":
            amount = int(row["amount"] or 0)
            if src_type == "P" and not is_bot(row, "src"):
                player_heal[row["src_name"]] += amount
        elif event == "UNIT_DIED":
            if dst_type == "C":
                kills.add(row["dst_guid"])
            elif dst_type == "P":
                deaths.add(row["dst_name"])
        elif event == "SPELL_CAST_START" and src_type == "C":
            spell = row["spell"] or "0"
            enemy_casts[spell] += 1
            enemy_cast_names[spell] = row["src_name"] or row["dst_name"]

    result = "died" if deaths else "cleared"
    return {
        "seq": index,
        "map": map_id,
        "instance": inst_id,
        "start": fmt_ts(start),
        "end": fmt_ts(end),
        "duration_s": max(0, end - start),
        "result": result,
        "mobs_seen": len(mobs),
        "kills": len(kills),
        "deaths": sorted(deaths),
        "real_players": sorted(players),
        "damage_done": dict(player_damage.most_common()),
        "healing_done": dict(player_heal.most_common()),
        "damage_taken": dict(damage_taken.most_common(10)),
        "enemy_casts": [
            {"spell": s, "count": c, "from": enemy_cast_names.get(s, "")}
            for s, c in enemy_casts.most_common(15)
        ],
    }


def main():
    ap = argparse.ArgumentParser(description="分析服务端战斗日志（副本）")
    ap.add_argument("csv_path")
    ap.add_argument("--gap", type=int, default=10, help="拉怪切分间隔（秒），默认 10")
    ap.add_argument("--real-only", action="store_true", help="只看涉及真人的事件")
    ap.add_argument("--json", metavar="OUT", help="把结果另存为 JSON")
    args = ap.parse_args()

    try:
        rows = load_rows(args.csv_path, args.real_only)
    except OSError as exc:
        print(f"读不了 {args.csv_path}: {exc}", file=sys.stderr)
        return 1

    if not rows:
        print("没有事件（检查文件/过滤条件）")
        return 0

    # 按（map, instance）分组：一个实例 = 一轮副本
    by_instance = defaultdict(list)
    for row in rows:
        by_instance[(row["map"], row["inst"])].append(row)

    report = []
    for (map_id, inst_id), inst_rows in sorted(by_instance.items(), key=lambda kv: parse_ts(kv[1][0]["ts"])):
        clusters = split_clusters(inst_rows, args.gap)
        pulls = [cluster_report(cluster, i + 1, map_id, inst_id) for i, cluster in enumerate(clusters)]
        report.append({"map": map_id, "instance": inst_id, "pulls": pulls})

    for inst in report:
        print(f"\n=== map={inst['map']} instance={inst['instance']} pulls={len(inst['pulls'])} ===")
        for pull in inst["pulls"]:
            print(
                f"  #{pull['seq']:<2} {pull['start']} {pull['duration_s']:>4}s "
                f"{pull['result']:<7} mobs={pull['mobs_seen']:<2} kills={pull['kills']:<2} "
                f"deaths={','.join(pull['deaths']) or '-'}"
            )
            if pull["enemy_casts"]:
                spells = ", ".join(f"{c['spell']}x{c['count']}" for c in pull["enemy_casts"][:6])
                print(f"      敌方读条: {spells}")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=2)
        print(f"\nJSON 已写 {args.json}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
