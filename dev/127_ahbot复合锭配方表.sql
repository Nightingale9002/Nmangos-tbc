-- dev/127：AHBot 复合锭配方表 ahbot_price_recipe（建表 + 7 条配方行）—— 2026-09-26
-- ===============================================================
-- 为什么需要这份【带编号】的 SQL：代码 src/game/AuctionHouseBot/AuctionHouseBot.cpp 的
-- SettleRecipePrices() 会读本表（复合产物 price_ref = Σ 原料 price_ref × 用量）。
-- 本表此前只在本地建过（dev/ahbot_price_recipe_schema.sql 不带编号 ⇒ /root/apply_dev_sql.sh 不扫描），
-- 云端必须由这份编号文件建表；否则新代码起不来后果只是"打一条 SQL 报错、复合锭价格不动"（安全但不生效）。
--
-- 口径（站长 2026-09-25 定案）：复合锭【只由材料单向定价】—— 产物自身成交**不反向传导**（reverse_flow = 0），
-- 其流水只作观察后清零；只写 ahbot_market_state.price_ref，**不碰已挂出的拍卖单价格**。
--   青铜锭 2841     = 铜锭 2840 × 1 + 锡锭 3576 × 1
--   钢锭   3859     = 铁锭 3575 × 1 + 煤块 3857 × 1
--   魔钢锭 23448    = 魔铁锭 23445 × 3 + 恒金锭 23447 × 2
--   硬化精金锭 23573 = 精金锭 23446 × 10
--
-- 幂等：CREATE TABLE IF NOT EXISTS + INSERT ... ON DUPLICATE KEY UPDATE
--       （重复应用无副作用、不删已有数据；本表是"配置表"，不做 DROP）
-- 执行对象：character 库（tbccharacters）
-- ===============================================================

CREATE TABLE IF NOT EXISTS `tbccharacters`.`ahbot_price_recipe` (
  `product_item`    int unsigned     NOT NULL COMMENT '产物（复合锭）',
  `ingredient_item` int unsigned     NOT NULL COMMENT '原料',
  `count`           int unsigned     NOT NULL DEFAULT 1 COMMENT '用量',
  `auction_house`   tinyint unsigned NOT NULL DEFAULT 2,
  `reverse_flow`    tinyint unsigned NOT NULL DEFAULT 0 COMMENT '产物成交是否反向传导到原料（0=否，站长口径）',
  `enabled`         tinyint unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`auction_house`,`product_item`,`ingredient_item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AH 市场商人：复合锭配方（单向：价=Σ原料价×用量，不反向传导）';

INSERT INTO `tbccharacters`.`ahbot_price_recipe`
  (`auction_house`,`product_item`,`ingredient_item`,`count`,`reverse_flow`,`enabled`) VALUES
  (2,  2841,  2840,  1, 0, 1),   -- 青铜锭     = 铜锭×1
  (2,  2841,  3576,  1, 0, 1),   --             + 锡锭×1
  (2,  3859,  3575,  1, 0, 1),   -- 钢锭       = 铁锭×1
  (2,  3859,  3857,  1, 0, 1),   --             + 煤块×1
  (2, 23448, 23445,  3, 0, 1),   -- 魔钢锭     = 魔铁锭×3
  (2, 23448, 23447,  2, 0, 1),   --             + 恒金锭×2
  (2, 23573, 23446, 10, 0, 1)    -- 硬化精金锭 = 精金锭×10
ON DUPLICATE KEY UPDATE `count` = VALUES(`count`), `reverse_flow` = VALUES(`reverse_flow`), `enabled` = VALUES(`enabled`);

-- 复核（应为 7 行 / 4 个产物）：
-- SELECT COUNT(*) AS rows_total, COUNT(DISTINCT product_item) AS products FROM `tbccharacters`.`ahbot_price_recipe`;
