-- ============================================================
-- [ahbot] Market-maker 做市商表结构 + 商品分类 (整合版, 原 dev/055-059)
-- Target: tbccharacters(角色库). 世界库表引用带 tbcmangos. 前缀。
-- 幂等可重复执行: CREATE IF NOT EXISTS; 加列带 information_schema 守卫;
-- INSERT 用 IGNORE/ON DUPLICATE; 标记用幂等 UPDATE。
-- category: 0=默认不动(回loot流程供给) 1=市场商品(默认,央行流动定价)
--           2=低级商品(单价固定=price卖店价,预留) 3=禁售(永不供给/收购)
-- policy(旧标记): 0=auto 1=force market; 已被 category 取代, 保留兼容。
-- ============================================================
USE tbccharacters;

-- ---------------- 1) 表结构 ----------------
CREATE TABLE IF NOT EXISTS `ahbot_catalog` (
  `item` INT UNSIGNED NOT NULL,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0 = exclude from market-maker catalog',
  `target` INT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'desired holdings; 0 = config default',
  `capacity` INT UNSIGNED NOT NULL DEFAULT 200 COMMENT 'hard cap; 0 = config default',
  `policy` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'legacy: 0=auto 1=force market 2=force transition',
  `category` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0 untouched(loot) 1 market 2 low(vendor-price) 3 never-supplied',
  `price` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'category=2 fixed unit price (vendor SellPrice)',
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ahbot market-maker catalog overrides';

-- 旧库升级: 列缺失时补加(带默认1); 已存在则跳过 -> 幂等
SET @has_cat := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='ahbot_catalog' AND COLUMN_NAME='category');
SET @sql := IF(@has_cat = 0,
  'ALTER TABLE `ahbot_catalog` ADD COLUMN `category` TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `policy`, ADD COLUMN `price` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `category`',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- 统一列默认值(旧库由旧057建的列默认0也纠正为1) - 幂等
ALTER TABLE `ahbot_catalog` ALTER COLUMN `category` SET DEFAULT 1;

CREATE TABLE IF NOT EXISTS `ahbot_inventory` (
  `item` INT UNSIGNED NOT NULL,
  `auction_house` INT UNSIGNED NOT NULL,
  `qty` INT UNSIGNED NOT NULL DEFAULT 0,
  `avg_cost` INT UNSIGNED NOT NULL DEFAULT 0,
  `spent` INT UNSIGNED NOT NULL DEFAULT 0,
  `earned` INT UNSIGNED NOT NULL DEFAULT 0,
  `flow_bought` INT UNSIGNED NOT NULL DEFAULT 0,
  `flow_sold` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`item`, `auction_house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ahbot market-maker virtual inventory ledger';

-- ---------------- 2) 种子覆盖(原055) ----------------
INSERT IGNORE INTO `ahbot_catalog` (`item`, `enabled`, `target`, `capacity`) VALUES
(2589, 1, 100, 200),  -- Linen Cloth
(2592, 1, 100, 200),  -- Wool Cloth
(4306, 1, 100, 200),  -- Silk Cloth
(4338, 1, 100, 200),  -- Mageweave Cloth
(14047, 1, 100, 200), -- Runecloth
(21877, 1, 100, 200), -- Netherweave Cloth
(12359, 1, 60, 200),  -- Thorium Bar
(12365, 1, 60, 200),  -- Dense Stone
(8170, 1, 60, 200);   -- Rugged Leather

-- ---------------- 3) 外域 301+ 材料 policy=1 市场标记(原056; category 默认1) ----------------
INSERT INTO ahbot_catalog (item, enabled, target, capacity, policy, category)
SELECT DISTINCT x.reagent, 1, 0, 0, 1, 1
FROM (SELECT st.Reagent1 reagent FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent1 > 0
UNION ALL SELECT st.Reagent2 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent2 > 0
UNION ALL SELECT st.Reagent3 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent3 > 0
UNION ALL SELECT st.Reagent4 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent4 > 0
UNION ALL SELECT st.Reagent5 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent5 > 0
UNION ALL SELECT st.Reagent6 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent6 > 0
UNION ALL SELECT st.Reagent7 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent7 > 0
UNION ALL SELECT st.Reagent8 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent8 > 0) x
JOIN tbcmangos.item_template it ON it.entry = x.reagent
WHERE it.class = 7 AND it.ItemLevel >= 60
ON DUPLICATE KEY UPDATE policy = IF(policy = 0, 1, policy);

-- housekeeping: 低等级(地球)材料不保留 policy=1
UPDATE ahbot_catalog c JOIN tbcmangos.item_template it ON it.entry = c.item
SET c.policy = 0 WHERE c.policy = 1 AND it.ItemLevel < 60;

-- ---------------- 4) 副本独占材料 category=3 + 清残留(原058) ----------------
INSERT INTO `ahbot_catalog` (item, enabled, target, capacity, policy, category, price) VALUES
  (34664, 1, 0, 0, 0, 3, 0),  -- 太阳之尘 Sunmote
  (32428, 1, 0, 0, 0, 3, 0),  -- 黑暗之心 Heart of Darkness
  (30183, 1, 0, 0, 0, 3, 0),  -- 虚空漩涡 Nether Vortex
  (23572, 1, 0, 0, 0, 3, 0)   -- 原始虚空 Primal Nether
ON DUPLICATE KEY UPDATE category = 3, policy = 0;

DELETE FROM `ahbot_inventory` WHERE item IN (34664, 32428, 30183, 23572);
DELETE FROM `ahbot_price` WHERE item IN (34664, 32428, 30183, 23572);

-- ---------------- 5) 只有制作来源的物品 category=3(原059; 顺带清 policy) ----------------
UPDATE `ahbot_catalog` c
JOIN (
  SELECT ei AS item_id FROM (
    SELECT EffectItemType1 AS ei FROM tbcmangos.spell_template WHERE Effect1 IN (24,43) AND EffectItemType1 > 0
    UNION SELECT EffectItemType2 FROM tbcmangos.spell_template WHERE Effect2 IN (24,43) AND EffectItemType2 > 0
    UNION SELECT EffectItemType3 FROM tbcmangos.spell_template WHERE Effect3 IN (24,43) AND EffectItemType3 > 0
  ) m
  WHERE m.ei NOT IN (SELECT item FROM tbcmangos.creature_loot_template)
    AND m.ei NOT IN (SELECT item FROM tbcmangos.gameobject_loot_template)
    AND m.ei NOT IN (SELECT item FROM tbcmangos.fishing_loot_template)
    AND m.ei NOT IN (SELECT item FROM tbcmangos.skinning_loot_template)
    AND m.ei NOT IN (SELECT item FROM tbcmangos.disenchant_loot_template)
    AND m.ei NOT IN (SELECT item FROM tbcmangos.item_loot_template)
) x ON c.item = x.item_id
SET c.category = 3, c.policy = 0;


-- ---------------- 6) 统一扩容所有 category=1 贸易品的库存（满足冲专业需求） ----------------
-- 目标：确保玩家能一次性购买到足够材料冲满专业（工程、锻造、制皮、裁缝等）
-- 按子类设定最低 target 和 capacity，若当前值已高于此则保留
UPDATE `ahbot_catalog` c
JOIN `tbcmangos`.`item_template` it ON it.entry = c.item
SET c.target = GREATEST(c.target, 
    CASE 
        WHEN it.subclass IN (1, 2, 5, 6) THEN 800   -- 布料、皮革、石头、矿石 → 高消耗
        WHEN it.subclass IN (3, 9, 10, 12) THEN 400 -- 草药、宝石、元素、附魔 → 中等消耗
        ELSE 200                                    -- 其他贸易品 → 基础保障
    END),
    c.capacity = GREATEST(c.capacity, 
    CASE 
        WHEN it.subclass IN (1, 2, 5, 6) THEN 2400
        WHEN it.subclass IN (3, 9, 10, 12) THEN 1200
        ELSE 600
    END)
WHERE c.category = 1 AND it.class = 7;

-- 此操作不会影响 category=3 的禁售物品（如太阳之尘等）。
-- 执行后，配合配置文件中提高 RefillPerCycle/ListBatch，即可保证拍卖行挂单量充足。

-- [2026-09-07] legacy duplicate tables no longer used (single source = ahbot_market_state)
DROP TABLE IF EXISTS ahbot_catalog, ahbot_inventory;

