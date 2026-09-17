USE tbcmangos;
-- 075_精英刷新统一600秒（10分钟）.sql（2026-09-17）
--
-- 背景：071 的定案原本是"普通怪(rank0) 300 秒 / 精英(rank1) 900 秒"，但**合并成 071 时"精英→900"这一段丢了**
--       （071 现在只有 15 条 UPDATE，只剩文件头那行说明）→ 本地因为早先单独跑过旧的
--       `dev/074_精英刷新统一900秒.sql` 而是 900，**云端从未执行过**（例：18411 Durn the Hungerer 云端 600/1500）。
-- 站长 2026-09-17 重新定案：**随机区间没意义 → 精英(rank1) 一律统一 600 秒（10 分钟）**，
--       不再保留 600/1500 这类随机窗口。本文件实现该定案。
--
-- 范围（与 071 的"精英"口径一致，环境无关，按规则写而不是 entry 列表）：
--   ① creature_template.Rank = 1（精英）
--   ② 世界地图 map IN (0, 1, 530)（不动副本/战场）
--   ③ 有掉落（LootId / PickpocketLootId / SkinningLootId 任一非 0）
--   ④ 无 ScriptName（脚本驱动的怪交给脚本）
--   ⑤ NpcFlags = 0（不是商人/训练师/任务发布者等）
--   ⑥ CreatureType <> 8（排除小动物/杂项）
--   ⑦ 排除**真实活动刷点**（该 guid 登记在 game_event_creature 且对应 event 存在于 game_event 表；
--      活动怪的刷新时间只在活动期间起作用，动了会破坏活动节奏）——这同时覆盖了 15743/15744 这类
--      "同一 entry 既有活动刷点又有普通刷点"的情况（按 guid 排除，不按 entry）。
--   含刷怪组成员（不排除 spawn_group 成员）。
--   **稀有（rank2 稀有精英 / rank4 稀有）与世界 boss（rank3）一律不动。**
--
-- 云端只读预演（2026-09-17，逐档 COUNT）：
--   范围内共 1,236 刷点 / 233 entry，其中 =600 已有 401 / 75，需要改的 **835 刷点 / 157 entry**：
--     · 原值 >600 或区间（会变快）：448 刷点 / 58 entry（最大 172800 秒）
--     · 原值 max<600（会变慢，多为 071 之前被当普通怪改成 300 的精英）：387 刷点 / 100 entry
-- 幂等：带目标值判断，可重复执行。生效需重启 mangosd（creature 表启动时载入）。

-- ============ 精英(rank1) 统一 600 秒 ============
UPDATE creature c
  JOIN creature_template t ON t.Entry = c.id
   SET c.spawntimesecsmin = 600, c.spawntimesecsmax = 600
 WHERE t.Rank = 1
   AND c.map IN (0, 1, 530)
   AND (t.ScriptName IS NULL OR t.ScriptName = '')
   AND t.NpcFlags = 0
   AND t.CreatureType <> 8
   AND (t.LootId <> 0 OR t.PickpocketLootId <> 0 OR t.SkinningLootId <> 0)
   AND NOT EXISTS (SELECT 1 FROM game_event_creature g JOIN game_event e ON e.entry = g.event WHERE g.guid = c.guid)
   AND (c.spawntimesecsmin <> 600 OR c.spawntimesecsmax <> 600);

-- ============ 校验 ============
-- 1) 范围内应再无"非 600"的行（本地应为 0；云端应用后应为 0）
SELECT COUNT(*) AS residual_not_600
  FROM creature c JOIN creature_template t ON t.Entry = c.id
 WHERE t.Rank = 1 AND c.map IN (0, 1, 530)
   AND (t.ScriptName IS NULL OR t.ScriptName = '')
   AND t.NpcFlags = 0 AND t.CreatureType <> 8
   AND (t.LootId <> 0 OR t.PickpocketLootId <> 0 OR t.SkinningLootId <> 0)
   AND NOT EXISTS (SELECT 1 FROM game_event_creature g JOIN game_event e ON e.entry = g.event WHERE g.guid = c.guid)
   AND (c.spawntimesecsmin <> 600 OR c.spawntimesecsmax <> 600);

-- 2) 抽查：18411 Durn the Hungerer（云端原为 600/1500）
SELECT c.guid, c.id, t.Name, t.Rank, c.spawntimesecsmin, c.spawntimesecsmax
  FROM creature c JOIN creature_template t ON t.Entry = c.id WHERE c.id = 18411;

-- 3) 稀有/世界 boss（rank2/3/4）**不在本语句范围内**，这里只列出它们当前的值供对照（本语句不会改它们）
SELECT COUNT(*) AS rare_or_boss_rows_total,
       SUM(c.spawntimesecsmin = 600 AND c.spawntimesecsmax = 600) AS rare_or_boss_at_600_before
  FROM creature c JOIN creature_template t ON t.Entry = c.id
 WHERE t.Rank IN (2, 3, 4) AND c.map IN (0, 1, 530);
