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
--
-- ⛔ 【全静态 SQL】：本文件没有任何查询 / 判断 / 动态 SQL（`SET @` / `PREPARE` / `information_schema` 一律不用）。
--    站长定规：SQL 里不用逻辑查询，一律静态写死值。结构变更（新增列）已在 **2026-09-22 用静态 ALTER
--    在本地库与云端库建好**，因此本文件只负责建日志表；那句 ALTER 留在文末"结构变更记录"里备查
--    （不放进本文件，是为了避免重跑时 1060 Duplicate column 报错卡住 marker 队列）。

-- 1) auction_history —— 拍卖行成交日志（含玩家↔玩家、玩家↔AHBot、买断与竞价获胜）
--    写入点：AuctionEntry::AuctionBidWinning()（唯一成交结算点）
--    幂等：`CREATE TABLE IF NOT EXISTS` 本身幂等，重跑无副作用。
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

-- 结构变更记录（已完成，无需重复执行；如需在全新库重建请手工跑这一句）：
--   2026-09-22 已在【本地库 + 云端库】执行，云端实测
--     `SHOW COLUMNS FROM tbccharacters.ahbot_market_state LIKE 'last_settle_time';`
--     → last_settle_time  int unsigned  NO  ''  0
--   ALTER TABLE tbccharacters.ahbot_market_state
--     ADD COLUMN last_settle_time INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '上次流水结算时刻(unix)';

-- 回滚：
--   ALTER TABLE tbccharacters.ahbot_market_state DROP COLUMN last_settle_time;
--   DROP TABLE tbccharacters.auction_history;
