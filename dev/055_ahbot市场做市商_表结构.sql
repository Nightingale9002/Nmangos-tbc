-- ============================================================
-- [ahbot] Market-maker: catalog overrides + inventory ledger
-- Target database: tbccharacters (the characters DB).
-- Run via dev/run_dev_sql.ps1 -Database tbccharacters
-- (the USE below also makes it safe under any default database).
-- ============================================================
USE tbccharacters;

-- ----------------------------------------------------------------
-- [ahbot] Market-maker inventory ledger + catalog overrides
-- Tables live in the CHARACTERS database (like ahbot_items/ahbot_price).
-- The base catalog universe is computed at runtime from the WORLD db
-- (droppable+priceable Class 7 items); this table only holds operator
-- overrides (disable an item, tweak its target/capacity).
-- ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ahbot_catalog` (
  `item` INT UNSIGNED NOT NULL,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '0 = exclude this item from the market-maker catalog',
  `target` INT UNSIGNED NOT NULL DEFAULT 50 COMMENT 'desired holdings (units) for this item; 0 = use config default',
  `capacity` INT UNSIGNED NOT NULL DEFAULT 200 COMMENT 'hard cap on holdings; 0 = use config default',
  `policy` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=auto(ItemLevel) 1=force market 2=force transition',
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ahbot market-maker catalog overrides';

CREATE TABLE IF NOT EXISTS `ahbot_inventory` (
  `item` INT UNSIGNED NOT NULL,
  `auction_house` INT UNSIGNED NOT NULL,
  `qty` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'total units held by the bot (listed + reserve)',
  `avg_cost` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'weighted average unit cost (copper) of purchases',
  `spent` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'gold (copper) paid out to players for purchases',
  `earned` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'gold (copper) received from players for sales',
  `flow_bought` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'units bought from players since last settle',
  `flow_sold` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'units sold to players since last settle',
  PRIMARY KEY (`item`, `auction_house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ahbot market-maker virtual inventory ledger';

-- seed overrides for a few items the operator previously tuned (cloth 50%, enchanting 50%)
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