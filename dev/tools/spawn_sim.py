#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""刷怪组离线模拟器：不加载地图，直接在数据库上复现 `SpawnGroup::Spawn` 的规则，
算出"每个刷怪组成员会刷出什么 entry、会不会生成"。

为什么要它：实例地图只有玩家进入才会创建，服务端里"造一个无玩家实例 + 强制加载网格"的路子
会在网格加载阶段崩（2026-10-01 实测崩在 creature guid 5520093），而在实例里验证刷怪组又是刚需
（例如"禁魔监狱缺艾瑞达"）。这里把规则搬到离线，既不碰地图加载、又能一次把所有副本算出来。

复现的规则（与 src/game/Maps/SpawnGroup.cpp / Globals/ObjectMgr.cpp 对齐）：
  * entry 来源优先级：`RandomEntry`（有 creature_spawn_entry）> `OwnEntry`（creature.id != 0）
    > NOTHING > 组的 `spawn_group_entry`（`GetEligibleEntry`）
  * `MaxCount == 0` 时由 ObjectMgr 载入阶段推导（见 load_deductions）
  * 候选池：EqualChanced（Chance==0）与 ExplicitlyChanced（Chance>0），各自带 MaxCount/MinCount
  * 配额：validEntries（每 entry 剩余额度）与 minEntries（MinCount 剩余）
  * 成员筛选：世界里已有对象（跳过）/ 重生时间未到（MaxCount==1 时整体阻塞）/ spawnMask 与难度不符
  * `Chance` 成员：每个 guid 只掷一次（m_chosenSpawns 记忆）
  * 地图为副本时：entry 在"首次生成"时定下并记忆（m_chosenEntries）
  * squad：随机选一个 squad，成员由 squad 的 guid→entry 决定

用法：
    python spawn_sim.py 552                 # 模拟一张图（多次采样给概率）
    python spawn_sim.py 552 --runs 200
    python spawn_sim.py --list-instances    # 列出本地库所有副本地图及其刷怪组数量
    python spawn_sim.py 552 --tsv out.tsv
"""
import argparse
import random
import subprocess
import sys
from collections import Counter, defaultdict

MYSQL = r"C:\Program Files\MySQL\MySQL Server 9.3\bin\mysql.exe"
DB = "tbcmangos"


def q(sql):
    out = subprocess.run([MYSQL, '-h', '127.0.0.1', '-u', 'root', '-pqwerty', DB,
                          '-N', '--batch', '--raw', '--default-character-set=utf8mb4', '-e', sql],
                         capture_output=True, text=True, encoding='utf-8', errors='replace')
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        raise SystemExit('query failed:\n' + sql)
    return [l.split('\t') for l in out.stdout.splitlines() if l.strip()]


class Group:
    def __init__(self, gid, name, gtype, maxcount, wscond, flags, enabled):
        self.id = gid
        self.name = name
        self.type = gtype               # 0 = creature, 1 = gameobject
        self.maxcount = maxcount        # 0 => 载入阶段推导
        self.wscond = wscond
        self.flags = flags
        self.enabled = enabled
        self.members = []               # [(dbguid, slotid, chance)]
        self.entries = []               # [(entry, mincount, maxcount, chance)]
        self.squads = defaultdict(dict)  # squad_id -> {guid: entry}
        self.equally = []
        self.explicit = []

    def deduce(self):
        """复现 ObjectMgr::LoadSpawnGroups 结尾对 MaxCount/候选分组的推导。"""
        if self.maxcount == 0:
            max_random = sum(e[2] for e in self.entries)
            if any(e[3] == 0 for e in self.entries):
                self.maxcount = len(self.members)
            else:
                self.maxcount = min(max_random, len(self.members))
            if not self.maxcount and not self.entries:
                self.maxcount = len(self.members)
        self.equally = [e for e in self.entries if e[3] == 0]
        self.explicit = [e for e in self.entries if e[3] != 0]


def load(mapid):
    groups = {}
    for row in q("SELECT Id, Name, Type, MaxCount, WorldState, Flags FROM spawn_group"):
        groups[int(row[0])] = Group(int(row[0]), row[1], int(row[2]), int(row[3]),
                                    int(row[4]), int(row[5]), 1)
    for row in q("SELECT Id, Guid, SlotId, Chance FROM spawn_group_spawn"):
        gid = int(row[0])
        if gid in groups:
            groups[gid].members.append((int(row[1]), int(row[2]), int(row[3])))
    for row in q("SELECT Id, Entry, MinCount, MaxCount, Chance FROM spawn_group_entry"):
        gid = int(row[0])
        if gid in groups:
            groups[gid].entries.append((int(row[1]), int(row[2]), int(row[3]), int(row[4])))
    for row in q("SELECT Id, SquadId, Guid, Entry FROM spawn_group_squad"):
        gid = int(row[0])
        if gid in groups:
            groups[gid].squads[int(row[1])][int(row[2])] = int(row[3])

    # 生物数据：map / id / spawnMask / 自身随机候选
    creature = {}
    for row in q("SELECT c.guid, c.id, c.map, c.spawnMask, "
                 "(SELECT COUNT(*) FROM creature_spawn_entry s WHERE s.guid = c.guid) "
                 "FROM creature c WHERE c.map = %d" % mapid):
        creature[int(row[0])] = {'id': int(row[1]), 'map': int(row[2]),
                                 'mask': int(row[3]), 'ownRand': int(row[4])}
    return groups, creature


def simulate(groups, creature, difficulty, rng):
    """返回 {group_id: [(dbguid, entry, 'ok'|'entry0'), ...]} 以及未生成原因统计。"""
    result = {}
    reasons = Counter()
    for gid, g in sorted(groups.items()):
        if g.type != 0:
            continue
        own = [m for m in g.members if m[0] in creature]   # 只模拟本图成员
        if not own:
            continue
        g.deduce()
        if not g.enabled:
            reasons['group disabled (spawnMask 0)'] += 1
            continue
        if g.wscond:
            reasons['group has worldstate condition (assumed not satisfied)'] += 1
            continue

        # spawnmask 过滤
        eligible = [m for m in own if (creature[m[0]]['mask'] & (1 << difficulty))]
        skipped_mask = len(own) - len(eligible)

        spawned = []
        # 世界里已有对象/重生时间：离线模拟假设"副本刚开、都在冷却外、世界里没有对象"
        if len(eligible) > g.maxcount:
            rng.shuffle(eligible)
            eligible = eligible[:g.maxcount]

        # 配额
        valid = {e[0]: (e[2] if e[2] > 0 else 10 ** 9) for e in g.entries}
        mins = {e[0]: e[1] for e in g.entries if e[1] > 0}
        chosen_squad = None
        if g.squads:
            squad_ids = sorted(g.squads)
            chosen_squad = rng.choice(squad_ids)
            eligible = [m for m in eligible if m[0] in g.squads[chosen_squad]]

        def pick_entry():
            if mins:
                e = rng.choice(sorted(mins))
                return e
            if g.explicit:
                roll = rng.randint(1, 100)
                for e in sorted(g.explicit, key=lambda x: x[0]):
                    if valid.get(e[0], 0) > 0:
                        if roll <= e[3]:
                            return e[0]
                        roll -= e[3]
            if g.equally:
                cand = [e[0] for e in g.equally if valid.get(e[0], 0) > 0]
                if cand:
                    return rng.choice(cand)
            return 0

        for dbguid, _slot, chance in eligible:
            if chance:                                  # HasChancedSpawns：每个 guid 只掷一次
                if rng.randint(1, 100) > chance:
                    continue
            data = creature[dbguid]
            if data['ownRand']:
                entry = 'random(own table)'             # creature_spawn_entry 有候选
            elif data['id']:
                entry = data['id']
            elif chosen_squad is not None:
                entry = g.squads[chosen_squad].get(dbguid, 0)
            else:
                entry = pick_entry()
                if valid.get(entry):
                    valid[entry] -= 1
                if entry in mins:
                    mins[entry] -= 1
                    if mins[entry] == 0:
                        del mins[entry]
            if entry in (0, 'random(own table)'):
                spawned.append((dbguid, entry))
            else:
                spawned.append((dbguid, entry))
        if skipped_mask:
            reasons['members skipped by spawnMask/difficulty'] += skipped_mask
        zero = sum(1 for _g, e in spawned if e == 0)
        if zero:
            reasons['members resolved to entry 0 (nothing spawns)'] += zero
        result[gid] = spawned
    return result, reasons


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('mapid', nargs='?', type=int)
    ap.add_argument('--runs', type=int, default=100, help='采样次数（给概率）')
    ap.add_argument('--difficulty', type=int, default=0, help='0=普通 1=英雄')
    ap.add_argument('--list-instances', action='store_true')
    ap.add_argument('--tsv')
    ap.add_argument('--top', type=int, default=25)
    args = ap.parse_args()

    if args.list_instances:
        rows = q("SELECT c.map, COUNT(DISTINCT sgs.Id) AS groups_cnt, COUNT(*) AS members "
                 "FROM creature c JOIN spawn_group_spawn sgs ON sgs.Guid = c.guid "
                 "JOIN instance_template it ON it.map = c.map "
                 "GROUP BY c.map ORDER BY c.map")
        print('副本地图 / 有刷怪组的成员数:')
        for mp, gcnt, members in rows:
            print('  map %-5s groups %-4s members %s' % (mp, gcnt, members))
        return 0

    if not args.mapid:
        ap.error('需要 mapid（或用 --list-instances）')

    groups, creature = load(args.mapid)
    per_group = defaultdict(Counter)
    zero_reports = []
    reason_total = Counter()
    for i in range(args.runs):
        rng = random.Random(1000 + i)
        res, reasons = simulate(groups, creature, args.difficulty, rng)
        for gid, spawned in res.items():
            for dbguid, entry in spawned:
                per_group[gid][(dbguid, entry)] += 1
        reason_total.update(reasons)

    print('=' * 92)
    print('刷怪组离线模拟：map %u（难度 %u，采样 %u 次）' % (args.mapid, args.difficulty, args.runs))
    print('=' * 92)
    unresolved = 0
    for gid in sorted(per_group):
        g = groups[gid]
        print('\n[group %u] %s   MaxCount=%u  members=%u  entries=%u  squads=%u'
              % (gid, g.name, g.maxcount, len(g.members), len(g.entries), len(g.squads)))
        rows = []
        for (dbguid, entry), cnt in sorted(per_group[gid].items(), key=lambda kv: -kv[1]):
            pct = 100.0 * cnt / args.runs
            data = creature.get(dbguid, {})
            rows.append((dbguid, entry, pct, data.get('id', '?')))
        for dbguid, entry, pct, own in rows[:args.top]:
            if entry == 0:
                unresolved += 1
                tag = '  <== entry 0：什么都不会生成'
            else:
                tag = ''
            print('    guid %-9s entry %-22s %5.1f%%%s' % (dbguid, entry, pct, tag))
        if len(rows) > args.top:
            print('    ...（还有 %d 行）' % (len(rows) - args.top))

    print('\n--- 汇总 ---')
    print('  有成员生成的组: %d' % len(per_group))
    for k, v in reason_total.most_common():
        print('  %-55s %d' % (k, v))
    if unresolved:
        print('  ⚠ 有 %d 个 (组,成员) 组合解析成 entry 0 —— 用 spawn_audit.py 看全库清单' % unresolved)

    if args.tsv:
        with open(args.tsv, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('group_id\tgroup_name\tdbguid\tentry\tprobability\tmember_own_entry\n')
            for gid in sorted(per_group):
                for (dbguid, entry), cnt in sorted(per_group[gid].items()):
                    fh.write('%d\t%s\t%d\t%s\t%.3f\t%s\n'
                             % (gid, groups[gid].name, dbguid, entry, cnt / args.runs,
                                creature.get(dbguid, {}).get('id', '')))
        print('\n明细已写入 %s' % args.tsv)
    return 0


if __name__ == '__main__':
    sys.exit(main())
