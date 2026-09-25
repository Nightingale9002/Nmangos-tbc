-- dev/129：卡拉伯尔鬼骑士 21784 四个刷新点统一巡逻（复制 76084 的 156 点路径）—— 2026-09-26
-- ===============================================================
-- 站长："21784 的'有时候缺少路径'，应该是都在巡逻才对。目前只有一个巡逻 3个不动。"
--   修法（站长选定方案 a）：把 76084 的路径原样复制给 76082 / 76083 / 76085，
--   并把四个刷新点都设为 MovementType=2（WAYPOINT_MOTION_TYPE）。
--   （creature_movement 以 guid 为主键 ⇒ 各刷新点各持一份路径，互不影响、零共享风险。）
--
-- 幂等：
--   ① 复制用 INSERT ... ON DUPLICATE KEY UPDATE（重复应用只覆盖成同一份数据）；
--   ② MovementType 的 UPDATE 带 <> 守卫。
-- 执行对象：world 库（tbcmangos，表名不加库前缀，与 dev/117 等一致）
-- ⚠️ 路点在 mangosd 启动时加载 ⇒ 需重启（或对应 reload）后才生效；本文件仅改数据库。
-- ===============================================================

-- 1) 把 76084 的路径复制到另外三个刷新点（756 点 × 3）
INSERT INTO `creature_movement` (`Id`,`Point`,`PositionX`,`PositionY`,`PositionZ`,`Orientation`,`WaitTime`,`ScriptId`,`Comment`)
SELECT 76082, `Point`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `WaitTime`, `ScriptId`, `Comment`
  FROM `creature_movement` WHERE `Id` = 76084
ON DUPLICATE KEY UPDATE
  `PositionX` = VALUES(`PositionX`), `PositionY` = VALUES(`PositionY`), `PositionZ` = VALUES(`PositionZ`),
  `Orientation` = VALUES(`Orientation`), `WaitTime` = VALUES(`WaitTime`), `ScriptId` = VALUES(`ScriptId`), `Comment` = VALUES(`Comment`);

INSERT INTO `creature_movement` (`Id`,`Point`,`PositionX`,`PositionY`,`PositionZ`,`Orientation`,`WaitTime`,`ScriptId`,`Comment`)
SELECT 76083, `Point`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `WaitTime`, `ScriptId`, `Comment`
  FROM `creature_movement` WHERE `Id` = 76084
ON DUPLICATE KEY UPDATE
  `PositionX` = VALUES(`PositionX`), `PositionY` = VALUES(`PositionY`), `PositionZ` = VALUES(`PositionZ`),
  `Orientation` = VALUES(`Orientation`), `WaitTime` = VALUES(`WaitTime`), `ScriptId` = VALUES(`ScriptId`), `Comment` = VALUES(`Comment`);

INSERT INTO `creature_movement` (`Id`,`Point`,`PositionX`,`PositionY`,`PositionZ`,`Orientation`,`WaitTime`,`ScriptId`,`Comment`)
SELECT 76085, `Point`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `WaitTime`, `ScriptId`, `Comment`
  FROM `creature_movement` WHERE `Id` = 76084
ON DUPLICATE KEY UPDATE
  `PositionX` = VALUES(`PositionX`), `PositionY` = VALUES(`PositionY`), `PositionZ` = VALUES(`PositionZ`),
  `Orientation` = VALUES(`Orientation`), `WaitTime` = VALUES(`WaitTime`), `ScriptId` = VALUES(`ScriptId`), `Comment` = VALUES(`Comment`);

-- 2) 四个刷新点都改成巡逻
UPDATE `creature` SET `MovementType` = 2
WHERE `id` = 21784 AND `MovementType` <> 2;

-- 复核（应为 4 行、每行 156 点、MovementType 全为 2）：
-- SELECT c.guid, c.MovementType, COUNT(m.Point) AS points
--   FROM `creature` c LEFT JOIN `creature_movement` m ON m.Id = c.guid
--  WHERE c.id = 21784 GROUP BY c.guid, c.MovementType;
