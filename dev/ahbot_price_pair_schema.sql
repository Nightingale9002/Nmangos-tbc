-- dev/ahbot_price_pair_schema.sql（结构件，**不带编号** ⇒ 不会被 /root/apply_dev_sql.sh 扫描执行；在两个库手工执行）
-- ===============================================================
-- dev/price_pair 成对材料「共同定价」表 —— 站长 2026-09-25 指示：
--   ① 不同商品对的比例不一样 ⇒ 比例必须逐对配置；
--   ② 商品对中**任意一件**的价格变化都要影响整对（双向传播）。
--
-- 语义：derived_item 的价格 = base_item 的价格 × ratio（ratio = "多少件 base 折 1 件 derived"）。
--   * 精华 6 组：base = 次级X精华，derived = 强效X精华，ratio = 3（站长口径 1 强效 = 3 次级）
--   * 棱光碎片： base = 小块棱光碎片，derived = 大块棱光碎片，ratio = 3（配方 28022：小块×3 → 大块×1 ✓）
--   * 库内转化配方对精华是 2:1（spell 13361/13632/13739/20039/32977），与站长口径 3:1 不一致 ⇒ 以站长口径为准，
--     配方只作留档；所以比例写在本表里，**不写死在代码**。
--
-- last_base_price / last_sync_time：给周期对账用（判断这一周期里是哪一件先动、避免来回抖动）。
-- ===============================================================

CREATE TABLE IF NOT EXISTS `tbccharacters`.`ahbot_price_pair` (
  `id`               int unsigned      NOT NULL AUTO_INCREMENT,
  `auction_house`    tinyint unsigned  NOT NULL DEFAULT 2,
  `base_item`        int unsigned      NOT NULL COMMENT '基准件：价格由市场发现',
  `derived_item`     int unsigned      NOT NULL COMMENT '派生件：价格 = base × ratio',
  `ratio`            int unsigned      NOT NULL DEFAULT 3 COMMENT '多少件 base 折 1 件 derived（逐对配置，各不相同）',
  `enabled`          tinyint unsigned  NOT NULL DEFAULT 1,
  `last_base_price`  int unsigned      NOT NULL DEFAULT 0 COMMENT '上次对账时的基准价（铜）',
  `last_sync_time`   int unsigned      NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pair` (`auction_house`,`base_item`,`derived_item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AH 市场商人：成对材料共同定价（比例逐对配置）';

-- 现有商品对（精华 6 组 + 棱光碎片 1 组），比例均为 3
INSERT IGNORE INTO `tbccharacters`.`ahbot_price_pair` (`auction_house`,`base_item`,`derived_item`,`ratio`,`enabled`) VALUES
  (2, 10938, 10939, 3, 1),   -- 次级魔法精华 -> 强效魔法精华
  (2, 10998, 11082, 3, 1),   -- 次级星界精华 -> 强效星界精华
  (2, 11134, 11135, 3, 1),   -- 次级秘法精华 -> 强效秘法精华
  (2, 11174, 11175, 3, 1),   -- 次级虚空精华 -> 强效虚空精华
  (2, 16202, 16203, 3, 1),   -- 次级不灭精华 -> 强效不灭精华
  (2, 22447, 22446, 3, 1),   -- 次级位面精华 -> 强效位面精华
  (2, 22448, 22449, 3, 1);   -- 小块棱光碎片 -> 大块棱光碎片
