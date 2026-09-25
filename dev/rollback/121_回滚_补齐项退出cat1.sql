-- dev/rollback/121_回滚_补齐项退出cat1.sql
-- 把 dev/121 新增的矿石/锭/石头/小块棱光碎片 退回 category=0（等于「不管」，与它们原来的状态一致）；
-- 小块棱光碎片 22448 原来是被禁（cat3），如需完全复原请把下面那行改成 category=3。
-- 幂等：带 `AND category = 1` 守卫 ⇒ 重跑 0 行。

UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 2842 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 3576 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 3577 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 6037 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 23447 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 23449 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 2775 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 2776 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 10620 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 0, `price` = 0, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 12365 AND `category` = 1;
