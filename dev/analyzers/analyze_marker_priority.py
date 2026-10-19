#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""analyze_marker_priority.py —— 从服务端日志的 [MARKER] 行，自动分析"骷髅标记优先级"。

站长口径（2026-10-18）：
  "记录骷髅团队标记的标记和更改 …… 这样的好处是可以根据骷髅头标记自动分析优先级。"

  → 真人（或 bot）把哪只怪标成骷髅，就是一次**人工优先级标注**；次数越多越说明"这只怪该先打"。
     本工具把日志里的标记事件聚合成 `ai_playerbot_priority_target` 的候选行：

       entry   = 怪物 entry（日志里 old_entry/new_entry 已带上）
       priority= 5（默认：被标过骷髅 = 最高优先级）
       source  = 'skull-log'
       reason  = '骷髅标记 N 次（首次 .. 最后 ..）'

日志格式（Group::SetTargetIcon 落盘，见 src/game/Groups/Group.cpp）：
  [MARKER] group=1 leader=甲(A) changer=乙(B) icon=7(skull) old=Mob-0-.. old_entry=12345 new=.. new_entry=0

用法：
  # 只看统计（不生成 SQL）
  python dev/analyzers/analyze_marker_priority.py --log /path/to/Server.log

  # 只看骷髅（icon=7）并生成 upsert SQL
  python dev/analyzers/analyze_marker_priority.py --log Server.log --icon skull --sql out.sql

  # 排除"清标"事件（new_entry=0 表示这一格被清空）
  python dev/analyzers/analyze_marker_priority.py --log Server.log --min-count 2

注意：
  * 只统计 `new_entry != 0`（被设成标记的目标）；`old_entry` 只用于统计"被改掉"次数。
  * 默认不连库：纯离线分析日志；`--sql` 的输出可直接人工复核后再执行。
"""

import argparse
import sys
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import os
import re
import sys
from collections import OrderedDict

ICONS = ["star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull"]

# [MARKER] group=1 leader=.. changer=.. icon=7(skull) old=.. old_entry=0 new=.. new_entry=12345
MARKER_RE = re.compile(
    r"\[MARKER\]\s+group=(?P<group>\d+)\s+leader=(?P<leader>.+?)\s+changer=(?P<changer>.+?)\s+"
    r"icon=(?P<icon>\d+)(?:\((?P<icon_name>[a-z]+)\))?\s+"
    r"old=(?P<old>.+?)\s+old_entry=(?P<old_entry>\d+)\s+"
    r"new=(?P<new>.+?)\s+new_entry=(?P<new_entry>\d+)"
)

NAME_RE = re.compile(r"^(?P<name>.+?)\((?P<guid>[^()]+)\)$")


def parse_name(desc):
    if not desc or desc == "-":
        return "-"
    m = NAME_RE.match(desc)
    return m.group("name") if m else desc


def scan(path):
    """-> (marks, clears)；marks: entry -> dict(count/first/last/name/groups)"""
    marks = OrderedDict()
    clears = OrderedDict()
    total = 0

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "[MARKER]" not in line:
                continue
            m = MARKER_RE.search(line)
            if not m:
                continue
            total += 1

            icon = int(m.group("icon"))
            entry = int(m.group("new_entry"))
            old_entry = int(m.group("old_entry"))
            ts_m = re.match(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", line)
            ts = ts_m.group(1) if ts_m else ""

            # 只关心"被设成标记"的那一步
            if entry:
                rec = marks.setdefault(entry, {
                    "count": 0, "first": ts, "last": ts,
                    "name": parse_name(m.group("new")),
                    "groups": set(), "changers": set(), "icons": set(),
                })
                rec["count"] += 1
                rec["last"] = ts or rec["last"]
                rec["groups"].add(m.group("group"))
                rec["changers"].add(parse_name(m.group("changer")))
                rec["icons"].add(ICONS[icon] if icon < len(ICONS) else str(icon))
            # 清标 / 改标走掉的目标
            if old_entry and old_entry != entry:
                clears[old_entry] = clears.get(old_entry, 0) + 1

    return marks, clears, total


def emit_sql(marks, clears, out_path, priority, min_count, maps=None):
    lines = [
        "-- analyze_marker_priority.py 生成（人工复核后再执行）",
        "-- 语义：站长口径「越大越优先」，5 = 最危险/最该先打",
        "-- source='skull-log' 便于以后重跑时区分人工校订（guide/manual）与日志推导",
        "",
    ]
    for entry, rec in marks.items():
        if rec["count"] < min_count:
            continue
        reason = "骷髅标记 %d 次（%s ~ %s；标记人：%s）" % (
            rec["count"], rec["first"], rec["last"], ",".join(sorted(rec["changers"])) or "-")
        if entry in clears:
            reason += "；被改掉/清标 %d 次" % clears[entry]
        reason = reason.replace("'", "''")[:255]
        lines.append(
            "INSERT INTO `tbcmangos`.`ai_playerbot_priority_target` "
            "(`entry`,`priority`,`source`,`reason`) VALUES (%d,%d,'skull-log','%s') "
            "ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),"
            "`source`=VALUES(`source`),`reason`=VALUES(`reason`);" % (entry, priority, reason))

    text = "\n".join(lines) + "\n"
    if out_path:
        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return len(lines) - 4
    sys.stdout.write(text)
    return len(lines) - 4


def main():
    ap = argparse.ArgumentParser(description="按 [MARKER] 日志自动分析骷髅标记优先级")
    ap.add_argument("--log", required=True, help="服务端日志（包含 [MARKER] 行，例如 Server.log）")
    ap.add_argument("--icon", default="skull", help="只统计哪个标记（默认 skull；all = 全部）")
    ap.add_argument("--min-count", type=int, default=1, help="至少被标记几次才输出（默认 1）")
    ap.add_argument("--priority", type=int, default=5, help="写进表的优先级（默认 5 = 最高）")
    ap.add_argument("--sql", default=None, help="输出 SQL 到这个文件（默认打印到屏幕）")
    ap.add_argument("--top", type=int, default=30, help="屏幕统计显示前 N 条")
    args = ap.parse_args()

    if not os.path.isfile(args.log):
        sys.exit("找不到日志：%s" % args.log)

    marks, clears, total = scan(args.log)
    if total == 0:
        sys.exit("日志里没有 [MARKER] 行 —— 确认服务端已运行带标记日志的版本（Group::SetTargetIcon）")

    if args.icon != "all":
        keep = {e: r for e, r in marks.items() if args.icon in r["icons"]}
        marks = keep

    print("=== 统计 ===")
    print("标记事件总数：%d；涉及怪物 entry：%d；被清标/改走的 entry：%d"
          % (total, len(marks), len(clears)))

    print("\n=== 被标最多的怪（前 %d）===" % args.top)
    print("%-10s %-6s %-32s %s" % ("entry", "次数", "名字", "标记种类"))
    for entry, rec in sorted(marks.items(), key=lambda kv: -kv[1]["count"])[:args.top]:
        print("%-10d %-6d %-32s %s" % (entry, rec["count"], rec["name"],
                                       ",".join(sorted(rec["icons"]))))

    if args.min_count > 1:
        pass
    n = emit_sql(marks, clears, args.sql, args.priority, args.min_count)
    print("\n生成 SQL 行数：%d%s" % (n, "（已写入 %s）" % args.sql if args.sql else "（见下方/标准输出）"))


if __name__ == "__main__":
    main()
