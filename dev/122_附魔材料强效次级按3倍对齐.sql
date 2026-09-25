-- dev/122 附魔材料按「1 强效 = 3 次级」对齐（AH 市场商人 auction_house=2）
-- ===============================================================
-- 站长 2026-09-25 定案：附魔材料的定价口径 = **1 个强效 = 3 个次级**（同一档的"强效X精华 / 次级X精华"成对），
--   大块棱光碎片同理 = 3 × 小块棱光碎片。
--
-- 现状核对（2026-09-25，本地库实测）：
--   * 6 组精华**本来就是精确 3.00 倍**（下次级价 ×3 = 强效价），所以本文件对它们是"把规则写死 + 加守卫"，
--     重跑 0 行；一旦以后次级价变动，本文件重跑即可把它们拉回 3 倍（但**周期内的实时同步靠代码**，见 KNOWN_ISSUES 待办）。
--   * 大块棱光碎片 22449 目前 price_ref=27337，而小块棱光碎片 22448 的 price_ref=13164 ⇒ 比值 2.08 ✗ ⇒ 应为 3×13164=**39492**。
--     注意：22448 仍保持 **category=3（被禁，不挂单）**，站长 2026-09-25 明确不改它；本文件只读它的 price_ref 作为定价基准。
--
-- 幂等：每条带 `AND (price <> X OR price_ref <> X)` 守卫 ⇒ 重跑 0 行。
-- 生效：ahbot_market_state 启动/.ahbot reload 载入 ⇒ 需重启或 reload。
-- 回滚：dev/rollback/122_回滚_附魔材料还原.sql
-- ===============================================================

SET NAMES utf8mb4;

-- 一、6 组精华：强效 = 3 × 次级（数值为当期次级价的 3 倍，写死）
-- 强效魔法精华 10939 = 3 × 次级魔法精华 10938 (299)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 897, `price` = 0 WHERE `auction_house` = 2 AND `item` = 10939 AND (`price_ref` <> 897 OR `price` <> 0);
-- 强效星界精华 11082 = 3 × 次级星界精华 10998 (743)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 2229, `price` = 0 WHERE `auction_house` = 2 AND `item` = 11082 AND (`price_ref` <> 2229 OR `price` <> 0);
-- 强效秘法精华 11135 = 3 × 次级秘法精华 11134 (2437)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 7311, `price` = 0 WHERE `auction_house` = 2 AND `item` = 11135 AND (`price_ref` <> 7311 OR `price` <> 0);
-- 强效虚空精华 11175 = 3 × 次级虚空精华 11174 (6236)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 18708, `price` = 0 WHERE `auction_house` = 2 AND `item` = 11175 AND (`price_ref` <> 18708 OR `price` <> 0);
-- 强效不灭精华 16203 = 3 × 次级不灭精华 16202 (9511)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 28533, `price` = 0 WHERE `auction_house` = 2 AND `item` = 16203 AND (`price_ref` <> 28533 OR `price` <> 0);
-- 强效位面精华 22446 = 3 × 次级位面精华 22447 (17659)
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 52977, `price` = 0 WHERE `auction_house` = 2 AND `item` = 22446 AND (`price_ref` <> 52977 OR `price` <> 0);

-- 二、棱光碎片：大块 22449 = 3 × 小块 22448 (13164) = 39492
--    （小块棱光碎片 22448 保持 category=3 被禁，不动它的行；只把大块价按 3 倍对齐）
UPDATE `tbccharacters`.`ahbot_market_state` SET `price_ref` = 39492, `price` = 0 WHERE `auction_house` = 2 AND `item` = 22449 AND (`price_ref` <> 39492 OR `price` <> 0);
