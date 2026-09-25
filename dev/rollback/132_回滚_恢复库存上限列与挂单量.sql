-- =====================================================================================
-- 132_回滚_恢复库存上限列与挂单量.sql
-- 对应：dev/132_ahbot去掉曝光与库存上限_按target补满.sql
-- 日期：2026-09-26        适用库：tbccharacters        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 注意：**只回滚数据不够**。capacity 列一旦恢复，代码里没有任何地方再读它（v4 已删除
-- 曝光切片/库存上限逻辑），所以要真正回到旧行为必须同时 git revert 掉 AHBot 那次改造
-- （QuoteCatalog 按真实货架补满 → 曝光切片）并重新编译部署。此文件只负责列结构与数值。
-- =====================================================================================

-- 1) 恢复 capacity 列（幂等）
SET @has_capacity := (SELECT COUNT(*) FROM information_schema.COLUMNS
                       WHERE TABLE_SCHEMA = 'tbccharacters'
                         AND TABLE_NAME = 'ahbot_market_state'
                         AND COLUMN_NAME = 'capacity');
SET @stmt := IF(@has_capacity = 0,
                'ALTER TABLE `tbccharacters`.`ahbot_market_state` ADD COLUMN `capacity` INT UNSIGNED NOT NULL DEFAULT 0',
                'DO 0');
PREPARE s FROM @stmt;
EXECUTE s;
DEALLOCATE PREPARE s;

-- 2) 从备份恢复 target / capacity 原值
UPDATE `tbccharacters`.`ahbot_market_state` m
  JOIN `tbccharacters`.`ahbot_market_state_bak_20260926_cap` b
    ON b.item = m.item AND b.auction_house = m.auction_house
   SET m.target = b.target, m.capacity = b.capacity
 WHERE m.target <> b.target OR m.capacity <> b.capacity;

-- 3) 核对：恢复成改造前的 1600/4800、800/2400、400/1200、100/300 等档位
SELECT category, target, capacity, COUNT(*) AS rows_cnt
  FROM `tbccharacters`.`ahbot_market_state`
 WHERE auction_house = 2 AND enabled = 1 AND category IN (1,2)
 GROUP BY category, target, capacity ORDER BY category, target;
