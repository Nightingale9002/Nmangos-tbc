-- dev/rollback/118 回滚：把这些锭还原成修改前的状态（category/price/price_ref/target/capacity）
-- 幂等：带 `AND category = 1` 守卫

DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 2840 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 2841 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 3575 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 3859 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 3860 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `enabled` = 1, `category` = 3, `price` = 0, `target` = 1600, `capacity` = 4800, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 12359 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 23445 AND `category` = 1;
DELETE FROM `tbccharacters`.`ahbot_market_state` WHERE `auction_house` = 2 AND `item` = 23446 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `enabled` = 1, `category` = 3, `price` = 0, `target` = 800, `capacity` = 2400, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 23448 AND `category` = 1;
UPDATE `tbccharacters`.`ahbot_market_state` SET `enabled` = 1, `category` = 3, `price` = 0, `target` = 1600, `capacity` = 4800, `price_ref` = 0 WHERE `auction_house` = 2 AND `item` = 23573 AND `category` = 1;

