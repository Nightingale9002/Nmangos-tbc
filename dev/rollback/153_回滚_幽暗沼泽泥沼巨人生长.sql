-- =====================================================================================
-- 153_回滚_幽暗沼泽泥沼巨人生长.sql
-- 对应：dev/153_幽暗沼泽泥沼巨人生长_修正.sql        日期：2026-10-06        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 把英雄法术列表 2016401 的循环「生长」放回去，并删掉新增的 EventAI 行。
-- =====================================================================================

-- 删掉新增的 EventAI 行
DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` = 1772302;

-- 放回英雄版法术列表的第 1 位（生长，10 秒循环）
DELETE FROM `tbcmangos`.`creature_spell_list` WHERE `Id` = 2016401 AND `Position` = 1;
INSERT INTO `tbcmangos`.`creature_spell_list`
 (`Id`, `Position`, `SpellId`, `Flags`, `CombatCondition`, `TargetId`, `ScriptId`, `Availability`,
  `Probability`, `InitialMin`, `InitialMax`, `RepeatMin`, `RepeatMax`, `Comments`)
VALUES
 (2016401, 1, 40318, 0, -1, 2, 0, 100, 0, 10000, 10000, 10000, 10000, 'Bog Giant - Growth - self');

-- 核对：期望 2016401 有 3 行（生长/Trample/Fungal Decay）、17723 只剩 1772301
SELECT `Id`, `Position`, `SpellId`, `Comments` FROM `tbcmangos`.`creature_spell_list` WHERE `Id` = 2016401 ORDER BY `Position`;
SELECT `id`, `creature_id`, `comment` FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 17723 ORDER BY `id`;