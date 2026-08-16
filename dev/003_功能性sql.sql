-- =====================================================
-- 恢复开门任务
-- =====================================================

UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_level` = '68', `required_item` = '24490' WHERE (`id` = '4131');
UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_item` = '24490' WHERE (`id` = '4135');
UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_level` = '70', `required_quest_done` = '10888' WHERE (`id` = '4470');
UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_quest_done` = '10445' WHERE (`id` = '4319');
UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_quest_done` = '10949' WHERE (`id` = '4598');
UPDATE `tbcmangos`.`areatrigger_teleport` SET `required_quest_done` = '10901' WHERE (`id` = '4416');

UPDATE quest_template SET PrevQuestId = 11007 WHERE Entry = 11550;   -- 欺诈者降临前置 = 通关风暴要塞

-- 太阳之井高地入口：完成"大难不死"(11492) 才能进
UPDATE areatrigger_teleport SET required_quest_done = 11492 WHERE id = 4889;

-- 魔导师平台入口：完成"欺诈者降临"(11550) 才能进
UPDATE areatrigger_teleport SET required_quest_done = 11550 WHERE id = 4887;


-- =====================================================
-- 任务物品每人一份
-- =====================================================

-- 所有任务物品（class = 12，Quest 类）加 MULTI_DROP(2048)：团队里每个人都能拾取自己的一份
UPDATE item_template SET Flags = Flags | 2048 WHERE class = 12;

-- 少数被归为 Misc(15) 的团队任务物品（Boss 头/信物）也一并加上
UPDATE item_template SET Flags = Flags | 2048 WHERE entry IN (22520, 32385, 32386, 32405);


-- ============================================================
-- 任务物品掉落率：由 mangosd.conf 的 Rate.Drop.Item.Quest 控制（已设为 100）。
-- 不在 SQL 里统一改 -100，避免把布/草/矿/食材等双重身份材料误伤。
-- （负 chance 的数值大小有意义：实际掉率 = |ChanceOrQuestChance| x Rate.Drop.Item.Quest）
-- ============================================================
