-- ============================================================
-- [ahbot] 附魔材料套利处理（简化方案）
-- 方案：小块棱光碎片(22448) 设 category=3，AHBot 不再上架/收购；
--       大块棱光(22449)、虚空水晶(22450)、连结水晶(20725) 保持动态(category=1)。
-- 这样避免 335 级 1大块<->3小块 无冷却互转带来的 AHBot 无限套利。
--
-- 同时维护旧表(当前运行版本)与新表(待切换版本)：
--   ahbot_catalog / ahbot_price / ahbot_market_state
-- 幂等：全部为 UPDATE / INSERT ON DUPLICATE KEY UPDATE，可重复执行。
-- ============================================================
USE tbccharacters;

-- ---------------- 1) 旧表：ahbot_catalog ----------------
-- 22448 小块棱光碎片 -> category=3(ban，不供给/不收购)
-- 22449/22450/20725 -> category=1(dynamic，动态定价)
UPDATE `ahbot_catalog`
SET `category` = CASE `item`
    WHEN 22448 THEN 3
    WHEN 22449 THEN 1
    WHEN 22450 THEN 1
    WHEN 20725 THEN 1
    ELSE `category`
END
WHERE `item` IN (22448, 22449, 22450, 20725);

-- ---------------- 2) 旧表：ahbot_price ----------------
-- 小块棱光不再交易，清掉其旧参考价；其余保留/更新为合理初始价
UPDATE `ahbot_price`
SET `price` = CASE `item`
    WHEN 22448 THEN 0
    WHEN 22449 THEN 108000
    WHEN 22450 THEN 250000
    WHEN 20725 THEN 40000
    ELSE `price`
END
WHERE `item` IN (22448, 22449, 22450, 20725);

-- ---------------- 3) 新表：ahbot_market_state ----------------
UPDATE `ahbot_market_state`
SET `category` = CASE `item`
        WHEN 22448 THEN 3
        WHEN 22449 THEN 1
        WHEN 22450 THEN 1
        WHEN 20725 THEN 1
        ELSE `category`
    END,
    `price` = CASE `item`
        WHEN 22448 THEN 0
        WHEN 22449 THEN 108000
        WHEN 22450 THEN 250000
        WHEN 20725 THEN 40000
        ELSE `price`
    END,
    `price_ref` = CASE `item`
        WHEN 22448 THEN 0
        WHEN 22449 THEN 108000
        WHEN 22450 THEN 250000
        WHEN 20725 THEN 40000
        ELSE `price_ref`
    END
WHERE `item` IN (22448, 22449, 22450, 20725);

-- 若新表中尚缺 20725，则补一个中立 house 的参考行
INSERT INTO `ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`,
                                  `qty`, `avg_cost`, `spent`, `earned`, `flow_bought`, `flow_sold`,
                                  `price_ref`, `override_base_price`, `override_add_chance`,
                                  `override_min_amount`, `override_max_amount`)
VALUES (20725, 0, 1, 1, 40000, 400, 1200, 0, 0, 0, 0, 0, 0, 40000, 0, 0, 0, 0)
ON DUPLICATE KEY UPDATE
    `category` = 1,
    `price` = 40000,
    `price_ref` = 40000;

-- ---------------- 4) 验证 ----------------
SELECT `item`, `auction_house`, `enabled`, `category`, `price`, `price_ref`
FROM `ahbot_market_state`
WHERE `item` IN (22448, 22449, 22450, 20725)
ORDER BY `item`, `auction_house`;