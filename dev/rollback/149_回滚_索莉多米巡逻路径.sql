-- 回滚 dev/149：删掉索莉多米（guid 23453）的巡逻路径，movementType 退回 IDLE(0)
-- 回滚前状态：creature_movement 0 行、creature.MovementType = 0（四个参考库一致）

DELETE FROM `creature_movement` WHERE `Id` = 23453;
UPDATE `creature` SET `MovementType` = 0 WHERE `guid` = 23453;
