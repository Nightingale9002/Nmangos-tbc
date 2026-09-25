-- dev/rollback/123_回滚_棱光碎片还原.sql
-- ===============================================================
-- 回滚 dev/123：把棱光碎片恢复成 dev/122 之后的状态：
--   * 大块棱光碎片 22449：27337 → 39492
--   * 小块棱光碎片 22448：category 1 → 3（退回被禁）、price_ref 9112 → 13164
-- 幂等：带目标值守卫 ⇒ 重跑 0 行。
-- 生效：需重启或 .ahbot reload。
-- ===============================================================

UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 39492 WHERE `auction_house` = 2 AND `item` = 22449 AND `price_ref` = 27337;

UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 3, `price_ref` = 13164 WHERE `auction_house` = 2 AND `item` = 22448 AND `category` = 1;
