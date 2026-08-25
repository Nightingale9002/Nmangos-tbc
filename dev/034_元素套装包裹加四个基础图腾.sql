-- =============================================================
-- 萨满职业套装包(90015 元素套装包裹) 添加四个基础图腾
-- 任务: 90145/90155 实战训练：萨满祭司 奖励 90015
-- 图腾: 5175 地之图腾 / 5176 火之图腾 / 5177 水之图腾 / 5178 空气图腾
-- 幂等: ON DUPLICATE KEY UPDATE，可重复执行
-- =============================================================

INSERT INTO item_loot_template (entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount, condition_id, comments) VALUES
(90015, 5175, 100, 0, 1, 1, 0, '地之图腾'),
(90015, 5176, 100, 0, 1, 1, 0, '火之图腾'),
(90015, 5177, 100, 0, 1, 1, 0, '水之图腾'),
(90015, 5178, 100, 0, 1, 1, 0, '空气图腾')
ON DUPLICATE KEY UPDATE ChanceOrQuestChance=100;
