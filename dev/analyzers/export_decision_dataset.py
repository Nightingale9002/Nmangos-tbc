#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
export_decision_dataset.py —— 把线上采集的数据导出成"决策/调参数据集"（离线，本地跑）。

输入（都先 scp 到本地，云端不做分析）：
  --combatlog  logs/combatlog_instances.csv       服务端战斗日志（dev: CombatLogRecorder）
  --pull-log   ai_playerbot_pull_log.csv          可选：拉怪表导出（每拉一行，含 result）
  --server-log Server.log                         可选：含 [DECISION] 决策打分日志
  --out        dataset.jsonl                      输出：一行一个样本（features/label/meta）
  --out-csv    dataset.csv                        可选：扁平 CSV（便于 pandas/sklearn）

口径：
  - 用 combatlog 还原"每一波拉怪"（怪→玩家 事件 + 间隔切分，同 analyze_combatlog.py）；
  - 每一波 = 一个样本：
      features: 时长、怪数、击杀、死亡、玩家伤害/治疗/承伤、敌方读条次数与种类、是否真人局…
      label   : result（有真人死亡=died，否则=cleared；优先用 pull-log 的 result 覆盖）
  - [DECISION] 行按时间窗口并入特征（score/override 统计），后续可做行为克隆/权重调参。
"""

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

ANCHOR_GAP = 10          # 秒：怪→玩家事件间隔超过它 = 新的一波
DECISION_RE = re.compile(
    r"\[DECISION\] bot=(?P<bot>\S+) kind=(?P<kind>\S+) entry=(?P<entry>\d+) "
    r"override=(?P<override>\d+) score=(?P<score>-?\d+(?:\.\d+)?) "
    r"tier=(?P<tier>-?\d+) dist=(?P<dist>[\d.]+)")


def fnum(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def inum(v):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return 0


def load_combatlog(path, real_only):
    rows = []
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
        for row in csv.DictReader(fh):
            if not row.get("event"):
                continue
            if real_only:
                real = False
                for prefix in ("src", "dst"):
                    if row.get(prefix + "_type") == "P" and inum(row.get(prefix + "_bot")) == 0:
                        real = True
                if not real:
                    continue
            rows.append(row)
    rows.sort(key=lambda r: inum(r.get("ts")))
    return rows


def split_pulls(rows):
    """按 (map,instance) 分组，再按"怪→玩家"锚点间隔切分。"""
    by_inst = defaultdict(list)
    for row in rows:
        by_inst[(row.get("map"), row.get("inst"))].append(row)

    pulls = []
    for (map_id, inst_id), inst_rows in sorted(by_inst.items()):
        current, last_anchor = [], 0
        for row in inst_rows:
            anchor = row.get("src_type") == "C" and row.get("dst_type") == "P"
            ts = inum(row.get("ts"))
            if anchor and current and ts - last_anchor > ANCHOR_GAP:
                pulls.append((map_id, inst_id, current))
                current = []
            current.append(row)
            if anchor:
                last_anchor = ts
        if current:
            pulls.append((map_id, inst_id, current))
    return pulls


def summarize_pull(map_id, inst_id, rows, index):
    ts = [inum(r.get("ts")) for r in rows]
    start, end = min(ts), max(ts)
    duration = max(1, end - start)

    mobs, kills, deaths = set(), set(), set()
    dmg_done = dmg_taken = heal = 0
    enemy_casts = Counter()
    player_casts = 0
    real_players = set()

    for row in rows:
        evt = row.get("event")
        st, dt = row.get("src_type"), row.get("dst_type")
        if st == "P" and inum(row.get("src_bot")) == 0:
            real_players.add(row.get("src_name"))
        if dt == "P" and inum(row.get("dst_bot")) == 0:
            real_players.add(row.get("dst_name"))

        if st == "C":
            mobs.add(row.get("src_guid"))
        if dt == "C":
            mobs.add(row.get("dst_guid"))

        if evt in ("SWING_DAMAGE", "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE"):
            amount = inum(row.get("amount"))
            if st == "P" and inum(row.get("src_bot")) == 0:
                dmg_done += amount
            if dt == "P":
                dmg_taken += amount
        elif evt == "SPELL_HEAL" and st == "P" and inum(row.get("src_bot")) == 0:
            heal += inum(row.get("amount"))
        elif evt == "SPELL_CAST_START":
            if st == "C":
                enemy_casts[row.get("spell") or "0"] += 1
            elif st == "P":
                player_casts += 1
        elif evt == "UNIT_DIED":
            if dt == "C":
                kills.add(row.get("dst_guid"))
            elif dt == "P":
                deaths.add(row.get("dst_name"))

    features = {
        "duration_s": duration,
        "mobs_seen": len(mobs),
        "kills": len(kills),
        "deaths": len(deaths),
        "real_player": 1 if real_players else 0,
        "real_players": sorted([p for p in real_players if p]),
        "dmg_done": dmg_done,
        "dmg_taken": dmg_taken,
        "heal_done": heal,
        "dps": round(dmg_done / float(duration), 2),
        "hps": round(heal / float(duration), 2),
        "incoming_dps": round(dmg_taken / float(duration), 2),
        "enemy_cast_count": sum(enemy_casts.values()),
        "enemy_cast_kinds": len(enemy_casts),
        "player_cast_count": player_casts,
        "enemy_cast_top": [s for s, _ in enemy_casts.most_common(5)],
    }
    label = "died" if deaths else "cleared"
    return {
        "meta": {"map": map_id, "instance": inst_id, "seq": index,
                 "start": int(start), "end": int(end)},
        "features": features,
        "label": label,
    }


def load_pull_log(path):
    """可选：把拉怪表导出成 {(map, instance, seq): row}（seq 从 1 开始按时间排序）。"""
    out = {}
    if not path:
        return out
    with open(path, "r", encoding="utf-8", errors="replace", newline="") as fh:
        for row in csv.DictReader(fh):
            key = (row.get("map"), row.get("instance_id"))
            out.setdefault(key, []).append(row)
    return out


def load_decisions(path):
    """可选：解析 [DECISION] 行 → [(ts, dict)]"""
    out = []
    if not path:
        return out
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = DECISION_RE.search(line)
            if not m:
                continue
            stamp = line[:19]
            try:
                ts = int(datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S")
                         .replace(tzinfo=timezone.utc).timestamp())
            except ValueError:
                continue
            out.append((ts, m.groupdict()))
    return out


def attach_decisions(samples, decisions):
    if not decisions:
        return
    for sample in samples:
        start = sample["meta"]["start"]
        end = sample["meta"]["end"]
        window = [d for ts, d in decisions if start <= ts <= end]
        if not window:
            continue
        sample["features"]["decision_count"] = len(window)
        sample["features"]["decision_override"] = sum(1 for d in window if d["override"] == "1")
        sample["features"]["decision_score_avg"] = round(
            sum(fnum(d["score"]) for d in window) / len(window), 2)


def write_outputs(samples, out_jsonl, out_csv):
    with open(out_jsonl, "w", encoding="utf-8") as fh:
        for sample in samples:
            fh.write(json.dumps(sample, ensure_ascii=False) + "\n")

    if out_csv:
        keys = sorted({k for s in samples for k in s["features"]})
        with open(out_csv, "w", encoding="utf-8", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow(["map", "instance", "seq", "label"] + keys)
            for sample in samples:
                writer.writerow([sample["meta"]["map"], sample["meta"]["instance"],
                                 sample["meta"]["seq"], sample["label"]]
                                + [sample["features"].get(k, "") for k in keys])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--combatlog", required=True)
    ap.add_argument("--pull-log")
    ap.add_argument("--server-log")
    ap.add_argument("--out", default="dataset.jsonl")
    ap.add_argument("--out-csv")
    ap.add_argument("--real-only", action="store_true", help="只保留涉及真人的事件")
    args = ap.parse_args()

    try:
        rows = load_combatlog(args.combatlog, args.real_only)
    except OSError as exc:
        print(f"读不了 combatlog: {exc}", file=sys.stderr)
        return 1

    pulls = split_pulls(rows)
    samples = []
    for index, (map_id, inst_id, pull_rows) in enumerate(pulls, 1):
        samples.append(summarize_pull(map_id, inst_id, pull_rows, index))

    attach_decisions(samples, load_decisions(args.server_log))

    # 用拉怪表的 result 覆盖 label（更权威），并补 ord/source
    pull_log = load_pull_log(args.pull_log)
    for sample in samples:
        key = (sample["meta"]["map"], sample["meta"]["instance"])
        entries = pull_log.get(key)
        if not entries:
            continue
        seq = sample["meta"]["seq"] - 1
        if seq < len(entries):
            row = entries[seq]
            sample["meta"]["ord"] = inum(row.get("ord"))
            sample["meta"]["pull_result"] = row.get("result") or ""
            if row.get("result") in ("cleared", "died"):
                sample["label"] = row["result"]
            sample["features"]["pull_deaths"] = inum(row.get("deaths"))

    write_outputs(samples, args.out, args.out_csv)

    labels = Counter(s["label"] for s in samples)
    print(f"样本 {len(samples)} 条（{args.out}）")
    print(f"标签分布: {dict(labels)}")
    if samples:
        print(f"特征: {sorted(samples[0]['features'].keys())}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
