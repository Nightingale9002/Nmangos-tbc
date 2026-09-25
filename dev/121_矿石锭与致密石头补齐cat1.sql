-- dev/121 矿石/锭/石头补齐 cat1（AH 市场商人 auction_house=2）
-- ===============================================================
-- 站长 2026-09-25 指示（范围）：把与已列入 cat1 的矿石同类的锭补进去；别的石头放进去了但致密的石头没放。
--   明确不动：小块棱光碎片 22448（保持 cat3 被禁）、黑铁锭 11371、奥金锭 12360、附魔瑟银锭 12655、
--             源质锭 17771、黑钢锭 3861、守护之石 12809、小块/大块黑曜石碎片 22202/22203、萨弗隆铁锭 17203。
--
-- 价格口径（沿用 dev/118）：
--   * 锭 = 熔炼配方（spell_template Effect=24 + 试剂）逐层累加材料价；**优先 Smelt 类配方（直接吃矿石）**，
--     没有 Smelt 配方时才用 Transmute 类。
--     材料价优先：新的矿石 BuyPrice → 书目价(price) → 书目参考价(price_ref) → 商人价估算 max(SellPrice×5,BuyPrice)。
--   * 矿石/石头 = 商人 BuyPrice（与书目里已有的矿石/坚固的石头一致）。
-- | entry | 名称 | 价格(铜) | 依据 |
-- |---|---|---|---|
-- | 2842 | Silver Bar | 300 | Smelt Silver：2775×1=300(新列入矿石 BuyPrice 300) |
-- | 3576 | Tin Bar | 100 | Smelt Tin：2771×1=100(书目参考价 100) |
-- | 3577 | Gold Bar | 2000 | Smelt Gold：2776×1=2000(新列入矿石 BuyPrice 2000) |
-- | 6037 | Truesilver Bar | 2000 | Smelt Truesilver：7911×1=2000(书目参考价 2000) |
-- | 23447 | Eternium Bar | 10000 | Smelt Eternium：23427×2=10000(书目参考价 5000) |
-- | 23449 | Khorium Bar | 20000 | Smelt Khorium：23426×2=20000(书目参考价 10000) |
-- | 2775 | Silver Ore | 300 | 矿石 ⇒ 用商人 BuyPrice（与其它矿石行一致） |
-- | 2776 | Gold Ore | 2000 | 矿石 ⇒ 用商人 BuyPrice（与其它矿石行一致） |
-- | 10620 | Thorium Ore | 1000 | 矿石 ⇒ 用商人 BuyPrice（与其它矿石行一致） |
-- | 12365 | Dense Stone | 1000 | 石头 ⇒ 用商人 BuyPrice（与坚固的石头一致） |
--
-- 幂等：INSERT IGNORE + 带 `category<>1 OR price<>… OR price_ref<>…` 守卫的 UPDATE ⇒ 重跑 0 行。
-- 生效：ahbot_market_state 启动/.ahbot reload 时读取 ⇒ 需重启或 reload。
-- 回滚：dev/rollback/121_回滚_补齐项退出cat1.sql
-- ===============================================================

SET NAMES utf8mb4;

-- Silver Bar 2842（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (2842,2,1,1,300,1600,4800,300);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=300, `price_ref`=300, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=2842 AND (`category`<>1 OR `enabled`<>1 OR `price`<>300 OR `price_ref`<>300);

-- Tin Bar 3576（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (3576,2,1,1,100,1600,4800,100);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=100, `price_ref`=100, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=3576 AND (`category`<>1 OR `enabled`<>1 OR `price`<>100 OR `price_ref`<>100);

-- Gold Bar 3577（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (3577,2,1,1,2000,1600,4800,2000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=2000, `price_ref`=2000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=3577 AND (`category`<>1 OR `enabled`<>1 OR `price`<>2000 OR `price_ref`<>2000);

-- Truesilver Bar 6037（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (6037,2,1,1,2000,1600,4800,2000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=2000, `price_ref`=2000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=6037 AND (`category`<>1 OR `enabled`<>1 OR `price`<>2000 OR `price_ref`<>2000);

-- Eternium Bar 23447（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (23447,2,1,1,10000,1600,4800,10000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=10000, `price_ref`=10000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=23447 AND (`category`<>1 OR `enabled`<>1 OR `price`<>10000 OR `price_ref`<>10000);

-- Khorium Bar 23449（锭=熔炼成本）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (23449,2,1,1,20000,1600,4800,20000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=20000, `price_ref`=20000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=23449 AND (`category`<>1 OR `enabled`<>1 OR `price`<>20000 OR `price_ref`<>20000);

-- Silver Ore 2775（矿石=BuyPrice）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (2775,2,1,1,300,1600,4800,300);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=300, `price_ref`=300, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=2775 AND (`category`<>1 OR `enabled`<>1 OR `price`<>300 OR `price_ref`<>300);

-- Gold Ore 2776（矿石=BuyPrice）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (2776,2,1,1,2000,1600,4800,2000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=2000, `price_ref`=2000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=2776 AND (`category`<>1 OR `enabled`<>1 OR `price`<>2000 OR `price_ref`<>2000);

-- Thorium Ore 10620（矿石=BuyPrice）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (10620,2,1,1,1000,1600,4800,1000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=1000, `price_ref`=1000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=10620 AND (`category`<>1 OR `enabled`<>1 OR `price`<>1000 OR `price_ref`<>1000);

-- Dense Stone 12365（石头=BuyPrice）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (12365,2,1,1,1000,1600,4800,1000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category`=1, `enabled`=1, `price`=1000, `price_ref`=1000, `target`=1600, `capacity`=4800 WHERE `auction_house`=2 AND `item`=12365 AND (`category`<>1 OR `enabled`<>1 OR `price`<>1000 OR `price_ref`<>1000);
