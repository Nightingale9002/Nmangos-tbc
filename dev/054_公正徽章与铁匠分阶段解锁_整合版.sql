-- =============================================================
-- 054 卡布魔兽 · 公正徽章与铁匠分阶段解锁（整合版）
-- 整合自：054（G'eras 分档）、054b（虚空旋涡BoP）、055（Exarch Nasuun 对话）、056（Anwehu 加条件）
-- 用途：完整可重放，覆盖本批次所有改动的数据部分。
-- 依赖条件 id（均 ≤65535，避 service uint16 截断坑）：
--   28023 = quest 10445《永恒水瓶》(G'eras P3 档门槛)
--   28024 = quest 10959《背叛者之死》黑暗神殿·击杀伊利丹(Anwehu P5 档门槛)
-- 生效 reload（顺序重要）：conditions → npc_vendor → npc_vendor_template → item_template → npc_text
-- =============================================================

-- ########## 一、G'eras(guid96654/entry18525) 公正徽章装备分档 ##########
-- 无条件档：装等≤115(110+115 Inferno) + 源生虚空(23572)
-- P3 档(需完成10445)：装等≥128(128/132/133/136) + 虚空旋涡(30183)
-- 0a) 备份
DROP TABLE IF EXISTS npc_vendor_bak_18525_20260830;
CREATE TABLE npc_vendor_bak_18525_20260830 AS SELECT * FROM npc_vendor WHERE entry=18525;
DROP TABLE IF EXISTS conditions_bak_28023_20260830;
CREATE TABLE conditions_bak_28023_20260830 AS SELECT * FROM conditions WHERE condition_entry=28023;

-- 1a) 条件28023：已完成任务10445《永恒水瓶》
INSERT INTO conditions (condition_entry, type, value1, value2, value3, value4, flags, comments)
VALUES (28023, 8, 10445, 0, 0, 0, 0, 'Gera badge P3 gate - quest 10445 Vials of Eternity')
ON DUPLICATE KEY UPDATE comments=VALUES(comments);

-- 2a) P3 档物品挂条件（装等≥128 + 虚空旋涡30183）
UPDATE npc_vendor nv
JOIN item_template i ON i.entry = nv.item
SET nv.condition_id = 28023
WHERE nv.entry = 18525 AND (i.ItemLevel >= 128 OR nv.item = 30183);

-- 3a) 验证（P3档83 / 无条件54）
SELECT 'Gera P3挂条件' AS k, COUNT(*) AS v FROM npc_vendor nv JOIN item_template i ON i.entry=nv.item WHERE nv.entry=18525 AND nv.condition_id=28023;
SELECT 'Gera 无条件' AS k, COUNT(*) AS v FROM npc_vendor nv JOIN item_template i ON i.entry=nv.item WHERE nv.entry=18525 AND nv.condition_id=0;

-- ########## 二、虚空旋涡(30183)改为拾取绑定(BoP) ##########
-- 防"一人完成10445兑换后交易给未完成者"绕过门槛；含掉落一并BoP
-- 0b) 备份
DROP TABLE IF EXISTS item_template_bak_30183_20260830;
CREATE TABLE item_template_bak_30183_20260830 AS SELECT * FROM item_template WHERE entry=30183;

-- 1b) 改拾取绑定
UPDATE item_template SET bonding = 1 WHERE entry = 30183;

-- 2b) 验证
SELECT name, bonding, Quality FROM item_template WHERE entry=30183;

-- ########## 三、Exarch Nasuun(24932) 对话补全：军械库12300 + 铁砧12301 ##########
-- 文本：locales_npc_text.loc4 = 台服中文(zh_ref)；npc_text.text0_0 = 英文fallback(classicmangos_ref)
-- 0c) 备份
DROP TABLE IF EXISTS npc_text_bak_12300_20260830;
CREATE TABLE npc_text_bak_12300_20260830 AS SELECT * FROM npc_text WHERE ID IN (12300,12301);
DROP TABLE IF EXISTS locales_npc_text_bak_12300_20260830;
CREATE TABLE locales_npc_text_bak_12300_20260830 AS SELECT * FROM locales_npc_text WHERE entry IN (12300,12301);

-- 1c) npc_text 主文本（英文 fallback）
INSERT IGNORE INTO npc_text (ID, text0_0, lang0, prob0) VALUES
(12300, "I am glad that you ask. Our efforts to take the armory are at $3233w percent of our projections.$B$BI know that Battlemage Arynna and Harbinger Inuuro need your help. Seek them inside the Sun's Reach Sanctum on the Isle of Quel'Danas.", 0, 1),
(12301, "Last I heard from Hauthaa, she indicated that we are $3228w percent of the way there.$B$BI cannot express how vital it is to our efforts that we get them created. Our men and women are going to need better armor and weapons, and the anvil and forge are the key to that.$B$BYou will find the smith behind the Sun's Reach Armory, $N.", 0, 1);

-- 2c) locales_npc_text loc4 = 台服中文（表无主键，先删再插防重复）
DELETE FROM locales_npc_text WHERE entry IN (12300,12301);
INSERT INTO locales_npc_text (entry, Text0_0_loc4) VALUES
(12300, '我很高兴你问了。我们完成了计画的$3233w％。$B$B我知道战斗法师艾里娜和先驱者因努罗需要你的帮忙。你可以在奎尔丹纳斯岛的日境圣所找到他们。'),
(12301, '我从荷莎那边听来，她说我们才完成了目标的$3228w％。$B$B我无法说明完成这些对我们的计画来说有多重要。我们的男女战士都需要更好的铠甲与武器，而铁砧与熔炉是关键。$B$B你将会在日境军械库找到铁匠，$N。');

-- 3c) 验证
SELECT n.ID, LEFT(n.text0_0,40) main_en, LEFT(l.Text0_0_loc4,40) loc4_zh
FROM npc_text n LEFT JOIN locales_npc_text l ON l.entry=n.ID WHERE n.ID IN (12300,12301);

-- ########## 四、铁匠 Anwehu(27667/template 505) P5 徽章装备加任务10959条件 ##########
-- Anwehu 卖 57 件 P5 太阳之井徽章装备(141/146)，需完成 10959《背叛者之死》(黑暗神殿·击杀伊利丹)
-- Smith Hauthaa(25046) 由 game_event 307 脚本刷新且无售货，本批次不处理。
-- template 505 仅 Anwehu 使用，安全。
-- 0d) 备份
DROP TABLE IF EXISTS npc_vendor_template_bak_505_20260830;
CREATE TABLE npc_vendor_template_bak_505_20260830 AS SELECT * FROM npc_vendor_template WHERE entry=505;
DROP TABLE IF EXISTS conditions_bak_28024_20260830;
CREATE TABLE conditions_bak_28024_20260830 AS SELECT * FROM conditions WHERE condition_entry=28024;

-- 1d) 条件28024：已完成任务10959
INSERT INTO conditions (condition_entry, type, value1, value2, value3, value4, flags, comments)
VALUES (28024, 8, 10959, 0, 0, 0, 0, 'Anwehu badge gear - quest 10959 Fall of the Betrayer (Illidan) rewarded')
ON DUPLICATE KEY UPDATE comments=VALUES(comments);

-- 2d) template 505 全部 57 件挂条件 28024
UPDATE npc_vendor_template SET condition_id = 28024 WHERE entry = 505;

-- 3d) 验证
SELECT COUNT(*) AS tpl_505_total FROM npc_vendor_template WHERE entry=505;
SELECT COUNT(*) AS tpl_505_cond FROM npc_vendor_template WHERE entry=505 AND condition_id=28024;
SELECT condition_entry, type, value1, value2 FROM conditions WHERE condition_entry IN (28023,28024);

-- =============================================================
-- 生效 reload（顺序）：
--   .reload conditions
--   .reload npc_vendor
--   .reload npc_vendor_template
--   .reload item_template
--   .reload npc_text
-- 回滚（逐项）：
--   G'eras 分档：
--     UPDATE npc_vendor nv JOIN npc_vendor_bak_18525_20260830 b ON nv.entry=b.entry AND nv.item=b.item
--     SET nv.condition_id=b.condition_id WHERE nv.entry=18525;
--     DELETE FROM conditions WHERE condition_entry=28023;
--   虚空旋涡：UPDATE item_template SET bonding=0 WHERE entry=30183;
--   Nasuun 对话：DELETE FROM npc_text WHERE ID IN(12300,12301);
--                DELETE FROM locales_npc_text WHERE entry IN(12300,12301);
--   Anwehu：UPDATE npc_vendor_template SET condition_id=0 WHERE entry=505;
--            DELETE FROM conditions WHERE condition_entry=28024;
-- =============================================================
