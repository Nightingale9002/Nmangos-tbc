-- ============================================================
-- 064_翻译错译修复_第二批.sql
-- 来自全库(37,238条)英中对应检验 + 人工核实
-- ============================================================
-- 只改 zhCN (name_loc4)。locales_* 启动时加载，需重启或
-- .reload locales_creature 生效。
--
-- 制定：2026-09-12
-- ============================================================


-- ============================================================
-- C 类：可由"同系列一致性"或"错别字"机械确定（8 条）
-- ============================================================

-- C1. 颜色错：Nether Drakonid (Green) 被译成"蓝色"
--     同系列证据：22027(Black)=黑色、22029(Purple)=紫色、22030(Blue)=蓝色、
--                 22032(Boss Green)=虚空龙兽Boss(绿色)
--                 —— 8 条里只有 22031 的 Green 写成了蓝色
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '虚空龙兽(绿色)' WHERE `entry` = 22031;

-- C2/C3/C4. 护甲商整条链错位一格（布甲对、皮/锁/板全错）
--     原状：Cloth=布甲商 ✓ | Leather=板甲商 ✗ | Mail=皮甲商 ✗ | Plate=锁甲商 ✗
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '皮甲商' WHERE `entry` = 26305;  -- Leather
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '锁甲商' WHERE `entry` = 26306;  -- Mail
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '板甲商' WHERE `entry` = 26308;  -- Plate

-- C5. 阵营错：Horde 被译成"联盟"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '2.3 部落日常除错' WHERE `entry` = 24481;

-- C6. 错别字："地狱猎犬"写成了"地域猎犬"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '地狱猎犬训练师' WHERE `entry` = 5007;

-- C7. 整名错配：英文 "Half-eaten body"（吃了一半的尸体），
--     中文却是 "[DND] Wounded Lion's Footman"（完全不同的东西）
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '吃了一半的尸体' WHERE `entry` = 262;

-- C8. Ground Flower（地花）被译成"爆竹"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '地花' WHERE `entry` = 25518;


-- ============================================================
-- D 类：人名/命名类，需要你确认译法后再执行（2 条）
-- ============================================================

-- D1. LePeux (24503) 是一个人名，线上却是"臭鼬"
-- UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '勒珀' WHERE `entry` = 24503;

-- D2. Jebediah McWeaksauce (24989) 是人名，线上却是"尊特拉华达"（另一个人）
-- UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '杰贝迪亚·麦克威克索斯' WHERE `entry` = 24989;


-- ============================================================
-- 验证
-- ============================================================
-- SELECT ct.Entry, ct.Name, lc.name_loc4 FROM tbcmangos.creature_template ct
--   JOIN tbcmangos.locales_creature lc ON lc.entry=ct.Entry
--   WHERE ct.Entry IN (22031,26305,26306,26308,24481,5007,262,25518);
-- SELECT ct.Entry, ct.Name, lc.name_loc4 FROM tbcmangos.creature_template ct
--   JOIN tbcmangos.locales_creature lc ON lc.entry=ct.Entry
--   WHERE ct.Name LIKE 'Nether Drakonid%' OR ct.Name LIKE '%Armor Vendor%' ORDER BY ct.Entry;

-- ============================================================
-- 回滚
-- ============================================================
-- UPDATE tbcmangos.locales_creature SET name_loc4='虚空龙兽(蓝色)' WHERE entry=22031;
-- UPDATE tbcmangos.locales_creature SET name_loc4='板甲商' WHERE entry=26305;
-- UPDATE tbcmangos.locales_creature SET name_loc4='皮甲商' WHERE entry=26306;
-- UPDATE tbcmangos.locales_creature SET name_loc4='锁甲商' WHERE entry=26308;
-- UPDATE tbcmangos.locales_creature SET name_loc4='2.3 联盟日常除错' WHERE entry=24481;
-- UPDATE tbcmangos.locales_creature SET name_loc4='地域猎犬训练师' WHERE entry=5007;
-- UPDATE tbcmangos.locales_creature SET name_loc4='[DND] Wounded Lion''s Footman' WHERE entry=262;
-- UPDATE tbcmangos.locales_creature SET name_loc4='爆竹' WHERE entry=25518;
