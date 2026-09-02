-- =====================================================
-- 出生点/路径错位修复合集（整合原 057/058/059）
-- 2026-09-02。覆盖 5 类：
--   ① 永歌 Eversong Tender guid55482（整删）
--   ② 冬泉错钉 Simone/Bear/Archaeologist/Thug/Saltspittle（058）
--   ③ Kolkar guid375 路径孤悬（008风格改随机）
--   ④ Bash'ir Arcanist guid77971 路径孤点（删 point8）
--   ⑤ Mana Snapper guid5306118 出生点错钉（挪 p2）
-- 判定口径：waypoint/出生点错位、路径孤点、出生点被钉到别区。
-- 逐只备份见 _agent_tmp/bk_{guid}_*.sql，可回滚。
-- =====================================================

-- ############ ① 删除出生点错误的 Eversong Tender guid55482（原057） ############
-- 出生锚点 8472,-7927(Z157)，37点路径全在1300码外 8900,-6814(Z12~34)；waypoint 途经艾伦达尔
-- 瀑布断崖被压入地下(Z119 vs floor138)。整删该生物+专属路径。关联表均无引用。
START TRANSACTION;
DELETE FROM `creature`          WHERE `guid` = 55482;
DELETE FROM `creature_movement` WHERE `id`   = 55482;
COMMIT;

-- ############ ② 清理被钉到冬泉 Artorius wp1 的错钉生物（原058） ############
-- Simone/Bear/Thug/Saltspittle 出生点被统一写至冬泉(7815.9,-4443.4,667.4)，该坐标实为
-- Artorius(42301) 巡逻起点(保留)。
START TRANSACTION;
-- Simone the Inconspicuous: 冬泉 -> 安戈洛 her wp1 (任务7636脚本怪,带宠物,路径在安戈洛地表Z~-270)
UPDATE `creature` SET position_x=-7624.853, position_y=-907.312, position_z=-268.210 WHERE guid=24439;
-- Ashenvale Bear: 冬泉 -> 灰谷 wp1
UPDATE `creature` SET position_x=2247.421,  position_y=-910.603, position_z=89.710 WHERE guid=156119;
-- Enslaved Archaeologist: 修正Y镜像, 出生点 -> wp1
UPDATE `creature` SET position_x=-6459.147, position_y=-1255.761, position_z=180.679 WHERE guid=5807;
-- Forsaken Thug / Saltspittle: 无路径且无从定位, 删除
DELETE FROM `creature` WHERE guid IN (156135,156139);
COMMIT;

-- ############ ③ Kolkar Stormer guid375, map1 ############
-- 17点路径孤悬贫瘠之地中部(-50..54,-1714..-1817)；出生点(-1450.98,-3014.94) 有同类57只，
-- 本体位置正常，路径被误画。008风格：删路径改随机(主流同类 MT1/spawndist5)。
START TRANSACTION;
DELETE FROM creature_movement WHERE Id = 375;
UPDATE creature SET MovementType = 1, spawndist = 5 WHERE guid = 375;
COMMIT;

-- ############ ④ Bash'ir Arcanist guid77971, map530 Bash'ir Landing ############
-- 出生点(3724,5983) 正确；29点路径中 point8=(717,6034) 孤悬3000码外(前后3719,6027/3718,6044)。删孤点。
START TRANSACTION;
DELETE FROM creature_movement WHERE Id = 77971 AND Point = 8;
COMMIT;

-- ############ ⑤ Mana Snapper guid5306118, map530 虚空风暴 ############
-- 出生点错钉(3644.69,3899.27) 到 Phase Hunter 飞行区；正确位置为路径点 p2(3519.63,4087.28)。
-- InhabitType=3 地面生物不应走穿虚空路径。删2点路径，出生点挪p2，MT1/spawndist5。
START TRANSACTION;
DELETE FROM creature_movement WHERE Id = 5306118;
UPDATE creature SET position_x=3519.63, position_y=4087.28, position_z=117.84,
       MovementType=1, spawndist=5 WHERE guid = 5306118;
COMMIT;

-- =====================================================
-- 校验（全部）
-- =====================================================
SELECT '55482_creature' chk, COUNT(*) n FROM creature WHERE guid=55482
UNION ALL SELECT '55482_mv', COUNT(*) FROM creature_movement WHERE Id=55482
UNION ALL SELECT 'simone', COUNT(*) FROM creature WHERE guid=24439
UNION ALL SELECT 'bear', COUNT(*) FROM creature WHERE guid=156119
UNION ALL SELECT 'archaeo', COUNT(*) FROM creature WHERE guid=5807
UNION ALL SELECT 'thug_salt', COUNT(*) FROM creature WHERE guid IN (156135,156139)
UNION ALL SELECT 'kolkar_mv', COUNT(*) FROM creature_movement WHERE Id=375
UNION ALL SELECT 'bashir_p8', COUNT(*) FROM creature_movement WHERE Id=77971 AND Point=8
UNION ALL SELECT 'manasnap_mv', COUNT(*) FROM creature_movement WHERE Id=5306118;
