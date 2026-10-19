# -*- coding: utf-8 -*-
# 从攻略提取"禁站扇区"：正面锥形 -> front；龙类甩尾/尾击 -> back（两者都有 -> front,back）
# 输出 dev/200_boss_avoid_sectors_seed.sql（幂等 UPDATE）
import json, re, subprocess
GUIDE = r"D:\Game\cmangos\Nmangos-tbc\dev\tbc五人本攻略.md"
JSONF = r"D:\Game\cmangos\_agent_tmp\boss_abilities.json"
OUT = r"D:\Game\cmangos\Nmangos-tbc\dev\200_boss_avoid_sectors_seed.sql"
FRONT_KW = ("正面", "锥形", "顺劈", "前方", "扫射", "正面锥")
BACK_KW = ("甩尾", "尾巴", "尾部", "尾击", "身后", "背后")
def mysql(sql):
    r = subprocess.run(["mysql","-uroot","-pqwerty","-N","--default-character-set=utf8mb4","tbcmangos"], input=sql.encode("utf-8"), capture_output=True)
    return r.stdout.decode("utf-8","replace")
def norm(s): return re.sub(r"[\s·・\-\+《》〈〉()（）\[\]「」]", "", s)
rows = [l.split("\t") for l in mysql("SELECT entry, name_loc4 FROM locales_creature WHERE name_loc4<>'';").strip().split("\n") if "\t" in l]
exact, normd = {}, {}
for r in rows:
    n = re.sub(r"\s*\(\d+\)$", "", r[1].strip()); exact.setdefault(n,int(r[0])); normd.setdefault(norm(n),int(r[0]))
# 正文
dungeon=boss=None; prose={}
for line in open(GUIDE, encoding="utf-8"):
    if line.startswith("# "): dungeon=line[2:].strip(); boss=None; continue
    if line.startswith("## "): boss=line[3:].strip(); prose[(dungeon,boss)]=""; continue
    if line.startswith("### "): continue
    if boss: prose[(dungeon,boss)] += line.strip()+"\n"
data = json.load(open(JSONF, encoding="utf-8"))
masks = {}
for dname, bosses in data.items():
    for bname, info in bosses.items():
        text = prose.get((dname,bname), "")
        for s in info.get("skills", []):
            text += " " + s.get("name","") + " " + s.get("desc","")
        mask = set()
        if any(k in text for k in FRONT_KW): mask.add("front")
        if any(k in text for k in BACK_KW): mask.add("back")
        if not mask: continue
        entry = exact.get(bname) or normd.get(norm(bname))
        if not entry:
            cand = [(n,e) for n,e in normd.items() if norm(bname) and (norm(bname) in n or n in norm(bname))]
            entry = cand[0][1] if cand else 0
        if not entry: continue
        masks.setdefault(entry, set()).update(mask)
lines = ["-- 200_BOSS能力表_禁站扇区种子.sql（dev/analyzers/seed_boss_avoid.py 生成；幂等 UPDATE）"]
lines.append("-- 正面锥形 -> front；龙类甩尾/尾击 -> back；两者都有 -> 'front,back'")
# frontal 类别一律 front
lines.append("UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `category`='frontal' AND `avoid_sectors`='';")
for entry, mask in sorted(masks.items()):
    val = ",".join(sorted(mask))
    lines.append(f"UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='{val}' WHERE `boss_entry`={entry};")
open(OUT,"w",encoding="utf-8").write("\n".join(lines)+"\n")
print("entries:", len(masks), "->", OUT)
for e,m in sorted(masks.items()):
    print("  ", e, sorted(m))