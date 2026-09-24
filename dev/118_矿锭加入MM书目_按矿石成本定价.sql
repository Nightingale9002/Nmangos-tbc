-- dev/118 把「锭」加入 AHBot 市场商人书目（category=1），价格 = **熔炼配方的矿石成本价**
-- ===============================================================
-- 站长定案（2026-09-24）：铜锭/青铜锭/钢锭/秘银锭/瑟银锭/魔铁锭/精金锭/魔钢锭/硬化精金锭 共 9 件改成 cat1；石头系列先不动。
-- 价格口径（站长）：按**矿石成本价**计算 —— 用熔炼配方（spell_template 里 Effect=24 的制造法术 + 试剂）逐层累加：
--   材料价优先取 AHBot 书目价(price) → 书目参考价(price_ref) → 配方反推 → 商人价估算 max(SellPrice×5, BuyPrice)。
--
-- | 锭 | 成本(铜) | 配方链 | 原 category |
-- |---|---|---|---|
-- | 铜锭 2840 | 20 | 铜矿石×1（书目参考价 20） | 无行(=0) |
-- | 青铜锭 2841 | 120 | 铜锭20 + 锡锭100 | 无行(=0) |
-- | 铁锭 3575 | 600 | 铁矿石×1（书目参考价 600） | 无行(=0) |
-- | 钢锭 3859 | 1100 | 铁锭600 + 煤块500 | 无行(=0) |
-- | 秘银锭 3860 | 1000 | 秘银矿石×1（书目参考价 1000） | 无行(=0) |
-- | 瑟银锭 12359 | 1250 | 瑟银矿石×1（商人价估算 1250） | 3 |
-- | 魔铁锭 23445 | 8000 | 魔铁矿石×2（书目参考价 4000×2） | 无行(=0) |
-- | 精金锭 23446 | 12000 | 精金矿石×2（书目参考价 6000×2） | 无行(=0) |
-- | 魔钢锭 23448 | 44000 | 魔铁锭×3(24000) + 恒金锭×2(20000) | 3 |
-- | 硬化精金锭 23573 | 120000 | 精金锭×10 | 3 |
--
-- 注：`target=1600` / `capacity=4800` 与书目里其它金属石头行保持一致。
--     瑟银矿石目前不在书目里（cat0），其价 1250 来自"商人价估算"；若日后把瑟银矿石也放进书目，瑟银锭/奥金锭等成本应随之重算。
-- 幂等：INSERT IGNORE + 带 `category<>1 OR price<>… ` 守卫的 UPDATE ⇒ 重跑 0 行。
-- 生效：`ahbot_market_state` 由 AHBot 启动时/`.ahbot reload` 读取 ⇒ 需重启（或站长手动 reload）。
-- 回滚：`dev/rollback/118_回滚_矿锭退出书目.sql`
-- ===============================================================

-- 铜锭 (2840)：铜矿石×1（书目参考价 20）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (2840, 2, 1, 1, 20, 1600, 4800, 20);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 20, `price_ref` = 20, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 2840 AND (`category` <> 1 OR `price` <> 20 OR `price_ref` <> 20 OR `enabled` <> 1);

-- 青铜锭 (2841)：铜锭20 + 锡锭100
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (2841, 2, 1, 1, 120, 1600, 4800, 120);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 120, `price_ref` = 120, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 2841 AND (`category` <> 1 OR `price` <> 120 OR `price_ref` <> 120 OR `enabled` <> 1);

-- 铁锭 (3575)：铁矿石×1（书目参考价 600）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (3575, 2, 1, 1, 600, 1600, 4800, 600);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 600, `price_ref` = 600, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 3575 AND (`category` <> 1 OR `price` <> 600 OR `price_ref` <> 600 OR `enabled` <> 1);

-- 钢锭 (3859)：铁锭600 + 煤块500
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (3859, 2, 1, 1, 1100, 1600, 4800, 1100);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 1100, `price_ref` = 1100, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 3859 AND (`category` <> 1 OR `price` <> 1100 OR `price_ref` <> 1100 OR `enabled` <> 1);

-- 秘银锭 (3860)：秘银矿石×1（书目参考价 1000）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (3860, 2, 1, 1, 1000, 1600, 4800, 1000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 1000, `price_ref` = 1000, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 3860 AND (`category` <> 1 OR `price` <> 1000 OR `price_ref` <> 1000 OR `enabled` <> 1);

-- 瑟银锭 (12359)：瑟银矿石×1（商人价估算 1250）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (12359, 2, 1, 1, 1250, 1600, 4800, 1250);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 1250, `price_ref` = 1250, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 12359 AND (`category` <> 1 OR `price` <> 1250 OR `price_ref` <> 1250 OR `enabled` <> 1);

-- 魔铁锭 (23445)：魔铁矿石×2（书目参考价 4000×2）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (23445, 2, 1, 1, 8000, 1600, 4800, 8000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 8000, `price_ref` = 8000, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 23445 AND (`category` <> 1 OR `price` <> 8000 OR `price_ref` <> 8000 OR `enabled` <> 1);

-- 精金锭 (23446)：精金矿石×2（书目参考价 6000×2）
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (23446, 2, 1, 1, 12000, 1600, 4800, 12000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 12000, `price_ref` = 12000, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 23446 AND (`category` <> 1 OR `price` <> 12000 OR `price_ref` <> 12000 OR `enabled` <> 1);

-- 魔钢锭 (23448)：魔铁锭×3(24000) + 恒金锭×2(20000)
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (23448, 2, 1, 1, 44000, 1600, 4800, 44000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 44000, `price_ref` = 44000, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 23448 AND (`category` <> 1 OR `price` <> 44000 OR `price_ref` <> 44000 OR `enabled` <> 1);

-- 硬化精金锭 (23573)：精金锭×10
INSERT IGNORE INTO `tbccharacters`.`ahbot_market_state` (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `price_ref`) VALUES (23573, 2, 1, 1, 120000, 1600, 4800, 120000);
UPDATE `tbccharacters`.`ahbot_market_state` SET `category` = 1, `enabled` = 1, `price` = 120000, `price_ref` = 120000, `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` = 23573 AND (`category` <> 1 OR `price` <> 120000 OR `price_ref` <> 120000 OR `enabled` <> 1);

