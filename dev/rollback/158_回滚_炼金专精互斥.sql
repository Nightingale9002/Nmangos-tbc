-- =====================================================================================
-- 158 回滚：把炼金三系专精任务的 RequiredCondition 恢复成 0（即恢复"专精不互斥"的原始数据）。
-- =====================================================================================

UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 0
 WHERE `entry` IN (10897, 10899, 10902, 10905, 10906, 10907)
   AND `RequiredCondition` = 261;

SELECT `entry`, `Title`, `RequiredCondition`, `ExclusiveGroup`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (10897, 10899, 10902, 10905, 10906, 10907)
 ORDER BY `entry`;
