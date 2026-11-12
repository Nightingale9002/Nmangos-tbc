-- ============================================================================
-- 198_策略表迁移到世界库.sql（2026-10-19 站长口径：bot 策略移到世界数据库）
--
-- 背景：ai_playerbot_boss_strategy / custom_strategy / priority_target /
--       decision_weight 原来在角色库 tbccharacters；引擎已改为读世界库 tbcmangos。
--       （ai_playerbot_priority_obs 仍是运行期观测数据，保留在角色库，不迁移。）
--
-- 幂等：CREATE TABLE IF NOT EXISTS + INSERT IGNORE；重复执行安全。
-- 注意：需要能跨库访问 tbccharacters（同一 MySQL 实例/账号）。
-- ============================================================================
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `tbcmangos`.`ai_playerbot_boss_strategy`
  LIKE `tbccharacters`.`ai_playerbot_boss_strategy`;
INSERT IGNORE INTO `tbcmangos`.`ai_playerbot_boss_strategy`
  SELECT * FROM `tbccharacters`.`ai_playerbot_boss_strategy`;

CREATE TABLE IF NOT EXISTS `tbcmangos`.`ai_playerbot_custom_strategy`
  LIKE `tbccharacters`.`ai_playerbot_custom_strategy`;
INSERT IGNORE INTO `tbcmangos`.`ai_playerbot_custom_strategy`
  SELECT * FROM `tbccharacters`.`ai_playerbot_custom_strategy`;

CREATE TABLE IF NOT EXISTS `tbcmangos`.`ai_playerbot_priority_target`
  LIKE `tbccharacters`.`ai_playerbot_priority_target`;
INSERT IGNORE INTO `tbcmangos`.`ai_playerbot_priority_target`
  SELECT * FROM `tbccharacters`.`ai_playerbot_priority_target`;

CREATE TABLE IF NOT EXISTS `tbcmangos`.`ai_playerbot_decision_weight`
  LIKE `tbccharacters`.`ai_playerbot_decision_weight`;
INSERT IGNORE INTO `tbcmangos`.`ai_playerbot_decision_weight`
  SELECT * FROM `tbccharacters`.`ai_playerbot_decision_weight`;

-- 复核（手工执行）：
--   SELECT COUNT(*) FROM tbcmangos.ai_playerbot_boss_strategy;
--   SELECT COUNT(*) FROM tbcmangos.ai_playerbot_custom_strategy;
--   SELECT COUNT(*) FROM tbcmangos.ai_playerbot_priority_target;
--   SELECT COUNT(*) FROM tbcmangos.ai_playerbot_decision_weight;
