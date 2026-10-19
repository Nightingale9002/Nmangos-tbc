-- 179 台词补录：PlayerBots 模块里原先硬编码的英文玩家可见提示，改为走 ai_playerbot_texts 台词表。
-- 配套代码改动：BOT_TEXT("英文原句") —— name/text 存英文原句，text_loc4 存中文（zhCN）。
-- 幂等：每条先做「不存在才插入」，再无条件 UPDATE 一次英文/中文文本；重复执行结果不变。
-- 注意：本表 name 列没有唯一索引，且已有 127 个重名，所以不能用 ON DUPLICATE KEY UPDATE。

SET NAMES utf8mb4;

INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Attack Targets ---', '--- Attack Targets ---', '--- 攻击目标 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Attack Targets ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Attack Targets ---', `text_loc4` = '--- 攻击目标 ---' WHERE `name` = '--- Attack Targets ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Attackers ---', '--- Attackers ---', '--- 攻击者 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Attackers ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Attackers ---', `text_loc4` = '--- 攻击者 ---' WHERE `name` = '--- Attackers ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Completed quests ---', '--- Completed quests ---', '--- 已完成任务 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Completed quests ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Completed quests ---', `text_loc4` = '--- 已完成任务 ---' WHERE `name` = '--- Completed quests ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Elixir ---', '--- Elixir ---', '--- 药剂 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Elixir ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Elixir ---', `text_loc4` = '--- 药剂 ---' WHERE `name` = '--- Elixir ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Enchant ---', '--- Enchant ---', '--- 附魔 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Enchant ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Enchant ---', `text_loc4` = '--- 附魔 ---' WHERE `name` = '--- Enchant ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Flask ---', '--- Flask ---', '--- 合剂 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Flask ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Flask ---', `text_loc4` = '--- 合剂 ---' WHERE `name` = '--- Flask ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Food ---', '--- Food ---', '--- 食物 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Food ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Food ---', `text_loc4` = '--- 食物 ---' WHERE `name` = '--- Food ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Incompleted quests ---', '--- Incompleted quests ---', '--- 未完成任务 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Incompleted quests ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Incompleted quests ---', `text_loc4` = '--- 未完成任务 ---' WHERE `name` = '--- Incompleted quests ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Scroll ---', '--- Scroll ---', '--- 卷轴 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Scroll ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Scroll ---', `text_loc4` = '--- 卷轴 ---' WHERE `name` = '--- Scroll ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Summary ---', '--- Summary ---', '--- 汇总 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Summary ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Summary ---', `text_loc4` = '--- 汇总 ---' WHERE `name` = '--- Summary ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- Threat ---', '--- Threat ---', '--- 仇恨 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- Threat ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- Threat ---', `text_loc4` = '--- 仇恨 ---' WHERE `name` = '--- Threat ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- armor ---', '--- armor ---', '--- 护甲 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- armor ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- armor ---', `text_loc4` = '--- 护甲 ---' WHERE `name` = '--- armor ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- consumable ---', '--- consumable ---', '--- 消耗品 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- consumable ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- consumable ---', `text_loc4` = '--- 消耗品 ---' WHERE `name` = '--- consumable ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- container ---', '--- container ---', '--- 容器 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- container ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- container ---', `text_loc4` = '--- 容器 ---' WHERE `name` = '--- container ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- gems ---', '--- gems ---', '--- 宝石 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- gems ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- gems ---', `text_loc4` = '--- 宝石 ---' WHERE `name` = '--- gems ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- keys ---', '--- keys ---', '--- 钥匙 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- keys ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- keys ---', `text_loc4` = '--- 钥匙 ---' WHERE `name` = '--- keys ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- other ---', '--- other ---', '--- 其他 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- other ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- other ---', `text_loc4` = '--- 其他 ---' WHERE `name` = '--- other ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- projectile ---', '--- projectile ---', '--- 弹药 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- projectile ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- projectile ---', `text_loc4` = '--- 弹药 ---' WHERE `name` = '--- projectile ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- quest items ---', '--- quest items ---', '--- 任务物品 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- quest items ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- quest items ---', `text_loc4` = '--- 任务物品 ---' WHERE `name` = '--- quest items ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- quiver ---', '--- quiver ---', '--- 箭袋 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- quiver ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- quiver ---', `text_loc4` = '--- 箭袋 ---' WHERE `name` = '--- quiver ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- reagent ---', '--- reagent ---', '--- 材料 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- reagent ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- reagent ---', `text_loc4` = '--- 材料 ---' WHERE `name` = '--- reagent ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- recipe ---', '--- recipe ---', '--- 配方 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- recipe ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- recipe ---', `text_loc4` = '--- 配方 ---' WHERE `name` = '--- recipe ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- trade goods ---', '--- trade goods ---', '--- 商品 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- trade goods ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- trade goods ---', `text_loc4` = '--- 商品 ---' WHERE `name` = '--- trade goods ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '--- weapon ---', '--- weapon ---', '--- 武器 ---', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '--- weapon ---');
UPDATE `ai_playerbot_texts` SET `text` = '--- weapon ---', `text_loc4` = '--- 武器 ---' WHERE `name` = '--- weapon ---';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Bank ===', '=== Bank ===', '=== 银行 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Bank ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Bank ===', `text_loc4` = '=== 银行 ===' WHERE `name` = '=== Bank ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Custom strategies ===', '=== Custom strategies ===', '=== 自定义策略 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Custom strategies ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Custom strategies ===', `text_loc4` = '=== 自定义策略 ===' WHERE `name` = '=== Custom strategies ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Equip ===', '=== Equip ===', '=== 装备 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Equip ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Equip ===', `text_loc4` = '=== 装备 ===' WHERE `name` = '=== Equip ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Equipment ===', '=== Equipment ===', '=== 装备 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Equipment ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Equipment ===', `text_loc4` = '=== 装备 ===' WHERE `name` = '=== Equipment ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Inventory ===', '=== Inventory ===', '=== 背包 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Inventory ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Inventory ===', `text_loc4` = '=== 背包 ===' WHERE `name` = '=== Inventory ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Mailbox ===', '=== Mailbox ===', '=== 邮箱 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Mailbox ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Mailbox ===', `text_loc4` = '=== 邮箱 ===' WHERE `name` = '=== Mailbox ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Spells ===', '=== Spells ===', '=== 法术 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Spells ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Spells ===', `text_loc4` = '=== 法术 ===' WHERE `name` = '=== Spells ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '=== Taxi ===', '=== Taxi ===', '=== 飞行点 ===', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '=== Taxi ===');
UPDATE `ai_playerbot_texts` SET `text` = '=== Taxi ===', `text_loc4` = '=== 飞行点 ===' WHERE `name` = '=== Taxi ===';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'A pleasure doing business with you', 'A pleasure doing business with you', '跟你做生意很愉快', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'A pleasure doing business with you');
UPDATE `ai_playerbot_texts` SET `text` = 'A pleasure doing business with you', `text_loc4` = '跟你做生意很愉快' WHERE `name` = 'A pleasure doing business with you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Aedm (Awesome energetic do move) spell trained.', 'Aedm (Awesome energetic do move) spell trained.', '已学会 Aedm（超有干劲的位移）法术。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Aedm (Awesome energetic do move) spell trained.');
UPDATE `ai_playerbot_texts` SET `text` = 'Aedm (Awesome energetic do move) spell trained.', `text_loc4` = '已学会 Aedm（超有干劲的位移）法术。' WHERE `name` = 'Aedm (Awesome energetic do move) spell trained.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Already have upcoming buffs, skipping ahead...', 'Already have upcoming buffs, skipping ahead...', '已经有后续的世界buff了，跳过。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Already have upcoming buffs, skipping ahead...');
UPDATE `ai_playerbot_texts` SET `text` = 'Already have upcoming buffs, skipping ahead...', `text_loc4` = '已经有后续的世界buff了，跳过。' WHERE `name` = 'Already have upcoming buffs, skipping ahead...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Arcane phase', 'Arcane phase', '奥术阶段', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Arcane phase');
UPDATE `ai_playerbot_texts` SET `text` = 'Arcane phase', `text_loc4` = '奥术阶段' WHERE `name` = 'Arcane phase';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Arcane phase ended', 'Arcane phase ended', '奥术阶段结束', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Arcane phase ended');
UPDATE `ai_playerbot_texts` SET `text` = 'Arcane phase ended', `text_loc4` = '奥术阶段结束' WHERE `name` = 'Arcane phase ended';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Arrived at Feathermoon Stronghold. Heading to Feralas mainland...', 'Arrived at Feathermoon Stronghold. Heading to Feralas mainland...', '到了羽月要塞，接下来去菲拉斯内陆……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Arrived at Feathermoon Stronghold. Heading to Feralas mainland...');
UPDATE `ai_playerbot_texts` SET `text` = 'Arrived at Feathermoon Stronghold. Heading to Feralas mainland...', `text_loc4` = '到了羽月要塞，接下来去菲拉斯内陆……' WHERE `name` = 'Arrived at Feathermoon Stronghold. Heading to Feralas mainland...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Arrived at Shyn in Camp Mojache. Heading to Dire Maul...', 'Arrived at Shyn in Camp Mojache. Heading to Dire Maul...', '到了莫沙彻营地的夏恩，接下来去厄运之槌……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Arrived at Shyn in Camp Mojache. Heading to Dire Maul...');
UPDATE `ai_playerbot_texts` SET `text` = 'Arrived at Shyn in Camp Mojache. Heading to Dire Maul...', `text_loc4` = '到了莫沙彻营地的夏恩，接下来去厄运之槌……' WHERE `name` = 'Arrived at Shyn in Camp Mojache. Heading to Dire Maul...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Avoid creature list is empty', 'Avoid creature list is empty', '避让生物名单是空的', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Avoid creature list is empty');
UPDATE `ai_playerbot_texts` SET `text` = 'Avoid creature list is empty', `text_loc4` = '避让生物名单是空的' WHERE `name` = 'Avoid creature list is empty';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Blizzard phase', 'Blizzard phase', '暴风雪阶段', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Blizzard phase');
UPDATE `ai_playerbot_texts` SET `text` = 'Blizzard phase', `text_loc4` = '暴风雪阶段' WHERE `name` = 'Blizzard phase';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Bot can not use this mount here.', 'Bot can not use this mount here.', '这里不能用这个坐骑。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Bot can not use this mount here.');
UPDATE `ai_playerbot_texts` SET `text` = 'Bot can not use this mount here.', `text_loc4` = '这里不能用这个坐骑。' WHERE `name` = 'Bot can not use this mount here.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Bot does not have this mount spell.', 'Bot does not have this mount spell.', '这个坐骑法术我还没学。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Bot does not have this mount spell.');
UPDATE `ai_playerbot_texts` SET `text` = 'Bot does not have this mount spell.', `text_loc4` = '这个坐骑法术我还没学。' WHERE `name` = 'Bot does not have this mount spell.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Bot does not have this mount.', 'Bot does not have this mount.', '这个坐骑我还没有。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Bot does not have this mount.');
UPDATE `ai_playerbot_texts` SET `text` = 'Bot does not have this mount.', `text_loc4` = '这个坐骑我还没有。' WHERE `name` = 'Bot does not have this mount.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Calling my pet', 'Calling my pet', '召唤我的宠物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Calling my pet');
UPDATE `ai_playerbot_texts` SET `text` = 'Calling my pet', `text_loc4` = '召唤我的宠物' WHERE `name` = 'Calling my pet';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Can not loot quest item, my bags are full', 'Can not loot quest item, my bags are full', '任务物品捡不了，我包满了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Can not loot quest item, my bags are full');
UPDATE `ai_playerbot_texts` SET `text` = 'Can not loot quest item, my bags are full', `text_loc4` = '任务物品捡不了，我包满了' WHERE `name` = 'Can not loot quest item, my bags are full';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Can''t find any innkeeper around', 'Can''t find any innkeeper around', '附近找不到旅店老板', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Can''t find any innkeeper around');
UPDATE `ai_playerbot_texts` SET `text` = 'Can''t find any innkeeper around', `text_loc4` = '附近找不到旅店老板' WHERE `name` = 'Can''t find any innkeeper around';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot equip this item to the specified slot.', 'Cannot equip this item to the specified slot.', '这件物品没法装备到指定的栏位。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot equip this item to the specified slot.');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot equip this item to the specified slot.', `text_loc4` = '这件物品没法装备到指定的栏位。' WHERE `name` = 'Cannot equip this item to the specified slot.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find Bonfire spawn data in Feralas', 'Cannot find Bonfire spawn data in Feralas', '在菲拉斯找不到篝火的刷新数据', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find Bonfire spawn data in Feralas');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find Bonfire spawn data in Feralas', `text_loc4` = '在菲拉斯找不到篝火的刷新数据' WHERE `name` = 'Cannot find Bonfire spawn data in Feralas';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find Dire Maul North door', 'Cannot find Dire Maul North door', '找不到厄运之槌北区的门', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find Dire Maul North door');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find Dire Maul North door', `text_loc4` = '找不到厄运之槌北区的门' WHERE `name` = 'Cannot find Dire Maul North door';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find Dire Maul North door spawn data', 'Cannot find Dire Maul North door spawn data', '找不到厄运之槌北区门的刷新数据', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find Dire Maul North door spawn data');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find Dire Maul North door spawn data', `text_loc4` = '找不到厄运之槌北区门的刷新数据' WHERE `name` = 'Cannot find Dire Maul North door spawn data';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any Songflower spawn data', 'Cannot find any Songflower spawn data', '找不到轻歌花的刷新数据', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any Songflower spawn data');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any Songflower spawn data', `text_loc4` = '找不到轻歌花的刷新数据' WHERE `name` = 'Cannot find any Songflower spawn data';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any Songflower spawn to regroup at', 'Cannot find any Songflower spawn to regroup at', '找不到可以集合的轻歌花刷新点', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any Songflower spawn to regroup at');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any Songflower spawn to regroup at', `text_loc4` = '找不到可以集合的轻歌花刷新点' WHERE `name` = 'Cannot find any Songflower spawn to regroup at';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any flightmaster to talk', 'Cannot find any flightmaster to talk', '找不到可以对话的飞行管理员', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any flightmaster to talk');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any flightmaster to talk', `text_loc4` = '找不到可以对话的飞行管理员' WHERE `name` = 'Cannot find any flightmaster to talk';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any npc to repair at', 'Cannot find any npc to repair at', '找不到可以修理的 npc', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any npc to repair at');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any npc to repair at', `text_loc4` = '找不到可以修理的 npc' WHERE `name` = 'Cannot find any npc to repair at';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any portal to teleport', 'Cannot find any portal to teleport', '找不到可以传送的门', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any portal to teleport');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any portal to teleport', `text_loc4` = '找不到可以传送的门' WHERE `name` = 'Cannot find any portal to teleport';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find any spirit healer nearby', 'Cannot find any spirit healer nearby', '附近找不到灵魂医者', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find any spirit healer nearby');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find any spirit healer nearby', `text_loc4` = '附近找不到灵魂医者' WHERE `name` = 'Cannot find any spirit healer nearby';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find auctioneer nearby', 'Cannot find auctioneer nearby', '附近找不到拍卖师', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find auctioneer nearby');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find auctioneer nearby', `text_loc4` = '附近找不到拍卖师' WHERE `name` = 'Cannot find auctioneer nearby';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting Disarm Trap on Suppression Device', 'Casting Disarm Trap on Suppression Device', '正在对压制装置施放解除陷阱', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting Disarm Trap on Suppression Device');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting Disarm Trap on Suppression Device', `text_loc4` = '正在对压制装置施放解除陷阱' WHERE `name` = 'Casting Disarm Trap on Suppression Device';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cleared travel target fetches', 'Cleared travel target fetches', '已清空旅行目标的获取记录', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cleared travel target fetches');
UPDATE `ai_playerbot_texts` SET `text` = 'Cleared travel target fetches', `text_loc4` = '已清空旅行目标的获取记录' WHERE `name` = 'Cleared travel target fetches';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Correct usage: glyph [glyph item link/remove] (optional slotnumber)', 'Correct usage: glyph [glyph item link/remove] (optional slotnumber)', '正确用法：glyph [雕文物品链接/remove]（可选：栏位编号）', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Correct usage: glyph [glyph item link/remove] (optional slotnumber)');
UPDATE `ai_playerbot_texts` SET `text` = 'Correct usage: glyph [glyph item link/remove] (optional slotnumber)', `text_loc4` = '正确用法：glyph [雕文物品链接/remove]（可选：栏位编号）' WHERE `name` = 'Correct usage: glyph [glyph item link/remove] (optional slotnumber)';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Correct usage: set value <value name> <value>', 'Correct usage: set value <value name> <value>', '正确用法：set value <变量名> <数值>', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Correct usage: set value <value name> <value>');
UPDATE `ai_playerbot_texts` SET `text` = 'Correct usage: set value <value name> <value>', `text_loc4` = '正确用法：set value <变量名> <数值>' WHERE `name` = 'Correct usage: set value <value name> <value>';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Could not move to rpg target. Drop rpg target', 'Could not move to rpg target. Drop rpg target', '走不到生活目标那里，放弃这个目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Could not move to rpg target. Drop rpg target');
UPDATE `ai_playerbot_texts` SET `text` = 'Could not move to rpg target. Drop rpg target', `text_loc4` = '走不到生活目标那里，放弃这个目标' WHERE `name` = 'Could not move to rpg target. Drop rpg target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Creature flag lootable.', 'Creature flag lootable.', '这个生物标记为可拾取。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Creature flag lootable.');
UPDATE `ai_playerbot_texts` SET `text` = 'Creature flag lootable.', `text_loc4` = '这个生物标记为可拾取。' WHERE `name` = 'Creature flag lootable.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Creature flag skinnable and has skill.', 'Creature flag skinnable and has skill.', '这个生物可以剥皮，而且我有对应技能。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Creature flag skinnable and has skill.');
UPDATE `ai_playerbot_texts` SET `text` = 'Creature flag skinnable and has skill.', `text_loc4` = '这个生物可以剥皮，而且我有对应技能。' WHERE `name` = 'Creature flag skinnable and has skill.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Creature flag skinnable not enough skill.', 'Creature flag skinnable not enough skill.', '这个生物能剥皮，但我技能不够。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Creature flag skinnable not enough skill.');
UPDATE `ai_playerbot_texts` SET `text` = 'Creature flag skinnable not enough skill.', `text_loc4` = '这个生物能剥皮，但我技能不够。' WHERE `name` = 'Creature flag skinnable not enough skill.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Creature without loot or skin flag.', 'Creature without loot or skin flag.', '这个生物没有拾取或剥皮标记。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Creature without loot or skin flag.');
UPDATE `ai_playerbot_texts` SET `text` = 'Creature without loot or skin flag.', `text_loc4` = '这个生物没有拾取或剥皮标记。' WHERE `name` = 'Creature without loot or skin flag.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Deactivating Suppression Device', 'Deactivating Suppression Device', '正在关闭压制装置', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Deactivating Suppression Device');
UPDATE `ai_playerbot_texts` SET `text` = 'Deactivating Suppression Device', `text_loc4` = '正在关闭压制装置' WHERE `name` = 'Deactivating Suppression Device';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Default talent spec for this class was not fount. Please check your config', 'Default talent spec for this class was not fount. Please check your config', '这个职业的默认天赋方案没找到，请检查你的配置', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Default talent spec for this class was not fount. Please check your config');
UPDATE `ai_playerbot_texts` SET `text` = 'Default talent spec for this class was not fount. Please check your config', `text_loc4` = '这个职业的默认天赋方案没找到，请检查你的配置' WHERE `name` = 'Default talent spec for this class was not fount. Please check your config';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Dismissing pet', 'Dismissing pet', '解散宠物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Dismissing pet');
UPDATE `ai_playerbot_texts` SET `text` = 'Dismissing pet', `text_loc4` = '解散宠物' WHERE `name` = 'Dismissing pet';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Elementals are out', 'Elementals are out', '元素怪出来了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Elementals are out');
UPDATE `ai_playerbot_texts` SET `text` = 'Elementals are out', `text_loc4` = '元素怪出来了' WHERE `name` = 'Elementals are out';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Entered Dire Maul North. Gained all Dire Maul Tribute buffs!', 'Entered Dire Maul North. Gained all Dire Maul Tribute buffs!', '进入厄运之槌北区，拿到了全部厄运之槌贡品buff！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Entered Dire Maul North. Gained all Dire Maul Tribute buffs!');
UPDATE `ai_playerbot_texts` SET `text` = 'Entered Dire Maul North. Gained all Dire Maul Tribute buffs!', `text_loc4` = '进入厄运之槌北区，拿到了全部厄运之槌贡品buff！' WHERE `name` = 'Entered Dire Maul North. Gained all Dire Maul Tribute buffs!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Failed to take flight from Bragok.', 'Failed to take flight from Bragok.', '从布拉格克那里起飞失败。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Failed to take flight from Bragok.');
UPDATE `ai_playerbot_texts` SET `text` = 'Failed to take flight from Bragok.', `text_loc4` = '从布拉格克那里起飞失败。' WHERE `name` = 'Failed to take flight from Bragok.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Failed to take flight from Dungar Longdrink.', 'Failed to take flight from Dungar Longdrink.', '从杜加尔·朗德瑞克那里起飞失败。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Failed to take flight from Dungar Longdrink.');
UPDATE `ai_playerbot_texts` SET `text` = 'Failed to take flight from Dungar Longdrink.', `text_loc4` = '从杜加尔·朗德瑞克那里起飞失败。' WHERE `name` = 'Failed to take flight from Dungar Longdrink.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Failed to take flight from Thyssiana.', 'Failed to take flight from Thyssiana.', '从瑟希安娜那里起飞失败。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Failed to take flight from Thyssiana.');
UPDATE `ai_playerbot_texts` SET `text` = 'Failed to take flight from Thyssiana.', `text_loc4` = '从瑟希安娜那里起飞失败。' WHERE `name` = 'Failed to take flight from Thyssiana.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Fair trade', 'Fair trade', '交易公平', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Fair trade');
UPDATE `ai_playerbot_texts` SET `text` = 'Fair trade', `text_loc4` = '交易公平' WHERE `name` = 'Fair trade';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Fine.. I''ll stay right here..', 'Fine.. I''ll stay right here..', '行吧……我就待在这儿不动了……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Fine.. I''ll stay right here..');
UPDATE `ai_playerbot_texts` SET `text` = 'Fine.. I''ll stay right here..', `text_loc4` = '行吧……我就待在这儿不动了……' WHERE `name` = 'Fine.. I''ll stay right here..';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Fire phase', 'Fire phase', '火焰阶段', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Fire phase');
UPDATE `ai_playerbot_texts` SET `text` = 'Fire phase', `text_loc4` = '火焰阶段' WHERE `name` = 'Fire phase';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'GO has item needed for quest.', 'GO has item needed for quest.', '这个物件上有任务需要的物品。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'GO has item needed for quest.');
UPDATE `ai_playerbot_texts` SET `text` = 'GO has item needed for quest.', `text_loc4` = '这个物件上有任务需要的物品。' WHERE `name` = 'GO has item needed for quest.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Gained Rallying Cry of the Dragonslayer!', 'Gained Rallying Cry of the Dragonslayer!', '拿到了屠龙者的咆哮！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Gained Rallying Cry of the Dragonslayer!');
UPDATE `ai_playerbot_texts` SET `text` = 'Gained Rallying Cry of the Dragonslayer!', `text_loc4` = '拿到了屠龙者的咆哮！' WHERE `name` = 'Gained Rallying Cry of the Dragonslayer!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Gained Songflower Serenade!', 'Gained Songflower Serenade!', '拿到了轻歌花的花语！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Gained Songflower Serenade!');
UPDATE `ai_playerbot_texts` SET `text` = 'Gained Songflower Serenade!', `text_loc4` = '拿到了轻歌花的花语！' WHERE `name` = 'Gained Songflower Serenade!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Gained Spirit of Zandalar!', 'Gained Spirit of Zandalar!', '拿到了赞达拉之魂！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Gained Spirit of Zandalar!');
UPDATE `ai_playerbot_texts` SET `text` = 'Gained Spirit of Zandalar!', `text_loc4` = '拿到了赞达拉之魂！' WHERE `name` = 'Gained Spirit of Zandalar!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Gained Warchief''s Blessing!', 'Gained Warchief''s Blessing!', '拿到了酋长的祝福！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Gained Warchief''s Blessing!');
UPDATE `ai_playerbot_texts` SET `text` = 'Gained Warchief''s Blessing!', `text_loc4` = '拿到了酋长的祝福！' WHERE `name` = 'Gained Warchief''s Blessing!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Getting new destination ranges for travel quest', 'Getting new destination ranges for travel quest', '正在为旅行任务获取新的目的地范围', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Getting new destination ranges for travel quest');
UPDATE `ai_playerbot_texts` SET `text` = 'Getting new destination ranges for travel quest', `text_loc4` = '正在为旅行任务获取新的目的地范围' WHERE `name` = 'Getting new destination ranges for travel quest';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go has bad lock.', 'Go has bad lock.', '这个物件的锁开不了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go has bad lock.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go has bad lock.', `text_loc4` = '这个物件的锁开不了。' WHERE `name` = 'Go has bad lock.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go has lock with key requirement.', 'Go has lock with key requirement.', '这个物件需要钥匙才能开。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go has lock with key requirement.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go has lock with key requirement.', `text_loc4` = '这个物件需要钥匙才能开。' WHERE `name` = 'Go has lock with key requirement.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go has no lockid.', 'Go has no lockid.', '这个物件没有锁的编号。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go has no lockid.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go has no lockid.', `text_loc4` = '这个物件没有锁的编号。' WHERE `name` = 'Go has no lockid.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go has only quests items we don''t need.', 'Go has only quests items we don''t need.', '这个物件上只有我们不需要的任务物品。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go has only quests items we don''t need.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go has only quests items we don''t need.', `text_loc4` = '这个物件上只有我们不需要的任务物品。' WHERE `name` = 'Go has only quests items we don''t need.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go has open lock.', 'Go has open lock.', '这个物件的锁是开着的。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go has open lock.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go has open lock.', `text_loc4` = '这个物件的锁是开着的。' WHERE `name` = 'Go has open lock.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go in skip go loot list.', 'Go in skip go loot list.', '这个物件在跳过拾取名单里。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go in skip go loot list.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go in skip go loot list.', `text_loc4` = '这个物件在跳过拾取名单里。' WHERE `name` = 'Go in skip go loot list.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go is serpentbloom.', 'Go is serpentbloom.', '这是蛇根草。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go is serpentbloom.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go is serpentbloom.', `text_loc4` = '这是蛇根草。' WHERE `name` = 'Go is serpentbloom.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Go requires skill.', 'Go requires skill.', '这个物件需要专业技能。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Go requires skill.');
UPDATE `ai_playerbot_texts` SET `text` = 'Go requires skill.', `text_loc4` = '这个物件需要专业技能。' WHERE `name` = 'Go requires skill.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Got all DM Tribute buffs! Leaving the instance...', 'Got all DM Tribute buffs! Leaving the instance...', '厄运之槌贡品buff全齐了！出副本……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Got all DM Tribute buffs! Leaving the instance...');
UPDATE `ai_playerbot_texts` SET `text` = 'Got all DM Tribute buffs! Leaving the instance...', `text_loc4` = '厄运之槌贡品buff全齐了！出副本……' WHERE `name` = 'Got all DM Tribute buffs! Leaving the instance...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Handing in guild petition', 'Handing in guild petition', '正在提交公会申请表', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Handing in guild petition');
UPDATE `ai_playerbot_texts` SET `text` = 'Handing in guild petition', `text_loc4` = '正在提交公会申请表' WHERE `name` = 'Handing in guild petition';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am already a spirit', 'I am already a spirit', '我已经是灵魂状态了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am already a spirit');
UPDATE `ai_playerbot_texts` SET `text` = 'I am already a spirit', `text_loc4` = '我已经是灵魂状态了' WHERE `name` = 'I am already a spirit';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am currently on a taxi.', 'I am currently on a taxi.', '我正坐飞行呢。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am currently on a taxi.');
UPDATE `ai_playerbot_texts` SET `text` = 'I am currently on a taxi.', `text_loc4` = '我正坐飞行呢。' WHERE `name` = 'I am currently on a taxi.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am in combat', 'I am in combat', '我在战斗中', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am in combat');
UPDATE `ai_playerbot_texts` SET `text` = 'I am in combat', `text_loc4` = '我在战斗中' WHERE `name` = 'I am in combat';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am not a spirit', 'I am not a spirit', '我不是灵魂状态', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am not a spirit');
UPDATE `ai_playerbot_texts` SET `text` = 'I am not a spirit', `text_loc4` = '我不是灵魂状态' WHERE `name` = 'I am not a spirit';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am ready for the next flight', 'I am ready for the next flight', '我准备好坐下一班飞行了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am ready for the next flight');
UPDATE `ai_playerbot_texts` SET `text` = 'I am ready for the next flight', `text_loc4` = '我准备好坐下一班飞行了' WHERE `name` = 'I am ready for the next flight';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I can''t call any pets', 'I can''t call any pets', '我没有能召唤的宠物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I can''t call any pets');
UPDATE `ai_playerbot_texts` SET `text` = 'I can''t call any pets', `text_loc4` = '我没有能召唤的宠物' WHERE `name` = 'I can''t call any pets';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I can''t dismiss my pet', 'I can''t dismiss my pet', '我没法解散宠物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I can''t dismiss my pet');
UPDATE `ai_playerbot_texts` SET `text` = 'I can''t dismiss my pet', `text_loc4` = '我没法解散宠物' WHERE `name` = 'I can''t dismiss my pet';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I can''t fly with you', 'I can''t fly with you', '我没法跟你一起飞', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I can''t fly with you');
UPDATE `ai_playerbot_texts` SET `text` = 'I can''t fly with you', `text_loc4` = '我没法跟你一起飞' WHERE `name` = 'I can''t fly with you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I can''t follow myself!', 'I can''t follow myself!', '我没法跟着我自己！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I can''t follow myself!');
UPDATE `ai_playerbot_texts` SET `text` = 'I can''t follow myself!', `text_loc4` = '我没法跟着我自己！' WHERE `name` = 'I can''t follow myself!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I can''t set to autocast that spell.', 'I can''t set to autocast that spell.', '那个法术没法设成自动施放。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I can''t set to autocast that spell.');
UPDATE `ai_playerbot_texts` SET `text` = 'I can''t set to autocast that spell.', `text_loc4` = '那个法术没法设成自动施放。' WHERE `name` = 'I can''t set to autocast that spell.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I cannot attack in flight', 'I cannot attack in flight', '飞行中我没法攻击', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I cannot attack in flight');
UPDATE `ai_playerbot_texts` SET `text` = 'I cannot attack in flight', `text_loc4` = '飞行中我没法攻击' WHERE `name` = 'I cannot attack in flight';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I cannot craft this', 'I cannot craft this', '这个我造不了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I cannot craft this');
UPDATE `ai_playerbot_texts` SET `text` = 'I cannot craft this', `text_loc4` = '这个我造不了' WHERE `name` = 'I cannot craft this';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I cannot send money', 'I cannot send money', '我没法寄钱', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I cannot send money');
UPDATE `ai_playerbot_texts` SET `text` = 'I cannot send money', `text_loc4` = '我没法寄钱' WHERE `name` = 'I cannot send money';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I don''t have any pets', 'I don''t have any pets', '我没有任何宠物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I don''t have any pets');
UPDATE `ai_playerbot_texts` SET `text` = 'I don''t have any pets', `text_loc4` = '我没有任何宠物' WHERE `name` = 'I don''t have any pets';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I have no path', 'I have no path', '我找不到路', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I have no path');
UPDATE `ai_playerbot_texts` SET `text` = 'I have no path', `text_loc4` = '我找不到路' WHERE `name` = 'I have no path';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I have no target', 'I have no target', '我没有目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I have no target');
UPDATE `ai_playerbot_texts` SET `text` = 'I have no target', `text_loc4` = '我没有目标' WHERE `name` = 'I have no target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I left my group', 'I left my group', '我退队了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I left my group');
UPDATE `ai_playerbot_texts` SET `text` = 'I left my group', `text_loc4` = '我退队了' WHERE `name` = 'I left my group';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I live, again!', 'I live, again!', '我又活过来了！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I live, again!');
UPDATE `ai_playerbot_texts` SET `text` = 'I live, again!', `text_loc4` = '我又活过来了！' WHERE `name` = 'I live, again!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I need to talk first', 'I need to talk first', '我得先跟他对话', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I need to talk first');
UPDATE `ai_playerbot_texts` SET `text` = 'I need to talk first', `text_loc4` = '我得先跟他对话' WHERE `name` = 'I need to talk first';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I will join you at your next relogin', 'I will join you at your next relogin', '你下次上线我就加入你', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I will join you at your next relogin');
UPDATE `ai_playerbot_texts` SET `text` = 'I will join you at your next relogin', `text_loc4` = '你下次上线我就加入你' WHERE `name` = 'I will join you at your next relogin';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I will not craft anything', 'I will not craft anything', '我什么都不会造', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I will not craft anything');
UPDATE `ai_playerbot_texts` SET `text` = 'I will not craft anything', `text_loc4` = '我什么都不会造' WHERE `name` = 'I will not craft anything';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m dead, guess I''ll reset my objective.', 'I''m dead, guess I''ll reset my objective.', '我死了，看来得重置一下目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m dead, guess I''ll reset my objective.');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m dead, guess I''ll reset my objective.', `text_loc4` = '我死了，看来得重置一下目标。' WHERE `name` = 'I''m dead, guess I''ll reset my objective.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m heading to your location but I''m in combat', 'I''m heading to your location but I''m in combat', '我正往你那儿去，但我在战斗中', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m heading to your location but I''m in combat');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m heading to your location but I''m in combat', `text_loc4` = '我正往你那儿去，但我在战斗中' WHERE `name` = 'I''m heading to your location but I''m in combat';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m not a healer or offhealer (please change my strats to heal or offheal)', 'I''m not a healer or offhealer (please change my strats to heal or offheal)', '我不是治疗也不是副治疗（请把我的策略改成治疗或副治疗）', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m not a healer or offhealer (please change my strats to heal or offheal)');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m not a healer or offhealer (please change my strats to heal or offheal)', `text_loc4` = '我不是治疗也不是副治疗（请把我的策略改成治疗或副治疗）' WHERE `name` = 'I''m not a healer or offhealer (please change my strats to heal or offheal)';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m not in a group', 'I''m not in a group', '我不在队伍里', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m not in a group');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m not in a group', `text_loc4` = '我不在队伍里' WHERE `name` = 'I''m not in a group';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m not in your guild!', 'I''m not in your guild!', '我不在你的公会里！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m not in your guild!');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m not in your guild!', `text_loc4` = '我不在你的公会里！' WHERE `name` = 'I''m not in your guild!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Ignored spell list is empty', 'Ignored spell list is empty', '忽略法术名单是空的', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Ignored spell list is empty');
UPDATE `ai_playerbot_texts` SET `text` = 'Ignored spell list is empty', `text_loc4` = '忽略法术名单是空的' WHERE `name` = 'Ignored spell list is empty';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Invalid game object', 'Invalid game object', '无效的游戏物件', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Invalid game object');
UPDATE `ai_playerbot_texts` SET `text` = 'Invalid game object', `text_loc4` = '无效的游戏物件' WHERE `name` = 'Invalid game object';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Loot object is empty.', 'Loot object is empty.', '可拾取的东西是空的。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Loot object is empty.');
UPDATE `ai_playerbot_texts` SET `text` = 'Loot object is empty.', `text_loc4` = '可拾取的东西是空的。' WHERE `name` = 'Loot object is empty.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Looting is not possible.', 'Looting is not possible.', '没法拾取。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Looting is not possible.');
UPDATE `ai_playerbot_texts` SET `text` = 'Looting is not possible.', `text_loc4` = '没法拾取。' WHERE `name` = 'Looting is not possible.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Max DPS!', 'Max DPS!', '全力输出！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Max DPS!');
UPDATE `ai_playerbot_texts` SET `text` = 'Max DPS!', `text_loc4` = '全力输出！' WHERE `name` = 'Max DPS!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Max wait time is 20 seconds!', 'Max wait time is 20 seconds!', '最长等待时间是20秒！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Max wait time is 20 seconds!');
UPDATE `ai_playerbot_texts` SET `text` = 'Max wait time is 20 seconds!', `text_loc4` = '最长等待时间是20秒！' WHERE `name` = 'Max wait time is 20 seconds!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Meet me at the graveyard', 'Meet me at the graveyard', '墓地见', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Meet me at the graveyard');
UPDATE `ai_playerbot_texts` SET `text` = 'Meet me at the graveyard', `text_loc4` = '墓地见' WHERE `name` = 'Meet me at the graveyard';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount in bg. No attackers or far from target and not in combat.', 'Mount in bg. No attackers or far from target and not in combat.', '战场里上坐骑：没人打我，离目标远，而且不在战斗。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount in bg. No attackers or far from target and not in combat.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount in bg. No attackers or far from target and not in combat.', `text_loc4` = '战场里上坐骑：没人打我，离目标远，而且不在战斗。' WHERE `name` = 'Mount in bg. No attackers or far from target and not in combat.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Far from group master and not in combat.', 'Mount. Far from group master and not in combat.', '上坐骑：离队长远，而且不在战斗。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Far from group master and not in combat.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Far from group master and not in combat.', `text_loc4` = '上坐骑：离队长远，而且不在战斗。' WHERE `name` = 'Mount. Far from group master and not in combat.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Group master mounted and no attackers.', 'Mount. Group master mounted and no attackers.', '上坐骑：队长骑上了，也没人打我。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Group master mounted and no attackers.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Group master mounted and no attackers.', `text_loc4` = '上坐骑：队长骑上了，也没人打我。' WHERE `name` = 'Mount. Group master mounted and no attackers.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Move to guard.', 'Mount. Move to guard.', '上坐骑：去守点。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Move to guard.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Move to guard.', `text_loc4` = '上坐骑：去守点。' WHERE `name` = 'Mount. Move to guard.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Move to stay.', 'Mount. Move to stay.', '上坐骑：回待命点。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Move to stay.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Move to stay.', `text_loc4` = '上坐骑：回待命点。' WHERE `name` = 'Mount. Move to stay.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Near rpg targets.', 'Mount. Near rpg targets.', '上坐骑：附近有生活目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Near rpg targets.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Near rpg targets.', `text_loc4` = '上坐骑：附近有生活目标。' WHERE `name` = 'Mount. Near rpg targets.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Rpg target far away.', 'Mount. Rpg target far away.', '上坐骑：生活目标离得远。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Rpg target far away.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Rpg target far away.', `text_loc4` = '上坐骑：生活目标离得远。' WHERE `name` = 'Mount. Rpg target far away.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Traveling some place.', 'Mount. Traveling some place.', '上坐骑：要跑远路。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Traveling some place.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Traveling some place.', `text_loc4` = '上坐骑：要跑远路。' WHERE `name` = 'Mount. Traveling some place.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mount. Unable to attack target and target is far or chaseable.', 'Mount. Unable to attack target and target is far or chaseable.', '上坐骑：打不到目标，而且目标离得远或者能追。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mount. Unable to attack target and target is far or chaseable.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mount. Unable to attack target and target is far or chaseable.', `text_loc4` = '上坐骑：打不到目标，而且目标离得远或者能追。' WHERE `name` = 'Mount. Unable to attack target and target is far or chaseable.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mounted, unmount to mount faster next time.', 'Mounted, unmount to mount faster next time.', '骑着呢，先下来，下次能上得更快。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mounted, unmount to mount faster next time.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mounted, unmount to mount faster next time.', `text_loc4` = '骑着呢，先下来，下次能上得更快。' WHERE `name` = 'Mounted, unmount to mount faster next time.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mounted, unmount to mount slower next time.', 'Mounted, unmount to mount slower next time.', '骑着呢，先下来，下次上得慢一点。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mounted, unmount to mount slower next time.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mounted, unmount to mount slower next time.', `text_loc4` = '骑着呢，先下来，下次上得慢一点。' WHERE `name` = 'Mounted, unmount to mount slower next time.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mounting failed.', 'Mounting failed.', '上坐骑失败。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mounting failed.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mounting failed.', `text_loc4` = '上坐骑失败。' WHERE `name` = 'Mounting failed.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mounting spell failed.', 'Mounting spell failed.', '坐骑法术施放失败。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mounting spell failed.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mounting spell failed.', `text_loc4` = '坐骑法术施放失败。' WHERE `name` = 'Mounting spell failed.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Mounting.', 'Mounting.', '正在上坐骑。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Mounting.');
UPDATE `ai_playerbot_texts` SET `text` = 'Mounting.', `text_loc4` = '正在上坐骑。' WHERE `name` = 'Mounting.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'My loot list is now empty', 'My loot list is now empty', '我的拾取名单现在是空的', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'My loot list is now empty');
UPDATE `ai_playerbot_texts` SET `text` = 'My loot list is now empty', `text_loc4` = '我的拾取名单现在是空的' WHERE `name` = 'My loot list is now empty';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No grind target found.', 'No grind target found.', '没找到刷怪目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No grind target found.');
UPDATE `ai_playerbot_texts` SET `text` = 'No grind target found.', `text_loc4` = '没找到刷怪目标。' WHERE `name` = 'No grind target found.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No items or game objects available', 'No items or game objects available', '没有可用的物品或游戏物件', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No items or game objects available');
UPDATE `ai_playerbot_texts` SET `text` = 'No items or game objects available', `text_loc4` = '没有可用的物品或游戏物件' WHERE `name` = 'No items or game objects available';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No meeting location found in guild MOTD', 'No meeting location found in guild MOTD', '公会公告里没找到集合地点', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No meeting location found in guild MOTD');
UPDATE `ai_playerbot_texts` SET `text` = 'No meeting location found in guild MOTD', `text_loc4` = '公会公告里没找到集合地点' WHERE `name` = 'No meeting location found in guild MOTD';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No new locations found for old destination.', 'No new locations found for old destination.', '旧目的地没有找到新地点。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No new locations found for old destination.');
UPDATE `ai_playerbot_texts` SET `text` = 'No new locations found for old destination.', `text_loc4` = '旧目的地没有找到新地点。' WHERE `name` = 'No new locations found for old destination.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No point. Rebuilding.', 'No point. Rebuilding.', '没有路径点，重建。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No point. Rebuilding.');
UPDATE `ai_playerbot_texts` SET `text` = 'No point. Rebuilding.', `text_loc4` = '没有路径点，重建。' WHERE `name` = 'No point. Rebuilding.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No reagent vendor entries found', 'No reagent vendor entries found', '没找到材料商人的记录', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No reagent vendor entries found');
UPDATE `ai_playerbot_texts` SET `text` = 'No reagent vendor entries found', `text_loc4` = '没找到材料商人的记录' WHERE `name` = 'No reagent vendor entries found';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No spells can be learned from this trainer', 'No spells can be learned from this trainer', '这个训练师没有能学的法术', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No spells can be learned from this trainer');
UPDATE `ai_playerbot_texts` SET `text` = 'No spells can be learned from this trainer', `text_loc4` = '这个训练师没有能学的法术' WHERE `name` = 'No spells can be learned from this trainer';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No target set', 'No target set', '没有设置目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No target set');
UPDATE `ai_playerbot_texts` SET `text` = 'No target set', `text_loc4` = '没有设置目标' WHERE `name` = 'No target set';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No valid guild travel order found', 'No valid guild travel order found', '没找到有效的公会旅行指令', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No valid guild travel order found');
UPDATE `ai_playerbot_texts` SET `text` = 'No valid guild travel order found', `text_loc4` = '没找到有效的公会旅行指令' WHERE `name` = 'No valid guild travel order found';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Not enough place to summon', 'Not enough place to summon', '这里地方太小，召唤不了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Not enough place to summon');
UPDATE `ai_playerbot_texts` SET `text` = 'Not enough place to summon', `text_loc4` = '这里地方太小，召唤不了' WHERE `name` = 'Not enough place to summon';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Not master looter.', 'Not master looter.', '我不是队长分配者。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Not master looter.');
UPDATE `ai_playerbot_texts` SET `text` = 'Not master looter.', `text_loc4` = '我不是队长分配者。' WHERE `name` = 'Not master looter.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Object too high or low.', 'Object too high or low.', '物件太高或者太低。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Object too high or low.');
UPDATE `ai_playerbot_texts` SET `text` = 'Object too high or low.', `text_loc4` = '物件太高或者太低。' WHERE `name` = 'Object too high or low.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Off with you', 'Off with you', '你走吧', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Off with you');
UPDATE `ai_playerbot_texts` SET `text` = 'Off with you', `text_loc4` = '你走吧' WHERE `name` = 'Off with you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Old destination was no longer valid.', 'Old destination was no longer valid.', '旧目的地已经失效了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Old destination was no longer valid.');
UPDATE `ai_playerbot_texts` SET `text` = 'Old destination was no longer valid.', `text_loc4` = '旧目的地已经失效了。' WHERE `name` = 'Old destination was no longer valid.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Old destination was tried too many times.', 'Old destination was tried too many times.', '旧目的地试了太多次。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Old destination was tried too many times.');
UPDATE `ai_playerbot_texts` SET `text` = 'Old destination was tried too many times.', `text_loc4` = '旧目的地试了太多次。' WHERE `name` = 'Old destination was tried too many times.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Pet has Phase Shift active, cannot attack', 'Pet has Phase Shift active, cannot attack', '宠物开着相位变换，没法攻击', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Pet has Phase Shift active, cannot attack');
UPDATE `ai_playerbot_texts` SET `text` = 'Pet has Phase Shift active, cannot attack', `text_loc4` = '宠物开着相位变换，没法攻击' WHERE `name` = 'Pet has Phase Shift active, cannot attack';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please provide a time to set (in seconds)', 'Please provide a time to set (in seconds)', '请提供要设置的时间（单位：秒）', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please provide a time to set (in seconds)');
UPDATE `ai_playerbot_texts` SET `text` = 'Please provide a time to set (in seconds)', `text_loc4` = '请提供要设置的时间（单位：秒）' WHERE `name` = 'Please provide a time to set (in seconds)';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please provide one or more player names', 'Please provide one or more player names', '请提供一个或多个玩家名字', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please provide one or more player names');
UPDATE `ai_playerbot_texts` SET `text` = 'Please provide one or more player names', `text_loc4` = '请提供一个或多个玩家名字' WHERE `name` = 'Please provide one or more player names';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please provide valid time to set (in seconds) between 1 and 99', 'Please provide valid time to set (in seconds) between 1 and 99', '请提供有效的时间（单位：秒），范围1到99', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please provide valid time to set (in seconds) between 1 and 99');
UPDATE `ai_playerbot_texts` SET `text` = 'Please provide valid time to set (in seconds) between 1 and 99', `text_loc4` = '请提供有效的时间（单位：秒），范围1到99' WHERE `name` = 'Please provide valid time to set (in seconds) between 1 and 99';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please select a target to attack', 'Please select a target to attack', '请先选一个攻击目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please select a target to attack');
UPDATE `ai_playerbot_texts` SET `text` = 'Please select a target to attack', `text_loc4` = '请先选一个攻击目标' WHERE `name` = 'Please select a target to attack';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please set to any of:|cffffffff near (default), tank, turnback, behind', 'Please set to any of:|cffffffff near (default), tank, turnback, behind', '请设置为以下之一：|cffffffff near（默认）、tank、turnback、behind', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please set to any of:|cffffffff near (default), tank, turnback, behind');
UPDATE `ai_playerbot_texts` SET `text` = 'Please set to any of:|cffffffff near (default), tank, turnback, behind', `text_loc4` = '请设置为以下之一：|cffffffff near（默认）、tank、turnback、behind' WHERE `name` = 'Please set to any of:|cffffffff near (default), tank, turnback, behind';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please set to any of:|cffffffff near, queue, chaos, circle, line, shield, arrow, melee, far, default', 'Please set to any of:|cffffffff near, queue, chaos, circle, line, shield, arrow, melee, far, default', '请设置为以下之一：|cffffffff near、queue、chaos、circle、line、shield、arrow、melee、far、default', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please set to any of:|cffffffff near, queue, chaos, circle, line, shield, arrow, melee, far, default');
UPDATE `ai_playerbot_texts` SET `text` = 'Please set to any of:|cffffffff near, queue, chaos, circle, line, shield, arrow, melee, far, default', `text_loc4` = '请设置为以下之一：|cffffffff near、queue、chaos、circle、line、shield、arrow、melee、far、default' WHERE `name` = 'Please set to any of:|cffffffff near, queue, chaos, circle, line, shield, arrow, melee, far, default';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please specify a + for add or - to remove a target', 'Please specify a + for add or - to remove a target', '请用 + 添加目标，或用 - 移除目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please specify a + for add or - to remove a target');
UPDATE `ai_playerbot_texts` SET `text` = 'Please specify a + for add or - to remove a target', `text_loc4` = '请用 + 添加目标，或用 - 移除目标' WHERE `name` = 'Please specify a + for add or - to remove a target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please specify a pet command (Like autocast).', 'Please specify a pet command (Like autocast).', '请指定宠物指令（比如 autocast）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please specify a pet command (Like autocast).');
UPDATE `ai_playerbot_texts` SET `text` = 'Please specify a pet command (Like autocast).', `text_loc4` = '请指定宠物指令（比如 autocast）。' WHERE `name` = 'Please specify a pet command (Like autocast).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please specify a pet spell to set the autocast.', 'Please specify a pet spell to set the autocast.', '请指定要设自动施放的宠物法术。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please specify a pet spell to set the autocast.');
UPDATE `ai_playerbot_texts` SET `text` = 'Please specify a pet spell to set the autocast.', `text_loc4` = '请指定要设自动施放的宠物法术。' WHERE `name` = 'Please specify a pet spell to set the autocast.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please specify one or more creatures to avoid', 'Please specify one or more creatures to avoid', '请指定一个或多个要避让的生物', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please specify one or more creatures to avoid');
UPDATE `ai_playerbot_texts` SET `text` = 'Please specify one or more creatures to avoid', `text_loc4` = '请指定一个或多个要避让的生物' WHERE `name` = 'Please specify one or more creatures to avoid';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Please specify one or more spells to ignore', 'Please specify one or more spells to ignore', '请指定一个或多个要忽略的法术', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Please specify one or more spells to ignore');
UPDATE `ai_playerbot_texts` SET `text` = 'Please specify one or more spells to ignore', `text_loc4` = '请指定一个或多个要忽略的法术' WHERE `name` = 'Please specify one or more spells to ignore';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered group size reset to random:', 'Prefered group size reset to random:', '偏好队伍人数已重置为随机：', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered group size reset to random:');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered group size reset to random:', `text_loc4` = '偏好队伍人数已重置为随机：' WHERE `name` = 'Prefered group size reset to random:';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered group size set to allow others to invite.', 'Prefered group size set to allow others to invite.', '偏好队伍人数已设为允许别人邀请我。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered group size set to allow others to invite.');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered group size set to allow others to invite.', `text_loc4` = '偏好队伍人数已设为允许别人邀请我。' WHERE `name` = 'Prefered group size set to allow others to invite.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered group size set to solo.', 'Prefered group size set to solo.', '偏好队伍人数已设为单人。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered group size set to solo.');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered group size set to solo.', `text_loc4` = '偏好队伍人数已设为单人。' WHERE `name` = 'Prefered group size set to solo.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered guild size reset to random:', 'Prefered guild size reset to random:', '偏好公会人数已重置为随机：', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered guild size reset to random:');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered guild size reset to random:', `text_loc4` = '偏好公会人数已重置为随机：' WHERE `name` = 'Prefered guild size reset to random:';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered rpg style reset to random:', 'Prefered rpg style reset to random:', '偏好生活风格已重置为随机：', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered rpg style reset to random:');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered rpg style reset to random:', `text_loc4` = '偏好生活风格已重置为随机：' WHERE `name` = 'Prefered rpg style reset to random:';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Quest log full but no droppable quests found for guild order', 'Quest log full but no droppable quests found for guild order', '任务日志满了，但为了公会指令也没找到可以放弃的任务', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Quest log full but no droppable quests found for guild order');
UPDATE `ai_playerbot_texts` SET `text` = 'Quest log full but no droppable quests found for guild order', `text_loc4` = '任务日志满了，但为了公会指令也没找到可以放弃的任务' WHERE `name` = 'Quest log full but no droppable quests found for guild order';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Quest shared', 'Quest shared', '任务已共享', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Quest shared');
UPDATE `ai_playerbot_texts` SET `text` = 'Quest shared', `text_loc4` = '任务已共享' WHERE `name` = 'Quest shared';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'QuestReward order has no questId', 'QuestReward order has no questId', '任务奖励指令里没有任务ID', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'QuestReward order has no questId');
UPDATE `ai_playerbot_texts` SET `text` = 'QuestReward order has no questId', `text_loc4` = '任务奖励指令里没有任务ID' WHERE `name` = 'QuestReward order has no questId';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'RTS control enabled.', 'RTS control enabled.', 'RTS 控制已开启。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'RTS control enabled.');
UPDATE `ai_playerbot_texts` SET `text` = 'RTS control enabled.', `text_loc4` = 'RTS 控制已开启。' WHERE `name` = 'RTS control enabled.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'RTS control spell removed.', 'RTS control spell removed.', 'RTS 控制法术已移除。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'RTS control spell removed.');
UPDATE `ai_playerbot_texts` SET `text` = 'RTS control spell removed.', `text_loc4` = 'RTS 控制法术已移除。' WHERE `name` = 'RTS control spell removed.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Random drop rpg target', 'Random drop rpg target', '随机放弃生活目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Random drop rpg target');
UPDATE `ai_playerbot_texts` SET `text` = 'Random drop rpg target', `text_loc4` = '随机放弃生活目标' WHERE `name` = 'Random drop rpg target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Reached Dire Maul in Feralas. Heading to Dire Maul North...', 'Reached Dire Maul in Feralas. Heading to Dire Maul North...', '到了菲拉斯的厄运之槌，接下来去北区……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Reached Dire Maul in Feralas. Heading to Dire Maul North...');
UPDATE `ai_playerbot_texts` SET `text` = 'Reached Dire Maul in Feralas. Heading to Dire Maul North...', `text_loc4` = '到了菲拉斯的厄运之槌，接下来去北区……' WHERE `name` = 'Reached Dire Maul in Feralas. Heading to Dire Maul North...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Reached Feralas mainland. Heading to Dire Maul...', 'Reached Feralas mainland. Heading to Dire Maul...', '到了菲拉斯内陆，接下来去厄运之槌……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Reached Feralas mainland. Heading to Dire Maul...');
UPDATE `ai_playerbot_texts` SET `text` = 'Reached Feralas mainland. Heading to Dire Maul...', `text_loc4` = '到了菲拉斯内陆，接下来去厄运之槌……' WHERE `name` = 'Reached Feralas mainland. Heading to Dire Maul...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Refreshed travel target', 'Refreshed travel target', '已刷新旅行目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Refreshed travel target');
UPDATE `ai_playerbot_texts` SET `text` = 'Refreshed travel target', `text_loc4` = '已刷新旅行目标' WHERE `name` = 'Refreshed travel target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Regrouping at Dire Maul North for portal...', 'Regrouping at Dire Maul North for portal...', '在厄运之槌北区集合开门……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Regrouping at Dire Maul North for portal...');
UPDATE `ai_playerbot_texts` SET `text` = 'Regrouping at Dire Maul North for portal...', `text_loc4` = '在厄运之槌北区集合开门……' WHERE `name` = 'Regrouping at Dire Maul North for portal...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Releasing...', 'Releasing...', '释放灵魂……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Releasing...');
UPDATE `ai_playerbot_texts` SET `text` = 'Releasing...', `text_loc4` = '释放灵魂……' WHERE `name` = 'Releasing...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Removed focus heal targets', 'Removed focus heal targets', '已移除专注治疗目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Removed focus heal targets');
UPDATE `ai_playerbot_texts` SET `text` = 'Removed focus heal targets', `text_loc4` = '已移除专注治疗目标' WHERE `name` = 'Removed focus heal targets';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Removed follow target', 'Removed follow target', '已移除跟随目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Removed follow target');
UPDATE `ai_playerbot_texts` SET `text` = 'Removed follow target', `text_loc4` = '已移除跟随目标' WHERE `name` = 'Removed follow target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Resetting all instances', 'Resetting all instances', '正在重置所有副本', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Resetting all instances');
UPDATE `ai_playerbot_texts` SET `text` = 'Resetting all instances', `text_loc4` = '正在重置所有副本' WHERE `name` = 'Resetting all instances';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Roll feedback disabled.', 'Roll feedback disabled.', '掷骰提示已关闭。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Roll feedback disabled.');
UPDATE `ai_playerbot_texts` SET `text` = 'Roll feedback disabled.', `text_loc4` = '掷骰提示已关闭。' WHERE `name` = 'Roll feedback disabled.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Roll feedback enalbed.', 'Roll feedback enalbed.', '掷骰提示已开启。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Roll feedback enalbed.');
UPDATE `ai_playerbot_texts` SET `text` = 'Roll feedback enalbed.', `text_loc4` = '掷骰提示已开启。' WHERE `name` = 'Roll feedback enalbed.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Rpg player target is targeting me. Drop target', 'Rpg player target is targeting me. Drop target', '那个生活目标玩家在盯我，放弃目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Rpg player target is targeting me. Drop target');
UPDATE `ai_playerbot_texts` SET `text` = 'Rpg player target is targeting me. Drop target', `text_loc4` = '那个生活目标玩家在盯我，放弃目标' WHERE `name` = 'Rpg player target is targeting me. Drop target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Rpg target is beyond react distance. Drop target', 'Rpg target is beyond react distance. Drop target', '生活目标超出反应距离，放弃目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Rpg target is beyond react distance. Drop target');
UPDATE `ai_playerbot_texts` SET `text` = 'Rpg target is beyond react distance. Drop target', `text_loc4` = '生活目标超出反应距离，放弃目标' WHERE `name` = 'Rpg target is beyond react distance. Drop target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Rpg target is far from mater. Random drop target.', 'Rpg target is far from mater. Random drop target.', '生活目标离主人太远，随机放弃目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Rpg target is far from mater. Random drop target.');
UPDATE `ai_playerbot_texts` SET `text` = 'Rpg target is far from mater. Random drop target.', `text_loc4` = '生活目标离主人太远，随机放弃目标。' WHERE `name` = 'Rpg target is far from mater. Random drop target.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Rpg target is moving. Random drop target.', 'Rpg target is moving. Random drop target.', '生活目标在移动，随机放弃目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Rpg target is moving. Random drop target.');
UPDATE `ai_playerbot_texts` SET `text` = 'Rpg target is moving. Random drop target.', `text_loc4` = '生活目标在移动，随机放弃目标。' WHERE `name` = 'Rpg target is moving. Random drop target.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Running away', 'Running away', '跑路', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Running away');
UPDATE `ai_playerbot_texts` SET `text` = 'Running away', `text_loc4` = '跑路' WHERE `name` = 'Running away';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sending pet to attack', 'Sending pet to attack', '派宠物上去打', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sending pet to attack');
UPDATE `ai_playerbot_texts` SET `text` = 'Sending pet to attack', `text_loc4` = '派宠物上去打' WHERE `name` = 'Sending pet to attack';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting movePosition to water surface.', 'Setting movePosition to water surface.', '把移动点设到水面。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting movePosition to water surface.');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting movePosition to water surface.', `text_loc4` = '把移动点设到水面。' WHERE `name` = 'Setting movePosition to water surface.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting pet to aggressive mode', 'Setting pet to aggressive mode', '把宠物设成主动攻击模式', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting pet to aggressive mode');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting pet to aggressive mode', `text_loc4` = '把宠物设成主动攻击模式' WHERE `name` = 'Setting pet to aggressive mode';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting pet to defensive mode', 'Setting pet to defensive mode', '把宠物设成防御模式', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting pet to defensive mode');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting pet to defensive mode', `text_loc4` = '把宠物设成防御模式' WHERE `name` = 'Setting pet to defensive mode';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting pet to follow me', 'Setting pet to follow me', '让宠物跟着我', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting pet to follow me');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting pet to follow me', `text_loc4` = '让宠物跟着我' WHERE `name` = 'Setting pet to follow me';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting pet to passive mode', 'Setting pet to passive mode', '把宠物设成被动模式', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting pet to passive mode');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting pet to passive mode', `text_loc4` = '把宠物设成被动模式' WHERE `name` = 'Setting pet to passive mode';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Setting pet to stay in place', 'Setting pet to stay in place', '让宠物原地待命', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Setting pet to stay in place');
UPDATE `ai_playerbot_texts` SET `text` = 'Setting pet to stay in place', `text_loc4` = '让宠物原地待命' WHERE `name` = 'Setting pet to stay in place';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sorry, I am already in such team', 'Sorry, I am already in such team', '抱歉，我已经在这样的战队里了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sorry, I am already in such team');
UPDATE `ai_playerbot_texts` SET `text` = 'Sorry, I am already in such team', `text_loc4` = '抱歉，我已经在这样的战队里了' WHERE `name` = 'Sorry, I am already in such team';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Speed not faster than current.', 'Speed not faster than current.', '速度还没现在快。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Speed not faster than current.');
UPDATE `ai_playerbot_texts` SET `text` = 'Speed not faster than current.', `text_loc4` = '速度还没现在快。' WHERE `name` = 'Speed not faster than current.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking flight to Booty Bay!', 'Taking flight to Booty Bay!', '飞往藏宝海湾！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking flight to Booty Bay!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking flight to Booty Bay!', `text_loc4` = '飞往藏宝海湾！' WHERE `name` = 'Taking flight to Booty Bay!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking flight to Camp Mojache!', 'Taking flight to Camp Mojache!', '飞往莫沙彻营地！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking flight to Camp Mojache!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking flight to Camp Mojache!', `text_loc4` = '飞往莫沙彻营地！' WHERE `name` = 'Taking flight to Camp Mojache!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking flight to Feathermoon Stronghold!', 'Taking flight to Feathermoon Stronghold!', '飞往羽月要塞！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking flight to Feathermoon Stronghold!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking flight to Feathermoon Stronghold!', `text_loc4` = '飞往羽月要塞！' WHERE `name` = 'Taking flight to Feathermoon Stronghold!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking flight to Thalanaar!', 'Taking flight to Thalanaar!', '飞往萨兰纳尔！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking flight to Thalanaar!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking flight to Thalanaar!', `text_loc4` = '飞往萨兰纳尔！' WHERE `name` = 'Taking flight to Thalanaar!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking the portal home!', 'Taking the portal home!', '走传送门回家！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking the portal home!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking the portal home!', `text_loc4` = '走传送门回家！' WHERE `name` = 'Taking the portal home!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Target could not be found. Drop rpg target', 'Target could not be found. Drop rpg target', '找不到目标，放弃生活目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Target could not be found. Drop rpg target');
UPDATE `ai_playerbot_texts` SET `text` = 'Target could not be found. Drop rpg target', `text_loc4` = '找不到目标，放弃生活目标' WHERE `name` = 'Target could not be found. Drop rpg target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Target is cooling down because a group member found it to be inactive.', 'Target is cooling down because a group member found it to be inactive.', '队友发现这个目标不可用，进入冷却。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Target is cooling down because a group member found it to be inactive.');
UPDATE `ai_playerbot_texts` SET `text` = 'Target is cooling down because a group member found it to be inactive.', `text_loc4` = '队友发现这个目标不可用，进入冷却。' WHERE `name` = 'Target is cooling down because a group member found it to be inactive.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Thanks', 'Thanks', '谢了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Thanks');
UPDATE `ai_playerbot_texts` SET `text` = 'Thanks', `text_loc4` = '谢了' WHERE `name` = 'Thanks';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Thanks for the invite!', 'Thanks for the invite!', '谢谢邀请！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Thanks for the invite!');
UPDATE `ai_playerbot_texts` SET `text` = 'Thanks for the invite!', `text_loc4` = '谢谢邀请！' WHERE `name` = 'Thanks for the invite!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The avoid creature list has been cleared', 'The avoid creature list has been cleared', '避让生物名单已清空', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The avoid creature list has been cleared');
UPDATE `ai_playerbot_texts` SET `text` = 'The avoid creature list has been cleared', `text_loc4` = '避让生物名单已清空' WHERE `name` = 'The avoid creature list has been cleared';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The ignored spell list has been cleared', 'The ignored spell list has been cleared', '忽略法术名单已清空', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The ignored spell list has been cleared');
UPDATE `ai_playerbot_texts` SET `text` = 'The ignored spell list has been cleared', `text_loc4` = '忽略法术名单已清空' WHERE `name` = 'The ignored spell list has been cleared';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target can''t be pulled', 'The target can''t be pulled', '这个目标拉不了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target can''t be pulled');
UPDATE `ai_playerbot_texts` SET `text` = 'The target can''t be pulled', `text_loc4` = '这个目标拉不了' WHERE `name` = 'The target can''t be pulled';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is clearing because it was a travel once destination.', 'The target is clearing because it was a travel once destination.', '因为这是「去一次就完事」的目的地，目标被清除。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is clearing because it was a travel once destination.');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is clearing because it was a travel once destination.', `text_loc4` = '因为这是「去一次就完事」的目的地，目标被清除。' WHERE `name` = 'The target is clearing because it was a travel once destination.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is cooling down because the destination was no longer active or the conditions are no longer true.', 'The target is cooling down because the destination was no longer active or the conditions are no longer true.', '目的地已失效或条件不再满足，目标进入冷却。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is cooling down because the destination was no longer active or the conditions are no longer true.');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is cooling down because the destination was no longer active or the conditions are no longer true.', `text_loc4` = '目的地已失效或条件不再满足，目标进入冷却。' WHERE `name` = 'The target is cooling down because the destination was no longer active or the conditions are no longer true.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is cooling down because we failed to move to it a few times in a row.', 'The target is cooling down because we failed to move to it a few times in a row.', '连续几次走不到这个目标，进入冷却。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is cooling down because we failed to move to it a few times in a row.');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is cooling down because we failed to move to it a few times in a row.', `text_loc4` = '连续几次走不到这个目标，进入冷却。' WHERE `name` = 'The target is cooling down because we failed to move to it a few times in a row.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is ready to travel start now.', 'The target is ready to travel start now.', '目标已就绪，现在出发。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is ready to travel start now.');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is ready to travel start now.', `text_loc4` = '目标已就绪，现在出发。' WHERE `name` = 'The target is ready to travel start now.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is starting to work because the destination has been reached.', 'The target is starting to work because the destination has been reached.', '已经到达目的地，目标开始工作。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is starting to work because the destination has been reached.');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is starting to work because the destination has been reached.', `text_loc4` = '已经到达目的地，目标开始工作。' WHERE `name` = 'The target is starting to work because the destination has been reached.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'The target is too far away', 'The target is too far away', '目标离得太远', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'The target is too far away');
UPDATE `ai_playerbot_texts` SET `text` = 'The target is too far away', `text_loc4` = '目标离得太远' WHERE `name` = 'The target is too far away';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'This inn is my new home', 'This inn is my new home', '这家旅店就是我的新家了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'This inn is my new home');
UPDATE `ai_playerbot_texts` SET `text` = 'This inn is my new home', `text_loc4` = '这家旅店就是我的新家了' WHERE `name` = 'This inn is my new home';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'This trainer cannot teach me', 'This trainer cannot teach me', '这个训练师教不了我', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'This trainer cannot teach me');
UPDATE `ai_playerbot_texts` SET `text` = 'This trainer cannot teach me', `text_loc4` = '这个训练师教不了我' WHERE `name` = 'This trainer cannot teach me';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Too far from path. Rebuilding.', 'Too far from path. Rebuilding.', '离路线太远，重建。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Too far from path. Rebuilding.');
UPDATE `ai_playerbot_texts` SET `text` = 'Too far from path. Rebuilding.', `text_loc4` = '离路线太远，重建。' WHERE `name` = 'Too far from path. Rebuilding.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Travel target expired because it was from a player that is no longer in the group.', 'Travel target expired because it was from a player that is no longer in the group.', '这个旅行目标来自一个已经不在队伍里的玩家，所以过期了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Travel target expired because it was from a player that is no longer in the group.');
UPDATE `ai_playerbot_texts` SET `text` = 'Travel target expired because it was from a player that is no longer in the group.', `text_loc4` = '这个旅行目标来自一个已经不在队伍里的玩家，所以过期了。' WHERE `name` = 'Travel target expired because it was from a player that is no longer in the group.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Travel target expired because the status time was exceeded.', 'Travel target expired because the status time was exceeded.', '旅行目标超时，已过期。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Travel target expired because the status time was exceeded.');
UPDATE `ai_playerbot_texts` SET `text` = 'Travel target expired because the status time was exceeded.', `text_loc4` = '旅行目标超时，已过期。' WHERE `name` = 'Travel target expired because the status time was exceeded.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Traveling to Dire Maul North for world buffs', 'Traveling to Dire Maul North for world buffs', '前往厄运之槌北区吃世界buff', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Traveling to Dire Maul North for world buffs');
UPDATE `ai_playerbot_texts` SET `text` = 'Traveling to Dire Maul North for world buffs', `text_loc4` = '前往厄运之槌北区吃世界buff' WHERE `name` = 'Traveling to Dire Maul North for world buffs';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Traveling to nearest Songflower for world buffs', 'Traveling to nearest Songflower for world buffs', '前往最近的轻歌花吃世界buff', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Traveling to nearest Songflower for world buffs');
UPDATE `ai_playerbot_texts` SET `text` = 'Traveling to nearest Songflower for world buffs', `text_loc4` = '前往最近的轻歌花吃世界buff' WHERE `name` = 'Traveling to nearest Songflower for world buffs';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Traveling to the Dire Maul in Feralas', 'Traveling to the Dire Maul in Feralas', '前往菲拉斯的厄运之槌', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Traveling to the Dire Maul in Feralas');
UPDATE `ai_playerbot_texts` SET `text` = 'Traveling to the Dire Maul in Feralas', `text_loc4` = '前往菲拉斯的厄运之槌' WHERE `name` = 'Traveling to the Dire Maul in Feralas';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Under/above object drop rpg target', 'Under/above object drop rpg target', '目标在物件下方或上方，放弃生活目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Under/above object drop rpg target');
UPDATE `ai_playerbot_texts` SET `text` = 'Under/above object drop rpg target', `text_loc4` = '目标在物件下方或上方，放弃生活目标' WHERE `name` = 'Under/above object drop rpg target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Able to attack target.', 'Unmount. Able to attack target.', '下坐骑：能打到目标了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Able to attack target.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Able to attack target.', `text_loc4` = '下坐骑：能打到目标了。' WHERE `name` = 'Unmount. Able to attack target.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Near rpg target.', 'Unmount. Near rpg target.', '下坐骑：到生活目标附近了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Near rpg target.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Near rpg target.', `text_loc4` = '下坐骑：到生活目标附近了。' WHERE `name` = 'Unmount. Near rpg target.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Near stay location.', 'Unmount. Near stay location.', '下坐骑：到待命点了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Near stay location.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Near stay location.', `text_loc4` = '下坐骑：到待命点了。' WHERE `name` = 'Unmount. Near stay location.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Near travel target.', 'Unmount. Near travel target.', '下坐骑：到旅行目标附近了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Near travel target.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Near travel target.', `text_loc4` = '下坐骑：到旅行目标附近了。' WHERE `name` = 'Unmount. Near travel target.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Near umounted group master.', 'Unmount. Near umounted group master.', '下坐骑：队长下坐骑了，就在旁边。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Near umounted group master.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Near umounted group master.', `text_loc4` = '下坐骑：队长下坐骑了，就在旁边。' WHERE `name` = 'Unmount. Near umounted group master.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. Near umounted guard position.', 'Unmount. Near umounted guard position.', '下坐骑：到守点附近了，不用骑了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. Near umounted guard position.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. Near umounted guard position.', `text_loc4` = '下坐骑：到守点附近了，不用骑了。' WHERE `name` = 'Unmount. Near umounted guard position.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unmount. On a taxi or a boat/zeppelin.', 'Unmount. On a taxi or a boat/zeppelin.', '下坐骑：在飞行点或者船上/飞艇上。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unmount. On a taxi or a boat/zeppelin.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unmount. On a taxi or a boat/zeppelin.', `text_loc4` = '下坐骑：在飞行点或者船上/飞艇上。' WHERE `name` = 'Unmount. On a taxi or a boat/zeppelin.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: Combat stuck detected, resetting position.', 'Unstuck: Combat stuck detected, resetting position.', '脱困：检测到战斗中卡住，重置位置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: Combat stuck detected, resetting position.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: Combat stuck detected, resetting position.', `text_loc4` = '脱困：检测到战斗中卡住，重置位置。' WHERE `name` = 'Unstuck: Combat stuck detected, resetting position.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: Fallback to reset action.', 'Unstuck: Fallback to reset action.', '脱困：改用重置动作兜底。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: Fallback to reset action.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: Fallback to reset action.', `text_loc4` = '脱困：改用重置动作兜底。' WHERE `name` = 'Unstuck: Fallback to reset action.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: Long combat stuck detected, attempting hearthstone or repop.', 'Unstuck: Long combat stuck detected, attempting hearthstone or repop.', '脱困：长时间战斗中卡住，尝试炉石或复活重置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: Long combat stuck detected, attempting hearthstone or repop.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: Long combat stuck detected, attempting hearthstone or repop.', `text_loc4` = '脱困：长时间战斗中卡住，尝试炉石或复活重置。' WHERE `name` = 'Unstuck: Long combat stuck detected, attempting hearthstone or repop.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: Long move stuck detected, attempting hearthstone or repop.', 'Unstuck: Long move stuck detected, attempting hearthstone or repop.', '脱困：长时间移动中卡住，尝试炉石或复活重置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: Long move stuck detected, attempting hearthstone or repop.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: Long move stuck detected, attempting hearthstone or repop.', `text_loc4` = '脱困：长时间移动中卡住，尝试炉石或复活重置。' WHERE `name` = 'Unstuck: Long move stuck detected, attempting hearthstone or repop.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: Move stuck detected, resetting.', 'Unstuck: Move stuck detected, resetting.', '脱困：检测到移动卡住，重置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: Move stuck detected, resetting.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: Move stuck detected, resetting.', `text_loc4` = '脱困：检测到移动卡住，重置。' WHERE `name` = 'Unstuck: Move stuck detected, resetting.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unstuck: No specific source, resetting.', 'Unstuck: No specific source, resetting.', '脱困：没找到具体原因，直接重置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unstuck: No specific source, resetting.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unstuck: No specific source, resetting.', `text_loc4` = '脱困：没找到具体原因，直接重置。' WHERE `name` = 'Unstuck: No specific source, resetting.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Usage: ''craft [itemId]'' or ''craft reset''', 'Usage: ''craft [itemId]'' or ''craft reset''', '用法：craft [物品ID] 或 craft reset', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Usage: ''craft [itemId]'' or ''craft reset''');
UPDATE `ai_playerbot_texts` SET `text` = 'Usage: ''craft [itemId]'' or ''craft reset''', `text_loc4` = '用法：craft [物品ID] 或 craft reset' WHERE `name` = 'Usage: ''craft [itemId]'' or ''craft reset''';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Usage: cs <name> <idx> <command>', 'Usage: cs <name> <idx> <command>', '用法：cs <名称> <序号> <命令>', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Usage: cs <name> <idx> <command>');
UPDATE `ai_playerbot_texts` SET `text` = 'Usage: cs <name> <idx> <command>', `text_loc4` = '用法：cs <名称> <序号> <命令>' WHERE `name` = 'Usage: cs <name> <idx> <command>';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Usage: quest reward [auto|list|ask|reset|?]', 'Usage: quest reward [auto|list|ask|reset|?]', '用法：quest reward [auto|list|ask|reset|?]', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Usage: quest reward [auto|list|ask|reset|?]');
UPDATE `ai_playerbot_texts` SET `text` = 'Usage: quest reward [auto|list|ask|reset|?]', `text_loc4` = '用法：quest reward [auto|list|ask|reset|?]' WHERE `name` = 'Usage: quest reward [auto|list|ask|reset|?]';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Usage: rndbot help/stats/update/reset/init/refresh/add/remove/more..', 'Usage: rndbot help/stats/update/reset/init/refresh/add/remove/more..', '用法：rndbot help/stats/update/reset/init/refresh/add/remove/more..', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Usage: rndbot help/stats/update/reset/init/refresh/add/remove/more..');
UPDATE `ai_playerbot_texts` SET `text` = 'Usage: rndbot help/stats/update/reset/init/refresh/add/remove/more..', `text_loc4` = '用法：rndbot help/stats/update/reset/init/refresh/add/remove/more..' WHERE `name` = 'Usage: rndbot help/stats/update/reset/init/refresh/add/remove/more..';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Values supported: group size, guild size', 'Values supported: group size, guild size', '支持的变量：group size、guild size', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Values supported: group size, guild size');
UPDATE `ai_playerbot_texts` SET `text` = 'Values supported: group size, guild size', `text_loc4` = '支持的变量：group size、guild size' WHERE `name` = 'Values supported: group size, guild size';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Waiting for summoned members to arrive before applying buffs...', 'Waiting for summoned members to arrive before applying buffs...', '等一下被召唤过来的队友，人齐了再上buff……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Waiting for summoned members to arrive before applying buffs...');
UPDATE `ai_playerbot_texts` SET `text` = 'Waiting for summoned members to arrive before applying buffs...', `text_loc4` = '等一下被召唤过来的队友，人齐了再上buff……' WHERE `name` = 'Waiting for summoned members to arrive before applying buffs...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Waiting for transport on different map.', 'Waiting for transport on different map.', '在别的 map 上等交通工具。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Waiting for transport on different map.');
UPDATE `ai_playerbot_texts` SET `text` = 'Waiting for transport on different map.', `text_loc4` = '在别的 map 上等交通工具。' WHERE `name` = 'Waiting for transport on different map.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'We had some destinations but we moved too far since. Trying to get a new list.', 'We had some destinations but we moved too far since. Trying to get a new list.', '本来有目的地的，但我们跑太远了，重新找一批。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'We had some destinations but we moved too far since. Trying to get a new list.');
UPDATE `ai_playerbot_texts` SET `text` = 'We had some destinations but we moved too far since. Trying to get a new list.', `text_loc4` = '本来有目的地的，但我们跑太远了，重新找一批。' WHERE `name` = 'We had some destinations but we moved too far since. Trying to get a new list.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Welcome back!', 'Welcome back!', '欢迎回来！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Welcome back!');
UPDATE `ai_playerbot_texts` SET `text` = 'Welcome back!', `text_loc4` = '欢迎回来！' WHERE `name` = 'Welcome back!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Welcome!', 'Welcome!', '欢迎！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Welcome!');
UPDATE `ai_playerbot_texts` SET `text` = 'Welcome!', `text_loc4` = '欢迎！' WHERE `name` = 'Welcome!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Wherever you go, I''ll follow..', 'Wherever you go, I''ll follow..', '你去哪儿我都跟着……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Wherever you go, I''ll follow..');
UPDATE `ai_playerbot_texts` SET `text` = 'Wherever you go, I''ll follow..', `text_loc4` = '你去哪儿我都跟着……' WHERE `name` = 'Wherever you go, I''ll follow..';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Whisper position <name> ?/set/reset', 'Whisper position <name> ?/set/reset', '私聊命令：position <名字> ?/set/reset', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Whisper position <name> ?/set/reset');
UPDATE `ai_playerbot_texts` SET `text` = 'Whisper position <name> ?/set/reset', `text_loc4` = '私聊命令：position <名字> ?/set/reset' WHERE `name` = 'Whisper position <name> ?/set/reset';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'World buff collection complete!', 'World buff collection complete!', '世界buff全部收集完毕！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'World buff collection complete!');
UPDATE `ai_playerbot_texts` SET `text` = 'World buff collection complete!', `text_loc4` = '世界buff全部收集完毕！' WHERE `name` = 'World buff collection complete!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You already have the maximum number of characters', 'You already have the maximum number of characters', '你的角色数量已经达到上限', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You already have the maximum number of characters');
UPDATE `ai_playerbot_texts` SET `text` = 'You already have the maximum number of characters', `text_loc4` = '你的角色数量已经达到上限' WHERE `name` = 'You already have the maximum number of characters';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You can not request more than one item', 'You can not request more than one item', '你一次只能要一件物品', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You can not request more than one item');
UPDATE `ai_playerbot_texts` SET `text` = 'You can not request more than one item', `text_loc4` = '你一次只能要一件物品' WHERE `name` = 'You can not request more than one item';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You can use discount to buy items only', 'You can use discount to buy items only', '折扣只能用来买东西', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You can use discount to buy items only');
UPDATE `ai_playerbot_texts` SET `text` = 'You can use discount to buy items only', `text_loc4` = '折扣只能用来买东西' WHERE `name` = 'You can use discount to buy items only';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You cannot hire higher level characters than you', 'You cannot hire higher level characters than you', '你不能雇佣等级比你还高的角色', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You cannot hire higher level characters than you');
UPDATE `ai_playerbot_texts` SET `text` = 'You cannot hire higher level characters than you', `text_loc4` = '你不能雇佣等级比你还高的角色' WHERE `name` = 'You cannot hire higher level characters than you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You have no target', 'You have no target', '你没有目标', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You have no target');
UPDATE `ai_playerbot_texts` SET `text` = 'You have no target', `text_loc4` = '你没有目标' WHERE `name` = 'You have no target';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You may only add bots from an active session', 'You may only add bots from an active session', '只有在活动会话里才能添加机器人', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You may only add bots from an active session');
UPDATE `ai_playerbot_texts` SET `text` = 'You may only add bots from an active session', `text_loc4` = '只有在活动会话里才能添加机器人' WHERE `name` = 'You may only add bots from an active session';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'accept trade', 'accept trade', '接受交易', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'accept trade');
UPDATE `ai_playerbot_texts` SET `text` = 'accept trade', `text_loc4` = '接受交易' WHERE `name` = 'accept trade';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'glyph all/wanted/equiped for list of glyphs', 'glyph all/wanted/equiped for list of glyphs', 'glyph all/wanted/equiped 可以列出雕文', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'glyph all/wanted/equiped for list of glyphs');
UPDATE `ai_playerbot_texts` SET `text` = 'glyph all/wanted/equiped for list of glyphs', `text_loc4` = 'glyph all/wanted/equiped 可以列出雕文' WHERE `name` = 'glyph all/wanted/equiped for list of glyphs';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'open trade window', 'open trade window', '打开交易窗口', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'open trade window');
UPDATE `ai_playerbot_texts` SET `text` = 'open trade window', `text_loc4` = '打开交易窗口' WHERE `name` = 'open trade window';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'outfit <name> +[item] to add items', 'outfit <name> +[item] to add items', 'outfit <名字> +[物品] 添加物品', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'outfit <name> +[item] to add items');
UPDATE `ai_playerbot_texts` SET `text` = 'outfit <name> +[item] to add items', `text_loc4` = 'outfit <名字> +[物品] 添加物品' WHERE `name` = 'outfit <name> +[item] to add items';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'outfit <name> -[item] to remove items', 'outfit <name> -[item] to remove items', 'outfit <名字> -[物品] 移除物品', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'outfit <name> -[item] to remove items');
UPDATE `ai_playerbot_texts` SET `text` = 'outfit <name> -[item] to remove items', `text_loc4` = 'outfit <名字> -[物品] 移除物品' WHERE `name` = 'outfit <name> -[item] to remove items';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'outfit <name> equip/replace to equip items', 'outfit <name> equip/replace to equip items', 'outfit <名字> equip/replace 穿戴物品', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'outfit <name> equip/replace to equip items');
UPDATE `ai_playerbot_texts` SET `text` = 'outfit <name> equip/replace to equip items', `text_loc4` = 'outfit <名字> equip/replace 穿戴物品' WHERE `name` = 'outfit <name> equip/replace to equip items';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'rtsc file needs atleast 2 parameters: rtsc file save/load file_name optional:position_name_part optional:bot_name_part', 'rtsc file needs atleast 2 parameters: rtsc file save/load file_name optional:position_name_part optional:bot_name_part', 'rtsc file 至少需要2个参数：rtsc file save/load 文件名 可选:位置名片段 可选:机器人名片段', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'rtsc file needs atleast 2 parameters: rtsc file save/load file_name optional:position_name_part optional:bot_name_part');
UPDATE `ai_playerbot_texts` SET `text` = 'rtsc file needs atleast 2 parameters: rtsc file save/load file_name optional:position_name_part optional:bot_name_part', `text_loc4` = 'rtsc file 至少需要2个参数：rtsc file save/load 文件名 可选:位置名片段 可选:机器人名片段' WHERE `name` = 'rtsc file needs atleast 2 parameters: rtsc file save/load file_name optional:position_name_part optional:bot_name_part';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'set enchant spell', 'set enchant spell', '设置附魔法术', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'set enchant spell');
UPDATE `ai_playerbot_texts` SET `text` = 'set enchant spell', `text_loc4` = '设置附魔法术' WHERE `name` = 'set enchant spell';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'starting trade', 'starting trade', '开始交易', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'starting trade');
UPDATE `ai_playerbot_texts` SET `text` = 'starting trade', `text_loc4` = '开始交易' WHERE `name` = 'starting trade';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'usage: help/list/reload/more.. or add/init/remove/more.. PLAYERNAME', 'usage: help/list/reload/more.. or add/init/remove/more.. PLAYERNAME', '用法：help/list/reload/more.. 或 add/init/remove/more.. 玩家名', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'usage: help/list/reload/more.. or add/init/remove/more.. PLAYERNAME');
UPDATE `ai_playerbot_texts` SET `text` = 'usage: help/list/reload/more.. or add/init/remove/more.. PLAYERNAME', `text_loc4` = '用法：help/list/reload/more.. 或 add/init/remove/more.. 玩家名' WHERE `name` = 'usage: help/list/reload/more.. or add/init/remove/more.. PLAYERNAME';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'was moving trying to mount again.', 'was moving trying to mount again.', '刚才在移动，再试着上一次坐骑。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'was moving trying to mount again.');
UPDATE `ai_playerbot_texts` SET `text` = 'was moving trying to mount again.', `text_loc4` = '刚才在移动，再试着上一次坐骑。' WHERE `name` = 'was moving trying to mount again.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'whisper ''mail ?'' to query mailbox, ''mail take/delete/read filter'' to take/delete/read mails by filter', 'whisper ''mail ?'' to query mailbox, ''mail take/delete/read filter'' to take/delete/read mails by filter', '私聊我 mail ? 查邮箱，mail take/delete/read 筛选条件 可以按条件取件/删除/阅读', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'whisper ''mail ?'' to query mailbox, ''mail take/delete/read filter'' to take/delete/read mails by filter');
UPDATE `ai_playerbot_texts` SET `text` = 'whisper ''mail ?'' to query mailbox, ''mail take/delete/read filter'' to take/delete/read mails by filter', `text_loc4` = '私聊我 mail ? 查邮箱，mail take/delete/read 筛选条件 可以按条件取件/删除/阅读' WHERE `name` = 'whisper ''mail ?'' to query mailbox, ''mail take/delete/read filter'' to take/delete/read mails by filter';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'you cannot control bots yet', 'you cannot control bots yet', '你现在还不能控制机器人', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'you cannot control bots yet');
UPDATE `ai_playerbot_texts` SET `text` = 'you cannot control bots yet', `text_loc4` = '你现在还不能控制机器人' WHERE `name` = 'you cannot control bots yet';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '|cffff0000Playerbot system is currently disabled!', '|cffff0000Playerbot system is currently disabled!', '|cffff0000机器人系统当前已关闭！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '|cffff0000Playerbot system is currently disabled!');
UPDATE `ai_playerbot_texts` SET `text` = '|cffff0000Playerbot system is currently disabled!', `text_loc4` = '|cffff0000机器人系统当前已关闭！' WHERE `name` = '|cffff0000Playerbot system is currently disabled!';

-- 校验：本文件涉及的 name 必须都有中文
-- SELECT name, text, text_loc4 FROM ai_playerbot_texts WHERE text_loc4 = '' AND name IN (...);


-- 补齐：含变量的动态提示（代码里用 BOT_TEXT2 + %占位符，占位符原样保留）

INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object (hostile) ignored (out of free range).', '%object (hostile) ignored (out of free range).', '%object（敌对）已忽略（超出自由活动范围）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object (hostile) ignored (out of free range).');
UPDATE `ai_playerbot_texts` SET `text` = '%object (hostile) ignored (out of free range).', `text_loc4` = '%object（敌对）已忽略（超出自由活动范围）。' WHERE `name` = '%object (hostile) ignored (out of free range).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object (hostile) selected.', '%object (hostile) selected.', '%object（敌对）已选中。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object (hostile) selected.');
UPDATE `ai_playerbot_texts` SET `text` = '%object (hostile) selected.', `text_loc4` = '%object（敌对）已选中。' WHERE `name` = '%object (hostile) selected.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (%levels levels above bot).', '%object ignored (%levels levels above bot).', '%object 已忽略（比机器人高 %levels 级）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (%levels levels above bot).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (%levels levels above bot).', `text_loc4` = '%object 已忽略（比机器人高 %levels 级）。' WHERE `name` = '%object ignored (%levels levels above bot).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (can not fight elites currently).', '%object ignored (can not fight elites currently).', '%object 已忽略（现在打不了精英）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (can not fight elites currently).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (can not fight elites currently).', `text_loc4` = '%object 已忽略（现在打不了精英）。' WHERE `name` = '%object ignored (can not fight elites currently).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (far from master).', '%object ignored (far from master).', '%object 已忽略（离主人太远）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (far from master).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (far from master).', `text_loc4` = '%object 已忽略（离主人太远）。' WHERE `name` = '%object ignored (far from master).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (ignore critters).', '%object ignored (ignore critters).', '%object 已忽略（不理会小动物）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (ignore critters).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (ignore critters).', `text_loc4` = '%object 已忽略（不理会小动物）。' WHERE `name` = '%object ignored (ignore critters).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (is pet or evading/unkillable).', '%object ignored (is pet or evading/unkillable).', '%object 已忽略（是宠物，或者闪避/打不死）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (is pet or evading/unkillable).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (is pet or evading/unkillable).', `text_loc4` = '%object 已忽略（是宠物，或者闪避/打不死）。' WHERE `name` = '%object ignored (is pet or evading/unkillable).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (not needed for active quest).', '%object ignored (not needed for active quest).', '%object 已忽略（当前任务不需要）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (not needed for active quest).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (not needed for active quest).', `text_loc4` = '%object 已忽略（当前任务不需要）。' WHERE `name` = '%object ignored (not needed for active quest).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (not xp and not needed for quest).', '%object ignored (not xp and not needed for quest).', '%object 已忽略（没经验，任务也不需要）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (not xp and not needed for quest).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (not xp and not needed for quest).', `text_loc4` = '%object 已忽略（没经验，任务也不需要）。' WHERE `name` = '%object ignored (not xp and not needed for quest).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (out of free range).', '%object ignored (out of free range).', '%object 已忽略（超出自由活动范围）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (out of free range).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (out of free range).', `text_loc4` = '%object 已忽略（超出自由活动范围）。' WHERE `name` = '%object ignored (out of free range).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (tapped, cced or out of range).', '%object ignored (tapped, cced or out of range).', '%object 已忽略（已被抢、被控或超出距离）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (tapped, cced or out of range).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (tapped, cced or out of range).', `text_loc4` = '%object 已忽略（已被抢、被控或超出距离）。' WHERE `name` = '%object ignored (tapped, cced or out of range).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object ignored (to far above/below).', '%object ignored (to far above/below).', '%object 已忽略（离得太高或太低）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object ignored (to far above/below).');
UPDATE `ai_playerbot_texts` SET `text` = '%object ignored (to far above/below).', `text_loc4` = '%object 已忽略（离得太高或太低）。' WHERE `name` = '%object ignored (to far above/below).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object increased distance (%count bots already targeting).', '%object increased distance (%count bots already targeting).', '%object 拉远了距离（已经有 %count 个机器人在打）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object increased distance (%count bots already targeting).');
UPDATE `ai_playerbot_texts` SET `text` = '%object increased distance (%count bots already targeting).', `text_loc4` = '%object 拉远了距离（已经有 %count 个机器人在打）。' WHERE `name` = '%object increased distance (%count bots already targeting).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object increased distance (not needed for quest).', '%object increased distance (not needed for quest).', '%object 拉远了距离（任务不需要）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object increased distance (not needed for quest).');
UPDATE `ai_playerbot_texts` SET `text` = '%object increased distance (not needed for quest).', `text_loc4` = '%object 拉远了距离（任务不需要）。' WHERE `name` = '%object increased distance (not needed for quest).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%object selected.', '%object selected.', '%object 已选中。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%object selected.');
UPDATE `ai_playerbot_texts` SET `text` = '%object selected.', `text_loc4` = '%object 已选中。' WHERE `name` = '%object selected.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%player %count points loaded from %file', '%player %count points loaded from %file', '%player 的 %count 个路径点已从 %file 载入', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%player %count points loaded from %file');
UPDATE `ai_playerbot_texts` SET `text` = '%player %count points loaded from %file', `text_loc4` = '%player 的 %count 个路径点已从 %file 载入' WHERE `name` = '%player %count points loaded from %file';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%player %count points saved to %file', '%player %count points saved to %file', '%player 的 %count 个路径点已保存到 %file', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%player %count points saved to %file');
UPDATE `ai_playerbot_texts` SET `text` = '%player %count points saved to %file', `text_loc4` = '%player 的 %count 个路径点已保存到 %file' WHERE `name` = '%player %count points saved to %file';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%text is not a [spelllink].', '%text is not a [spelllink].', '%text 不是[法术链接]。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%text is not a [spelllink].');
UPDATE `ai_playerbot_texts` SET `text` = '%text is not a [spelllink].', `text_loc4` = '%text 不是[法术链接]。' WHERE `name` = '%text is not a [spelllink].';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%text is not a known runeforgespell.', '%text is not a known runeforgespell.', '%text 不是已知的符文熔铸法术。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%text is not a known runeforgespell.');
UPDATE `ai_playerbot_texts` SET `text` = '%text is not a known runeforgespell.', `text_loc4` = '%text 不是已知的符文熔铸法术。' WHERE `name` = '%text is not a known runeforgespell.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Applying %spell to weapon.', 'Applying %spell to weapon.', '正在把 %spell 附到武器上。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Applying %spell to weapon.');
UPDATE `ai_playerbot_texts` SET `text` = 'Applying %spell to weapon.', `text_loc4` = '正在把 %spell 附到武器上。' WHERE `name` = 'Applying %spell to weapon.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Arrived at %npcName. Searching for a Songflower...', 'Arrived at %npcName. Searching for a Songflower...', '到了 %npcName，开始找轻歌花……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Arrived at %npcName. Searching for a Songflower...');
UPDATE `ai_playerbot_texts` SET `text` = 'Arrived at %npcName. Searching for a Songflower...', `text_loc4` = '到了 %npcName，开始找轻歌花……' WHERE `name` = 'Arrived at %npcName. Searching for a Songflower...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Can not move to loot %guid because it no longer exists.', 'Can not move to loot %guid because it no longer exists.', '走不到 %guid 去拾取，因为它已经不存在了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Can not move to loot %guid because it no longer exists.');
UPDATE `ai_playerbot_texts` SET `text` = 'Can not move to loot %guid because it no longer exists.', `text_loc4` = '走不到 %guid 去拾取，因为它已经不存在了。' WHERE `name` = 'Can not move to loot %guid because it no longer exists.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Can not move to loot %object because it is not possible to loot.', 'Can not move to loot %object because it is not possible to loot.', '走不到 %object 去拾取，因为没法拾取。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Can not move to loot %object because it is not possible to loot.');
UPDATE `ai_playerbot_texts` SET `text` = 'Can not move to loot %object because it is not possible to loot.', `text_loc4` = '走不到 %object 去拾取，因为没法拾取。' WHERE `name` = 'Can not move to loot %object because it is not possible to loot.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot cast Portal: %keyword yet...', 'Cannot cast Portal: %keyword yet...', '现在还开不了传送门：%keyword……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot cast Portal: %keyword yet...');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot cast Portal: %keyword yet...', `text_loc4` = '现在还开不了传送门：%keyword……' WHERE `name` = 'Cannot cast Portal: %keyword yet...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Cannot find travel destination for %name', 'Cannot find travel destination for %name', '找不到 %name 的旅行目的地', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Cannot find travel destination for %name');
UPDATE `ai_playerbot_texts` SET `text` = 'Cannot find travel destination for %name', `text_loc4` = '找不到 %name 的旅行目的地' WHERE `name` = 'Cannot find travel destination for %name';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting %spell', 'Casting %spell', '正在施放 %spell', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting %spell');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting %spell', `text_loc4` = '正在施放 %spell' WHERE `name` = 'Casting %spell';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting %spell near %object', 'Casting %spell near %object', '正在 %object 附近施放 %spell', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting %spell near %object');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting %spell near %object', `text_loc4` = '正在 %object 附近施放 %spell' WHERE `name` = 'Casting %spell near %object';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting %spell on %item', 'Casting %spell on %item', '正在对 %item 施放 %spell', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting %spell on %item');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting %spell on %item', `text_loc4` = '正在对 %item 施放 %spell' WHERE `name` = 'Casting %spell on %item';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting %spell on %object', 'Casting %spell on %object', '正在对 %object 施放 %spell', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting %spell on %object');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting %spell on %object', `text_loc4` = '正在对 %object 施放 %spell' WHERE `name` = 'Casting %spell on %object';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Casting Portal: %keyword for the group!', 'Casting Portal: %keyword for the group!', '正在为队伍开传送门：%keyword！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Casting Portal: %keyword for the group!');
UPDATE `ai_playerbot_texts` SET `text` = 'Casting Portal: %keyword for the group!', `text_loc4` = '正在为队伍开传送门：%keyword！' WHERE `name` = 'Casting Portal: %keyword for the group!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Disenchanting %item', 'Disenchanting %item', '正在分解 %item', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Disenchanting %item');
UPDATE `ai_playerbot_texts` SET `text` = 'Disenchanting %item', `text_loc4` = '正在分解 %item' WHERE `name` = 'Disenchanting %item';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Exited Dire Maul. Waiting for Portal: %portalName...', 'Exited Dire Maul. Waiting for Portal: %portalName...', '出厄运之槌了，等传送门：%portalName……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Exited Dire Maul. Waiting for Portal: %portalName...');
UPDATE `ai_playerbot_texts` SET `text` = 'Exited Dire Maul. Waiting for Portal: %portalName...', `text_loc4` = '出厄运之槌了，等传送门：%portalName……' WHERE `name` = 'Exited Dire Maul. Waiting for Portal: %portalName...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Found %object stopping early.', 'Found %object stopping early.', '找到 %object，提前停下。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Found %object stopping early.');
UPDATE `ai_playerbot_texts` SET `text` = 'Found %object stopping early.', `text_loc4` = '找到 %object，提前停下。' WHERE `name` = 'Found %object stopping early.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I don''t know how to travel to %destination', 'I don''t know how to travel to %destination', '我不知道怎么去 %destination', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I don''t know how to travel to %destination');
UPDATE `ai_playerbot_texts` SET `text` = 'I don''t know how to travel to %destination', `text_loc4` = '我不知道怎么去 %destination' WHERE `name` = 'I don''t know how to travel to %destination';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I don''t know how to travel to %title', 'I don''t know how to travel to %title', '我不知道怎么去 %title', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I don''t know how to travel to %title');
UPDATE `ai_playerbot_texts` SET `text` = 'I don''t know how to travel to %title', `text_loc4` = '我不知道怎么去 %title' WHERE `name` = 'I don''t know how to travel to %title';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I have no hearthstone', 'I have no hearthstone', '我没有炉石', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I have no hearthstone');
UPDATE `ai_playerbot_texts` SET `text` = 'I have no hearthstone', `text_loc4` = '我没有炉石' WHERE `name` = 'I have no hearthstone';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I should fly', 'I should fly', '我该飞', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I should fly');
UPDATE `ai_playerbot_texts` SET `text` = 'I should fly', `text_loc4` = '我该飞' WHERE `name` = 'I should fly';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I shouldn''t fly', 'I shouldn''t fly', '我不该飞', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I shouldn''t fly');
UPDATE `ai_playerbot_texts` SET `text` = 'I shouldn''t fly', `text_loc4` = '我不该飞' WHERE `name` = 'I shouldn''t fly';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Jumping off %transport', 'Jumping off %transport', '从 %transport 上跳下去', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Jumping off %transport');
UPDATE `ai_playerbot_texts` SET `text` = 'Jumping off %transport', `text_loc4` = '从 %transport 上跳下去' WHERE `name` = 'Jumping off %transport';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Learning %recipe', 'Learning %recipe', '正在学习 %recipe', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Learning %recipe');
UPDATE `ai_playerbot_texts` SET `text` = 'Learning %recipe', `text_loc4` = '正在学习 %recipe' WHERE `name` = 'Learning %recipe';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Let me enchant this %item with %spell for you %player.', 'Let me enchant this %item with %spell for you %player.', '我来帮你把这个 %item 附上 %spell，%player。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Let me enchant this %item with %spell for you %player.');
UPDATE `ai_playerbot_texts` SET `text` = 'Let me enchant this %item with %spell for you %player.', `text_loc4` = '我来帮你把这个 %item 附上 %spell，%player。' WHERE `name` = 'Let me enchant this %item with %spell for you %player.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Moving to Suppression Device at %distance yards', 'Moving to Suppression Device at %distance yards', '正在移动到 %distance 码外的压制装置', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Moving to Suppression Device at %distance yards');
UPDATE `ai_playerbot_texts` SET `text` = 'Moving to Suppression Device at %distance yards', `text_loc4` = '正在移动到 %distance 码外的压制装置' WHERE `name` = 'Moving to Suppression Device at %distance yards';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'My hearthstone is not ready', 'My hearthstone is not ready', '我的炉石还没好', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'My hearthstone is not ready');
UPDATE `ai_playerbot_texts` SET `text` = 'My hearthstone is not ready', `text_loc4` = '我的炉石还没好' WHERE `name` = 'My hearthstone is not ready';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Opening %item', 'Opening %item', '正在打开 %item', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Opening %item');
UPDATE `ai_playerbot_texts` SET `text` = 'Opening %item', `text_loc4` = '正在打开 %item' WHERE `name` = 'Opening %item';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Portal to %keyword is already open!', 'Portal to %keyword is already open!', '去 %keyword 的传送门已经开好了！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Portal to %keyword is already open!');
UPDATE `ai_playerbot_texts` SET `text` = 'Portal to %keyword is already open!', `text_loc4` = '去 %keyword 的传送门已经开好了！' WHERE `name` = 'Portal to %keyword is already open!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered group size set to invite up to %value', 'Prefered group size set to invite up to %value', '偏好队伍人数已设为最多邀请 %value 人', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered group size set to invite up to %value');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered group size set to invite up to %value', `text_loc4` = '偏好队伍人数已设为最多邀请 %value 人' WHERE `name` = 'Prefered group size set to invite up to %value';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered guild size set to %type', 'Prefered guild size set to %type', '偏好公会人数已设为 %type', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered guild size set to %type');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered guild size set to %type', `text_loc4` = '偏好公会人数已设为 %type' WHERE `name` = 'Prefered guild size set to %type';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Prefered rpg style set to %style', 'Prefered rpg style set to %style', '偏好生活风格已设为 %style', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Prefered rpg style set to %style');
UPDATE `ai_playerbot_texts` SET `text` = 'Prefered rpg style set to %style', `text_loc4` = '偏好生活风格已设为 %style' WHERE `name` = 'Prefered rpg style set to %style';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Regrouping at Dire Maul North before portal to %portalName...', 'Regrouping at Dire Maul North before portal to %portalName...', '在厄运之槌北区集合，然后开传送门去 %portalName……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Regrouping at Dire Maul North before portal to %portalName...');
UPDATE `ai_playerbot_texts` SET `text` = 'Regrouping at Dire Maul North before portal to %portalName...', `text_loc4` = '在厄运之槌北区集合，然后开传送门去 %portalName……' WHERE `name` = 'Regrouping at Dire Maul North before portal to %portalName...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Regrouping at Songflower waiting for Portal: %portalName...', 'Regrouping at Songflower waiting for Portal: %portalName...', '在轻歌花集合，等传送门：%portalName……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Regrouping at Songflower waiting for Portal: %portalName...');
UPDATE `ai_playerbot_texts` SET `text` = 'Regrouping at Songflower waiting for Portal: %portalName...', `text_loc4` = '在轻歌花集合，等传送门：%portalName……' WHERE `name` = 'Regrouping at Songflower waiting for Portal: %portalName...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Summoning %summonName to the group!', 'Summoning %summonName to the group!', '正在把 %summonName 召唤到队伍里！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Summoning %summonName to the group!');
UPDATE `ai_playerbot_texts` SET `text` = 'Summoning %summonName to the group!', `text_loc4` = '正在把 %summonName 召唤到队伍里！' WHERE `name` = 'Summoning %summonName to the group!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Taking the portal to %keyword!', 'Taking the portal to %keyword!', '走传送门去 %keyword！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Taking the portal to %keyword!');
UPDATE `ai_playerbot_texts` SET `text` = 'Taking the portal to %keyword!', `text_loc4` = '走传送门去 %keyword！' WHERE `name` = 'Taking the portal to %keyword!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Thank you %name.', 'Thank you %name.', '谢谢你，%name。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Thank you %name.');
UPDATE `ai_playerbot_texts` SET `text` = 'Thank you %name.', `text_loc4` = '谢谢你，%name。' WHERE `name` = 'Thank you %name.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'There are no innkeepers near you', 'There are no innkeepers near you', '你附近没有旅店老板', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'There are no innkeepers near you');
UPDATE `ai_playerbot_texts` SET `text` = 'There are no innkeepers near you', `text_loc4` = '你附近没有旅店老板' WHERE `name` = 'There are no innkeepers near you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'There are no innkeepers nearby', 'There are no innkeepers nearby', '附近没有旅店老板', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'There are no innkeepers nearby');
UPDATE `ai_playerbot_texts` SET `text` = 'There are no innkeepers nearby', `text_loc4` = '附近没有旅店老板' WHERE `name` = 'There are no innkeepers nearby';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'There is no meeting stone near you', 'There is no meeting stone near you', '你附近没有集合石', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'There is no meeting stone near you');
UPDATE `ai_playerbot_texts` SET `text` = 'There is no meeting stone near you', `text_loc4` = '你附近没有集合石' WHERE `name` = 'There is no meeting stone near you';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'There is no meeting stone nearby', 'There is no meeting stone nearby', '附近没有集合石', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'There is no meeting stone nearby');
UPDATE `ai_playerbot_texts` SET `text` = 'There is no meeting stone nearby', `text_loc4` = '附近没有集合石' WHERE `name` = 'There is no meeting stone nearby';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Traveling to %name for world buffs', 'Traveling to %name for world buffs', '前往 %name 吃世界buff', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Traveling to %name for world buffs');
UPDATE `ai_playerbot_texts` SET `text` = 'Traveling to %name for world buffs', `text_loc4` = '前往 %name 吃世界buff' WHERE `name` = 'Traveling to %name for world buffs';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Try to mount with %spell', 'Try to mount with %spell', '试着用 %spell 上坐骑', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Try to mount with %spell');
UPDATE `ai_playerbot_texts` SET `text` = 'Try to mount with %spell', `text_loc4` = '试着用 %spell 上坐骑' WHERE `name` = 'Try to mount with %spell';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Waiting for %seconds seconds!', 'Waiting for %seconds seconds!', '还要等 %seconds 秒！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Waiting for %seconds seconds!');
UPDATE `ai_playerbot_texts` SET `text` = 'Waiting for %seconds seconds!', `text_loc4` = '还要等 %seconds 秒！' WHERE `name` = 'Waiting for %seconds seconds!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Waiting for a mage to open Portal: %keyword...', 'Waiting for a mage to open Portal: %keyword...', '等法师开传送门：%keyword……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Waiting for a mage to open Portal: %keyword...');
UPDATE `ai_playerbot_texts` SET `text` = 'Waiting for a mage to open Portal: %keyword...', `text_loc4` = '等法师开传送门：%keyword……' WHERE `name` = 'Waiting for a mage to open Portal: %keyword...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'We are near %title', 'We are near %title', '我们到 %title 附近了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'We are near %title');
UPDATE `ai_playerbot_texts` SET `text` = 'We are near %title', `text_loc4` = '我们到 %title 附近了' WHERE `name` = 'We are near %title';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'We are now near %name.', 'We are now near %name.', '我们现在到 %name 附近了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'We are now near %name.');
UPDATE `ai_playerbot_texts` SET `text` = 'We are now near %name.', `text_loc4` = '我们现在到 %name 附近了。' WHERE `name` = 'We are now near %name.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You can use this %item better than me, %player.', 'You can use this %item better than me, %player.', '这个 %item 你用得比我好，%player。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You can use this %item better than me, %player.');
UPDATE `ai_playerbot_texts` SET `text` = 'You can use this %item better than me, %player.', `text_loc4` = '这个 %item 你用得比我好，%player。' WHERE `name` = 'You can use this %item better than me, %player.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You have no hearthstone', 'You have no hearthstone', '你没有炉石', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You have no hearthstone');
UPDATE `ai_playerbot_texts` SET `text` = 'You have no hearthstone', `text_loc4` = '你没有炉石' WHERE `name` = 'You have no hearthstone';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Your hearthstone is not ready', 'Your hearthstone is not ready', '你的炉石还没好', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Your hearthstone is not ready');
UPDATE `ai_playerbot_texts` SET `text` = 'Your hearthstone is not ready', `text_loc4` = '你的炉石还没好' WHERE `name` = 'Your hearthstone is not ready';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'if we want to travel to %title', 'if we want to travel to %title', '如果要去 %title', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'if we want to travel to %title');
UPDATE `ai_playerbot_texts` SET `text` = 'if we want to travel to %title', `text_loc4` = '如果要去 %title' WHERE `name` = 'if we want to travel to %title';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'we should head to %name', 'we should head to %name', '我们应该先去 %name', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'we should head to %name');
UPDATE `ai_playerbot_texts` SET `text` = 'we should head to %name', `text_loc4` = '我们应该先去 %name' WHERE `name` = 'we should head to %name';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'we should head to %name in %area', 'we should head to %name in %area', '我们应该先去 %name，在 %area', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'we should head to %name in %area');
UPDATE `ai_playerbot_texts` SET `text` = 'we should head to %name in %area', `text_loc4` = '我们应该先去 %name，在 %area' WHERE `name` = 'we should head to %name in %area';

