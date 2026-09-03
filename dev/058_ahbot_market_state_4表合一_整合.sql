-- ============================================================
-- [ahbot] 4 表合一: ahbot_catalog + ahbot_inventory + ahbot_price
--         + ahbot_items  ->  ahbot_market_state (角色库 tbccharacters)
-- 幂等可重复执行（DDL IF NOT EXISTS / 渐进式备份判断可选）
-- 注意:
--   1) 本脚本先备份旧表再建新表并迁移，不删除旧表（最后清理可选）。
--   2) 新表 PK (item, auction_house)，item 级配置(catalog/items)  会在同一 item 的
--      多个 house 行上复制，代码按 item 去重读取即可。
--   3) policy 为历史遗留列，已被 category 取代，不再迁入新表。
-- ============================================================
USE tbccharacters;

-- ---------------- 1) 备份现有数据 ----------------
-- 重复执行时若同名 _backup 表已存在，则跳过该表的再次备份（不会覆盖原备份）。
CREATE TABLE IF NOT EXISTS ahbot_catalog_backup AS SELECT * FROM ahbot_catalog;
CREATE TABLE IF NOT EXISTS ahbot_inventory_backup AS SELECT * FROM ahbot_inventory;
CREATE TABLE IF NOT EXISTS ahbot_price_backup AS SELECT * FROM ahbot_price;
CREATE TABLE IF NOT EXISTS ahbot_items_backup AS SELECT * FROM ahbot_items;

-- ---------------- 2) 创建新表结构 ----------------
DROP TABLE IF EXISTS `ahbot_market_state`;

CREATE TABLE IF NOT EXISTS `ahbot_market_state` (
  `item` INT UNSIGNED NOT NULL,
  `auction_house` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=中立,1=联盟,6=部落',

  -- 配置（原 catalog）
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `category` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0=loot,1=market,2=fixed,3=ban',
  `price` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'category=2 固定价',
  `target` INT UNSIGNED NOT NULL DEFAULT 500,
  `capacity` INT UNSIGNED NOT NULL DEFAULT 1500,

  -- 状态（原 inventory）
  `qty` INT UNSIGNED NOT NULL DEFAULT 0,
  `avg_cost` INT UNSIGNED NOT NULL DEFAULT 0,
  `spent` INT UNSIGNED NOT NULL DEFAULT 0,
  `earned` INT UNSIGNED NOT NULL DEFAULT 0,
  `flow_bought` INT UNSIGNED NOT NULL DEFAULT 0,
  `flow_sold` INT UNSIGNED NOT NULL DEFAULT 0,

  -- 参考价（原 price）
  `price_ref` INT UNSIGNED NOT NULL DEFAULT 0,

  -- 覆盖规则（原 ahbot_items）
  `override_base_price` INT UNSIGNED NOT NULL DEFAULT 0,
  `override_add_chance` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `override_min_amount` INT UNSIGNED NOT NULL DEFAULT 0,
  `override_max_amount` INT UNSIGNED NOT NULL DEFAULT 0,

  PRIMARY KEY (`item`, `auction_house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='AHBot 统一市场状态';

-- ---------------- 3) 迁移数据 ----------------
INSERT INTO ahbot_market_state (
    item, auction_house,
    enabled, category, price, target, capacity,
    qty, avg_cost, spent, earned, flow_bought, flow_sold,
    price_ref,
    override_base_price, override_add_chance, override_min_amount, override_max_amount
)
SELECT
    c.item,
    COALESCE(i.auction_house, 0) AS auction_house,
    c.enabled,
    c.category,
    COALESCE(c.price, 0) AS price,
    GREATEST(COALESCE(c.target, 500), 200) AS target,
    GREATEST(COALESCE(c.capacity, 1500), 600) AS capacity,
    COALESCE(i.qty, 0) AS qty,
    COALESCE(i.avg_cost, 0) AS avg_cost,
    COALESCE(i.spent, 0) AS spent,
    COALESCE(i.earned, 0) AS earned,
    COALESCE(i.flow_bought, 0) AS flow_bought,
    COALESCE(i.flow_sold, 0) AS flow_sold,
    COALESCE(p.price, 0) AS price_ref,
    COALESCE(it.value, 0) AS override_base_price,
    COALESCE(it.add_chance, 0) AS override_add_chance,
    COALESCE(it.min_amount, 0) AS override_min_amount,
    COALESCE(it.max_amount, 0) AS override_max_amount
FROM ahbot_catalog c
LEFT JOIN ahbot_inventory i ON i.item = c.item
LEFT JOIN ahbot_price p ON p.item = c.item AND p.auction_house = COALESCE(i.auction_house, 0)
LEFT JOIN ahbot_items it ON it.item = c.item
ON DUPLICATE KEY UPDATE
    enabled = VALUES(enabled),
    category = VALUES(category),
    price = VALUES(price),
    target = VALUES(target),
    capacity = VALUES(capacity),
    qty = VALUES(qty),
    avg_cost = VALUES(avg_cost),
    spent = VALUES(spent),
    earned = VALUES(earned),
    flow_bought = VALUES(flow_bought),
    flow_sold = VALUES(flow_sold),
    price_ref = VALUES(price_ref),
    override_base_price = VALUES(override_base_price),
    override_add_chance = VALUES(override_add_chance),
    override_min_amount = VALUES(override_min_amount),
    override_max_amount = VALUES(override_max_amount);

-- ---------------- 4) 数据验证 ----------------
-- 检查总记录数是否与 catalog 一致（注意 catalog 是 item 级、新表为 item+house 级，
-- 若需要精确对比请使用 SELECT COUNT(DISTINCT item) FROM ahbot_market_state）
SELECT 'catalog_total' AS chk, COUNT(*) AS n FROM ahbot_catalog;
SELECT 'market_distinct_items' AS chk, COUNT(DISTINCT item) AS n FROM ahbot_market_state;
SELECT 'market_total_rows' AS chk, COUNT(*) AS n FROM ahbot_market_state;

-- 抽查几个关键物品
SELECT * FROM ahbot_market_state WHERE item IN (2589, 22445, 23427);

-- 旧表默认保留；确认新系统稳定后可手工执行：
-- DROP TABLE ahbot_catalog, ahbot_inventory, ahbot_price, ahbot_items;
