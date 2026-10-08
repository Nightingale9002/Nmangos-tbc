-- =====================================================================================
-- 166_回滚_泥沼巨人激怒对齐.sql
-- 回滚 dev/166_幽暗沼泽泥沼巨人_激怒事件按官方清单对齐.sql
-- 日期：2026-10-07        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 把 1772301 恢复成改动前的原值（= 上游 tbcmangos_orig 的原样）：
--   event_flags   1030 → 1027（0x403 = REPEATABLE | NORMAL | COMBAT_ACTION，仅普通难度）
--   action1_param3  32 → 0（不打断当前施法）
-- 【生效】creature_ai_scripts 启动时载入 ⇒ 需重启。
-- =====================================================================================

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1027,
       `action1_param3` = 0,
       `comment` = 'Bog Giant (Normal) - Cast Enrage at 30% HP'
 WHERE `id` = 1772301
   AND `creature_id` = 17723
   AND `event_flags` IN (1027, 1030)
   AND `action1_param3` IN (0, 32);

-- ---------- 核对 ----------
-- 期望：event_flags=1027、action1_param3=0
SELECT `id`, `creature_id`, `event_type`, `event_flags`, `event_param1`, `event_param2`,
       `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`, `action2_param1`
  FROM `tbcmangos`.`creature_ai_scripts`
 WHERE `creature_id` = 17723
 ORDER BY `id`;
