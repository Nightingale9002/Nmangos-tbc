-- 181 台词补录：PlayerBots 模块里 BOT_TEXT("…") / BOT_TEXT2("…", …) 用到、但本地库
--      ai_playerbot_texts 里查不到的 97 个 key（其中 no_permission_for_bot_command 是
--      第 4 项『.bot 命令闸门』新加的拒绝提示）。
-- name = 英文 key、text = 英文 key、text_loc4 = 地道中文（zhCN）。
-- 幂等：每条先做『不存在才插入』，再无条件 UPDATE 一次；因为 name 列**没有唯一索引**（表里已有 127 个重名），
--       不能用 ON DUPLICATE KEY UPDATE。重复执行结果不变。

SET NAMES utf8mb4;

INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%available/%required for questId: %quest_id', '%available/%required for questId: %quest_id', '任务 %quest_id：%available/%required', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%available/%required for questId: %quest_id');
UPDATE `ai_playerbot_texts` SET `text` = '%available/%required for questId: %quest_id', `text_loc4` = '任务 %quest_id：%available/%required' WHERE `name` = '%available/%required for questId: %quest_id';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph can not be equiped for this level', '%glyph can not be equiped for this level', '%glyph 在现在的等级还用不了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph can not be equiped for this level');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph can not be equiped for this level', `text_loc4` = '%glyph 在现在的等级还用不了' WHERE `name` = '%glyph can not be equiped for this level';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph does not fit in slot %slot', '%glyph does not fit in slot %slot', '%glyph 放不进 %slot 号插槽', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph does not fit in slot %slot');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph does not fit in slot %slot', `text_loc4` = '%glyph 放不进 %slot 号插槽' WHERE `name` = '%glyph does not fit in slot %slot';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph is already active', '%glyph is already active', '%glyph 已经是激活状态了', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph is already active');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph is already active', `text_loc4` = '%glyph 已经是激活状态了' WHERE `name` = '%glyph is already active';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph is not a valid glyph', '%glyph is not a valid glyph', '%glyph 不是有效的雕文', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph is not a valid glyph');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph is not a valid glyph', `text_loc4` = '%glyph 不是有效的雕文' WHERE `name` = '%glyph is not a valid glyph';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph is not a valid glyph for this class', '%glyph is not a valid glyph for this class', '%glyph 不是本职业能用的雕文', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph is not a valid glyph for this class');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph is not a valid glyph for this class', `text_loc4` = '%glyph 不是本职业能用的雕文' WHERE `name` = '%glyph is not a valid glyph for this class';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%glyph is not found in inventory', '%glyph is not found in inventory', '背包里找不到 %glyph', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%glyph is not found in inventory');
UPDATE `ai_playerbot_texts` SET `text` = '%glyph is not found in inventory', `text_loc4` = '背包里找不到 %glyph' WHERE `name` = '%glyph is not found in inventory';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%name, I got this guild....', '%name, I got this guild....', '%name，这个公会是我拉起来的……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%name, I got this guild....');
UPDATE `ai_playerbot_texts` SET `text` = '%name, I got this guild....', `text_loc4` = '%name，这个公会是我拉起来的……' WHERE `name` = '%name, I got this guild....';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%name, you should join my guild!', '%name, you should join my guild!', '%name，来我们公会吧！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%name, you should join my guild!');
UPDATE `ai_playerbot_texts` SET `text` = '%name, you should join my guild!', `text_loc4` = '%name，来我们公会吧！' WHERE `name` = '%name, you should join my guild!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%name, your guild has over 1000 members. To stop it from reaching the 1064 member limit I refuse to join it.', '%name, your guild has over 1000 members. To stop it from reaching the 1064 member limit I refuse to join it.', '%name，你的公会已经超过 1000 人了。为了不让它撞上 1064 人的上限，我不能加入。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%name, your guild has over 1000 members. To stop it from reaching the 1064 member limit I refuse to join it.');
UPDATE `ai_playerbot_texts` SET `text` = '%name, your guild has over 1000 members. To stop it from reaching the 1064 member limit I refuse to join it.', `text_loc4` = '%name，你的公会已经超过 1000 人了。为了不让它撞上 1064 人的上限，我不能加入。' WHERE `name` = '%name, your guild has over 1000 members. To stop it from reaching the 1064 member limit I refuse to join it.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '%quest_link - %item_link %quest_obj_available/%quest_obj_required', '%quest_link - %item_link %quest_obj_available/%quest_obj_required', '%quest_link - %item_link %quest_obj_available/%quest_obj_required', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '%quest_link - %item_link %quest_obj_available/%quest_obj_required');
UPDATE `ai_playerbot_texts` SET `text` = '%quest_link - %item_link %quest_obj_available/%quest_obj_required', `text_loc4` = '%quest_link - %item_link %quest_obj_available/%quest_obj_required' WHERE `name` = '%quest_link - %item_link %quest_obj_available/%quest_obj_required';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '..and it''s really beautifull and I feel like crying...', '..and it''s really beautifull and I feel like crying...', '……而且那里真的很美，我都要感动哭了……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '..and it''s really beautifull and I feel like crying...');
UPDATE `ai_playerbot_texts` SET `text` = '..and it''s really beautifull and I feel like crying...', `text_loc4` = '……而且那里真的很美，我都要感动哭了……' WHERE `name` = '..and it''s really beautifull and I feel like crying...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '..and please stop I''m lonenly and we can get a ride the whole time...', '..and please stop I''m lonenly and we can get a ride the whole time...', '……求你别说了，我一个人好孤单，而且我们全程都能搭车……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '..and please stop I''m lonenly and we can get a ride the whole time...');
UPDATE `ai_playerbot_texts` SET `text` = '..and please stop I''m lonenly and we can get a ride the whole time...', `text_loc4` = '……求你别说了，我一个人好孤单，而且我们全程都能搭车……' WHERE `name` = '..and please stop I''m lonenly and we can get a ride the whole time...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '..and watch your dog and do your homework...', '..and watch your dog and do your homework...', '……还要遛狗、写作业……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '..and watch your dog and do your homework...');
UPDATE `ai_playerbot_texts` SET `text` = '..and watch your dog and do your homework...', `text_loc4` = '……还要遛狗、写作业……' WHERE `name` = '..and watch your dog and do your homework...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '..and we have more members than just me...', '..and we have more members than just me...', '……我们公会可不只有我一个人……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '..and we have more members than just me...');
UPDATE `ai_playerbot_texts` SET `text` = '..and we have more members than just me...', `text_loc4` = '……我们公会可不只有我一个人……' WHERE `name` = '..and we have more members than just me...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '..and we raid once a week and are working on MC raids...', '..and we raid once a week and are working on MC raids...', '……我们每周开一次团，正在打熔火之心……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '..and we raid once a week and are working on MC raids...');
UPDATE `ai_playerbot_texts` SET `text` = '..and we raid once a week and are working on MC raids...', `text_loc4` = '……我们每周开一次团，正在打熔火之心……' WHERE `name` = '..and we raid once a week and are working on MC raids...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Applied %glyph to slot %slot', 'Applied %glyph to slot %slot', '已把 %glyph 镶入 %slot 号插槽', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Applied %glyph to slot %slot');
UPDATE `ai_playerbot_texts` SET `text` = 'Applied %glyph to slot %slot', `text_loc4` = '已把 %glyph 镶入 %slot 号插槽' WHERE `name` = 'Applied %glyph to slot %slot';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Checked at war for %factionname', 'Checked at war for %factionname', '已勾选对 %factionname 开战', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Checked at war for %factionname');
UPDATE `ai_playerbot_texts` SET `text` = 'Checked at war for %factionname', `text_loc4` = '已勾选对 %factionname 开战' WHERE `name` = 'Checked at war for %factionname';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Completed %quest_id', 'Completed %quest_id', '已完成任务 %quest_id', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Completed %quest_id');
UPDATE `ai_playerbot_texts` SET `text` = 'Completed %quest_id', `text_loc4` = '已完成任务 %quest_id' WHERE `name` = 'Completed %quest_id';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Completed %quest_link', 'Completed %quest_link', '已完成任务 %quest_link', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Completed %quest_link');
UPDATE `ai_playerbot_texts` SET `text` = 'Completed %quest_link', `text_loc4` = '已完成任务 %quest_link' WHERE `name` = 'Completed %quest_link';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Failed timer for %quest_id', 'Failed timer for %quest_id', '任务 %quest_id 计时失败', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Failed timer for %quest_id');
UPDATE `ai_playerbot_texts` SET `text` = 'Failed timer for %quest_id', `text_loc4` = '任务 %quest_id 计时失败' WHERE `name` = 'Failed timer for %quest_id';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Failed timer for %quest_link, abandoning', 'Failed timer for %quest_link, abandoning', '任务 %quest_link 计时失败，放弃', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Failed timer for %quest_link, abandoning');
UPDATE `ai_playerbot_texts` SET `text` = 'Failed timer for %quest_link, abandoning', `text_loc4` = '任务 %quest_link 计时失败，放弃' WHERE `name` = 'Failed timer for %quest_link, abandoning';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Got %count of itemId: %item_id for quest', 'Got %count of itemId: %item_id for quest', '为任务拿到 %item_id，共 %count 个', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Got %count of itemId: %item_id for quest');
UPDATE `ai_playerbot_texts` SET `text` = 'Got %count of itemId: %item_id for quest', `text_loc4` = '为任务拿到 %item_id，共 %count 个' WHERE `name` = 'Got %count of itemId: %item_id for quest';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Haha.. you are the man! We are going to raid Molten...', 'Haha.. you are the man! We are going to raid Molten...', '哈哈……你太给力了！我们要去熔火之心开团……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Haha.. you are the man! We are going to raid Molten...');
UPDATE `ai_playerbot_texts` SET `text` = 'Haha.. you are the man! We are going to raid Molten...', `text_loc4` = '哈哈……你太给力了！我们要去熔火之心开团……' WHERE `name` = 'Haha.. you are the man! We are going to raid Molten...';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey %name I''m raiding in %zone_name do you want to join me?', 'Hey %name I''m raiding in %zone_name do you want to join me?', '嘿 %name，我在 %zone_name 打团，一起来吗？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey %name I''m raiding in %zone_name do you want to join me?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey %name I''m raiding in %zone_name do you want to join me?', `text_loc4` = '嘿 %name，我在 %zone_name 打团，一起来吗？' WHERE `name` = 'Hey %name I''m raiding in %zone_name do you want to join me?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey %name do you want create a guild together?', 'Hey %name do you want create a guild together?', '嘿 %name，要不要一起建个公会？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey %name do you want create a guild together?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey %name do you want create a guild together?', `text_loc4` = '嘿 %name，要不要一起建个公会？' WHERE `name` = 'Hey %name do you want create a guild together?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey %name do you want join my group? I''m heading for %zone_name', 'Hey %name do you want join my group? I''m heading for %zone_name', '嘿 %name，要不要加入我的队伍？我正要去 %zone_name', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey %name do you want join my group? I''m heading for %zone_name');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey %name do you want join my group? I''m heading for %zone_name', `text_loc4` = '嘿 %name，要不要加入我的队伍？我正要去 %zone_name' WHERE `name` = 'Hey %name do you want join my group? I''m heading for %zone_name';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey %name do you want to join %guildname? We have %members members and looking to become number 1 of the server.', 'Hey %name do you want to join %guildname? We have %members members and looking to become number 1 of the server.', '嘿 %name，要不要加入 %guildname？我们有 %members 名成员，目标就是做本服第一。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey %name do you want to join %guildname? We have %members members and looking to become number 1 of the server.');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey %name do you want to join %guildname? We have %members members and looking to become number 1 of the server.', `text_loc4` = '嘿 %name，要不要加入 %guildname？我们有 %members 名成员，目标就是做本服第一。' WHERE `name` = 'Hey %name do you want to join %guildname? We have %members members and looking to become number 1 of the server.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey %name do you want to join my guild?', 'Hey %name do you want to join my guild?', '嘿 %name，要不要加入我的公会？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey %name do you want to join my guild?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey %name do you want to join my guild?', `text_loc4` = '嘿 %name，要不要加入我的公会？' WHERE `name` = 'Hey %name do you want to join my guild?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey Hey! do you guys wanna join my gild????', 'Hey Hey! do you guys wanna join my gild????', '嘿嘿！你们几个要不要加入我的工会啊？？？？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey Hey! do you guys wanna join my gild????');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey Hey! do you guys wanna join my gild????', `text_loc4` = '嘿嘿！你们几个要不要加入我的工会啊？？？？' WHERE `name` = 'Hey Hey! do you guys wanna join my gild????';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey anyone wanna group up in %zone_name?', 'Hey anyone wanna group up in %zone_name?', '嘿，有人在 %zone_name 想组队吗？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey anyone wanna group up in %zone_name?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey anyone wanna group up in %zone_name?', `text_loc4` = '嘿，有人在 %zone_name 想组队吗？' WHERE `name` = 'Hey anyone wanna group up in %zone_name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey anyone want to raid in %zone_name', 'Hey anyone want to raid in %zone_name', '嘿，有人想在 %zone_name 打团吗', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey anyone want to raid in %zone_name');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey anyone want to raid in %zone_name', `text_loc4` = '嘿，有人想在 %zone_name 打团吗' WHERE `name` = 'Hey anyone want to raid in %zone_name';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey do you want to form a guild?', 'Hey do you want to form a guild?', '嘿，要不要一起建个公会？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey do you want to form a guild?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey do you want to form a guild?', `text_loc4` = '嘿，要不要一起建个公会？' WHERE `name` = 'Hey do you want to form a guild?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Hey man you wanna join my guild %name?', 'Hey man you wanna join my guild %name?', '嘿兄弟，要不要加入我的公会 %name？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Hey man you wanna join my guild %name?');
UPDATE `ai_playerbot_texts` SET `text` = 'Hey man you wanna join my guild %name?', `text_loc4` = '嘿兄弟，要不要加入我的公会 %name？' WHERE `name` = 'Hey man you wanna join my guild %name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I already have at war checked for %factionname.', 'I already have at war checked for %factionname.', '我已经勾选对 %factionname 开战了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I already have at war checked for %factionname.');
UPDATE `ai_playerbot_texts` SET `text` = 'I already have at war checked for %factionname.', `text_loc4` = '我已经勾选对 %factionname 开战了。' WHERE `name` = 'I already have at war checked for %factionname.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I already have at war unchecked for %factionname.', 'I already have at war unchecked for %factionname.', '我已经取消对 %factionname 的开战了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I already have at war unchecked for %factionname.');
UPDATE `ai_playerbot_texts` SET `text` = 'I already have at war unchecked for %factionname.', `text_loc4` = '我已经取消对 %factionname 的开战了。' WHERE `name` = 'I already have at war unchecked for %factionname.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I am leaving this guild to prevent it from reaching the %guild_bot_limit member limit.', 'I am leaving this guild to prevent it from reaching the %guild_bot_limit member limit.', '我这就退会，免得它撞上 %guild_bot_limit 人的上限。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I am leaving this guild to prevent it from reaching the %guild_bot_limit member limit.');
UPDATE `ai_playerbot_texts` SET `text` = 'I am leaving this guild to prevent it from reaching the %guild_bot_limit member limit.', `text_loc4` = '我这就退会，免得它撞上 %guild_bot_limit 人的上限。' WHERE `name` = 'I am leaving this guild to prevent it from reaching the %guild_bot_limit member limit.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I do not have %skillname.', 'I do not have %skillname.', '我不会 %skillname。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I do not have %skillname.');
UPDATE `ai_playerbot_texts` SET `text` = 'I do not have %skillname.', `text_loc4` = '我不会 %skillname。' WHERE `name` = 'I do not have %skillname.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I do not have any factions where I can toggle at war.', 'I do not have any factions where I can toggle at war.', '我没有可以切换开战状态的声望阵营。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I do not have any factions where I can toggle at war.');
UPDATE `ai_playerbot_texts` SET `text` = 'I do not have any factions where I can toggle at war.', `text_loc4` = '我没有可以切换开战状态的声望阵营。' WHERE `name` = 'I do not have any factions where I can toggle at war.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I do not have any visible factions.', 'I do not have any visible factions.', '我没有任何可见的声望阵营。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I do not have any visible factions.');
UPDATE `ai_playerbot_texts` SET `text` = 'I do not have any visible factions.', `text_loc4` = '我没有任何可见的声望阵营。' WHERE `name` = 'I do not have any visible factions.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I do not have skills.', 'I do not have skills.', '我一个技能都还没有。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I do not have skills.');
UPDATE `ai_playerbot_texts` SET `text` = 'I do not have skills.', `text_loc4` = '我一个技能都还没有。' WHERE `name` = 'I do not have skills.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I do not know %factionname.', 'I do not know %factionname.', '我不认识 %factionname 这个阵营。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I do not know %factionname.');
UPDATE `ai_playerbot_texts` SET `text` = 'I do not know %factionname.', `text_loc4` = '我不认识 %factionname 这个阵营。' WHERE `name` = 'I do not know %factionname.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I think you would be a good contribution to %guildname. Would you like to join %name?', 'I think you would be a good contribution to %guildname. Would you like to join %name?', '我觉得你能给 %guildname 带来很大帮助。%name，你愿意加入吗？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I think you would be a good contribution to %guildname. Would you like to join %name?');
UPDATE `ai_playerbot_texts` SET `text` = 'I think you would be a good contribution to %guildname. Would you like to join %name?', `text_loc4` = '我觉得你能给 %guildname 带来很大帮助。%name，你愿意加入吗？' WHERE `name` = 'I think you would be a good contribution to %guildname. Would you like to join %name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I would love to join!', 'I would love to join!', '我很乐意加入！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I would love to join!');
UPDATE `ai_playerbot_texts` SET `text` = 'I would love to join!', `text_loc4` = '我很乐意加入！' WHERE `name` = 'I would love to join!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'I''m not really good at smalltalk. Do you wanna join my guild %name/r?', 'I''m not really good at smalltalk. Do you wanna join my guild %name/r?', '我不太会闲聊。%name，你要加入我的公会吗？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'I''m not really good at smalltalk. Do you wanna join my guild %name/r?');
UPDATE `ai_playerbot_texts` SET `text` = 'I''m not really good at smalltalk. Do you wanna join my guild %name/r?', `text_loc4` = '我不太会闲聊。%name，你要加入我的公会吗？' WHERE `name` = 'I''m not really good at smalltalk. Do you wanna join my guild %name/r?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Joining as %role, %spotsleft %role spots left.', 'Joining as %role, %spotsleft %role spots left.', '以 %role 身份加入，还剩 %spotsleft 个 %role 位置。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Joining as %role, %spotsleft %role spots left.');
UPDATE `ai_playerbot_texts` SET `text` = 'Joining as %role, %spotsleft %role spots left.', `text_loc4` = '以 %role 身份加入，还剩 %spotsleft 个 %role 位置。' WHERE `name` = 'Joining as %role, %spotsleft %role spots left.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Joining as %role.', 'Joining as %role.', '以 %role 身份加入。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Joining as %role.');
UPDATE `ai_playerbot_texts` SET `text` = 'Joining as %role.', `text_loc4` = '以 %role 身份加入。' WHERE `name` = 'Joining as %role.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'My guild %guildname has %members quality members. Would you like to make it 1 more %name?', 'My guild %guildname has %members quality members. Would you like to make it 1 more %name?', '我的公会 %guildname 有 %members 名好手。%name，要不要让它再多一个？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'My guild %guildname has %members quality members. Would you like to make it 1 more %name?');
UPDATE `ai_playerbot_texts` SET `text` = 'My guild %guildname has %members quality members. Would you like to make it 1 more %name?', `text_loc4` = '我的公会 %guildname 有 %members 名好手。%name，要不要让它再多一个？' WHERE `name` = 'My guild %guildname has %members quality members. Would you like to make it 1 more %name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No free slot available for %glyph', 'No free slot available for %glyph', '没有空插槽能放 %glyph', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No free slot available for %glyph');
UPDATE `ai_playerbot_texts` SET `text` = 'No free slot available for %glyph', `text_loc4` = '没有空插槽能放 %glyph' WHERE `name` = 'No free slot available for %glyph';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'No glyph in slot %slot', 'No glyph in slot %slot', '%slot 号插槽里没有雕文', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'No glyph in slot %slot');
UPDATE `ai_playerbot_texts` SET `text` = 'No glyph in slot %slot', `text_loc4` = '%slot 号插槽里没有雕文' WHERE `name` = 'No glyph in slot %slot';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to GuildRecruitment, %rand1, %rand2, %rand3', 'Posted to GuildRecruitment, %rand1, %rand2, %rand3', '已在公会招募频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to GuildRecruitment, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to GuildRecruitment, %rand1, %rand2, %rand3', `text_loc4` = '已在公会招募频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to GuildRecruitment, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to LFG, %rand1, %rand2, %rand3', 'Posted to LFG, %rand1, %rand2, %rand3', '已在寻求组队频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to LFG, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to LFG, %rand1, %rand2, %rand3', `text_loc4` = '已在寻求组队频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to LFG, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to LocalDefense, %rand1, %rand2, %rand3', 'Posted to LocalDefense, %rand1, %rand2, %rand3', '已在本土防务频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to LocalDefense, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to LocalDefense, %rand1, %rand2, %rand3', `text_loc4` = '已在本土防务频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to LocalDefense, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to WorldDefense, %rand1, %rand2, %rand3', 'Posted to WorldDefense, %rand1, %rand2, %rand3', '已在世界防务频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to WorldDefense, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to WorldDefense, %rand1, %rand2, %rand3', `text_loc4` = '已在世界防务频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to WorldDefense, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to general, %rand1, %rand2, %rand3', 'Posted to general, %rand1, %rand2, %rand3', '已在综合频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to general, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to general, %rand1, %rand2, %rand3', `text_loc4` = '已在综合频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to general, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to guild, %rand1, %rand2, %rand3', 'Posted to guild, %rand1, %rand2, %rand3', '已在公会频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to guild, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to guild, %rand1, %rand2, %rand3', `text_loc4` = '已在公会频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to guild, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to trade, %rand1, %rand2, %rand3', 'Posted to trade, %rand1, %rand2, %rand3', '已在交易频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to trade, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to trade, %rand1, %rand2, %rand3', `text_loc4` = '已在交易频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to trade, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Posted to world, %rand1, %rand2, %rand3', 'Posted to world, %rand1, %rand2, %rand3', '已在世界频道发布：%rand1、%rand2、%rand3', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Posted to world, %rand1, %rand2, %rand3');
UPDATE `ai_playerbot_texts` SET `text` = 'Posted to world, %rand1, %rand2, %rand3', `text_loc4` = '已在世界频道发布：%rand1、%rand2、%rand3' WHERE `name` = 'Posted to world, %rand1, %rand2, %rand3';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Removed %glyph from slot %slot', 'Removed %glyph from slot %slot', '已从 %slot 号插槽取下 %glyph', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Removed %glyph from slot %slot');
UPDATE `ai_playerbot_texts` SET `text` = 'Removed %glyph from slot %slot', `text_loc4` = '已从 %slot 号插槽取下 %glyph' WHERE `name` = 'Removed %glyph from slot %slot';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Send me an invite %name!', 'Send me an invite %name!', '%name，邀请我呀！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Send me an invite %name!');
UPDATE `ai_playerbot_texts` SET `text` = 'Send me an invite %name!', `text_loc4` = '%name，邀请我呀！' WHERE `name` = 'Send me an invite %name!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Slot %slot is locked', 'Slot %slot is locked', '%slot 号插槽是锁住的', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Slot %slot is locked');
UPDATE `ai_playerbot_texts` SET `text` = 'Slot %slot is locked', `text_loc4` = '%slot 号插槽是锁住的' WHERE `name` = 'Slot %slot is locked';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'So what do you guys say are you going to join are you going to join?', 'So what do you guys say are you going to join are you going to join?', '那你们说呢，到底加不加入？加不加入啊？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'So what do you guys say are you going to join are you going to join?');
UPDATE `ai_playerbot_texts` SET `text` = 'So what do you guys say are you going to join are you going to join?', `text_loc4` = '那你们说呢，到底加不加入？加不加入啊？' WHERE `name` = 'So what do you guys say are you going to join are you going to join?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sorry, I am in a guild already %name.', 'Sorry, I am in a guild already %name.', '抱歉 %name，我已经有公会了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sorry, I am in a guild already %name.');
UPDATE `ai_playerbot_texts` SET `text` = 'Sorry, I am in a guild already %name.', `text_loc4` = '抱歉 %name，我已经有公会了。' WHERE `name` = 'Sorry, I am in a guild already %name.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sorry, I don''t want to join your guild %name :(.', 'Sorry, I don''t want to join your guild %name :(.', '抱歉 %name，我不想加入你的公会 :(', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sorry, I don''t want to join your guild %name :(.');
UPDATE `ai_playerbot_texts` SET `text` = 'Sorry, I don''t want to join your guild %name :(.', `text_loc4` = '抱歉 %name，我不想加入你的公会 :(' WHERE `name` = 'Sorry, I don''t want to join your guild %name :(.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sounds good %name sign me up!', 'Sounds good %name sign me up!', '听着不错，%name，算我一个！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sounds good %name sign me up!');
UPDATE `ai_playerbot_texts` SET `text` = 'Sounds good %name sign me up!', `text_loc4` = '听着不错，%name，算我一个！' WHERE `name` = 'Sounds good %name sign me up!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Sure I will join you.', 'Sure I will join you.', '好啊，我加入。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Sure I will join you.');
UPDATE `ai_playerbot_texts` SET `text` = 'Sure I will join you.', `text_loc4` = '好啊，我加入。' WHERE `name` = 'Sure I will join you.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unable change at war for %factionname because peace is forced for this faction.', 'Unable change at war for %factionname because peace is forced for this faction.', '没法切换对 %factionname 的开战状态，这个阵营强制和平。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unable change at war for %factionname because peace is forced for this faction.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unable change at war for %factionname because peace is forced for this faction.', `text_loc4` = '没法切换对 %factionname 的开战状态，这个阵营强制和平。' WHERE `name` = 'Unable change at war for %factionname because peace is forced for this faction.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unable to unlearn %skillname', 'Unable to unlearn %skillname', '无法遗忘 %skillname', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unable to unlearn %skillname');
UPDATE `ai_playerbot_texts` SET `text` = 'Unable to unlearn %skillname', `text_loc4` = '无法遗忘 %skillname' WHERE `name` = 'Unable to unlearn %skillname';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unable uncheck at war for %factionname because they hate me too much.', 'Unable uncheck at war for %factionname because they hate me too much.', '没法取消对 %factionname 的开战，他们太恨我了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unable uncheck at war for %factionname because they hate me too much.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unable uncheck at war for %factionname because they hate me too much.', `text_loc4` = '没法取消对 %factionname 的开战，他们太恨我了。' WHERE `name` = 'Unable uncheck at war for %factionname because they hate me too much.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unchecked at war for %factionname', 'Unchecked at war for %factionname', '已取消对 %factionname 的开战', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unchecked at war for %factionname');
UPDATE `ai_playerbot_texts` SET `text` = 'Unchecked at war for %factionname', `text_loc4` = '已取消对 %factionname 的开战' WHERE `name` = 'Unchecked at war for %factionname';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unknown group size. Valid sizes for lfg are 40, 25, 20, 10 and 5.', 'Unknown group size. Valid sizes for lfg are 40, 25, 20, 10 and 5.', '队伍人数无效。随机组队只支持 40、25、20、10 和 5 人。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unknown group size. Valid sizes for lfg are 40, 25, 20, 10 and 5.');
UPDATE `ai_playerbot_texts` SET `text` = 'Unknown group size. Valid sizes for lfg are 40, 25, 20, 10 and 5.', `text_loc4` = '队伍人数无效。随机组队只支持 40、25、20、10 和 5 人。' WHERE `name` = 'Unknown group size. Valid sizes for lfg are 40, 25, 20, 10 and 5.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Unlearned %skillname', 'Unlearned %skillname', '已遗忘 %skillname', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Unlearned %skillname');
UPDATE `ai_playerbot_texts` SET `text` = 'Unlearned %skillname', `text_loc4` = '已遗忘 %skillname' WHERE `name` = 'Unlearned %skillname';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'We''ve got a bunch of high levels and we are really super friendly..', 'We''ve got a bunch of high levels and we are really super friendly..', '我们有一堆高等级玩家，而且人都特别nice……', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'We''ve got a bunch of high levels and we are really super friendly..');
UPDATE `ai_playerbot_texts` SET `text` = 'We''ve got a bunch of high levels and we are really super friendly..', `text_loc4` = '我们有一堆高等级玩家，而且人都特别nice……' WHERE `name` = 'We''ve got a bunch of high levels and we are really super friendly..';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'Welcome to %zone_name.... do you want to join my guild %name?', 'Welcome to %zone_name.... do you want to join my guild %name?', '欢迎来到 %zone_name……%name，要不要加入我的公会？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'Welcome to %zone_name.... do you want to join my guild %name?');
UPDATE `ai_playerbot_texts` SET `text` = 'Welcome to %zone_name.... do you want to join my guild %name?', `text_loc4` = '欢迎来到 %zone_name……%name，要不要加入我的公会？' WHERE `name` = 'Welcome to %zone_name.... do you want to join my guild %name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You are actually going to join my guild %name?', 'You are actually going to join my guild %name?', '%name，你真的要加入我的公会吗？', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You are actually going to join my guild %name?');
UPDATE `ai_playerbot_texts` SET `text` = 'You are actually going to join my guild %name?', `text_loc4` = '%name，你真的要加入我的公会吗？' WHERE `name` = 'You are actually going to join my guild %name?';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'You are not in a guild %name!', 'You are not in a guild %name!', '%name，你根本就没有公会！', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'You are not in a guild %name!');
UPDATE `ai_playerbot_texts` SET `text` = 'You are not in a guild %name!', `text_loc4` = '%name，你根本就没有公会！' WHERE `name` = 'You are not in a guild %name!';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'because I was told to get this item.', 'because I was told to get this item.', '因为有人让我拿这件东西。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'because I was told to get this item.');
UPDATE `ai_playerbot_texts` SET `text` = 'because I was told to get this item.', `text_loc4` = '因为有人让我拿这件东西。' WHERE `name` = 'because I was told to get this item.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping as a replacement of %current (%cPower) because it is stronger (%nPower).', 'for equiping as a replacement of %current (%cPower) because it is stronger (%nPower).', '用来替换 %current（%cPower），因为它更强（%nPower）。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping as a replacement of %current (%cPower) because it is stronger (%nPower).');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping as a replacement of %current (%cPower) because it is stronger (%nPower).', `text_loc4` = '用来替换 %current（%cPower），因为它更强（%nPower）。' WHERE `name` = 'for equiping as a replacement of %current (%cPower) because it is stronger (%nPower).';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping as a replacement of %current because it has a higher level or quality.', 'for equiping as a replacement of %current because it has a higher level or quality.', '用来替换 %current，因为它的等级或品质更高。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping as a replacement of %current because it has a higher level or quality.');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping as a replacement of %current because it has a higher level or quality.', `text_loc4` = '用来替换 %current，因为它的等级或品质更高。' WHERE `name` = 'for equiping as a replacement of %current because it has a higher level or quality.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping as a replacement of %current because it is broken.', 'for equiping as a replacement of %current because it is broken.', '用来替换 %current，因为它已经损坏了。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping as a replacement of %current because it is broken.');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping as a replacement of %current because it is broken.', `text_loc4` = '用来替换 %current，因为它已经损坏了。' WHERE `name` = 'for equiping as a replacement of %current because it is broken.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping as upgrade because the slot is empty.', 'for equiping as upgrade because the slot is empty.', '用来升级装备，因为这个部位还空着。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping as upgrade because the slot is empty.');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping as upgrade because the slot is empty.', `text_loc4` = '用来升级装备，因为这个部位还空着。' WHERE `name` = 'for equiping as upgrade because the slot is empty.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping as upgrade.', 'for equiping as upgrade.', '用来升级装备。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping as upgrade.');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping as upgrade.', `text_loc4` = '用来升级装备。' WHERE `name` = 'for equiping as upgrade.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'for equiping until I can find something better.', 'for equiping until I can find something better.', '先穿着，等找到更好的再说。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'for equiping until I can find something better.');
UPDATE `ai_playerbot_texts` SET `text` = 'for equiping until I can find something better.', `text_loc4` = '先穿着，等找到更好的再说。' WHERE `name` = 'for equiping until I can find something better.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'no_permission_for_bot_command', 'no_permission_for_bot_command', '你没有权限使用这个机器人命令。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'no_permission_for_bot_command');
UPDATE `ai_playerbot_texts` SET `text` = 'no_permission_for_bot_command', `text_loc4` = '你没有权限使用这个机器人命令。' WHERE `name` = 'no_permission_for_bot_command';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to bank for future use.', 'to bank for future use.', '先存银行以后再用。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to bank for future use.');
UPDATE `ai_playerbot_texts` SET `text` = 'to bank for future use.', `text_loc4` = '先存银行以后再用。' WHERE `name` = 'to bank for future use.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to complete an objective for a quest.', 'to complete an objective for a quest.', '用来完成某个任务目标。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to complete an objective for a quest.');
UPDATE `ai_playerbot_texts` SET `text` = 'to complete an objective for a quest.', `text_loc4` = '用来完成某个任务目标。' WHERE `name` = 'to complete an objective for a quest.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to repost on AH for %price_min to %price_max.', 'to repost on AH for %price_min to %price_max.', '准备以 %price_min 到 %price_max 的价格重新挂到拍卖行。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to repost on AH for %price_min to %price_max.');
UPDATE `ai_playerbot_texts` SET `text` = 'to repost on AH for %price_min to %price_max.', `text_loc4` = '准备以 %price_min 到 %price_max 的价格重新挂到拍卖行。' WHERE `name` = 'to repost on AH for %price_min to %price_max.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to repost on AH.', 'to repost on AH.', '准备重新挂到拍卖行。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to repost on AH.');
UPDATE `ai_playerbot_texts` SET `text` = 'to repost on AH.', `text_loc4` = '准备重新挂到拍卖行。' WHERE `name` = 'to repost on AH.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to sell to a vendor for %price.', 'to sell to a vendor for %price.', '准备按 %price 卖给商人。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to sell to a vendor for %price.');
UPDATE `ai_playerbot_texts` SET `text` = 'to sell to a vendor for %price.', `text_loc4` = '准备按 %price 卖给商人。' WHERE `name` = 'to sell to a vendor for %price.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to sell to a vendor.', 'to sell to a vendor.', '准备卖给商人。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to sell to a vendor.');
UPDATE `ai_playerbot_texts` SET `text` = 'to sell to a vendor.', `text_loc4` = '准备卖给商人。' WHERE `name` = 'to sell to a vendor.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to use as ammo.', 'to use as ammo.', '当弹药使。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to use as ammo.');
UPDATE `ai_playerbot_texts` SET `text` = 'to use as ammo.', `text_loc4` = '当弹药使。' WHERE `name` = 'to use as ammo.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to use it for my profession.', 'to use it for my profession.', '用在我的专业上。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to use it for my profession.');
UPDATE `ai_playerbot_texts` SET `text` = 'to use it for my profession.', `text_loc4` = '用在我的专业上。' WHERE `name` = 'to use it for my profession.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'to use it when I need it.', 'to use it when I need it.', '等需要的时候再用。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'to use it when I need it.');
UPDATE `ai_playerbot_texts` SET `text` = 'to use it when I need it.', `text_loc4` = '等需要的时候再用。' WHERE `name` = 'to use it when I need it.';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'wait_travel_combat', 'wait_travel_combat', '我在赶路，路上有怪，等我一下', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'wait_travel_combat');
UPDATE `ai_playerbot_texts` SET `text` = 'wait_travel_combat', `text_loc4` = '我在赶路，路上有怪，等我一下' WHERE `name` = 'wait_travel_combat';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT 'wandering', 'wandering', '四处游荡', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = 'wandering');
UPDATE `ai_playerbot_texts` SET `text` = 'wandering', `text_loc4` = '四处游荡' WHERE `name` = 'wandering';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '|cff00ff00%itemcount items recieved from mail: ', '|cff00ff00%itemcount items recieved from mail: ', '|cff00ff00从邮件收到 %itemcount 件物品： ', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '|cff00ff00%itemcount items recieved from mail: ');
UPDATE `ai_playerbot_texts` SET `text` = '|cff00ff00%itemcount items recieved from mail: ', `text_loc4` = '|cff00ff00从邮件收到 %itemcount 件物品： ' WHERE `name` = '|cff00ff00%itemcount items recieved from mail: ';
INSERT INTO `ai_playerbot_texts` (`name`, `text`, `text_loc4`, `say_type`, `reply_type`)
  SELECT '|cffffff00%money |cff00ff00recieved from mail.', '|cffffff00%money |cff00ff00recieved from mail.', '|cffffff00%money |cff00ff00从邮件收到。', 0, 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM `ai_playerbot_texts` WHERE `name` = '|cffffff00%money |cff00ff00recieved from mail.');
UPDATE `ai_playerbot_texts` SET `text` = '|cffffff00%money |cff00ff00recieved from mail.', `text_loc4` = '|cffffff00%money |cff00ff00从邮件收到。' WHERE `name` = '|cffffff00%money |cff00ff00recieved from mail.';
