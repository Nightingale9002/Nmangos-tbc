-- dev/rollback/105 回滚：把两处相位死行还原成上游原样
-- 幂等：分别带 `AND action1_param3 = 3` / `AND event_inverse_phase_mask = 2`
-- 用法：mysql ... < 本文件

UPDATE `creature_ai_scripts`
SET `action1_param3` = 1
WHERE `id` = 1922801 AND `action1_param3` = 3;

UPDATE `creature_ai_scripts`
SET `event_inverse_phase_mask` = 3
WHERE `id` = 1887502 AND `event_inverse_phase_mask` = 2;
