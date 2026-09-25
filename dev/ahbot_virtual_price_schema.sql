-- dev/ahbot_virtual_price_schema.sql（结构件，**不带编号** ⇒ 不被 apply_dev_sql.sh 扫描；两个库手工执行）
-- ===============================================================
-- 成对定价 v2：用「虚拟商品」当价格基准（站长 2026-09-25 设计）
--   站长原话要点：
--     * 两件都动时**分别取两件的价格变化**；
--     * 用一个**虚拟商品**做基准：例如铜矿与铜锭，把**矿和锭的买卖量都作用到"铜"的价格变化**上，
--       再用"铜"的价格**反馈**给铜矿和铜锭；
--     * 这样可以**防止递归**（两边都只写虚拟价、不从对方读），并且**两件商品同时收到同一个信号**。
--
-- 语义：
--   ahbot_price_pair.virtual_item = 该对所属虚拟商品 id；equiv_* = "1 件该物品折算多少份虚拟基准"
--     （矿石/锭：矿 1、锭 = 熔炼配方比例，如 铜锭=1 铜矿石 ⇒ 1；魔铁锭 = 2 魔铁矿石 ⇒ 2）
--     （精华：次级 1、强效 = 3 ⇒ 3；棱光碎片：小块 1、大块 = 3 ⇒ 3）
--   每周期：把该虚拟商品下**所有成员**的净买卖组数折算成虚拟基准份数 → 求和一个信号 →
--           按"每份 ±0.1%（可配）、小时 ±1%、日 ±10%"移动**虚拟价** →
--           再把虚拟价按 equiv 写回每个成员的 price/price_ref（**不改任何已挂单的价格**）。
-- ===============================================================

CREATE TABLE IF NOT EXISTS `tbccharacters`.`ahbot_virtual_price` (
  `virtual_item`     int unsigned      NOT NULL COMMENT '虚拟商品 id（自己编号，不对应 item_template）',
  `name`             varchar(64)       NOT NULL DEFAULT '' COMMENT '仅备注，例如"铜"、"强效/次级精华(魔法)"',
  `auction_house`    tinyint unsigned  NOT NULL DEFAULT 2,
  `price`            int unsigned      NOT NULL DEFAULT 0 COMMENT '虚拟基准价（铜）',
  `flow_bought`      int unsigned      NOT NULL DEFAULT 0 COMMENT '本结算窗口内、折算成虚拟基准份数的买入量',
  `flow_sold`        int unsigned      NOT NULL DEFAULT 0 COMMENT '本结算窗口内、折算成虚拟基准份数的卖出量',
  `hour_price`       int unsigned      NOT NULL DEFAULT 0 COMMENT '本小时窗口起始价（小时内涨幅上限用）',
  `hour_start`       int unsigned      NOT NULL DEFAULT 0,
  `day_price`        int unsigned      NOT NULL DEFAULT 0 COMMENT '本 24h 窗口起始价（日涨幅上限用）',
  `day_start`        int unsigned      NOT NULL DEFAULT 0,
  `last_settle_time` int unsigned      NOT NULL DEFAULT 0,
  `enabled`          tinyint unsigned  NOT NULL DEFAULT 1,
  PRIMARY KEY (`virtual_item`),
  KEY `house` (`auction_house`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AH 市场商人：成对/成族商品的虚拟基准价（防止递归、双向信号汇总）';

-- 给成对表补上"所属虚拟商品 + 折算份数"两列（矿/锭、精华、棱光碎片共用一个机制）
ALTER TABLE `tbccharacters`.`ahbot_price_pair`
  ADD COLUMN `virtual_item` int unsigned NOT NULL DEFAULT 0 COMMENT '所属虚拟商品 id（0=未纳入）' AFTER `enabled`,
  ADD COLUMN `equiv_base`   int unsigned NOT NULL DEFAULT 1 COMMENT '1 件 base 折算多少份虚拟基准（通常 1）' AFTER `virtual_item`,
  ADD COLUMN `equiv_derived` int unsigned NOT NULL DEFAULT 1 COMMENT '1 件 derived 折算多少份虚拟基准（矿石/锭=配方比例；精华=3；棱光=3）' AFTER `equiv_base`;

-- 现有 7 对（精华 6 + 棱光碎片 1）先挂到各自的虚拟商品上，虚拟价先用现值初始化
INSERT IGNORE INTO `tbccharacters`.`ahbot_virtual_price` (`virtual_item`,`name`,`auction_house`,`price`) VALUES
  (1, '魔法精华（次级/强效）', 2, 299),
  (2, '星界精华（次级/强效）', 2, 743),
  (3, '秘法精华（次级/强效）', 2, 2437),
  (4, '虚空精华（次级/强效）', 2, 6236),
  (5, '不灭精华（次级/强效）', 2, 9511),
  (6, '位面精华（次级/强效）', 2, 17659),
  (7, '棱光碎片（小块/大块）', 2, 9112);

UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 1, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 10938;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 2, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 10998;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 3, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 11134;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 4, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 11174;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 5, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 16202;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 6, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 22447;
UPDATE `tbccharacters`.`ahbot_price_pair` SET `virtual_item` = 7, `equiv_base` = 1, `equiv_derived` = 3 WHERE `auction_house` = 2 AND `base_item` = 22448;
