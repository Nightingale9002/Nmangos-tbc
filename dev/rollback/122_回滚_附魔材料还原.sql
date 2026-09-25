-- dev/rollback/122_回滚_附魔材料还原.sql
-- ===============================================================
-- 回滚 dev/122：把 6 组强效精华与棱光碎片的 price_ref 还原到改动前的值。
--   还原值 = 本地库 2026-09-25 改动前的实际值（强效精华本来就已经是 3 倍，所以它们其实没变；
--   真正发生变化的只有 大块棱光碎片 22449：39492 → 27337）。
-- 幂等：带 `AND price_ref = <新值>` 守卫 ⇒ 重跑 0 行。
-- 生效：需重启或 .ahbot reload。
-- ===============================================================

UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 897   WHERE `auction_house` = 2 AND `item` = 10939 AND `price_ref` = 897;
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 2229  WHERE `auction_house` = 2 AND `item` = 11082 AND `price_ref` = 2229;
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 7311  WHERE `auction_house` = 2 AND `item` = 11135 AND `price_ref` = 7311;
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 18708 WHERE `auction_house` = 2 AND `item` = 11175 AND `price_ref` = 18708;
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 28533 WHERE `auction_house` = 2 AND `item` = 16203 AND `price_ref` = 28533;
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 52977 WHERE `auction_house` = 2 AND `item` = 22446 AND `price_ref` = 52977;
-- 唯一实际生效的回滚行：大块棱光碎片还原 27337
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 27337 WHERE `auction_house` = 2 AND `item` = 22449 AND `price_ref` = 39492;
