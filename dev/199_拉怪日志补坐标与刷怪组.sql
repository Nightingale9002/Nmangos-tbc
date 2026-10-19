-- ============================================================================
-- 199_拉怪日志补坐标与刷怪组.sql（2026-10-19 站长口径）
--
-- 目的：拉怪日志除 target_guid（运行时 GUID，可能每次不同）外，再记录
--       目标坐标 + spawn_group.Id，供事后静态分析“自动开怪顺序”。
--       （本次只记录数据，不做自动写回；数据足够后再离线分析。）
--
-- 幂等：用 information_schema 判断列是否存在，重复执行安全。
-- ============================================================================
SET NAMES utf8mb4;
USE `tbcmangos`;

SET @sql = IF(
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log'
     AND column_name = 'target_x') = 0,
  'ALTER TABLE `ai_playerbot_pull_log`
     ADD COLUMN `target_x` FLOAT NOT NULL DEFAULT 0,
     ADD COLUMN `target_y` FLOAT NOT NULL DEFAULT 0,
     ADD COLUMN `target_z` FLOAT NOT NULL DEFAULT 0,
     ADD COLUMN `spawn_group_id` INT UNSIGNED NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 复核：
--   SHOW COLUMNS FROM tbcmangos.ai_playerbot_pull_log LIKE 'target_%';
--   SHOW COLUMNS FROM tbcmangos.ai_playerbot_pull_log LIKE 'spawn_group_id';
