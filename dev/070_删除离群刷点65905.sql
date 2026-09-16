-- 删除离群刷点 guid 65905（Shienor Wing Guard 18451）— 2026-09-16
--
-- 背景（站长判定：冗余刷点，删除）：
--   同模板 creature 18451 共 12 个刷点，其中 11 个在 Veil Shienor 主营地一带
--   （x -1600~-1900 / y 3869~4438 / **z 45~53**），唯独本条跑到了下营地西南 60~90 码外的谷地：
--   x -1957.77001953125000000000, y 3759.42993164062500000000, z -7.92699003219604500000（站桩：spawndist=0, movementtype=0）。
--   参考：同区域确有下营地（20×18449 Talonite + 7×18450 Sorcerer，z ≈ -4.8~13.8），
--   但 65905 是唯一下到谷地的 Wing Guard，位置离群且不参与任何事件/池/路径。
--
--   上游核对：`_tbc-db_ref/Full_DB/FullDB.sql` 与 `Nmangos-tbc-db` 备份中坐标与本库**完全一致**
--   → 属上游 tbc-db 继承数据，非本 fork 改动。
--
-- 关联表核对（执行前已确认均为 0 行）：creature_movement / creature_addon / game_event_creature / pool_creature；
--   下面仍做防御性清理，保证不同库状态下都干净。
-- 幂等，可重复执行

DELETE FROM tbcmangos.creature          WHERE `guid` = 65905;
DELETE FROM tbcmangos.creature_movement WHERE `id`   = 65905;
DELETE FROM tbcmangos.creature_addon    WHERE `guid` = 65905;
