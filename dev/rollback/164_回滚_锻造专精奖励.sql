-- =====================================================================================
-- 164_回滚_锻造专精奖励.sql
-- 回滚 dev/164_锻造专精奖励改走RewSpellCast_收口脚本路径.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 只回滚本次改动：① RewSpellCast 复位为 0；② 复原被删的 2 行 dbscripts_on_quest_end
-- （字段值取自改动前的原样快照：command 15 CAST_SPELL，其余全 0，condition_id 0）。
-- 【生效】quest_template / dbscripts 均为启动时载入 ⇒ 需重启。
-- =====================================================================================

-- ---------- A. 奖励字段复位 ----------
UPDATE `tbcmangos`.`quest_template`
   SET `RewSpellCast` = 0
 WHERE `entry` = 5283
   AND `RewSpellCast` = 9790;

UPDATE `tbcmangos`.`quest_template`
   SET `RewSpellCast` = 0
 WHERE `entry` = 5284
   AND `RewSpellCast` = 9789;

-- ---------- B. 复原脚本行（先删后插，幂等） ----------
DELETE FROM `tbcmangos`.`dbscripts_on_quest_end` WHERE `id` IN (5283, 5284);

INSERT INTO `tbcmangos`.`dbscripts_on_quest_end`
  (`id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `datalong3`, `buddy_entry`, `search_radius`,
   `data_flags`, `dataint`, `dataint2`, `dataint3`, `dataint4`, `datafloat`, `x`, `y`, `z`, `o`, `speed`,
   `condition_id`, `comments`)
VALUES
  (5283, 0, 0, 15, 9790, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Learn Armorsmithing'),
  (5284, 0, 0, 15, 9789, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Learn Weaponsmithing');

-- ---------- 核对 ----------
-- 期望：5283/5284 RewSpellCast 回到 0
SELECT `entry`, `RewSpell`, `RewSpellCast`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (5283, 5284)
 ORDER BY `entry`;

-- 期望：2 行（5283 → 9790、5284 → 9789）
SELECT `id`, `command`, `datalong`, `comments`
  FROM `tbcmangos`.`dbscripts_on_quest_end`
 WHERE `id` IN (5283, 5284)
 ORDER BY `id`;
