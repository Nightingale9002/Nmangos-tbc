-- =====================================================================================
-- 136_ahbot金币流水定价_加列.sql（2026-09-29）
-- 适用库：tbccharacters（**角色库**，不是 world 库 tbcmangos）
-- 类型：结构变更（加 2 列快照 / 删 2 列旧"窗口累加"）/ 幂等（可重复执行）
-- 配套代码：src/game/AuctionHouseBot/AuctionHouseBot.cpp / AuctionHouseBot.h（同一次提交）
-- 回滚：dev/rollback/136_回滚_删除金币流水列.sql
-- =====================================================================================
-- 【站长定案的口径（第二次修订：窗口累加器 → 快照差值）】AHBot 做市商的"长周期流水结算"
--   不再按**单位数 + 买卖比**动价，改按**金币流水**动价（单位：铜；窗口 =
--   AuctionHouseBot.MarketMaker.FlowSettleHours）：
--     · 降价：机器人为"从玩家手里收货"花出去的金币，每满 100 金（= 1,000,000 铜）
--             ⇒ 降 AuctionHouseBot.MarketMaker.MoveDownBpPer100Gold bp（默认 10 bp = 0.1%）
--     · 涨价：玩家为"买走我们的挂单"花掉的金币，每满 100 金 ⇒ 涨
--             AuctionHouseBot.MarketMaker.MoveUpBpPer100Gold bp（默认 10 bp = 0.1%），
--             且必须来自 **≥2 个不同买家**（单人自买自卖/养价不算需求，该窗口涨价额度作废）
--     · 同窗口两方向都有流水 ⇒ 先各自算 bp 再相减 netBp = upBp - downBp：
--             >0 涨 / <0 跌 / ==0 不动
--     · 不足 100 金的尾数按"整百金"**向下取整丢弃**（步骤数 = 金币铜数 / 1,000,000），
--             每次结算后窗口重新开始（快照推进 ⇒ 尾数不结转）
--     · 已取消：FlowMinUnits（最少单位数门槛）、FlowRatio（买卖比门槛）、
--             FlowMoveUpPct/FlowMoveDownPct（单次幅度封顶）
--     · 唯一保留的封顶：每 24 小时 ±MaxDailyMovePct（默认 10%，day_price/day_start 窗口）
--   ★ 窗口金币**不再由"窗口累加器"维护**：spent / earned 两列是累计值、是"金币的唯一真相"
--     （PnL 观测用，不能破坏），所以只存两个"上次结算时"的快照列，窗口金币 = 当前累计值 - 快照：
--       windowBoughtGold = spent  - last_settle_spent   （机器人花出去 ⇒ 降价侧）
--       windowSoldGold   = earned - last_settle_earned  （玩家花掉   ⇒ 涨价侧）
--     代码里对"快照异常大于当前累计值"做了**无符号下溢保护**（差值为负时夹到 0）。
--   注意：流的**单位数**计数 flow_bought / flow_sold 仍然保留累加与清零（既有 observability）。
-- -------------------------------------------------------------------------------------
-- 【本文件做什么】对 tbccharacters.ahbot_market_state 做两件事（顺序无关，均幂等）：
--   1) 加两列（INT UNSIGNED NOT NULL DEFAULT 0）—— "上次结算时"的 spent / earned 快照：
--          · last_settle_spent  = 上次结算时的 spent（累计值快照）；LoadInventory() 启动时读入，
--                                 UpdateMarketPrices() 的 SETTLE 块结算后推进
--          · last_settle_earned = 上次结算时的 earned（累计值快照）；同上
--   2) 删掉旧的窗口累加列（若存在）：
--          · flow_bought_gold / flow_sold_gold —— 旧口径的"窗口金币累加器"，已被快照口径取代；
--            代码不再 SELECT / UPDATE 这两列，留着只是垃圾列（删除**不影响** spent/earned 的累计数据）
-- -------------------------------------------------------------------------------------
-- 【为什么必须和代码一起上线 / 顺序】新代码的 SELECT 里带了 last_settle_spent / last_settle_earned
--   ⇒ **列不存在会直接报错**（客户端读不到字段，AHBot 的 LoadInventory 会失败）。云端夜间流程是
--   "先应用 dev SQL 再编译重启"，顺序天然正确；**手工部署时务必先执行本 SQL 再换二进制**。
-- 【生效方式】纯结构变更 ⇒ 执行后重启 mangosd（与本次代码一起）；不需要改 world 库。
-- 【幂等】用 information_schema 判断列是否存在后再 ALTER / DROP（MySQL 8 不支持
--   ADD/DROP COLUMN IF EXISTS），可重复执行：已存在的库会打印"已存在，跳过"。
-- 【验证】
--   SHOW COLUMNS FROM tbccharacters.ahbot_market_state LIKE '%settle%';
--   -- 期望 3 列：last_settle_time（旧列）+ last_settle_spent + last_settle_earned，默认值均为 0
--   SHOW COLUMNS FROM tbccharacters.ahbot_market_state LIKE '%_gold';
--   -- 期望**为空**（flow_bought_gold / flow_sold_gold 已被删除；spent/earned 不匹配该模式）
--   SELECT item, auction_house, spent, last_settle_spent, earned, last_settle_earned,
--          spent - last_settle_spent AS windowBoughtGold, earned - last_settle_earned AS windowSoldGold
--     FROM tbccharacters.ahbot_market_state
--    WHERE auction_house = 2 ORDER BY windowBoughtGold + windowSoldGold DESC LIMIT 20;
--   -- 生效后 Server.log 会出现新口径日志：
--   --   [AHBOT] SETTLE item=.. house=.. boughtGold=.. soldGold=.. upBp=.. downBp=.. buyers=.. old=.. new=.. result=..
--              （boughtGold / soldGold = 本窗口的 spent / earned 差值，即窗口金币）
-- 【回滚】dev/rollback/136_回滚_删除金币流水列.sql（幂等删列；回滚后必须同时回滚代码）
-- =====================================================================================

USE tbccharacters;

-- last_settle_spent：上次结算时的 spent（累计值快照）—— 窗口机器人花出去的金币 = spent - 本列
SET @has_last_settle_spent := (SELECT COUNT(*) FROM information_schema.COLUMNS
                                WHERE TABLE_SCHEMA = 'tbccharacters'
                                  AND TABLE_NAME = 'ahbot_market_state'
                                  AND COLUMN_NAME = 'last_settle_spent');
SET @sql_lss := IF(@has_last_settle_spent = 0,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` ADD COLUMN `last_settle_spent` INT UNSIGNED NOT NULL DEFAULT 0',
                   'SELECT ''last_settle_spent 已存在，跳过'' AS note');
PREPARE st_lss FROM @sql_lss;
EXECUTE st_lss;
DEALLOCATE PREPARE st_lss;

-- last_settle_earned：上次结算时的 earned（累计值快照）—— 窗口玩家花掉的金币 = earned - 本列
SET @has_last_settle_earned := (SELECT COUNT(*) FROM information_schema.COLUMNS
                                 WHERE TABLE_SCHEMA = 'tbccharacters'
                                   AND TABLE_NAME = 'ahbot_market_state'
                                   AND COLUMN_NAME = 'last_settle_earned');
SET @sql_lse := IF(@has_last_settle_earned = 0,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` ADD COLUMN `last_settle_earned` INT UNSIGNED NOT NULL DEFAULT 0',
                   'SELECT ''last_settle_earned 已存在，跳过'' AS note');
PREPARE st_lse FROM @sql_lse;
EXECUTE st_lse;
DEALLOCATE PREPARE st_lse;

-- flow_bought_gold：旧口径的"本窗口机器人花出去的金币"累加器 ⇒ 已被快照列取代，删除（若存在）
SET @has_flow_bought_gold := (SELECT COUNT(*) FROM information_schema.COLUMNS
                               WHERE TABLE_SCHEMA = 'tbccharacters'
                                 AND TABLE_NAME = 'ahbot_market_state'
                                 AND COLUMN_NAME = 'flow_bought_gold');
SET @sql_fbg := IF(@has_flow_bought_gold = 1,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` DROP COLUMN `flow_bought_gold`',
                   'SELECT ''flow_bought_gold 不存在，跳过'' AS note');
PREPARE st_fbg FROM @sql_fbg;
EXECUTE st_fbg;
DEALLOCATE PREPARE st_fbg;

-- flow_sold_gold：旧口径的"本窗口玩家花掉的金币"累加器 ⇒ 已被快照列取代，删除（若存在）
SET @has_flow_sold_gold := (SELECT COUNT(*) FROM information_schema.COLUMNS
                             WHERE TABLE_SCHEMA = 'tbccharacters'
                               AND TABLE_NAME = 'ahbot_market_state'
                               AND COLUMN_NAME = 'flow_sold_gold');
SET @sql_fsg := IF(@has_flow_sold_gold = 1,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` DROP COLUMN `flow_sold_gold`',
                   'SELECT ''flow_sold_gold 不存在，跳过'' AS note');
PREPARE st_fsg FROM @sql_fsg;
EXECUTE st_fsg;
DEALLOCATE PREPARE st_fsg;

-- 校验 1：快照两列都在（默认 0），且旧的 flow_bought_gold / flow_sold_gold 已不存在
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'tbccharacters'
   AND TABLE_NAME = 'ahbot_market_state'
   AND COLUMN_NAME IN ('last_settle_spent', 'last_settle_earned', 'flow_bought_gold', 'flow_sold_gold')
 ORDER BY ORDINAL_POSITION;

-- 校验 2：报价书目里窗口金币（快照差值）非 0 的行（重启后窗口内有成交时才会看到；结算后归零）
SELECT item, auction_house, price_ref, flow_bought, flow_sold,
       spent, last_settle_spent, spent - last_settle_spent AS windowBoughtGold,
       earned, last_settle_earned, earned - last_settle_earned AS windowSoldGold
  FROM `tbccharacters`.`ahbot_market_state`
 WHERE auction_house = 2
   AND (spent > last_settle_spent OR earned > last_settle_earned)
 ORDER BY (spent - last_settle_spent) + (earned - last_settle_earned) DESC
 LIMIT 20;
