-- dev/128：库斯卡宝箱（GO 184716 Coilskar Chest）的任务碎片恢复"任务限定" —— 2026-09-26
-- ===============================================================
-- 起因（站长："可能我们上一次改包厢掉落改坏了" ⇒ 属实）：
--   dev/117「箱子掉落按Wowhead重做」把 GO 184716 的 data1 从 21717 改指到新表 1084716，
--   新表里 30428「First Fragment of the Cipher of Damnation」（任务 10522 的第一块碎片）
--   被写成 `ChanceOrQuestChance = 10.61`（**正数 = 不做任务限定**，人人可掉），
--   丢掉了旧表 21717 里的 `-12`（**仅身上有该任务的玩家、12%**）。
--
-- 参考（本机 acore_world / WotLK 端）：同一条 = `Chance 12` + `QuestRequired 1` ⇒ 12% 且任务限定 ✓
--   （与我们的旧值 -12 完全等价）
--
-- 影响：不在任务 10522 上的玩家也能从箱子里开出这块任务碎片（占掉落位、白占背包）；
--       在任务上的玩家掉率也从 12% 变成 Wowhead 观测值 10.61%。
--
-- 修法（最小改动）：只把**新表 1084716** 里这一行改回 -12；dev/117 其它 Wowhead 掉落在本服是要的，保持不动。
--   ⚠️ 全量审计过：dev/117 重做的 39 个箱子里，**只有这一处**quest 限定行被改平（其余箱子本来就没有任务限定行）。
--
-- 幂等：带 `<> -12` 守卫的 UPDATE（重复应用 0 变更）
-- 执行对象：world 库（tbcmangos；表名不加库前缀，与 dev/117 等一致）
-- ===============================================================

UPDATE `gameobject_loot_template`
SET `ChanceOrQuestChance` = -12
WHERE `entry` = 1084716
  AND `item` = 30428
  AND `ChanceOrQuestChance` <> -12;

-- 复核（应为 1 行、ChanceOrQuestChance = -12）：
-- SELECT entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount
--   FROM gameobject_loot_template WHERE entry = 1084716 AND item = 30428;
