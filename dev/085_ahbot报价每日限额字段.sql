-- ============================================================================
-- 085_ahbot报价每日限额字段.sql（2026-09-18）
--
-- 站长新增要求：**报价一天上下最多移动 10%**。
--
-- 背景（为什么需要）：
--   价格发现是靠"流水结算"驱动的（`UpdateMarketPrices` 里 flow_bought/flow_sold → 每 FlowSettleHours
--   移动一次锚价，下跌 5% / 上涨 3%）。结算窗口调成 6h 后，一天最多结算 4 次 →
--   单日累计理论跌幅可达 ~18.5%，超过站长要求的 10%。所以需要给"每个物品的报价"加一个
--   **每 24 小时窗口的上下限**：窗口基准价 `day_price`（窗口开始时的报价）+ 窗口起点 `day_start`。
--
-- 代码侧（同批上线，`AuctionHouseBot.cpp/.h`）：
--   · 新增配置 `AuctionHouseBot.MarketMaker.MaxDailyMovePct`（默认 0 = 不限制；云端设为 10）
--     与 `AuctionHouseBot.MarketMaker.MaxGoldPerCycle`（收购熔断的金币总闸）；
--   · `UpdateMarketPrices()` 在落库前把 newPrice 夹在 `day_price ± MaxDailyMovePct%`；
--     窗口满 24h 时用当前报价重设 `day_price/day_start`；
--   · `LoadInventory()` 启动时读回这两个字段，保证跨重启的窗口连续。
--
-- 幂等：用 information_schema 判断后再 ALTER（MySQL 8 不支持 ADD COLUMN IF NOT EXISTS）。
-- 生效：新字段由 mangosd 启动时读取 → **需重启**（与本次其它改动一起）。
-- ============================================================================

USE tbccharacters;

-- day_price：窗口基准报价（铜）
SET @has_day_price := (SELECT COUNT(*) FROM information_schema.COLUMNS
                        WHERE TABLE_SCHEMA = 'tbccharacters'
                          AND TABLE_NAME = 'ahbot_market_state'
                          AND COLUMN_NAME = 'day_price');
SET @sql_dp := IF(@has_day_price = 0,
                  'ALTER TABLE ahbot_market_state ADD COLUMN `day_price` INT UNSIGNED NOT NULL DEFAULT 0',
                  'SELECT ''day_price 已存在，跳过'' AS note');
PREPARE st_dp FROM @sql_dp;
EXECUTE st_dp;
DEALLOCATE PREPARE st_dp;

-- day_start：窗口起始时间戳（unix）
SET @has_day_start := (SELECT COUNT(*) FROM information_schema.COLUMNS
                        WHERE TABLE_SCHEMA = 'tbccharacters'
                          AND TABLE_NAME = 'ahbot_market_state'
                          AND COLUMN_NAME = 'day_start');
SET @sql_ds := IF(@has_day_start = 0,
                  'ALTER TABLE ahbot_market_state ADD COLUMN `day_start` INT UNSIGNED NOT NULL DEFAULT 0',
                  'SELECT ''day_start 已存在，跳过'' AS note');
PREPARE st_ds FROM @sql_ds;
EXECUTE st_ds;
DEALLOCATE PREPARE st_ds;

-- 校验
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'tbccharacters'
   AND TABLE_NAME = 'ahbot_market_state'
   AND COLUMN_NAME IN ('day_price', 'day_start')
 ORDER BY ORDINAL_POSITION;

-- 当前窗口状态抽样（重启后每隔一个窗口会看到 day_start 刷新）
SELECT item, auction_house, price_ref, day_price, day_start
  FROM ahbot_market_state
 WHERE item IN (22445, 22449, 22450, 20725)
 ORDER BY item;
