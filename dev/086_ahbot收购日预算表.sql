-- ============================================================================
-- 086_ahbot收购日预算表.sql（2026-09-18）
--
-- 站长定案（熔断③，主闸）：
--   · 按 **50 人在线** 的目标规模，bot **每 24 小时最多释放 5000 金**；
--   · 考虑到在线时间不均匀 → 用"天"做硬限制，而不是"周期"；
--   · **同时保留周期闸**（`MarketMaker.MaxGoldPerCycle`），防止有人一上来就把日预算吃完；
--   · "真有人找到漏洞钻，那也算他的奖励" → 不设更多限制。
--
-- 本表用途：把"当前 24h 窗口 + 已释放金币"持久化，使日预算**跨重启连续**。
--   如果不持久化，每天 04:06 的夜间重启就会把预算重置 → 等于没有闸。
--
-- 代码侧（同批上线 `AuctionHouseBot.cpp/.h`）：
--   · 配置 `AuctionHouseBot.MarketMaker.MaxGoldPerDay`（单位铜；云端 50000000 = 5000 金）
--   · 配置 `AuctionHouseBot.MarketMaker.MaxGoldPerCycle`（单位铜；云端 300000 = 30 金/周期）
--   · `RollDailyBudgetWindow()`：满 24h 重置窗口；
--   · `PersistDailyBudget()`：每次收购后落库；
--   · `LoadInventory()`：启动时读回，跨重启连续；
--   · 触发时打 error 级日志（`[AHBOT] BUY BREAKER TRIPPED (daily) / (per-cycle)`）。
--
-- 读法：id 恒为 1（单行表）。day_start = 当前窗口起点（unix），gold_spent = 本窗口已释放金币（铜）。
-- 手动重置预算（例如临时放开）：UPDATE ahbot_daily_budget SET gold_spent = 0 WHERE id = 1;
--
-- 幂等：CREATE TABLE IF NOT EXISTS + INSERT IGNORE。
-- 生效：需要重启 mangosd（代码启动时读表）。
-- ============================================================================

USE tbccharacters;

CREATE TABLE IF NOT EXISTS ahbot_daily_budget (
    id          TINYINT UNSIGNED NOT NULL DEFAULT 1,
    day_start   INT UNSIGNED     NOT NULL DEFAULT 0  COMMENT '当前 24h 窗口起点（unix 时间戳）',
    gold_spent  BIGINT UNSIGNED  NOT NULL DEFAULT 0  COMMENT '本窗口 ahbot 收购已释放的金币（单位：铜）',
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AHBot 收购日预算（熔断用，跨重启连续）';

INSERT IGNORE INTO ahbot_daily_budget (id, day_start, gold_spent) VALUES (1, 0, 0);

-- 校验
SELECT id, day_start, gold_spent, ROUND(gold_spent/10000, 2) AS spent_gold,
       IF(day_start = 0, '窗口尚未开始（首次收购时初始化）', FROM_UNIXTIME(day_start)) AS window_start
  FROM ahbot_daily_budget;
