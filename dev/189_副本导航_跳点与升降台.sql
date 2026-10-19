-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：副本导航_跳点与升降台
-- 来源（旧编号）：205_副本导航_跳点与升降台.sql、205_副本导航_跳点与升降台.sql（数据）
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- [2026-10-19] 路线"连接点"：跳点 / 升降台·传送点（navmesh 没有的缺口用）
--   由 DungeonRoute.h → TryRouteLink() 使用：
--     kind=0 到 src 附近后朝 dst 跳（MoveJump）
--     kind=1 到 src 附近等 3 秒后传到 dst（脚本化"坐电梯"）
--   数据由人工/生成器填：src = 起跳/等电梯位置，dst = 落点/对岸位置。
-- ============================================================================
USE `tbcmangos`;
CREATE TABLE IF NOT EXISTS `ai_playerbot_route_link` (
  `map` smallint unsigned NOT NULL,
  `src_x` float NOT NULL,
  `src_y` float NOT NULL,
  `src_z` float NOT NULL,
  `dst_x` float NOT NULL,
  `dst_y` float NOT NULL,
  `dst_z` float NOT NULL,
  `kind` tinyint unsigned NOT NULL DEFAULT 0 COMMENT '0=跳点 1=升降台/传送点',
  `note` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`src_x`,`src_y`,`src_z`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================================

-- 电梯/升降台连接点（dev/tools/gen_lift_links.py 由 gameobject+TransportAnimation.dbc 生成）
USE `tbcmangos`;
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-1286.24,189.72,68.84,-1286.24,189.72,130.08,1,'lift entry=4170 guid=18298 dz=61');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-1308.38,185.29,68.59,-1308.38,185.29,130.08,1,'lift entry=4171 guid=18435 dz=61');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-5399.19,-2504.62,-40.28,-5399.19,-2504.62,89.02,1,'lift entry=11898 guid=16875 dz=129');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-4665.43,-1827.67,-43.89,-4665.43,-1827.67,85.41,1,'lift entry=11898 guid=16874 dz=129');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (209,2600.81,1228.72,-40.28,2600.81,1228.72,89.02,1,'lift entry=11898 guid=2090002 dz=129');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (47,1734.57,1372.32,-43.89,1734.57,1372.32,85.41,1,'lift entry=11898 guid=4700001 dz=129');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-5382.50,-2489.42,-40.53,-5382.50,-2489.42,89.03,1,'lift entry=11899 guid=16877 dz=130');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-4670.77,-1849.61,-44.14,-4670.77,-1849.61,85.41,1,'lift entry=11899 guid=16876 dz=130');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (209,2617.51,1243.92,-40.53,2617.51,1243.92,89.03,1,'lift entry=11899 guid=2090003 dz=130');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (47,1729.23,1350.39,-44.14,1729.23,1350.39,85.41,1,'lift entry=11899 guid=4700002 dz=130');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1596.15,291.80,-40.78,1596.15,291.80,55.72,1,'lift entry=20649 guid=44892 dz=97');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1596.04,282.74,55.40,1596.04,282.74,60.05,1,'lift entry=20650 guid=44976 dz=5');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1596.21,302.40,-40.66,1596.21,302.40,-32.53,1,'lift entry=20651 guid=44893 dz=8');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1595.26,188.64,-40.78,1595.26,188.64,55.72,1,'lift entry=20652 guid=44962 dz=97');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1595.38,197.71,55.40,1595.38,197.71,60.05,1,'lift entry=20653 guid=44891 dz=5');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1595.21,178.69,-40.52,1595.21,178.69,-32.39,1,'lift entry=20654 guid=44954 dz=8');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1544.24,240.77,-40.78,1544.24,240.77,55.72,1,'lift entry=20655 guid=44901 dz=97');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1553.30,240.66,55.40,1553.30,240.66,60.05,1,'lift entry=20656 guid=44890 dz=5');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,1533.88,240.83,-40.48,1533.88,240.83,-32.35,1,'lift entry=20657 guid=44909 dz=8');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-1028.04,-28.36,69.02,-1028.04,-28.36,140.50,1,'lift entry=47296 guid=20639 dz=71');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-1037.27,-49.24,69.27,-1037.27,-49.24,140.49,1,'lift entry=47297 guid=20640 dz=71');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,-5164.47,648.44,350.02,-5164.47,648.44,362.10,1,'lift entry=80022 guid=9411 dz=12');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,-5164.24,650.35,249.43,-5164.24,650.35,349.52,1,'lift entry=80023 guid=9450 dz=100');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (90,-806.89,323.96,-316.20,-806.89,323.96,-271.66,1,'lift entry=85556 guid=900012 dz=45');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,-3297.07,1898.14,106.55,-3297.07,1898.14,168.03,1,'lift entry=149045 guid=16760 dz=61');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (469,-6904.81,-1206.78,178.42,-6904.81,-1206.78,239.90,1,'lift entry=149045 guid=4690001 dz=61');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,-6904.81,-1206.78,178.42,-6904.81,-1206.78,239.90,1,'lift entry=149045 guid=6945 dz=61');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,-3207.32,1995.78,140.18,-3207.32,1995.78,167.78,1,'lift entry=149046 guid=16761 dz=28');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (469,-6900.42,-1339.33,212.05,-6900.42,-1339.33,239.65,1,'lift entry=149046 guid=4690002 dz=28');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,-6900.42,-1339.33,212.05,-6900.42,-1339.33,239.65,1,'lift entry=149046 guid=6946 dz=28');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (0,-5067.02,438.45,410.93,-5067.46,438.98,423.76,1,'lift entry=152614 guid=9290 dz=13');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,1916.50,5515.03,267.58,1916.06,5515.57,280.41,1,'lift entry=152614 guid=16871 dz=13');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,2264.14,-5566.10,21.11,2263.70,-5565.56,33.94,1,'lift entry=152614 guid=48263 dz=13');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (1,-11342.59,-4760.16,6.49,-11341.90,-4760.26,19.32,1,'lift entry=152614 guid=93886 dz=13');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,4.58,-1037.08,-114.95,4.58,-2454.07,7.20,1,'lift entry=176080 guid=18802 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,4.53,-1076.63,-114.95,4.53,-2473.86,7.20,1,'lift entry=176081 guid=18803 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,-45.40,3577.49,-114.98,-45.40,4975.79,7.18,1,'lift entry=176082 guid=18804 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,-45.40,3616.62,-114.98,-45.40,2512.15,6.99,1,'lift entry=176083 guid=18805 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,-45.39,3538.22,-114.98,-45.39,4956.25,7.18,1,'lift entry=176084 guid=18806 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (369,4.50,-1116.20,-114.95,4.50,-11.35,7.01,1,'lift entry=176085 guid=18807 dz=122');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,-1810.27,5590.54,2.91,-1810.27,5590.54,129.97,1,'lift entry=183169 guid=24055 dz=127');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,285.75,5918.21,26.14,268.49,5919.77,149.39,1,'lift entry=183177 guid=20505 dz=123');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,-2000.07,5678.34,66.15,-2000.07,5678.34,116.88,1,'lift entry=183202 guid=24074 dz=51');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,-2021.46,5482.74,3.00,-2021.46,5482.74,53.73,1,'lift entry=183203 guid=24075 dz=51');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (554,0.00,0.00,0.00,0.00,0.00,25.44,1,'lift entry=183788 guid=5540001 dz=25');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (530,4208.69,3111.24,183.82,4208.69,3111.24,335.30,1,'lift entry=184330 guid=25138 dz=151');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (548,-59.13,-98.80,-52.93,-59.13,-98.80,7.21,1,'lift entry=183490 guid=5480002 dz=60');
INSERT IGNORE INTO ai_playerbot_route_link (`map`,`src_x`,`src_y`,`src_z`,`dst_x`,`dst_y`,`dst_z`,`kind`,`note`) VALUES (548,50.00,-0.01,-72.06,50.00,-0.01,820.35,1,'lift entry=183407 guid=5480001 dz=892');
