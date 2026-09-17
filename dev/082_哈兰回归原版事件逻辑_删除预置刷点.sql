-- ============================================================================
-- 082_哈兰回归原版事件逻辑_删除预置刷点.sql（2026-09-18）
--
-- 背景（站长反馈）："重启后哈兰直接归部落了"+"NPC 刷新位置不对"+"哈兰应该按原来的事件逻辑来"
--
-- 根因（两条，都是我们自己造成的）：
--   ① 代码侧：fork 的三个 commit（d540af8b7 / 136f51d10 / a507553c5）把哈兰改成了
--      "初始归属=部落 + 双方 NPC 常驻 DB 刷点 + 易主时 despawn 输方" 的自制逻辑
--      （`m_zoneOwner(HORDE)`），于是**每次重启哈兰都回到部落手里**。
--   ② 数据侧：`dev/076_补哈兰NPC刷点.sql` 按"初版估值坐标"插了 40 行常驻刷点
--      （guid 9000001-9000040：10 商人 + 15 组双方卫兵），位置是绕哈兰旗帜画的圈，**并非原版位置**。
--
-- 原版逻辑（本次恢复的目标）：
--   · 哈兰初始**中立**（`m_zoneOwner = TEAM_NONE`），镇里没有常驻 NPC；
--   · 某方占领时，代码把事件交回 DB 脚本（`OutdoorPvPNA::HandleEvent` 对占领事件返回 false），
--     由 **`dbscripts_on_event` 11503（部落）/ 11504（联盟）** 在**原版真实坐标**上召唤
--     该阵营的 5 个商人 + 15 个卫兵（我们库里这两个脚本本来就有，各 20 行，未被改动）；
--   · 卫兵死亡后按原版逻辑在 5 分钟/1 小时（围城）后于原地召唤补充。
--   → 所以**不需要**任何"预置刷点"，076 那 40 行必须删掉，否则镇里会同时出现
--     "估值位置的常驻 NPC" 和 "事件召唤的正确位置 NPC" 两套。
--
-- 本文件做什么：删除 076 插入的那 40 行（guid 9000001-9000040），并做防御性清理。
--   幂等：先 DELETE 再校验，重复执行影响 0 行。
--   生效：`creature` 表在 mangosd 启动时载入 → 需重启（随下次 nightly）。
--
-- 保留说明：`dev/076_补哈兰NPC刷点.sql` 文件保留在仓库里（它已被应用、marker 不会回退），
--   但**不要**在新库上再执行它 —— 它已被本文件取代。
-- ============================================================================

USE tbcmangos;

-- ---------------------------------------------------------------------------
-- 1) 删除 076 预置的 40 行常驻刷点
-- ---------------------------------------------------------------------------
DELETE FROM creature WHERE guid BETWEEN 9000001 AND 9000040;

-- ---------------------------------------------------------------------------
-- 2) 防御性清理：这几个 guid 若出现在关联表里一并清掉（正常应为 0 行）
--    注意：只动我们插入的 guid 段，绝不碰 creature_movement_template 等按 entry 索引的表
-- ---------------------------------------------------------------------------
DELETE FROM creature_addon             WHERE guid BETWEEN 9000001 AND 9000040;
DELETE FROM creature_movement          WHERE id   BETWEEN 9000001 AND 9000040;
DELETE FROM creature_conditional_spawn WHERE guid BETWEEN 9000001 AND 9000040;
DELETE FROM spawn_group_spawn          WHERE guid BETWEEN 9000001 AND 9000040;
DELETE FROM game_event_creature        WHERE guid BETWEEN 9000001 AND 9000040;

-- ---------------------------------------------------------------------------
-- 3) 校验：应全部为 0
-- ---------------------------------------------------------------------------
SELECT 'leftover 076 spawns' AS check_name, COUNT(*) AS should_be_zero
  FROM creature WHERE guid BETWEEN 9000001 AND 9000040;

SELECT 'halaa npcs left in town' AS check_name, COUNT(*) AS should_be_zero
  FROM creature c
 WHERE c.map = 530
   AND c.position_x BETWEEN -1700 AND -1400
   AND c.position_y BETWEEN 7850 AND 8050
   AND c.id IN (18192,18256,18816,18817,18821,18822,21474,21483,21484,21485,21487,21488);

-- 4) 确认原版事件脚本仍在（各应有 20 行）
SELECT id AS event_script, COUNT(*) AS rows_cnt
  FROM dbscripts_on_event
 WHERE id IN (11503,11504)
 GROUP BY id ORDER BY id;
