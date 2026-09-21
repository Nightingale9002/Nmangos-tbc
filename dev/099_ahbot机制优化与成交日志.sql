-- AHBot 机制优化 + 拍卖行成交日志 (2026-09-21)
-- 目标库：character 库（tbccharacters）。用显式库名，不依赖 apply_dev_sql.sh 的默认库。
--
-- 背景（本次一并落地的机制改动，见 KNOWN_ISSUES「AHBot 机制优化」章）：
--   ① FlowMinUnits 20 -> 100、FlowRatio 120 -> 300（结算门槛/单边要求提高）
--   ② FlowSettleHours 24 -> 1 + FlowMoveUpPct/DownPct -> 1：每小时最多动 1%，
--      MaxDailyMovePct = 10 ⇒ 一天最多 ±10%（原来是"一天一跳 ±3/5%"）
--   ③ 涨价必须来自 ≥2 个不同买家（代码：soldBuyers 去重）⇒ 单人"养价"失效
--   ④ 方差对称化（ValueWithVariance 值域 [−V, +V]）
--   ⑤ 结算时钟 last_settle_time 持久化（原先只在内存 ⇒ 重启即提前结算）
--   ⑥ 成交日志 auction_history（所有成交一行，便于追踪经济）

-- 1) ahbot_market_state.last_settle_time —— 结算时钟持久化
--    幂等：MySQL 不支持 ADD COLUMN IF NOT EXISTS，用 information_schema 判断。
SET @exist := (SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = 'tbccharacters' AND TABLE_NAME = 'ahbot_market_state'
                  AND COLUMN_NAME = 'last_settle_time');
SET @ddl := IF(@exist = 0,
    'ALTER TABLE tbccharacters.ahbot_market_state ADD COLUMN last_settle_time INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''上次流水结算时刻(unix)''',
    'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) auction_history —— 拍卖行成交日志（含玩家↔玩家、玩家↔AHBot、买断与竞价获胜）
--    写入点：AuctionEntry::AuctionBidWinning()（唯一成交结算点）
CREATE TABLE IF NOT EXISTS tbccharacters.auction_history (
  id            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `time`        INT UNSIGNED     NOT NULL COMMENT 'unix 成交时刻',
  house         TINYINT UNSIGNED NOT NULL COMMENT '0=联盟 1=部落 2=中立（联动拍卖行后实际都是 2）',
  item_template INT UNSIGNED     NOT NULL COMMENT 'item_template.entry',
  item_count    INT UNSIGNED     NOT NULL COMMENT '成交数量（堆叠）',
  unit_price    INT UNSIGNED     NOT NULL COMMENT '成交单价（铜）',
  total_price   INT UNSIGNED     NOT NULL COMMENT '成交总价（铜）',
  seller_guid   INT UNSIGNED     NOT NULL COMMENT '卖家角色 guid；0 = AHBot',
  buyer_guid    INT UNSIGNED     NOT NULL COMMENT '买家角色 guid；0 = AHBot',
  seller_is_bot TINYINT(1)       NOT NULL DEFAULT 0,
  buyer_is_bot  TINYINT(1)       NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_time (`time`),
  KEY idx_item_time (item_template, `time`),
  KEY idx_bot (seller_is_bot, buyer_is_bot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- 回滚：
--   ALTER TABLE tbccharacters.ahbot_market_state DROP COLUMN last_settle_time;
--   DROP TABLE tbccharacters.auction_history;
