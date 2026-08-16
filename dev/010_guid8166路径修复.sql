-- ============================================================
-- guid 8166 路径修复（按 classicmangos_ref 参考）
-- 该怪是 creature_spawn_entry 池：440 Blackrock Grunt / 485 Blackrock Outrunner
-- id=0 + creature_spawn_entry(440,485) 保持不动，只修复 spawn 坐标与 waypoint
-- 正确数据：spawn -9785.2,-3218.1,58.7338；MovementType=2；2 个路径点
-- ============================================================
UPDATE `creature` SET `position_x` = -9785.2, `position_y` = -3218.1, `position_z` = 58.7338, `MovementType` = 2 WHERE `guid` = 8166;

DELETE FROM `creature_movement` WHERE `Id` = 8166;
INSERT INTO `creature_movement` (`Id`, `Point`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `WaitTime`, `ScriptId`) VALUES
(8166, 1, -9811.17, -3249.51, 59.4716, 3.35103, 30000, 0),
(8166, 2, -9785.2, -3218.1, 58.7338, 0.639646, 30000, 0);

