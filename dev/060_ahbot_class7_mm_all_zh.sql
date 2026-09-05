-- ============================================================
-- [ahbot] 2026-09-05: class7 贸易品(皮/布/矿/草等)统一为 MM(category=1)商品
-- 目的：所有 class7 有掉落来源的皮矿草一律纳入做市商(catalog)管理，
--       不再被 legacy loot 上架；配合 QuoteCatalog 无锚点静态价兜底，
--       保证新行也不会"无价隐形"。
-- 幂等：只补"缺 market_state 行"的条目，已有行不覆盖（INSERT IGNORE）。
-- 生效：执行后需 .ahbot reload 或重启使运行时重新装载目录；
--       报价兜底为代码改动，需重新编译部署。
-- ============================================================
USE tbccharacters;

INSERT IGNORE INTO `ahbot_market_state`
    (`item`, `auction_house`, `enabled`, `category`, `price`, `target`, `capacity`, `qty`, `price_ref`)
SELECT DISTINCT l.item, 2, 1, 1, 0, 500, 1500, 0, 0
FROM (
    SELECT item FROM tbcmangos.creature_loot_template
    UNION SELECT item FROM tbcmangos.gameobject_loot_template
    UNION SELECT item FROM tbcmangos.fishing_loot_template
    UNION SELECT item FROM tbcmangos.skinning_loot_template
    UNION SELECT item FROM tbcmangos.disenchant_loot_template
    UNION SELECT item FROM tbcmangos.item_loot_template
) l
JOIN tbcmangos.item_template it ON it.entry = l.item
WHERE it.class = 7 AND it.quality > 0 AND it.sellprice > 0
  AND NOT EXISTS (SELECT 1 FROM ahbot_market_state s WHERE s.item = l.item);
