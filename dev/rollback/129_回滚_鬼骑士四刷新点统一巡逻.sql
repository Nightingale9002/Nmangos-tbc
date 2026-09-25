-- =====================================================================
-- 回滚 dev/129_卡拉伯尔鬼骑士四个刷新点统一巡逻.sql
--
-- 还原内容：
--   ① 删除复制给 76082 / 76083 / 76085 的路点（只删这三个 guid 的整份路径）；
--   ② 把这三个刷新点的 MovementType 改回 0（站桩，dev/129 之前的值）；
--   ③ 76084 保持 MovementType=2 与它原有的 156 点路径（dev/129 完全没动它）。
--
-- 执行对象：world 库（tbcmangos）
-- 幂等：是（DELETE 不存在的行无副作用；UPDATE 带 <> 守卫）
-- =====================================================================

DELETE FROM `creature_movement` WHERE `Id` IN (76082, 76083, 76085);

UPDATE `creature` SET `MovementType` = 0
WHERE `guid` IN (76082, 76083, 76085) AND `MovementType` <> 0;

-- 复核（应为 76084 有 156 点、MovementType=2；另三个 0 点、MovementType=0）：
-- SELECT c.guid, c.MovementType, COUNT(m.Point) AS points
--   FROM `creature` c LEFT JOIN `creature_movement` m ON m.Id = c.guid
--  WHERE c.id = 21784 GROUP BY c.guid, c.MovementType;
