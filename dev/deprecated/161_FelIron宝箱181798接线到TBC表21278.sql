-- =====================================================================================
-- 161_FelIron宝箱181798接线到TBC表21278.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】dev/160 曾把 181798「Fel Iron Chest」指回它自带的旧表（快照 tbcmangos_orig 的 96 行），
--   那 96 行是**经典低级材料**（Iron Ore / Mithril Ore / Silk Cloth / Truesilver Bar…）⇒ 对 70 级外域
--   世界宝箱是错的（站长："181798 是明确错误的"）。
--   TBC 的正解是**同族**的 reference 结构表（站长提供）：
--     21260/21278/21279「Solid / Bound Fel Iron Chest」= 42002 随机物品 100% + 42001 宝石 10%
--                                                   + 50604 卷轴 75% + 药水（组内 35%/15%）
--   已核对 reference 内容确为 TBC：42001 宝石 ilvl 65-70；42002 180 行 ilvl 85-102、需求等级≥58；
--     50604 卷轴 6 行 ilvl 70、需求等级≥58（都在 tbcmangos.reference_loot_template）。
--   ⇒ 181798 接线到 **21278**（与 184932/184933 Bound Fel Iron Chest 共用同一张表）。
--   注意：181800/181802/181804 的接线（22342/22342/22984）与 wotlkmangos、acore_world 两个参考库
--     完全一致，**本次不动**（这几张表同样是上面那套 TBC reference 结构）。
-- 【做法】① data1 由 181798 改为 21278（守卫）；
--         ② 删除 181798 自带那 96 行（此后无模板指向该表）。
-- 【生效】掉落/模板启动时载入 ⇒ 需重启（云端随夜间重启）。
-- 【回滚】dev/rollback/161_回滚_FelIron宝箱181798.sql
-- =====================================================================================

-- ① 接线到 TBC 版掉落表
UPDATE `gameobject_template` SET `data1` = 21278 WHERE `entry` = 181798 AND `data1` = 181798;

-- ② 清掉旧表那 96 行（已无模板指向）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 181798;

-- ---------- 核对 ----------
-- 期望：data1 = 21278
SELECT `entry`, `name`, `data1` FROM `gameobject_template` WHERE `entry` = 181798;
-- 期望：21278 = 5 行（42001/42002/50604 + 13444/13446），且 181798 旧表 0 行
SELECT `entry`, `item`, `ChanceOrQuestChance` AS ch, `groupid` AS g, `mincountOrRef` AS ref, `maxcount` AS mx, `comments`
  FROM `gameobject_loot_template` WHERE `entry` = 21278 ORDER BY `groupid`, `item`;
SELECT COUNT(*) AS old_181798_rows FROM `gameobject_loot_template` WHERE `entry` = 181798;
