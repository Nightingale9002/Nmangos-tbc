-- ============================================================================
-- 080_中文中点回退为半角点.sql（2026-09-17）
--
-- 背景（站长游戏内实测）：
--   079 第 12 段（原 dev/081）把中文人名/地名里的中点由半角 · (U+00B7) 统一成了
--   全角 ・ (U+30FB)。但客户端字体没有 U+30FB 的字形，游戏里 NPC / 物品 / 任务名中的
--   这个点会显示成"方块"。站长确认后要求改回原来的半角中点 · (U+00B7)。
--
-- 结论（重要，不要再改回去）：
--   中文中点一律使用【半角 · (U+00B7)】；079 第 12 段的"全角 ・"规则作废。
--
-- 范围：全部 locales_* 表的 _loc4（zhCN）文本列，脚本自动枚举（共 40 列，
--       其中含全角 ・ 的 12 列、合计 9960 行）。已排除 *_bak% / *_dup% 备份表。
-- 幂等：只替换仍含 ・ 的行，可重复执行。
-- 顺序：**必须在 079 之后执行**，否则 079 第 12 段会把中点再改成全角。
-- 生效：locale 数据在 mangosd 启动时载入 → 应用后需重启 mangosd。
-- ============================================================================

SET NAMES utf8mb4;
USE tbcmangos;

-- locales_areatrigger_teleport.Text_loc4: full=0 half=0
UPDATE `locales_areatrigger_teleport` SET `Text_loc4` = REPLACE(`Text_loc4`, '・', '·') WHERE `Text_loc4` LIKE '%・%';

-- locales_creature.name_loc4: full=2474 half=0
UPDATE `locales_creature` SET `name_loc4` = REPLACE(`name_loc4`, '・', '·') WHERE `name_loc4` LIKE '%・%';

-- locales_creature.subname_loc4: full=0 half=12
UPDATE `locales_creature` SET `subname_loc4` = REPLACE(`subname_loc4`, '・', '·') WHERE `subname_loc4` LIKE '%・%';

-- locales_gameobject.closing_text_loc4: full=0 half=0
UPDATE `locales_gameobject` SET `closing_text_loc4` = REPLACE(`closing_text_loc4`, '・', '·') WHERE `closing_text_loc4` LIKE '%・%';

-- locales_gameobject.name_loc4: full=34 half=0
UPDATE `locales_gameobject` SET `name_loc4` = REPLACE(`name_loc4`, '・', '·') WHERE `name_loc4` LIKE '%・%';

-- locales_gameobject.opening_text_loc4: full=0 half=0
UPDATE `locales_gameobject` SET `opening_text_loc4` = REPLACE(`opening_text_loc4`, '・', '·') WHERE `opening_text_loc4` LIKE '%・%';

-- locales_gossip_menu_option.box_text_loc4: full=0 half=0
UPDATE `locales_gossip_menu_option` SET `box_text_loc4` = REPLACE(`box_text_loc4`, '・', '·') WHERE `box_text_loc4` LIKE '%・%';

-- locales_gossip_menu_option.option_text_loc4: full=0 half=40
UPDATE `locales_gossip_menu_option` SET `option_text_loc4` = REPLACE(`option_text_loc4`, '・', '·') WHERE `option_text_loc4` LIKE '%・%';

-- locales_item.description_loc4: full=0 half=35
UPDATE `locales_item` SET `description_loc4` = REPLACE(`description_loc4`, '・', '·') WHERE `description_loc4` LIKE '%・%';

-- locales_item.name_loc4: full=56 half=0
UPDATE `locales_item` SET `name_loc4` = REPLACE(`name_loc4`, '・', '·') WHERE `name_loc4` LIKE '%・%';

-- locales_npc_text.Text0_0_loc4: full=2771 half=0
UPDATE `locales_npc_text` SET `Text0_0_loc4` = REPLACE(`Text0_0_loc4`, '・', '·') WHERE `Text0_0_loc4` LIKE '%・%';

-- locales_npc_text.Text0_1_loc4: full=1544 half=0
UPDATE `locales_npc_text` SET `Text0_1_loc4` = REPLACE(`Text0_1_loc4`, '・', '·') WHERE `Text0_1_loc4` LIKE '%・%';

-- locales_npc_text.Text1_0_loc4: full=0 half=1217
UPDATE `locales_npc_text` SET `Text1_0_loc4` = REPLACE(`Text1_0_loc4`, '・', '·') WHERE `Text1_0_loc4` LIKE '%・%';

-- locales_npc_text.Text1_1_loc4: full=0 half=1307
UPDATE `locales_npc_text` SET `Text1_1_loc4` = REPLACE(`Text1_1_loc4`, '・', '·') WHERE `Text1_1_loc4` LIKE '%・%';

-- locales_npc_text.Text2_0_loc4: full=0 half=7
UPDATE `locales_npc_text` SET `Text2_0_loc4` = REPLACE(`Text2_0_loc4`, '・', '·') WHERE `Text2_0_loc4` LIKE '%・%';

-- locales_npc_text.Text2_1_loc4: full=0 half=7
UPDATE `locales_npc_text` SET `Text2_1_loc4` = REPLACE(`Text2_1_loc4`, '・', '·') WHERE `Text2_1_loc4` LIKE '%・%';

-- locales_npc_text.Text3_0_loc4: full=0 half=12
UPDATE `locales_npc_text` SET `Text3_0_loc4` = REPLACE(`Text3_0_loc4`, '・', '·') WHERE `Text3_0_loc4` LIKE '%・%';

-- locales_npc_text.Text3_1_loc4: full=0 half=12
UPDATE `locales_npc_text` SET `Text3_1_loc4` = REPLACE(`Text3_1_loc4`, '・', '·') WHERE `Text3_1_loc4` LIKE '%・%';

-- locales_npc_text.Text4_0_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text4_0_loc4` = REPLACE(`Text4_0_loc4`, '・', '·') WHERE `Text4_0_loc4` LIKE '%・%';

-- locales_npc_text.Text4_1_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text4_1_loc4` = REPLACE(`Text4_1_loc4`, '・', '·') WHERE `Text4_1_loc4` LIKE '%・%';

-- locales_npc_text.Text5_0_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text5_0_loc4` = REPLACE(`Text5_0_loc4`, '・', '·') WHERE `Text5_0_loc4` LIKE '%・%';

-- locales_npc_text.Text5_1_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text5_1_loc4` = REPLACE(`Text5_1_loc4`, '・', '·') WHERE `Text5_1_loc4` LIKE '%・%';

-- locales_npc_text.Text6_0_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text6_0_loc4` = REPLACE(`Text6_0_loc4`, '・', '·') WHERE `Text6_0_loc4` LIKE '%・%';

-- locales_npc_text.Text6_1_loc4: full=0 half=0
UPDATE `locales_npc_text` SET `Text6_1_loc4` = REPLACE(`Text6_1_loc4`, '・', '·') WHERE `Text6_1_loc4` LIKE '%・%';

-- locales_npc_text.Text7_0_loc4: full=0 half=7
UPDATE `locales_npc_text` SET `Text7_0_loc4` = REPLACE(`Text7_0_loc4`, '・', '·') WHERE `Text7_0_loc4` LIKE '%・%';

-- locales_npc_text.Text7_1_loc4: full=0 half=7
UPDATE `locales_npc_text` SET `Text7_1_loc4` = REPLACE(`Text7_1_loc4`, '・', '·') WHERE `Text7_1_loc4` LIKE '%・%';

-- locales_page_text.Text_loc4: full=17 half=222
UPDATE `locales_page_text` SET `Text_loc4` = REPLACE(`Text_loc4`, '・', '·') WHERE `Text_loc4` LIKE '%・%';

-- locales_points_of_interest.icon_name_loc4: full=0 half=61
UPDATE `locales_points_of_interest` SET `icon_name_loc4` = REPLACE(`icon_name_loc4`, '・', '·') WHERE `icon_name_loc4` LIKE '%・%';

-- locales_quest.Details_loc4: full=815 half=0
UPDATE `locales_quest` SET `Details_loc4` = REPLACE(`Details_loc4`, '・', '·') WHERE `Details_loc4` LIKE '%・%';

-- locales_quest.EndText_loc4: full=33 half=0
UPDATE `locales_quest` SET `EndText_loc4` = REPLACE(`EndText_loc4`, '・', '·') WHERE `EndText_loc4` LIKE '%・%';

-- locales_quest.Objectives_loc4: full=1914 half=0
UPDATE `locales_quest` SET `Objectives_loc4` = REPLACE(`Objectives_loc4`, '・', '·') WHERE `Objectives_loc4` LIKE '%・%';

-- locales_quest.ObjectiveText1_loc4: full=0 half=9
UPDATE `locales_quest` SET `ObjectiveText1_loc4` = REPLACE(`ObjectiveText1_loc4`, '・', '·') WHERE `ObjectiveText1_loc4` LIKE '%・%';

-- locales_quest.ObjectiveText2_loc4: full=0 half=1
UPDATE `locales_quest` SET `ObjectiveText2_loc4` = REPLACE(`ObjectiveText2_loc4`, '・', '·') WHERE `ObjectiveText2_loc4` LIKE '%・%';

-- locales_quest.ObjectiveText3_loc4: full=0 half=1
UPDATE `locales_quest` SET `ObjectiveText3_loc4` = REPLACE(`ObjectiveText3_loc4`, '・', '·') WHERE `ObjectiveText3_loc4` LIKE '%・%';

-- locales_quest.ObjectiveText4_loc4: full=0 half=0
UPDATE `locales_quest` SET `ObjectiveText4_loc4` = REPLACE(`ObjectiveText4_loc4`, '・', '·') WHERE `ObjectiveText4_loc4` LIKE '%・%';

-- locales_quest.OfferRewardText_loc4: full=115 half=0
UPDATE `locales_quest` SET `OfferRewardText_loc4` = REPLACE(`OfferRewardText_loc4`, '・', '·') WHERE `OfferRewardText_loc4` LIKE '%・%';

-- locales_quest.RequestItemsText_loc4: full=50 half=0
UPDATE `locales_quest` SET `RequestItemsText_loc4` = REPLACE(`RequestItemsText_loc4`, '・', '·') WHERE `RequestItemsText_loc4` LIKE '%・%';

-- locales_quest.Title_loc4: full=137 half=0
UPDATE `locales_quest` SET `Title_loc4` = REPLACE(`Title_loc4`, '・', '·') WHERE `Title_loc4` LIKE '%・%';

-- locales_questgiver_greeting.Text_loc4: full=0 half=0
UPDATE `locales_questgiver_greeting` SET `Text_loc4` = REPLACE(`Text_loc4`, '・', '·') WHERE `Text_loc4` LIKE '%・%';

-- locales_trainer_greeting.Text_loc4: full=0 half=0
UPDATE `locales_trainer_greeting` SET `Text_loc4` = REPLACE(`Text_loc4`, '・', '·') WHERE `Text_loc4` LIKE '%・%';

-- 校验：全角中点 U+30FB 应全部为 0（有残留即失败）
SELECT 'locales_areatrigger_teleport.Text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_areatrigger_teleport` WHERE `Text_loc4` LIKE '%・%';
SELECT 'locales_creature.name_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_creature` WHERE `name_loc4` LIKE '%・%';
SELECT 'locales_creature.subname_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_creature` WHERE `subname_loc4` LIKE '%・%';
SELECT 'locales_gameobject.closing_text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_gameobject` WHERE `closing_text_loc4` LIKE '%・%';
SELECT 'locales_gameobject.name_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_gameobject` WHERE `name_loc4` LIKE '%・%';
SELECT 'locales_gameobject.opening_text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_gameobject` WHERE `opening_text_loc4` LIKE '%・%';
SELECT 'locales_gossip_menu_option.box_text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_gossip_menu_option` WHERE `box_text_loc4` LIKE '%・%';
SELECT 'locales_gossip_menu_option.option_text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_gossip_menu_option` WHERE `option_text_loc4` LIKE '%・%';
SELECT 'locales_item.description_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_item` WHERE `description_loc4` LIKE '%・%';
SELECT 'locales_item.name_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_item` WHERE `name_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text0_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text0_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text0_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text0_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text1_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text1_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text1_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text1_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text2_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text2_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text2_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text2_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text3_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text3_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text3_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text3_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text4_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text4_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text4_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text4_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text5_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text5_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text5_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text5_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text6_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text6_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text6_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text6_1_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text7_0_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text7_0_loc4` LIKE '%・%';
SELECT 'locales_npc_text.Text7_1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_npc_text` WHERE `Text7_1_loc4` LIKE '%・%';
SELECT 'locales_page_text.Text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_page_text` WHERE `Text_loc4` LIKE '%・%';
SELECT 'locales_points_of_interest.icon_name_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_points_of_interest` WHERE `icon_name_loc4` LIKE '%・%';
SELECT 'locales_quest.Details_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `Details_loc4` LIKE '%・%';
SELECT 'locales_quest.EndText_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `EndText_loc4` LIKE '%・%';
SELECT 'locales_quest.Objectives_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `Objectives_loc4` LIKE '%・%';
SELECT 'locales_quest.ObjectiveText1_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `ObjectiveText1_loc4` LIKE '%・%';
SELECT 'locales_quest.ObjectiveText2_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `ObjectiveText2_loc4` LIKE '%・%';
SELECT 'locales_quest.ObjectiveText3_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `ObjectiveText3_loc4` LIKE '%・%';
SELECT 'locales_quest.ObjectiveText4_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `ObjectiveText4_loc4` LIKE '%・%';
SELECT 'locales_quest.OfferRewardText_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `OfferRewardText_loc4` LIKE '%・%';
SELECT 'locales_quest.RequestItemsText_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `RequestItemsText_loc4` LIKE '%・%';
SELECT 'locales_quest.Title_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_quest` WHERE `Title_loc4` LIKE '%・%';
SELECT 'locales_questgiver_greeting.Text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_questgiver_greeting` WHERE `Text_loc4` LIKE '%・%';
SELECT 'locales_trainer_greeting.Text_loc4' AS col, COUNT(*) AS leftover_full FROM `locales_trainer_greeting` WHERE `Text_loc4` LIKE '%・%';
