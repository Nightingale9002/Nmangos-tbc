-- =====================================================================
-- 117_回滚_箱子掉落还原.sql
-- 作用：把 39 个箱子 GO 的 data1 还原成旧值，并删除 117 新建的专属模板行
-- 用法：在 tbcmangos 执行本文件即可完整还原到 117 之前的状态
-- =====================================================================

SET NAMES utf8mb4;

-- 一、data1 还原（守卫：仅当已指向新模板时才还原）
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

-- 二、删除新建的专属掉落模板行
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

-- 三、删除新建的 gameobject_template 行
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

-- 旧模板（data1 原值）自始至终未被修改，无需还原。

-- 注意：`dev/117` 末尾还有两处追加（食物池 groupid=900、删除 entry=181798 的 96 行孤立旧表），
-- 回滚本文件会删掉 39 张新模板并把 data1 还原成旧值 ⇒ 食物池改动随之消失（旧 9933 未被改动，不受影响）；
-- 但 ①181798 的孤立旧表行**不会**恢复（本来就无人引用，可按 `tbcmangos_orig` 复制回来）。
