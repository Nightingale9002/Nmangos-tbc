-- dev/rollback/103 回滚：把 dev/103「工头/奴隶主死亡 → 奴隶脱战变友善」家族修复整体还原
-- 幂等：UPDATE 带新值判据；DELETE 不存在的行不报错
-- 用法：mysql ... < 本文件

-- ── A1 还原 17058 的接收动作（EVADE + SET_FACTION → 上游的 FLEE + 停表情）──
UPDATE `creature_ai_scripts`
SET `action1_type` = 25, `action1_param1` = 0, `action1_param2` = 0, `action1_param3` = 0,
    `action2_type` = 5,  `action2_param1` = 0,  `action2_param2` = 0, `action2_param3` = 0,
    `comment` = 'Dreghood Geomancer - Flee, Stop Emote, Set Phase 2 on Receive AI Event 6'
WHERE `id` = 1693701 AND `action1_type` = 24;

UPDATE `creature_ai_scripts`
SET `action1_type` = 25, `action1_param1` = 0, `action1_param2` = 0, `action1_param3` = 0,
    `action2_type` = 5,  `action2_param1` = 0,  `action2_param2` = 0, `action2_param3` = 0,
    `comment` = 'Dreghood Brute - Flee, Stop Emote, Set Phase 2 on Receive AI Event 6'
WHERE `id` = 1693802 AND `action1_type` = 24;

-- ── A2 还原 17058 死亡广播半径 40 → 15 ──
UPDATE `creature_ai_scripts`
SET `action2_param2` = 15,
    `comment` = 'Illidari Taskmaster - Cast Darkcrest Taskmaster Slain and Send AI Event 6 on Death'
WHERE `id` = 1705802 AND `action2_param2` = 40;

-- ── B 删除 17805/17799 新增的三行 ──
DELETE FROM `creature_ai_scripts` WHERE `id` = 1780511;
DELETE FROM `creature_ai_scripts` WHERE `id` = 1780512;
DELETE FROM `creature_ai_scripts` WHERE `id` = 1779907;
