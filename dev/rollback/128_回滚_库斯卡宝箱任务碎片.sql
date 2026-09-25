-- =====================================================================
-- 回滚 dev/128_库斯卡宝箱任务碎片恢复任务限定.sql
--
-- 作用：把 GO 184716（Coilskar Chest）新掉落表 1084716 里 30428
--       （First Fragment of the Cipher of Damnation）的掉落方式改回
--       dev/117 之后的原样：ChanceOrQuestChance = 10.61（正数、不限定任务）。
--
-- 执行对象：world 库（tbcmangos）
-- 幂等：是（带 <> 守卫）
-- =====================================================================

UPDATE `gameobject_loot_template`
SET `ChanceOrQuestChance` = 10.61
WHERE `entry` = 1084716
  AND `item` = 30428
  AND `ChanceOrQuestChance` <> 10.61;
