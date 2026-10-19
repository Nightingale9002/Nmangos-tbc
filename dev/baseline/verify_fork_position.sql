-- =============================================================================
-- verify_fork_position.sql —— 校验"我们的库停在上游哪一刻"
--
-- 只读：全是 SELECT，不写任何数据，可以随便重复跑。
--   用法（Windows）：cmd /c "mysql --host=127.0.0.1 --port=3306 --user=root -p tbcmangos < verify_fork_position.sql"
-- 判定标准见同目录 README.md 的"校验"一节。
-- =============================================================================

-- 1) 唯一可信的链：core 同步（required_sNNNN）。最后一条 = core 侧已经跟到的位置。
SELECT column_name AS core_sync_marker
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'db_version' AND column_name LIKE 'required\_%';

-- 2) 内容侧书签（不可信，只作参考）：最后一条 content_NNNN_*
SELECT column_name AS content_bookmark
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'db_version' AND column_name LIKE 'content\_%';

-- 3) 内容侧真实位置：三条上游更新的数据探针
SELECT '0001_ace_cards' AS probe,
       CASE WHEN COUNT(*) = 0 THEN 'APPLIED' ELSE 'MISSING' END AS verdict
  FROM gameobject_loot_template WHERE entry IN (21762, 21764) AND item = 49000;

SELECT '0021_c.23152' AS probe,
       CASE WHEN DamageMultiplier > 10 THEN 'APPLIED' ELSE 'MISSING' END AS verdict,
       DamageMultiplier AS `value`
  FROM creature_template WHERE entry = 23152;

SELECT '0044_kilrek' AS probe,
       CASE WHEN ExtraFlags & 0x200 THEN 'APPLIED' ELSE 'MISSING' END AS verdict,
       ExtraFlags AS `value`
  FROM creature_template WHERE entry = 17229;
