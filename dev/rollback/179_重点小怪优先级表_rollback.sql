-- 回滚件：179_重点小怪优先级表.sql
-- 表本身是"派生数据"（可从攻略重新生成），回滚 = 整表删除。
-- 用法：mysql ... tbccharacters < 本文件
-- （按项目约定：未验收期间才保留本文件；站长验收通过后请删掉它）
DROP TABLE IF EXISTS `ai_playerbot_priority_target`;
