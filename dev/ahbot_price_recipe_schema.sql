-- dev/ahbot_price_recipe_schema.sql（结构 + 配方行，**不带编号** ⇒ 不被 /root/apply_dev_sql.sh 自动扫描）
-- ===============================================================
-- 站长 2026-09-25：*"继续做青铜锭等"*，随后明确：**"魔钢锭还是由材料单独定价，不用做反向传导了"**。
--
-- 语义（最终口径）：复合锭 **单向由材料定价**：
--     青铜锭 2841   = 铜锭×1 + 锡锭×1
--     钢锭   3859   = 铁锭×1 + 煤块×1
--     魔钢锭 23448  = 魔铁锭×3 + 恒金锭×2
--     硬化精金锭 23573 = 精金锭×10
--   产物价 = Σ(原料当前 price_ref × count)，写回产物 price_ref（带 `<>` 守卫）；
--   **产物自身成交量不做反向传导**（`reverse_flow = 0`）：玩家买卖复合锭不改变任何原料/虚拟价，
--   复合锭自己的流水只作为观察量记录后清零（避免它被"自己的成交"推价，价格始终由材料解释）。
--   只写 ahbot_market_state.price_ref，**不碰已挂出的拍卖单价格**。
--
-- ⚠️ 本文件只在本机执行（云端未同步、未部署）；要上线时由站长下令后再执行。
-- 幂等：DROP TABLE IF EXISTS + CREATE + INSERT（表为本地新建、无写入者，可安全重建）⇒ 重跑结果一致。
-- ===============================================================

DROP TABLE IF EXISTS `tbccharacters`.`ahbot_price_recipe`;
CREATE TABLE `tbccharacters`.`ahbot_price_recipe` (
  `product_item`    int unsigned     NOT NULL COMMENT '产物（复合锭）',
  `ingredient_item` int unsigned     NOT NULL COMMENT '原料',
  `count`           int unsigned     NOT NULL DEFAULT 1 COMMENT '用量',
  `auction_house`   tinyint unsigned NOT NULL DEFAULT 2,
  `reverse_flow`    tinyint unsigned NOT NULL DEFAULT 0 COMMENT '产物成交是否反向传导到原料（0=否，站长口径）',
  `enabled`         tinyint unsigned NOT NULL DEFAULT 1,
  PRIMARY KEY (`auction_house`,`product_item`,`ingredient_item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AH 市场商人：复合锭配方（单向：价=Σ原料价×用量，不反向传导）';

INSERT INTO `tbccharacters`.`ahbot_price_recipe` (`auction_house`,`product_item`,`ingredient_item`,`count`,`reverse_flow`) VALUES
  (2,  2841,  2840,  1, 0),   -- 青铜锭   = 铜锭×1
  (2,  2841,  3576,  1, 0),   --          + 锡锭×1
  (2,  3859,  3575,  1, 0),   -- 钢锭     = 铁锭×1
  (2,  3859,  3857,  1, 0),   --          + 煤块×1
  (2, 23448, 23445,  3, 0),   -- 魔钢锭   = 魔铁锭×3
  (2, 23448, 23447,  2, 0),   --          + 恒金锭×2
  (2, 23573, 23446, 10, 0);   -- 硬化精金锭 = 精金锭×10
