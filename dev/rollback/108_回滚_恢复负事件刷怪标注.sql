-- =============================================================
-- dev/rollback/108 回滚：dev/108 恢复负事件刷怪标注
-- 说明：本库修补前 `game_event_creature` 负数行 = 0 条，
--       故回滚即删除全部负数行；全静态、幂等。
-- 生效：需重启 mangosd
-- =============================================================

DELETE FROM `game_event_creature` WHERE `event` < 0;

-- 核对：SELECT COUNT(*) FROM game_event_creature WHERE event < 0;   -- 期望 0
