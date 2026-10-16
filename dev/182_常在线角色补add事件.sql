-- 182_常在线角色补add事件.sql
-- ============================================================================
-- 为什么需要它（2026-10-17 实锤）：
--   `RandomPlayerbotMgr::GetBots()` 的候选池口径是
--       SELECT bot FROM ai_playerbot_random_bots WHERE owner=0 AND event='add'
--   ⇒ 只打了 `always=1` 标记、但**没有 `add` 事件**的角色**根本不在候选人名单里**，
--      任何登录排序 / 预留额度都不起作用 ⇒ 表现为"常在线名单上了 7/12、剩下几只永远离线"。
--   实测：云端 12 只 always=1 里有 5 只缺 add（214/215/216/218/219），补齐后立刻 12/12。
--
-- 本脚本做两件事（都幂等）：
--   ① 清掉 `event='add'` 的**重复行**（该表没有 (bot,event) 唯一键，只有 id 主键；
--      所以 `INSERT IGNORE` 不会去重，补数据时极易插出重复行 —— 重复行会让同一只 bot
--      在 availableBots 里出现多次，登录计数被虚增）。
--   ② 给每个 `always=1` 且**没有 add 行**的角色补一条 add。
--
-- 幂等性：重复执行结果不变（① 每 bot/event 只留最小 id；② 只补"没有 add 行"的）。
-- 用法：mysql --default-character-set=utf8mb4 tbccharacters < 本文件
-- ============================================================================

SET NAMES utf8mb4;

-- ① 清掉重复的 add 行（每个 bot 只保留 id 最小的那条）
DELETE dup FROM ai_playerbot_random_bots AS dup
JOIN ai_playerbot_random_bots AS keep
  ON dup.bot = keep.bot
 AND dup.event = keep.event
 AND dup.id > keep.id
WHERE dup.event = 'add';

-- ② 给缺 add 的常在线角色补一条
--    （用派生表包一层：MySQL 不允许对"正在被写入的表"做子查询）
INSERT INTO ai_playerbot_random_bots (`owner`, `bot`, `time`, `validIn`, `event`, `value`, `data`)
SELECT 0, missing.bot, UNIX_TIMESTAMP(), 1296000, 'add', 1, NULL
FROM (
    SELECT DISTINCT r.bot
    FROM ai_playerbot_random_bots r
    WHERE r.event = 'always'
      AND r.value = 1
      AND r.bot NOT IN (
            SELECT a.bot FROM (
                SELECT bot FROM ai_playerbot_random_bots WHERE event = 'add'
            ) AS a
      )
) AS missing;
