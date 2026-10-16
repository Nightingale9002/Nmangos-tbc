-- 178_TBC属性权重表_站长口径.sql
-- 依据：站长 2026-10-16 给出的"属性价值框架 + 各专精百分比评分"，按站长确认的固定换算折算成
--       ai_playerbot_weightscale_data 的**同专精相对权重**。
--
-- 换算约定（站长确认：⑤"1暴击"=1%暴击率，与"暴击等级"是固定比例）
--   70 级：1% 暴击 = 22.08 暴击等级；1% 急速 = 15.77 急速等级；1% 命中 = 15.77 命中等级；
--          1 精准 = 3.94 精准等级（26 精准 = 6.5%）；1 防御技能 = 2.4 防御等级
--   战士/圣骑/增强萨/熊德：1 力量 = 2 AP；盗贼/猎人：1 力量 = 1 近战 AP（基本无用）
--   权重是**同专精内的相对值**，跨专精不可比。每张表把"最重要的属性"锚定到 ~100-440。
--
-- 用法：这些**只写"达标前"的权重**；达标后的降权在 ai_playerbot_weightscale_caps（dev/177）。
-- 幂等：按 id 先删后插。执行：mysql -uroot -p tbcmangos < 178_TBC属性权重表_站长口径.sql
--
-- 未纳入本次改动（等站长给数字）：防战 3 / 防骑 5 的**相对量级**（只按你的先后顺序 + 收尾不动上游数值），
--   以及武器 DPS(mledps) —— 站长框架里没提，保持上游值。

DELETE FROM ai_playerbot_weightscale_data WHERE id IN
 (1,2, 4, 7,8,9, 10,11,12, 13,14, 15, 20, 22, 23,24,25, 26,27,28, 29, 31, 32);

-- ===== 武器战 1 / 狂暴战 2（站长 P3 BIS：1%暴击=1.3%DPS、1%急速=1.1%、满命中后1%=0.8%、336破甲=5.37%、20力量=40AP=2.4%）=====
-- 以"1 暴击等级 = 100"为基准；str=2×atkpwr；命中/精准达标前最高（降权见 dev/177）
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(1,'str',204),(1,'exprtng',160),(1,'hitrtng',150),(1,'hastertng',118),(1,'agi',110),(1,'atkpwr',102),
(1,'critstrkrtng',100),(1,'armorpenrtng',27),(1,'mledps',100),
(2,'str',204),(2,'exprtng',160),(2,'hitrtng',150),(2,'hastertng',125),(2,'agi',110),(2,'atkpwr',102),
(2,'critstrkrtng',100),(2,'armorpenrtng',27),(2,'mledps',100);

-- ===== 神圣骑 4（站长：智力绝对第一，2 分钟战斗 1 智 ≈ 4.4 法伤）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(4,'int',440),(4,'splheal',100),(4,'splpwr',100),(4,'manargn',60),(4,'spellcritstrkrtng',60),
(4,'spellhastertng',50),(4,'spi',40);

-- ===== 猎人 7/8/9（站长 P2 兽王：1 敏捷=2.1AP、1 暴击等级=1 命中等级=1.7AP、未满命中 1 命中≈2.6AP）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(7,'hitrtng',260),(7,'agi',210),(7,'critstrkrtng',170),(7,'hastertng',150),(7,'atkpwr',100),(7,'int',20),
(8,'hitrtng',260),(8,'agi',210),(8,'critstrkrtng',170),(8,'hastertng',150),(8,'atkpwr',100),(8,'int',20),
(9,'hitrtng',260),(9,'agi',210),(9,'critstrkrtng',170),(9,'hastertng',150),(9,'atkpwr',100),(9,'int',20);

-- ===== 盗贼 10/11/12（站长 EP：敏捷 2.21、命中 2.31、暴击 1.76；急速>暴击；精准/命中达标前最高）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(10,'hitrtng',250),(10,'exprtng',230),(10,'agi',221),(10,'hastertng',200),(10,'critstrkrtng',176),
(10,'armorpenrtng',120),(10,'atkpwr',100),(10,'str',50),(10,'mledps',100),
(11,'hitrtng',250),(11,'exprtng',230),(11,'agi',221),(11,'hastertng',200),(11,'critstrkrtng',176),
(11,'armorpenrtng',120),(11,'atkpwr',100),(11,'str',50),(11,'mledps',100),
(12,'hitrtng',250),(12,'exprtng',230),(12,'agi',221),(12,'hastertng',200),(12,'critstrkrtng',176),
(12,'armorpenrtng',120),(12,'atkpwr',100),(12,'str',50),(12,'mledps',100);

-- ===== 戒律 13 / 神圣牧 14（站长：急速 > 治疗强度 > 智力≈精神 > 暴击 > Mp5）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(13,'spellhastertng',150),(13,'splheal',100),(13,'spi',60),(13,'int',60),(13,'spellcritstrkrtng',40),(13,'manargn',15),
(14,'spellhastertng',150),(14,'splheal',100),(14,'spi',60),(14,'int',60),(14,'spellcritstrkrtng',40),(14,'manargn',15);

-- ===== 暗影牧 15（站长：命中 > 法伤 > 暴击/急速；1 智 ≈ 0.26 法伤）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(15,'spellhitrtng',140),(15,'splpwr',100),(15,'spellcritstrkrtng',80),(15,'spellhastertng',80),
(15,'int',26),(15,'spi',20),(15,'manargn',10);

-- ===== 元素萨 20（站长：法术伤害+暴击核心，只需约 51 命中）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(20,'splpwr',100),(20,'spellcritstrkrtng',80),(20,'spellhitrtng',70),(20,'spellhastertng',60),
(20,'int',20),(20,'manargn',20);

-- ===== 恢复萨 22（站长 Icy Veins 评分：治疗 1 / 急速 1.5 / Mp5 2 / 智力 0.5；精神几乎无收益）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(22,'manargn',200),(22,'spellhastertng',150),(22,'splheal',100),(22,'int',50),(22,'spellcritstrkrtng',30);

-- ===== 奥法 23（站长：1 智 ≈ 1.0 法伤；命中只需 76）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(23,'int',100),(23,'splpwr',100),(23,'spellhitrtng',70),(23,'spellcritstrkrtng',60),
(23,'spellhastertng',50),(23,'manargn',40),(23,'spi',30);

-- ===== 火法 24 / 冰法 25（站长：1 智 ≈ 0.2 法伤；命中 164）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(24,'splpwr',100),(24,'spellhitrtng',120),(24,'spellcritstrkrtng',70),(24,'spellhastertng',60),(24,'manargn',25),(24,'int',20),(24,'spi',15),
(25,'splpwr',100),(25,'spellhitrtng',120),(25,'spellcritstrkrtng',70),(25,'spellhastertng',60),(25,'manargn',25),(25,'int',20),(25,'spi',15);

-- ===== 术士 26/27/28（站长评分：法伤 55 / 急速 63 / 命中 60 / 暴击 43 / 智力 13，×2 取整）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(26,'spellhastertng',126),(26,'spellhitrtng',120),(26,'splpwr',110),(26,'spellcritstrkrtng',86),(26,'int',26),(26,'spi',10),(26,'manargn',6),
(27,'spellhastertng',126),(27,'spellhitrtng',120),(27,'splpwr',110),(27,'spellcritstrkrtng',86),(27,'int',26),(27,'spi',10),(27,'manargn',6),
(28,'spellhastertng',126),(28,'spellhitrtng',120),(28,'splpwr',110),(28,'spellcritstrkrtng',86),(28,'int',26),(28,'spi',10),(28,'manargn',6);

-- ===== 平衡德 29（站长：命中第一（天赋 4%→152，带图腾 114），达标后暴击 > 法伤）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(29,'spellhitrtng',140),(29,'spellcritstrkrtng',100),(29,'splpwr',90),(29,'spellhastertng',60),
(29,'int',20),(29,'spi',15),(29,'manargn',10);

-- ===== 防战 3（站长 2026-10-16 给出转换率与阈值）=====
-- 转换率：1力=2AP+0.05格挡值；1敏=1/30闪躲+1/33暴击+2护甲；1耐=10HP；
--         59.15防御等级=+1%闪躲/招架/格挡/-1%被暴/-1%被命中；18.92闪躲等级=1%闪躲；23.65招架等级=1%招架；
--         7.88格挡等级=1%格挡概率；15.77命中等级=1%命中；15.77精准等级=1%；22.08暴击等级=1%暴击
-- 阈值：免暴 490 防御技能(≈332 等级)、精准软上限 26(≈103)、硬上限 56、命中 9%(142)、护甲上限 35880
-- 达标后优先级（站长）：耐力 > 防御等级 > 护甲 > 躲闪 > 招架 > 格挡 > 敏捷 > 格挡值 > 命中 > 精准 > 力量
-- 站长确认①：**量级严格按转换率**（结果上"格挡等级"每点最便宜 ⇒ 每点价值高于闪躲/招架；量与顺序会因此不同）。
--   换算到"每点自身的百分比收益 ×1000"：
--     防御等级 1/59.15% ×(未命中+闪躲+招架+格挡 4 项) = 68；格挡等级 1/7.88 = 127（格挡只算半价 ⇒ 63）；
--     闪躲 1/18.92 = 53；招架 1/23.65 = 42；敏捷 = 1/30 闪躲 + 1/33 暴击 = 33+30 = 63。
--   耐力/护甲/力量/命中/精准/格挡值 站长没给统一换算基准 ⇒ 按他的优先级取锚值（sta 110、armor 95…）。
--   命中/精准达标后的降权在 dev/177（精准软上限 26、硬上限 56、护甲上限 35880）。
DELETE FROM ai_playerbot_weightscale_data WHERE id = 3;
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(3,'sta',110),(3,'defrtng',68),(3,'blockrtng',63),(3,'agi',63),(3,'dodgertng',53),(3,'parryrtng',42),
(3,'armor',95),(3,'hitrtng',52),(3,'exprtng',46),(3,'str',40),(3,'block',58),(3,'critstrkrtng',34),
(3,'atkpwr',30),(3,'mledps',100);

-- ===== 防骑 5（站长口径：达标后"抗 BOSS 优先 耐力 + 法伤"；宝石要法伤+耐力）=====
-- 转换率：1防御等级=0.05%硬免伤；1躲闪等级=0.053%；60防御等级=1%格挡+1%闪躲+1%招架+1%未命中；
--         2.37防御等级=1防御技能；7.9格挡等级=1%格挡；20防御等级≈72耐力（等价）
-- 阈值：免暴 490 防御技能(≈332 等级)；免碾 四维 ≥102.4%；法术命中额外 2%；格挡值上限 2400
-- 站长确认①：量级严格按转换率 ⇒ 防御等级 50（0.05%）、闪躲 53（0.053%）、格挡等级 127×0.5=63、招架 42。
-- 达标后优先级（站长）：耐力 > 法术伤害 > 命中 > 精准（这三项无统一换算基准 ⇒ 按锚值）
DELETE FROM ai_playerbot_weightscale_data WHERE id = 5;
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(5,'sta',110),(5,'blockrtng',63),(5,'dodgertng',53),(5,'defrtng',50),(5,'parryrtng',42),(5,'armor',70),
(5,'splpwr',90),(5,'spellhitrtng',50),(5,'block',44),(5,'exprtng',38),(5,'hitrtng',32),
(5,'agi',30),(5,'str',30),(5,'int',15),(5,'manargn',15),(5,'spellcritstrkrtng',15);


-- ===== 恢复德 31（站长 P2：治疗 ≥ 精神 > Mp5 > 智力 > 暴击；P5 才把急速提到前）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(31,'splheal',110),(31,'spi',90),(31,'spellhastertng',80),(31,'manargn',60),(31,'int',30),(31,'spellcritstrkrtng',10);

-- ===== 熊德 32（站长：免暴(156 防御等级/103 韧性) → 护甲上限 35880 → 耐力核心 → 敏捷；
--        1 耐=15.45HP、1 敏=2 护甲/14.7 敏=1% 躲闪/25 敏=1% 暴击；敏捷转化的护甲不吃熊形态 400%）=====
INSERT INTO ai_playerbot_weightscale_data (id, field, val) VALUES
(32,'sta',150),(32,'defrtng',120),(32,'agi',100),(32,'exprtng',100),(32,'hitrtng',100),
(32,'armor',80),(32,'dodgertng',60),(32,'str',60),(32,'critstrkrtng',40),(32,'feratkpwr',40),(32,'atkpwr',30),(32,'hastertng',20);
