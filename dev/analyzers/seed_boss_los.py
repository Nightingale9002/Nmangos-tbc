# -*- coding: utf-8 -*-
# 从攻略正文提取"需要卡视野"的 BOSS -> locales_creature.zhCN(name_loc4) 匹配 entry
# -> ai_playerbot_boss_spawn 取 map -> 生成 dev/196_BOSS能力表_LOS种子.sql（幂等）
import subprocess, re

GUIDE = r"D:\Game\cmangos\Nmangos-tbc\dev\tbc五人本攻略.md"
OUT = r"D:\Game\cmangos\Nmangos-tbc\dev\196_boss_ability_los_seed.sql"


def mysql(sql):
    r = subprocess.run(
        ["mysql", "-uroot", "-pqwerty", "-N", "--default-character-set=utf8mb4", "tbcmangos"],
        input=sql.encode("utf-8"), capture_output=True)
    return r.stdout.decode("utf-8", "replace")


def norm(s):
    return re.sub(r"[\s·・\-\+《》〈〉()（）\[\]「」]", "", s)


rows = [l.split("\t") for l in mysql("SELECT entry, name_loc4 FROM locales_creature WHERE name_loc4<>'';").strip().split("\n") if "\t" in l]
by_exact, by_norm = {}, {}
for r in rows:
    entry, name = int(r[0]), re.sub(r"\s*\(\d+\)$", "", r[1].strip())
    by_exact.setdefault(name, entry)
    by_norm.setdefault(norm(name), entry)
print("zhCN 名字:", len(rows))

LOS_KW = ("卡视角", "视角", "掩体", "拐角", "绕柱子", "柱子", "遮挡", "拉远", "看不见", "断视线", "挡住", "卡掉")

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

SKIP = ("重点小怪", "索引", "前言", "注意事项", "副本原则", "更新纪录", "引用")
spawn = {}
for line in mysql("SELECT DISTINCT map, entry FROM ai_playerbot_boss_spawn;").strip().split("\n"):
    if "\t" in line:
        m, e = line.split("\t")[:2]
        spawn.setdefault(int(e), set()).add(int(m))

hits, miss, out, seen = [], [], [], set()
for key in order:
    if key[1] in SKIP:
        continue
    body = prose.get(key, "")
    kw = [k for k in LOS_KW if k in body]
    if not kw:
        continue
    entry = by_exact.get(key[1]) or by_norm.get(norm(key[1]))
    if not entry:
        cand = [(n, e) for n, e in by_norm.items() if norm(key[1]) and (norm(key[1]) in n or n in norm(key[1]))]
        entry = cand[0][1] if cand else 0
    if not entry:
        miss.append(f"{key[0]}/{key[1]} kw={kw}")
        continue
    maps = spawn.get(entry) or {int(x) for x in mysql(f"SELECT DISTINCT map FROM creature WHERE id={entry};").split() if x.isdigit()} or {0}
    maps = {m for m in maps if m > 0}
    for m in maps:
        if (m, entry) in seen:
            continue
        seen.add((m, entry))
        note = ("攻略正文提到卡视野: " + "/".join(kw) + " | " + body.replace("\n", " "))[:200].replace("'", "''")
        out.append(f"({m},{entry},{entry},0,'los',0,'','los_all',0,'guide','{note}')")
    hits.append(f"{key[0]}/{key[1]} entry={entry} map={sorted(maps)}")

print("命中:", len(hits))
for h in hits:
    print("  ", h)
print("未匹配:", miss)

sql = ("-- 196_BOSS能力表_LOS种子.sql（dev/analyzers 从攻略正文提取；幂等 INSERT IGNORE）\n"
       "-- 让 PartyPositionCoordinator 的 LOS 触发集合有数据（category='los'）\n"
       "INSERT IGNORE INTO ai_playerbot_boss_ability "
       "(`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`interruptible`,`dispellable`,"
       "`generic_handling`,`needs_special`,`source`,`note`) VALUES\n"
       + ",\n".join(out) + ";\n")
open(OUT, "w", encoding="utf-8").write(sql)
print("SQL rows:", len(out), "->", OUT)
