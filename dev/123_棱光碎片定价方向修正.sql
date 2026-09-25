-- dev/123 棱光碎片：把小棱光也放进 cat1，并以「大块棱光碎片」为基准（1 大块 = 3 小块）
-- ===============================================================
-- 站长 2026-09-25 定案：
--   1) 基准必须是**真实挂单（cat1）**的那一件 —— dev/122 拿被禁的小块当基准是错的，本文件修正；
--   2) 并且**把小块棱光碎片 22448 也放进 cat1**（原来 cat3 被禁），这样两件都真实挂单，3:1 关系双向都成立，
--      与 6 组精华（强效/次级都在 cat1）的处理方式一致。
--
-- 具体改动（auction_house=2）：
--   * 22449 大块棱光碎片（已是 cat1）：price_ref 39492 → **27337**（还原为书目原值，作为基准价）
--   * 22448 小块棱光碎片：category **3 → 1**、enabled=1、price_ref 13164 → **9112**（= FLOOR(27337 / 3)；
--     3×9112 = 27336，差 1 铜为取整误差）、price=0、target/capacity = 400/1200（与其它 cat1 附魔材料一致）
--
-- 由此确立的通用口径（已写入 KNOWN_ISSUES）：
--   **"1 强效 = 3 次级" 这类关系，一律以"被列入 cat1、真实挂单的那一件"为基准，另一件按 1:3 反推。**
--   精华 6 组两件都在 cat1，历史数据就是"强效 = 3 × 次级"，保持不动。
--
-- 幂等：INSERT IGNORE + 带旧值/目标值守卫的 UPDATE ⇒ 重跑 0 行。
-- 生效：ahbot_market_state 启动/.ahbot reload 载入 ⇒ 需重启或 reload。
-- 回滚：dev/rollback/123_回滚_棱光碎片还原.sql（还原 22449=39492、22448 回 cat3/13164）
-- ===============================================================

SET NAMES utf8mb4;

-- 一、基准件还原：大块棱光碎片 22449 = 27337（dev/122 曾改成 39492）
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 27337 WHERE `auction_house` = 2 AND `item` = 22449 AND `price_ref` = 39492;

-- 二、小块棱光碎片 22448 进入 cat1，价格 = 大块 / 3 = 9112
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`,`auction_house`,`enabled`,`category`,`price`,`target`,`capacity`,`price_ref`) VALUES (22448,2,1,1,0,400,1200,9112);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 0, `price_ref` = 9112, `target` = 400, `capacity` = 1200 WHERE `auction_house` = 2 AND `item` = 22448 AND (`category` <> 1 OR `enabled` <> 1 OR `price` <> 0 OR `price_ref` <> 9112 OR `target` <> 400 OR `capacity` <> 1200);
