-- =====================================================================
-- dev/rollback/143 回滚：任务 11010 职业门 + NPC 23253 Kronk 坐姿
-- =====================================================================

DELETE FROM `creature_addon` WHERE `guid` = 91790;

UPDATE `quest_template` SET `RequiredCondition` = 0 WHERE `entry` = 11010;

DELETE FROM `conditions` WHERE `condition_entry` = 5800002;
