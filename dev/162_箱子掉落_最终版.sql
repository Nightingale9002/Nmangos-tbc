-- =====================================================================================
-- 162_箱子掉落_最终版.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【定案】站长 2026-10-06：**废弃此前所有"改箱子掉落"的 SQL**（dev/102 接线到 9933、dev/117 按 Wowhead
--   重做 39 个箱子、dev/159 回滚 21 个副本箱、dev/160/161 单独折腾 181798），只保留最终口径：
--     ① 39 个被 dev/117 改过的箱子**全部回到上游原样**（data1 指回原表、并删掉 dev/117 新建的
--        10<GO entry> 表）——这 39 个的原始 data1 与 wotlkmangos / acore_world 两个参考库一致；
--     ② **唯一保留的自定义改动**：181798「Fel Iron Chest」（外域 map 530 世界宝箱，48 个刷点）的
--        接线改为 **21278**（同族 TBC 表：42002 随机物品 100% + 42001 宝石 10% + 50604 卷轴 75% +
--        药水；reference 均为 TBC 内容：42002 = 180 行 ilvl 85-102/需求≥58）。
--        背景：上游两个参考库把 181798 指向 9933（经典 Solid Chest 通用表，Mana Potion/Mageweave 那类）
--        ⇒ 对 70 级外域箱是错的；181798 自带那张表（快照 96 行）同样是经典低级材料。
-- 【前置】本文件假设数据库处于"dev/117 已应用"或"已回滚"或"未应用"任一状态都安全：
--   UPDATE 全部带守卫（仅当 data1 仍是 dev/117 的新表 id 时才改）；DELETE 针对的是 dev/117 新建的表，
--   若已被删除则无效果。幂等，可重复执行。
-- 【生效】掉落/模板启动时载入 ⇒ 需重启（云端随夜间重启）。
-- 【回滚】dev/deprecated/rollback/117_回滚_箱子掉落还原.sql 的反向操作 = 重新执行
--   dev/deprecated/117_箱子掉落按Wowhead重做.sql（7.2MB，含 39 个箱子的全部 117 数据）。
-- =====================================================================================

SET NAMES utf8mb4;

-- ================== ① 39 个箱子回到上游（撤销 dev/117）==================
-- （39 条带守卫的 data1 还原 + 78 条删除 dev/117 新建的掉落表）

UPDATE `gameobject_template` SET `data1` = 2281 WHERE `entry` = 2850 AND `data1` = 902850;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 2282 WHERE `entry` = 2852 AND `data1` = 902852;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 2283 WHERE `entry` = 2855 AND `data1` = 902855;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 2284 WHERE `entry` = 2857 AND `data1` = 902857;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 5278 WHERE `entry` = 4149 AND `data1` = 904149;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 4075 WHERE `entry` = 74447 AND `data1` = 974447;  -- Large Iron Bound Chest
UPDATE `gameobject_template` SET `data1` = 4075 WHERE `entry` = 74448 AND `data1` = 974448;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 4074 WHERE `entry` = 75298 AND `data1` = 975298;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 4076 WHERE `entry` = 75299 AND `data1` = 975299;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 4077 WHERE `entry` = 75300 AND `data1` = 975300;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 5282 WHERE `entry` = 131978 AND `data1` = 1031978;  -- Large Mithril Bound Chest
UPDATE `gameobject_template` SET `data1` = 9931 WHERE `entry` = 153451 AND `data1` = 1053451;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 9932 WHERE `entry` = 153453 AND `data1` = 1053453;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 9933 WHERE `entry` = 153454 AND `data1` = 1053454;  -- Solid Chest
UPDATE `gameobject_template` SET `data1` = 9935 WHERE `entry` = 153463 AND `data1` = 1053463;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 9936 WHERE `entry` = 153464 AND `data1` = 1053464;  -- Large Solid Chest
UPDATE `gameobject_template` SET `data1` = 9935 WHERE `entry` = 153468 AND `data1` = 1053468;  -- Large Mithril Bound Chest
UPDATE `gameobject_template` SET `data1` = 9936 WHERE `entry` = 153469 AND `data1` = 1053469;  -- Large Mithril Bound Chest
UPDATE `gameobject_template` SET `data1` = 21278 WHERE `entry` = 181798 AND `data1` = 1081798;  -- Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 22342 WHERE `entry` = 181800 AND `data1` = 1081800;  -- Heavy Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 22342 WHERE `entry` = 181802 AND `data1` = 1081802;  -- Adamantite Bound Chest
UPDATE `gameobject_template` SET `data1` = 22984 WHERE `entry` = 181804 AND `data1` = 1081804;  -- Felsteel Chest
UPDATE `gameobject_template` SET `data1` = 21717 WHERE `entry` = 184716 AND `data1` = 1084716;  -- Coilskar Chest
UPDATE `gameobject_template` SET `data1` = 21260 WHERE `entry` = 184930 AND `data1` = 1084930;  -- Solid Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21260 WHERE `entry` = 184931 AND `data1` = 1084931;  -- Bound Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21278 WHERE `entry` = 184932 AND `data1` = 1084932;  -- Bound Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21278 WHERE `entry` = 184933 AND `data1` = 1084933;  -- Solid Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21279 WHERE `entry` = 184934 AND `data1` = 1084934;  -- Bound Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21279 WHERE `entry` = 184935 AND `data1` = 1084935;  -- Solid Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21280 WHERE `entry` = 184936 AND `data1` = 1084936;  -- Bound Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21280 WHERE `entry` = 184937 AND `data1` = 1084937;  -- Solid Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21281 WHERE `entry` = 184938 AND `data1` = 1084938;  -- Bound Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21281 WHERE `entry` = 184939 AND `data1` = 1084939;  -- Solid Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21261 WHERE `entry` = 184940 AND `data1` = 1084940;  -- Bound Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21261 WHERE `entry` = 184941 AND `data1` = 1084941;  -- Solid Adamantite Chest
UPDATE `gameobject_template` SET `data1` = 21762 WHERE `entry` = 185168 AND `data1` = 1085168;  -- Reinforced Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 21764 WHERE `entry` = 185169 AND `data1` = 1085169;  -- Reinforced Fel Iron Chest
UPDATE `gameobject_template` SET `data1` = 23324 WHERE `entry` = 187892 AND `data1` = 1087892;  -- Ice Chest
UPDATE `gameobject_template` SET `data1` = 23325 WHERE `entry` = 188124 AND `data1` = 1088124;  -- Ice Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 902850;   -- GO 2850 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 902852;   -- GO 2852 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 902855;   -- GO 2855 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 902857;   -- GO 2857 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 904149;   -- GO 4149 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 974447;   -- GO 74447 Large Iron Bound Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 974448;   -- GO 74448 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 975298;   -- GO 75298 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 975299;   -- GO 75299 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 975300;   -- GO 75300 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1031978;   -- GO 131978 Large Mithril Bound Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053451;   -- GO 153451 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053453;   -- GO 153453 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053454;   -- GO 153454 Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053463;   -- GO 153463 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053464;   -- GO 153464 Large Solid Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053468;   -- GO 153468 Large Mithril Bound Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1053469;   -- GO 153469 Large Mithril Bound Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081798;   -- GO 181798 Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081800;   -- GO 181800 Heavy Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081802;   -- GO 181802 Adamantite Bound Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081804;   -- GO 181804 Felsteel Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084716;   -- GO 184716 Coilskar Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084930;   -- GO 184930 Solid Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084931;   -- GO 184931 Bound Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084932;   -- GO 184932 Bound Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084933;   -- GO 184933 Solid Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084934;   -- GO 184934 Bound Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084935;   -- GO 184935 Solid Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084936;   -- GO 184936 Bound Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084937;   -- GO 184937 Solid Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084938;   -- GO 184938 Bound Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084939;   -- GO 184939 Solid Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084940;   -- GO 184940 Bound Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084941;   -- GO 184941 Solid Adamantite Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1085168;   -- GO 185168 Reinforced Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1085169;   -- GO 185169 Reinforced Fel Iron Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1087892;   -- GO 187892 Ice Chest
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1088124;   -- GO 188124 Ice Chest
DELETE FROM `gameobject_template` WHERE `entry` = 902850;   -- GO 2850 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 902852;   -- GO 2852 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 902855;   -- GO 2855 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 902857;   -- GO 2857 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 904149;   -- GO 4149 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 974447;   -- GO 74447 Large Iron Bound Chest
DELETE FROM `gameobject_template` WHERE `entry` = 974448;   -- GO 74448 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 975298;   -- GO 75298 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 975299;   -- GO 75299 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 975300;   -- GO 75300 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1031978;   -- GO 131978 Large Mithril Bound Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053451;   -- GO 153451 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053453;   -- GO 153453 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053454;   -- GO 153454 Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053463;   -- GO 153463 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053464;   -- GO 153464 Large Solid Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053468;   -- GO 153468 Large Mithril Bound Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1053469;   -- GO 153469 Large Mithril Bound Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1081798;   -- GO 181798 Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1081800;   -- GO 181800 Heavy Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1081802;   -- GO 181802 Adamantite Bound Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1081804;   -- GO 181804 Felsteel Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084716;   -- GO 184716 Coilskar Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084930;   -- GO 184930 Solid Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084931;   -- GO 184931 Bound Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084932;   -- GO 184932 Bound Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084933;   -- GO 184933 Solid Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084934;   -- GO 184934 Bound Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084935;   -- GO 184935 Solid Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084936;   -- GO 184936 Bound Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084937;   -- GO 184937 Solid Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084938;   -- GO 184938 Bound Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084939;   -- GO 184939 Solid Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084940;   -- GO 184940 Bound Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1084941;   -- GO 184941 Solid Adamantite Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1085168;   -- GO 185168 Reinforced Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1085169;   -- GO 185169 Reinforced Fel Iron Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1087892;   -- GO 187892 Ice Chest
DELETE FROM `gameobject_template` WHERE `entry` = 1088124;   -- GO 188124 Ice Chest

-- ================== ② 唯一保留的自定义改动：181798 -> 21278 ==================
-- 去掉 dev/160 残留（若它把 181798 的旧表灌回去过），并接线到 TBC 版同族表
DELETE FROM `gameobject_loot_template` WHERE `entry` = 181798;
UPDATE `gameobject_template` SET `data1` = 21278
 WHERE `entry` = 181798 AND `data1` IN (181798, 1081798, 9933, 21278) AND `data1` <> 21278;

-- ---------- 核对 ----------
-- 期望：181798 = 21278
SELECT `entry`, `name`, `data1` FROM `gameobject_template` WHERE `entry` = 181798;
-- 期望：0 行（dev/117 新建的表全部清除）
SELECT COUNT(*) AS leftover_117_tables FROM `gameobject_loot_template` WHERE `entry` >= 1081798 AND `entry` <= 1088124;
-- 期望：0 行（181798 旧表已清）
SELECT COUNT(*) AS old_181798_rows FROM `gameobject_loot_template` WHERE `entry` = 181798;
-- 期望：21278 的 5 行 TBC 结构
SELECT `entry`, `item`, `ChanceOrQuestChance` AS ch, `groupid` AS g, `mincountOrRef` AS ref, `comments`
  FROM `gameobject_loot_template` WHERE `entry` = 21278 ORDER BY `groupid`, `item`;
