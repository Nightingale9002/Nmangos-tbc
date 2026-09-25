-- 回滚件（整合版）：dev/131_快慢档升级_整合.sql 的完整回滚 —— 2026-09-26
-- 逆序执行各段：① 战备经验豁免 ② 满级奖励任务 ③ 前置/分支任务与挂接 ④ 法术+标记任务+条件
-- ⚠️ 回滚后必须重启 mangosd（自定义法术才会从内存消失）；已发出去的骑术/坐骑无法回收。

-- ===== 来自 135_回滚_战备任务经验不吃快档加成.sql =====
-- 回滚 dev/135：清掉 90140-90158 上的 QUEST_SPECIAL_FLAG_NO_XP_BONUS（|128）
-- ⚠️ 回滚后这些任务的经验会重新被「勤学苦练」的 3 倍光环放大（单次 3,000,000 → 9,000,000）。

UPDATE `quest_template`
SET `SpecialFlags` = `SpecialFlags` & ~128
WHERE `entry` IN (90140, 90141, 90142, 90143, 90144, 90145, 90146, 90147, 90148,
                  90150, 90151, 90152, 90153, 90154, 90155, 90156, 90157, 90158)
  AND (`SpecialFlags` & 128) <> 0;

-- 复核（期望 0 行）：
-- SELECT COUNT(*) FROM quest_template WHERE entry BETWEEN 90140 AND 90158 AND (SpecialFlags & 128) <> 0;


-- ===== 来自 133_回滚_快慢档任务B慢档奖励.sql =====
-- 回滚 dev/133：任务B（90340 联盟 / 90341 部落）+ 影月谷骑术训练师挂接
-- ⚠️ 已经发出去的**大师级骑术 300（技能 762 = 300）与飞行坐骑物品无法回收**（玩家身上已有）。
--    回滚只保证"不再发放"；如需回收，只能 GM 手工处理（坐骑物品可 `.delitem`，骑术技能无法下调）。
-- ⚠️ 依赖条件 5900210 在此之前保持存在（若同时回滚 dev/131，务必先回滚本文件再回滚 131）。

DELETE FROM `creature_questrelation`    WHERE `quest` IN (90340, 90341);
DELETE FROM `creature_involvedrelation` WHERE `quest` IN (90340, 90341);
DELETE FROM `quest_template`            WHERE `entry` IN (90340, 90341);

-- 复核（均应为 0 行）：
-- SELECT COUNT(*) FROM creature_questrelation    WHERE quest IN (90340,90341);
-- SELECT COUNT(*) FROM creature_involvedrelation WHERE quest IN (90340,90341);
-- SELECT COUNT(*) FROM quest_template            WHERE entry IN (90340,90341);


-- ===== 来自 132_回滚_快慢档任务A与挂接.sql =====
-- 回滚 dev/132：任务A（90300-90308）+ 新手村职业训练师挂接
-- ⚠️ 已经用任务A 进入快档的角色：回滚任务A **不会**移除 900001 光环（光环在 character_aura 里，
--    随角色数据持久化）。要一并撤销，需 GM 手动 `.unaura 900001`（或按 dev/131 的回滚说明处理）。

DELETE FROM `creature_questrelation`    WHERE `quest` BETWEEN 90300 AND 90308;
DELETE FROM `creature_involvedrelation` WHERE `quest` BETWEEN 90300 AND 90308;
DELETE FROM `quest_template`            WHERE `entry` BETWEEN 90300 AND 90308;

-- 复核（均应为 0 行）：
-- SELECT COUNT(*) FROM creature_questrelation    WHERE quest BETWEEN 90300 AND 90308;
-- SELECT COUNT(*) FROM creature_involvedrelation WHERE quest BETWEEN 90300 AND 90308;
-- SELECT COUNT(*) FROM quest_template            WHERE entry BETWEEN 90300 AND 90308;


-- ===== 来自 131_回滚_快慢档快档法术与标记.sql =====
-- 回滚 dev/131：快档法术 900001 + 隐藏标记任务 90350 + 条件行
-- ⚠️ 回滚后**必须重启** mangosd，才能让自定义法术彻底从内存里消失。
-- ⚠️ 已经确认过快档的角色身上还有 900001 光环（存在 character_aura 表）——
--    删掉法术行后，重启时 ObjectMgr 会因为找不到该法术而丢弃这些光环（`character_aura` 行仍在，
--    可按需手工清理：DELETE FROM character_aura WHERE spell = 900001;）
-- ⚠️ 已经领过任务B 奖励的骑术/坐骑**无法回收**。

DELETE FROM `spell_template` WHERE `Id` = 900001;
DELETE FROM `quest_template` WHERE `entry` = 90350;
DELETE FROM `conditions` WHERE `condition_entry` IN (5900101, 5900201, 5900210);

-- 复核（应为 0 行 / 0 行 / 0 行）：
-- SELECT COUNT(*) FROM spell_template WHERE Id = 900001;
-- SELECT COUNT(*) FROM quest_template WHERE entry = 90350;
-- SELECT COUNT(*) FROM conditions WHERE condition_entry IN (5900101,5900201,5900210);


