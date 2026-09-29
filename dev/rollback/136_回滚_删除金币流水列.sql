-- =====================================================================================
-- 136_回滚_删除金币流水列.sql
-- 对应：dev/136_ahbot金币流水定价_加列.sql
-- 日期：2026-09-29        适用库：tbccharacters（角色库）        类型：结构变更 / 幂等
-- -------------------------------------------------------------------------------------
-- 回滚内容：删除本次新增的两列"上次结算快照"
--     · tbccharacters.ahbot_market_state.last_settle_spent
--     · tbccharacters.ahbot_market_state.last_settle_earned
--   旧的 flow_bought / flow_sold（单位数）**不动**；spent / earned（累计观测列）**不动**。
--   ★ 旧的窗口累加列 flow_bought_gold / flow_sold_gold **不需要恢复**：那是被快照口径取代的
--     中间产物，恢复它没有意义（代码已不再读写这两列）。
--
-- 注意：**只回滚数据不够**。这两列是"金币流水定价"的载体，代码（AuctionHouseBot.cpp 的
-- SELECT/UPDATE/SETTLE 块）上线后一旦列被删除，LoadInventory() 的 SELECT 会直接报错 ⇒
-- 必须**同时 git revert 掉 AHBot 那次改造并重新编译部署**，再执行本文件。
-- 若只是临时回退，正确顺序是：换回旧二进制 → 再删列。
--
-- 幂等：用 information_schema 判断列是否存在后再 DROP（可重复执行）。
-- 验证：
--   SHOW COLUMNS FROM tbccharacters.ahbot_market_state LIKE '%settle%';
--   -- 期望只剩 last_settle_time
-- =====================================================================================

USE tbccharacters;

SET @has_last_settle_spent := (SELECT COUNT(*) FROM information_schema.COLUMNS
                                WHERE TABLE_SCHEMA = 'tbccharacters'
                                  AND TABLE_NAME = 'ahbot_market_state'
                                  AND COLUMN_NAME = 'last_settle_spent');
SET @sql_lss := IF(@has_last_settle_spent = 1,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` DROP COLUMN `last_settle_spent`',
                   'SELECT ''last_settle_spent 不存在，跳过'' AS note');
PREPARE st_lss FROM @sql_lss;
EXECUTE st_lss;
DEALLOCATE PREPARE st_lss;

SET @has_last_settle_earned := (SELECT COUNT(*) FROM information_schema.COLUMNS
                                 WHERE TABLE_SCHEMA = 'tbccharacters'
                                   AND TABLE_NAME = 'ahbot_market_state'
                                   AND COLUMN_NAME = 'last_settle_earned');
SET @sql_lse := IF(@has_last_settle_earned = 1,
                   'ALTER TABLE `tbccharacters`.`ahbot_market_state` DROP COLUMN `last_settle_earned`',
                   'SELECT ''last_settle_earned 不存在，跳过'' AS note');
PREPARE st_lse FROM @sql_lse;
EXECUTE st_lse;
DEALLOCATE PREPARE st_lse;

-- 核对：期望只剩 last_settle_time
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_DEFAULT
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'tbccharacters'
   AND TABLE_NAME = 'ahbot_market_state'
   AND COLUMN_NAME LIKE '%settle%'
 ORDER BY ORDINAL_POSITION;
