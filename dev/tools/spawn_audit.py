#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""刷点体检：找出"永远刷不出东西"的刷点，以及会被加载器跳过的刷怪组成员。

背景（dev/KNOWN_ISSUES.md 2026-10-01）：在 dynguid / 刷怪组系统里，一个刷点能否生成对象取决于
"谁能提供 entry"：
  * `creature.id` / `gameobject.id` 本身（OwnEntry），或
  * 该行自己的随机候选 `creature_spawn_entry` / `gameobject_spawn_entry`（RandomEntry），或
  * 它所属刷怪组的 `spawn_group_entry` / `spawn_group_squad`。
`id = 0` 且三者都没有的行会解析成 entry 0 ⇒ **什么都不生成，而且核心不报错**。
本脚本把这批行、以及"属于池/游戏事件因而会被刷怪组加载器跳过"的成员列出来。

用法：
    python spawn_audit.py                 # 打印摘要
    python spawn_audit.py --list 50       # 每类最多列 50 条明细
    python spawn_audit.py --tsv out.tsv   # 额外导出明细
退出码：0 = 没发现问题；1 = 发现"永远刷不出"的刷点。
"""
import argparse
import subprocess
import sys

MYSQL = r"C:\Program Files\MySQL\MySQL Server 9.3\bin\mysql.exe"
DB = "tbcmangos"


def q(sql):
    out = subprocess.run([MYSQL, '-h', '127.0.0.1', '-u', 'root', '-pqwerty', DB,
                          '-N', '--batch', '--raw', '--default-character-set=utf8mb4', '-e', sql],
                         capture_output=True, text=True, encoding='utf-8', errors='replace')
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        raise SystemExit('query failed')
    return [l.split('\t') for l in out.stdout.splitlines() if l.strip()]


BROKEN_CREATURE = """
SELECT c.guid, c.map, 'creature' AS kind,
       IFNULL((SELECT sg.Id FROM spawn_group_spawn sgs JOIN spawn_group sg ON sg.Id = sgs.Id
               WHERE sgs.Guid = c.guid LIMIT 1), 0) AS group_id
FROM creature c
WHERE c.id = 0
  AND NOT EXISTS (SELECT 1 FROM creature_spawn_entry s WHERE s.guid = c.guid)
  AND NOT EXISTS (SELECT 1 FROM spawn_group_spawn sgs
                  WHERE sgs.Guid = c.guid
                    AND EXISTS (SELECT 1 FROM spawn_group_entry e WHERE e.Id = sgs.Id)
                    AND EXISTS (SELECT 1 FROM spawn_group_spawn s2 WHERE s2.Id = sgs.Id)
                    AND sgs.Id IN (SELECT e.Id FROM spawn_group_entry e))
ORDER BY c.map, c.guid
"""

# 上面的 spawn_group_entry 存在性判断要写成"该组有随机候选"；用 EXISTS 而不是 JOIN 以免重复计数
BROKEN_CREATURE = """
SELECT c.guid, c.map, 'creature' AS kind,
       IFNULL((SELECT sgs.Id FROM spawn_group_spawn sgs WHERE sgs.Guid = c.guid LIMIT 1), 0) AS group_id
FROM creature c
WHERE c.id = 0
  AND NOT EXISTS (SELECT 1 FROM creature_spawn_entry s WHERE s.guid = c.guid)
  AND NOT EXISTS (SELECT 1 FROM spawn_group_spawn sgs
                  WHERE sgs.Guid = c.guid
                    AND (EXISTS (SELECT 1 FROM spawn_group_entry e WHERE e.Id = sgs.Id)
                         OR EXISTS (SELECT 1 FROM spawn_group_squad q WHERE q.Id = sgs.Id)))
ORDER BY c.map, c.guid
"""

BROKEN_GAMEOBJECT = """
SELECT g.guid, g.map, 'gameobject' AS kind,
       IFNULL((SELECT sgs.Id FROM spawn_group_spawn sgs WHERE sgs.Guid = g.guid LIMIT 1), 0) AS group_id
FROM gameobject g
WHERE g.id = 0
  AND NOT EXISTS (SELECT 1 FROM gameobject_spawn_entry s WHERE s.guid = g.guid)
  AND NOT EXISTS (SELECT 1 FROM spawn_group_spawn sgs
                  WHERE sgs.Guid = g.guid
                    AND (EXISTS (SELECT 1 FROM spawn_group_entry e WHERE e.Id = sgs.Id)
                         OR EXISTS (SELECT 1 FROM spawn_group_squad q WHERE q.Id = sgs.Id)))
ORDER BY g.map, g.guid
"""

SKIPPED_GROUP_MEMBERS = """
SELECT sgs.Id AS group_id, sgs.Guid, c.map, sg.Name
FROM spawn_group_spawn sgs
JOIN creature c ON c.guid = sgs.Guid
JOIN spawn_group sg ON sg.Id = sgs.Id
WHERE EXISTS (SELECT 1 FROM pool_creature pc WHERE pc.guid = sgs.Guid)
   OR EXISTS (SELECT 1 FROM game_event_creature ec WHERE ec.guid = sgs.Guid)
ORDER BY sgs.Id, sgs.Guid
"""

ORPHAN_POOL_MEMBERS = """
SELECT 'pool_creature' AS kind, pc.guid, IFNULL(c.map, -1) AS map, pc.pool_entry AS pool
FROM pool_creature pc LEFT JOIN creature c ON c.guid = pc.guid
WHERE c.guid IS NULL
UNION ALL
SELECT 'pool_gameobject', pg.guid, IFNULL(g.map, -1), pg.pool_entry
FROM pool_gameobject pg LEFT JOIN gameobject g ON g.guid = pg.guid
WHERE g.guid IS NULL
ORDER BY kind, pool
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', type=int, default=20, help='每类最多列多少条明细（默认 20，0 = 不列）')
    ap.add_argument('--tsv', help='把明细导出到该文件')
    args = ap.parse_args()

    broken = [(r[0], r[1], r[2], r[3]) for r in q(BROKEN_CREATURE)] + \
             [(r[0], r[1], r[2], r[3]) for r in q(BROKEN_GAMEOBJECT)]
    skipped = q(SKIPPED_GROUP_MEMBERS)
    orphans = q(ORPHAN_POOL_MEMBERS)

    by_map = {}
    for guid, mp, kind, gid in broken:
        by_map.setdefault(mp, []).append((guid, kind, gid))

    print('=' * 78)
    print('刷点体检（%s）' % DB)
    print('=' * 78)
    print('1) 永远刷不出的刷点（id=0、无自身候选、所在刷怪组也没有随机候选）: %d 个' % len(broken))
    if by_map:
        for mp, rows in sorted(by_map.items(), key=lambda kv: -len(kv[1])):
            print('   map %-5s : %d 个' % (mp, len(rows)))
        if args.list:
            print('   --- 明细（最多 %d 条）---' % args.list)
            for guid, mp, kind, gid in broken[:args.list]:
                print('     %-9s guid %-9s map %-5s group %s' % (kind, guid, mp, gid or '-'))
    print()
    print('2) 会被刷怪组加载器跳过的成员（同时属于池 / 游戏事件，两者不兼容）: %d 个' % len(skipped))
    for gid, guid, mp, name in skipped[:args.list]:
        print('     group %-9s guid %-9s map %-5s %s' % (gid, guid, mp, name))
    print()
    print('3) 池成员但本体不存在的（池里挂了空 guid）: %d 个' % len(orphans))
    for kind, guid, mp, pool in orphans[:args.list]:
        print('     %-9s guid %-9s map %-5s pool %s' % (kind, guid, mp, pool))

    if args.tsv:
        with open(args.tsv, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('kind\tguid\tmap\tgroup_or_pool\n')
            for guid, mp, kind, gid in broken:
                fh.write('%s\t%s\t%s\t%s\n' % (kind, guid, mp, gid))
            for gid, guid, mp, name in skipped:
                fh.write('skipped_group_member\t%s\t%s\t%s\n' % (guid, mp, gid))
            for kind, guid, mp, pool in orphans:
                fh.write('orphan_%s\t%s\t%s\t%s\n' % (kind, guid, mp, pool))
        print('\n明细已写入 %s' % args.tsv)

    return 1 if broken else 0


if __name__ == '__main__':
    sys.exit(main())
