-- =====================================================================================
-- 159_回滚117_副本宝箱21个.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】dev/117「箱子掉落按 Wowhead 重做」把 39 个箱子的 gameobject_template.data1 改指到新建的
--   10<GO entry> 掉落表，并把它们的掉落全部展平成"基本同属 groupid=1（互斥）"的大表：
--     · 城墙英雄尾王箱 185169：原本 21764 = 徽章 29434(100%/g0) + reference 组，被改成 22 行全互斥、
--       徽章只有 0.08% ⇒ 过半概率空箱、且不再必掉徽章（站长实测反馈"尾王箱子掉落不对"）；
--     · 其余副本箱：原本是 5~34 行的 reference 结构（reference_loot_template 里 40034~40039、
--       42001/42002/42004/42005/42007/42008、50604/60446/61000/49000 都齐全），被展平成 86~353 行。
--   ⇒ 站长 2026-10-06 定案：A 组 21 个副本/地下城宝箱**全部回滚**（B 组 18 个旧世界通用宝箱保持不动）。
-- 【做法】① 把 21 个箱子的 data1 用带守卫的 UPDATE 指回旧表（只有仍指向 117 新表时才改）；
--         ② 删除 117 为这 21 个箱子新建的表行（旧表与 reference_loot_template 一直没被动过，无需恢复）。
-- 【生效】gameobject_loot_template / gameobject_template 启动时载入 ⇒ 需重启（云端随夜间重启）。
-- 【回滚】dev/rollback/159_回滚_副本宝箱.sql（重新指回新表并灌回被删的行）
-- =====================================================================================

-- ① data1 指回旧表（守卫：仅当当前仍指向 117 的新表）
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

-- ② 删除 117 新建的掉落行
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081798;  -- Fel Iron Chest（353 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081800;  -- Heavy Fel Iron Chest（243 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081802;  -- Adamantite Bound Chest（238 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1081804;  -- Felsteel Chest（294 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084716;  -- Coilskar Chest（44 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084930;  -- Solid Fel Iron Chest（201 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084931;  -- Bound Fel Iron Chest（200 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084932;  -- Bound Fel Iron Chest（200 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084933;  -- Solid Fel Iron Chest（201 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084934;  -- Bound Fel Iron Chest（202 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084935;  -- Solid Fel Iron Chest（209 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084936;  -- Bound Adamantite Chest（178 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084937;  -- Solid Adamantite Chest（196 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084938;  -- Bound Adamantite Chest（174 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084939;  -- Solid Adamantite Chest（185 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084940;  -- Bound Adamantite Chest（86 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1084941;  -- Solid Adamantite Chest（87 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1085168;  -- Reinforced Fel Iron Chest（14 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1085169;  -- Reinforced Fel Iron Chest（22 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1087892;  -- Ice Chest（10 行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 1088124;  -- Ice Chest（11 行）

-- ---------- 核对 ----------
-- 期望：21 行，全部指回旧表（data1 等于每行注释里的旧值）
SELECT `entry`, `name`, `data1` FROM `gameobject_template`
 WHERE `entry` IN (181798,181800,181802,181804,184716,184930,184931,184932,184933,184934,184935,184936,184937,184938,184939,184940,184941,185168,185169,187892,188124) ORDER BY `entry`;
-- 期望：0 行（117 新建的表已清空）
SELECT COUNT(*) AS leftover_new_tables FROM `gameobject_loot_template`
 WHERE `entry` IN (1081798,1081800,1081802,1081804,1084716,1084930,1084931,1084932,1084933,1084934,1084935,1084936,1084937,1084938,1084939,1084940,1084941,1085168,1085169,1087892,1088124);
-- 期望：城墙英雄尾王箱恢复成 reference 结构（徽章 100% + 4 个 reference）
SELECT `entry`, `item`, `ChanceOrQuestChance`, `groupid`, `mincountOrRef`, `maxcount`
  FROM `gameobject_loot_template` WHERE `entry` = 21764 ORDER BY `groupid`, `item`;
