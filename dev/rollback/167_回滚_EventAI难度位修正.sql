-- =====================================================================================
-- 167_回滚_EventAI难度位修正.sql
-- 回滚 dev/167_EventAI难度位修正_第二批.sql
-- 日期：2026-10-07        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 恢复改动前的原值（= 上游 tbcmangos_orig 原样）：
--   1089903 flags 1025 → 1205、param 5000/7000/4000/6000 → 5000/8000/6000/10000
--   1089901 param → 5000/8000/10000/10000
--   333802  flags 1025 → 1029
--   1773403 flags 1030 → 1027、comment 复原
--   1797606 flags 1030 → 1026、comment 复原
--   1740001 flags 1031 → 1027、comment 复原
-- 【生效】creature_ai_scripts 启动时载入 ⇒ 需重启。
-- =====================================================================================

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1205, `event_param1` = 5000, `event_param2` = 8000,
       `event_param3` = 6000, `event_param4` = 10000
 WHERE `id` = 1089903 AND `creature_id` = 10899 AND `event_flags` = 1025;

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_param1` = 5000, `event_param2` = 8000, `event_param3` = 10000, `event_param4` = 10000
 WHERE `id` = 1089901 AND `creature_id` = 10899 AND `event_param1` = 10000;

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1029
 WHERE `id` = 333802 AND `creature_id` = 3338 AND `event_flags` = 1025;

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1027, `comment` = 'Underbog Lord (Normal) - Cast Enrage at 30% HP'
 WHERE `id` = 1773403 AND `creature_id` = 17734 AND `event_flags` = 1030;

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1026, `comment` = 'Commander Sarannis (Normal) - Cast Summon Reinforcement and start relay script at 55% HP'
 WHERE `id` = 1797606 AND `creature_id` = 17976 AND `event_flags` = 1030;

UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1027, `comment` = 'Felguard Annihilator (Normal) - Reset Threat'
 WHERE `id` = 1740001 AND `creature_id` = 17400 AND `event_flags` = 1031;

-- ---------- 核对 ----------
SELECT `id`, `creature_id`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts`
 WHERE `id` IN (1089901, 1089903, 333802, 1773403, 1797606, 1740001)
 ORDER BY `id`;
