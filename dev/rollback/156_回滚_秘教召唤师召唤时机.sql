-- =====================================================================================
-- 156 回滚：把「秘教召唤师」(18634) 的两个召唤事件还原成 145 的版本
--   —— event_type=4（EVENT_T_AGGRO，一进战斗就各 50% 掷骰召唤一次），其余不变。
-- 用法：mysql ... tbcmangos < 本文件，然后重启（或 .reload creature_ai_scripts）。
-- =====================================================================================

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` IN (1863410, 1863411);
INSERT INTO `tbcmangos`.`creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1863410, 18634, 4, 0, 50, 0, 0, 0, 0, 0, 0, 0, 11, 33507, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - On Aggro - 50% Summon Cabal Acolyte'),
(1863411, 18634, 4, 0, 50, 0, 0, 0, 0, 0, 0, 0, 11, 33506, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - On Aggro - 50% Summon Cabal Deathsworn');

SELECT `id`, `creature_id`, `event_type`, `event_chance`, `event_flags`,
       `event_param1`, `event_param2`, `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 18634 ORDER BY `id`;
