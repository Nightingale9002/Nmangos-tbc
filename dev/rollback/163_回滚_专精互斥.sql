-- =====================================================================================
-- 163_回滚_专精互斥.sql
-- 回滚 dev/163_专精互斥_四组任务挂RequiredCondition.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 只回滚本次真正改动的东西：
--   1) 16 个任务的 RequiredCondition 复位为 0（仅当它仍是本次写入的值时才动）；
--   2) 删除本次新建的 6 条制皮条件（903001~903006）。
-- 复用的条件（936 / 11001 / 20490 / 261）是库里原有数据，一律不删。
-- 【生效】conditions / quest_template 启动时载入 ⇒ 需重启。
-- =====================================================================================

-- ---------- A. 任务侧复位 ----------
UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 0
 WHERE `entry` IN (5141, 5143, 5144, 5145, 5146, 5148)
   AND `RequiredCondition` = 903006;

UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 0
 WHERE `entry` IN (10831, 10832, 10833)
   AND `RequiredCondition` = 936;

UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 0
 WHERE `entry` IN (3639, 3641, 3643)
   AND `RequiredCondition` = 11001;

UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 0
 WHERE `entry` IN (5283, 5284, 5301, 5302)
   AND `RequiredCondition` = 20490;

-- ---------- B. 删除本次新建的制皮条件 ----------
DELETE FROM `tbcmangos`.`conditions` WHERE `condition_entry` IN (903001, 903002, 903003, 903004, 903005, 903006);

-- ---------- 核对 ----------
-- 期望：16 行 RequiredCondition 全为 0
SELECT `entry`, `Title`, `RequiredCondition`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (5141, 5143, 5144, 5145, 5146, 5148, 10831, 10832, 10833, 3639, 3641, 3643, 5283, 5284, 5301, 5302)
 ORDER BY `entry`;

-- 期望：0 行
SELECT `condition_entry`, `type`, `value1`, `comments`
  FROM `tbcmangos`.`conditions`
 WHERE `condition_entry` BETWEEN 903001 AND 903006;
