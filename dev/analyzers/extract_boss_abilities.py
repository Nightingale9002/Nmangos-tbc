#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract_boss_abilities.py —— 从 dev/tbc五人本攻略.md 提取 BOSS/召唤物的技能与效果，
并按"能不能通用处理"先分一版类（之后再用 DB 填 spell_id / entry）。

站长口径（2026-10-18）：
  ① "对于boss我们是能按照通用策略处理的就处理，不能处理的我们再做单独的策略"；
  ② 召唤物/图腾**不按"是召唤物"给优先级**，按它自己的技能/效果分类（见 §召唤物）。

用法：
  python3 dev/analyzers/extract_boss_abilities.py
  python3 dev/analyzers/extract_boss_abilities.py --json _agent_tmp/boss_abilities.json

输出：stdout 统计 +（可选）JSON 明细。不改库、不需要 DB 连接。
tag/效果 → 通用处理 的映射：
  [打断]                         -> interrupt      (通用打断)
  [魔法]/[疾病]/[诅咒]/[毒]        -> dispel         (通用驱散)
  [重要]                         -> priority       (通用威胁表)
  [坦克]                         -> tank           (通用坦克/换坦判据，记 special 候选)
  范围/码/AOE/地面/锥形           -> aoe            (通用躲地板技)
  击退/冲锋/位移                  -> move           (通用躲/位移)
  召唤/图腾/分身                  -> summon         (按下一条：只记来源，不单独给优先级)
  治疗/恢复                       -> heal           (通用优先级/打断)
  其余                           -> other          (needs_special 候选)
"""

import argparse
import json
import re
import sys
from collections import Counter, defaultdict

TAG_RULES = [
    ("interrupt", ("打断",)),
    ("dispel", ("魔法", "疾病", "诅咒", "毒")),
    ("priority", ("重要",)),
    ("tank", ("坦克",)),
]

# 注意顺序：先判"跑位类"，再判普通 AOE —— 正面锥形/击退/卡视角/分散集合 都不是
# "躲开地板圈"能通用解决的（站长 2026-10-18："你把需要跑位的策略漏了"）。
TEXT_RULES = [
    ("frontal", ("锥形", "正面", "顺劈", "前方", "扫射")),
    ("knockback", ("击退", "冲锋", "抛飞", "拉拽", "位移", "击飞")),
    ("los", ("卡视角", "视角", "掩体", "阻挡视线", "拉远")),
    ("spread", ("分散", "散开", "分开站")),
    ("stack", ("集合", "靠近", "站一起")),
    ("kite", ("风筝", "拉走", "拉扯")),
    ("aoe", ("范围", "码内", "地面", "光环", "AOE", "aoe")),
    ("summon", ("召唤", "图腾", "分身")),
    ("heal", ("治疗", "恢复")),
]

GENERIC = {
    "interrupt": "通用打断",
    "dispel": "通用驱散",
    "priority": "通用威胁表",
    "heal": "通用优先级/打断",
    "aoe": "通用躲地板技",
    "move": "通用躲/位移",
    "summon": "按召唤物自身技能分类",
    "tank": "通用坦克",
    "other": "需单独策略",
    "damage": "通用（普通伤害）",
    "frontal": "需跑位：坦克转身/别站正面（待实现）",
    "knockback": "需跑位：沙包/击退回位（待实现）",
    "los": "需跑位：卡视角/拉远（待实现）",
    "spread": "需跑位：分散（待实现）",
    "stack": "需跑位：集合（待实现）",
    "kite": "需跑位：风筝/拉走（待实现）",
}

SKILL_RE = re.compile(r"^[-*]\s*(?P<name>[^：:]+?)\s*(?P<tags>(?:\[[^\]]+\]\s*)*)[：:]\s*(?P<desc>.*)$")


def classify(tags, desc):
    cats = []
    for tag in tags:
        for cat, keys in TAG_RULES:
            if tag in keys:
                cats.append(cat)
    for cat, keys in TEXT_RULES:
        if any(k in desc for k in keys):
            cats.append(cat)
    if not cats:
        cats = ["other"]
    # 去重保序
    seen = set()
    out = []
    for c in cats:
        if c not in seen:
            seen.add(c)
            out.append(c)
    # 无标签/普通伤害 ⇒ 归 damage（通用，不特殊处理）；[坦克] 只有明确"换坦"才特殊
    if out == ["other"]:
        out = ["damage"]
    # 需要跑位/站位的机制 ⇒ 通用"躲地板技"处理不了，必须先算 special（站长口径）
    POSITION_CATS = {"frontal", "knockback", "los", "spread", "stack", "kite"}
    needs_special = bool(POSITION_CATS.intersection(out)) or ("换坦" in desc or "换T" in desc or "换 T" in desc)
    generic = [GENERIC.get(c, "通用") for c in out]
    return out, generic, needs_special


def parse(path):
    dungeons = {}
    dungeon = None
    boss = None
    owner = None          # 召唤物/小怪名（#### 小节）；None = boss 本体
    in_skill = False

    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if line.startswith("# "):
                dungeon = line[2:].strip()
                dungeons.setdefault(dungeon, {})
                boss = owner = None
                in_skill = False
                continue
            if line.startswith("## "):
                boss = line[3:].strip()
                owner = None
                in_skill = False
                continue
            if line.startswith("### "):
                # 只有真的带"技能列表"的 ## 小节才算 boss（过滤"重点小怪/掉落列表"等误识别）
                in_skill = (line[4:].strip() == "技能列表")
                if in_skill and dungeon and boss:
                    dungeons[dungeon].setdefault(boss, {"skills": [], "summons": {}})
                continue
            if line.startswith("#### "):
                owner = line[5:].strip()
                if dungeon and boss:
                    dungeons[dungeon].setdefault(boss, {"skills": [], "summons": {}})
                    dungeons[dungeon][boss]["summons"].setdefault(owner, [])
                continue
            if not in_skill or not dungeon or not boss:
                continue
            m = SKILL_RE.match(line.strip())
            if not m:
                continue
            tags = re.findall(r"\[([^\]]+)\]", m.group("tags") or "")
            name = m.group("name").strip()
            desc = m.group("desc").strip()
            cats, generic, special = classify(tags, desc)
            skill = {
                "name": name,
                "tags": tags,
                "desc": desc[:200],
                "category": cats,
                "generic": generic,
                "needs_special": special,
            }
            if owner:
                dungeons[dungeon][boss]["summons"][owner].append(skill)
            else:
                dungeons[dungeon][boss]["skills"].append(skill)
    return dungeons


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--guide", default="dev/tbc五人本攻略.md")
    ap.add_argument("--json", metavar="OUT")
    args = ap.parse_args()

    try:
        data = parse(args.guide)
    except OSError as exc:
        print(f"读不了攻略: {exc}", file=sys.stderr)
        return 1

    total_boss = total_skill = total_special = total_summon = 0
    tag_counter = Counter()
    cat_counter = Counter()
    special_bosses = []

    for dungeon, bosses in data.items():
        real_bosses = [(b, v) for b, v in bosses.items() if v["skills"] or v["summons"]]
        if not real_bosses:
            continue
        print(f"\n=== {dungeon}（boss/小节 {len(real_bosses)} 个）===")
        for boss_name, info in real_bosses:
            skills = info["skills"]
            summons = info["summons"]
            total_boss += 1
            total_summon += len(summons)
            special = [s for s in skills if s["needs_special"]]
            if special or (not skills):
                special_bosses.append(f"{dungeon} / {boss_name}")
            for s in skills:
                total_skill += 1
                total_special += 1 if s["needs_special"] else 0
                for c in s["category"]:
                    cat_counter[c] += 1
                for t in s["tags"]:
                    tag_counter[t] += 1
            flag = " ★需单独" if special else ""
            print(f"  {boss_name}: {len(skills)} 招, 召唤物 {len(summons)} 个{flag}")

    print("\n=== 汇总 ===")
    print(f"  副本 {len([d for d in data if any(v['skills'] or v['summons'] for v in data[d].values())])} 个 / boss 小节 {total_boss} / 技能 {total_skill} / 召唤物小节 {total_summon}")
    print(f"  初步判为'需单独策略'的技能 {total_special} 条；相关 boss {len(special_bosses)} 个")
    print(f"  分类计数: {dict(cat_counter)}")
    print(f"  标签计数: {dict(tag_counter)}")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)
        print(f"\nJSON: {args.json}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
