-- dev/rollback/114 回滚：保镖不再跟随埃博尔变友善
-- ===============================================================
-- 撤销 `dev/114_埃博尔保镖随主人变友善.sql`：
--   1) 删掉新增的保镖脚本行 1848303；
--   2) 把 1848205 的第 3 个动作槽还原成空（0,0,0）并还原注释。
-- 幂等：带 `AND action3_type = 45` 条件。
-- 生效：creature_ai_scripts 启动载入 ⇒ 需重启。
-- ===============================================================

DELETE FROM `creature_ai_scripts` WHERE `id` = 1848303;

UPDATE `creature_ai_scripts`
SET `action3_type` = 0, `action3_param1` = 0, `action3_param2` = 0, `action3_param3` = 0,
    `comment` = 'Empoor - Delayed Despawn and Set Invincible on Evade'
WHERE `id` = 1848205 AND `action3_type` = 45;
