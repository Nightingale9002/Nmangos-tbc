# -*- coding: utf-8 -*-
# 从攻略（技能列表分类 + 正文关键词）生成"跑位触发"种子：
#   攻略 BOSS 中文名 -> locales_creature.name_loc4 -> entry -> ai_playerbot_boss_spawn.map
#   输出 INSERT IGNORE 到 dev/198_boss_ability_position_seed.sql
import json, re, subprocess

GUIDE = r"D:\Game\cmangos\Nmangos-tbc\dev\tbc五人本攻略.md"
JSONF = r"D:\Game\cmangos\_agent_tmp\boss_abilities.json"
OUT = r"D:\Game\cmangos\Nmangos-tbc\dev\198_boss_ability_position_seed.sql"

CATEGORY_GENERIC = {
    "los": "跑位:卡视野",
    "frontal": "跑位:避开正面",
    "knockback": "跑位:沙包/回位",
    "stack": "跑位:集合",
    "spread": "跑位:分散",
    "wall": "跑位:贴墙防击飞",
}
LOS_KW = ("卡视角", "视角", "掩体", "拐角", "绕柱子", "柱子", "遮挡", "拉远", "看不见", "断视线", "挡住", "卡掉")
WALL_KW = ("贴墙", "靠墙", "墙边", "背靠", "墙后", "推到墙上", "撞墙")
# 正文里的"集合/分散"（要贴站位语义，避免"集中火力"误判）
STACK_KW = ("集合", "分摊", "靠拢", "站一起", "同一侧", "同侧", "扎堆", "集中站", "抱团")
SPREAD_KW = ("分散", "散开", "分开站", "拉开距离", "彼此远离", "分散站", "不要站在一起", "拉开间距")


def mysql(sql):
    r = subprocess.run(["mysql", "-uroot", "-pqwerty", "-N", "--default-character-set=utf8mb4", "tbcmangos"],
                       input=sql.encode("utf-8"), capture_output=True)
    return r.stdout.decode("utf-8", "replace")


def kw_hits(text, kws):
    """命中关键词并带上下文；跳过"不要/别/无需/不必 + 关键词"的否定写法"""
    hits = []
    for k in kws:
        pos = 0
        while True:
            i = text.find(k, pos)
            if i < 0:
                break
            before = text[max(0, i - 4):i]
            pos = i + len(k)
            if any(n in before for n in ("不要", "别", "无需", "不用", "不必", "避免")):
                continue
            hits.append((k, text[max(0, i - 20):i + len(k) + 20].replace("\n", " ")))
    return hits


def norm(s):
    return re.sub(r"[\s·・\-\+《》〈〉()（）\[\]「」]", "", s)


def load_names():
    rows = [l.split("\t") for l in mysql("SELECT entry, name_loc4 FROM locales_creature WHERE name_loc4<>'';").strip().split("\n") if "\t" in l]
    exact, normd = {}, {}
    for r in rows:
        e, n = int(r[0]), re.sub(r"\s*\(\d+\)$", "", r[1].strip())
        exact.setdefault(n, e)
        normd.setdefault(norm(n), e)
    return exact, normd


def load_maps():
    spawn = {}
    for line in mysql("SELECT DISTINCT map, entry FROM ai_playerbot_boss_spawn;").strip().split("\n"):
        if "\t" in line:
            m, e = line.split("\t")[:2]
            spawn.setdefault(int(e), set()).add(int(m))
    return spawn


def maps_for(entry, spawn):
    maps = spawn.get(entry)
    if maps:
        return maps
    got = {int(x) for x in mysql(f"SELECT DISTINCT map FROM creature WHERE id={entry};").split() if x.strip().isdigit()}
    return {m for m in got if m > 0}


def main():
    data = json.load(open(JSONF, encoding="utf-8"))
    exact, normd = load_names()
    spawn = load_maps()

    # 正文：每个 boss 小节收集"卡视野"关键词
    dungeon = boss = None
    prose, order = {}, []
    for line in open(GUIDE, encoding="utf-8"):
        if line.startswith("# "):
            dungeon = line[2:].strip(); boss = None; continue
        if line.startswith("## "):
            boss = line[3:].strip(); order.append((dungeon, boss)); prose[(dungeon, boss)] = ""; continue
        if line.startswith("### "):
            continue
        if boss:
            prose[(dungeon, boss)] += line.strip() + "\n"

    buckets = {}
    for dungeon_name, bosses in data.items():
        for boss_name_skip, info in bosses.items():
            cats = set()
            names = []
            for s in info.get("skills", []):
                for c in s.get("category", []):
                    if c in CATEGORY_GENERIC:
                        cats.add(c)
                        names.append(f"{c}:{s.get('name','')}")
            if any(k in boss_name_skip for k in ("其他", "说明", "汇总", "索引", "前言", "注意", "原则", "更新", "致谢", "引用", "战术性", "五、", "BOSS 战术")):
                continue
            key = (dungeon_name, boss_name_skip)
            body = prose.get(key, "")
            for cat, kws in (("los", LOS_KW), ("wall", WALL_KW), ("stack", STACK_KW), ("spread", SPREAD_KW)):
                hits = kw_hits(body, kws)
                if hits:
                    cats.add(cat)
                    names.append(f"{cat}:攻略正文[{hits[0][1][:40]}]")
                    print(f"  [{cat}] {dungeon_name}/{boss_name_skip}: {hits[0][1][:60]}")
            if not cats:
                continue
            entry = exact.get(boss_name_skip) or normd.get(norm(boss_name_skip))
            # 只认精确/规范化精确匹配；不做子串兜底（避免把"BOSS战术"之类误配成某只怪）
            if not entry:
                continue
            for m in maps_for(entry, spawn):
                for c in cats:
                    buckets.setdefault((m, entry, c), []).append(f"{dungeon_name}/{boss_name_skip}")

    out = []
    for (m, entry, c), who in sorted(buckets.items()):
        note = ("攻略: " + " / ".join(sorted(set(who))))[:200].replace("'", "''")
        out.append(f"({m},{entry},{entry},0,'{c}',0,'','{CATEGORY_GENERIC[c]}',0,'guide','{note}')")

    sql = ("-- 198_BOSS能力表_跑位种子.sql（dev/analyzers/seed_boss_position.py 生成；幂等 INSERT IGNORE）\n"
           "-- 让 PartyPositionCoordinator 的五种跑位模式有触发数据：los/frontal/knockback/stack/spread\n"
           "INSERT IGNORE INTO `ai_playerbot_boss_ability` "
           "(`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`interruptible`,`dispellable`,"
           "`generic_handling`,`needs_special`,`source`,`note`) VALUES\n"
           + ",\n".join(out) + ";\n")
    open(OUT, "w", encoding="utf-8").write(sql)
    print("rows:", len(out), "->", OUT)
    for row in out[:20]:
        print("  ", row[:110])


if __name__ == "__main__":
    main()
