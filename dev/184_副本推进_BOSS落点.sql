-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：副本推进_BOSS落点
-- 来源（旧编号）：190_副本推进_boss落点.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- =====================================================================
-- 卡布魔兽 副本推进：每图 boss 落点（静态 boss + 触发/召唤 boss）
-- 目标库：世界库（tbcmangos）；表结构见 183_副本推进路线与巡逻表.sql
-- 生成：dev/tools/boss_point_gen.py（离线，勿手改）
-- 幂等：每图先 DELETE（按 map）再 INSERT，可重复执行。
-- 口径：① creature_loot_template 的 (Boss Loot) 引用
--       ② creature_template.ScriptName LIKE boss_% 
--       ③ creature_template.Rank = 3
--       静态 boss 取"离入口最近的刷点"；触发/召唤 boss 用脚本常量坐标（MANUAL）。
-- ord 一律 0：由 route_v2.py 的推进路线做完再回填。
-- =====================================================================

-- boss_point_gen map 30
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 30;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (30,11946,-1370.883,-220.208,98.510,0,'rank3'),(30,11947,-545.230,-165.350,57.014,0,'rank3'),(30,11948,722.430,-10.998,50.705,0,'rank3');
-- boss_point_gen map 33
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 33;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (33,4275,-76.754,2152.410,155.792,0,'script');
-- boss_point_gen map 34
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 34;
-- boss_point_gen map 36
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 36;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (36,646,-22.847,-797.283,20.374,0,'script');
-- boss_point_gen map 43
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 43;
-- boss_point_gen map 47
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 47;
-- boss_point_gen map 48
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 48;
-- boss_point_gen map 70
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 70;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (70,2748,104.338,272.310,-51.696,0,'script');
-- boss_point_gen map 90
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 90;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (90,7800,-531.324,670.159,-325.185,0,'script');
-- boss_point_gen map 109
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 109;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (109,5708,-467.617,-2.193,-148.802,0,'loot'),(109,5719,-646.480,122.121,-90.829,0,'loot'),(109,5722,-649.679,131.596,-90.829,0,'loot');
-- boss_point_gen map 129
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 129;
-- boss_point_gen map 189
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 189;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (189,3975,1965.090,-431.607,6.261,0,'script'),(189,3976,1153.870,1398.390,32.611,0,'script'),(189,3977,1202.130,1399.070,29.093,0,'script'),(189,6487,148.320,-428.692,18.486,0,'loot+script');
-- boss_point_gen map 209
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 209;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (209,7271,1912.173,1016.110,11.599,0,'script');
-- boss_point_gen map 229
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 229;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (229,9568,-22.633,-486.186,90.753,0,'script'),(229,9816,144.590,-258.050,96.500,0,'script+rank3'),(229,10363,36.451,-285.994,111.036,0,'rank3'),(229,10430,87.380,-554.120,111.100,0,'rank3');
-- boss_point_gen map 230
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 230;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (230,8929,1384.640,-831.486,-87.589,0,'script'),(230,9018,310.558,-146.251,-70.303,0,'script'),(230,9019,1380.180,-831.645,-87.590,0,'script'),(230,9033,652.390,21.374,-59.976,0,'script'),(230,9039,1281.140,-282.151,-78.136,0,'script'),(230,9156,1009.754,-239.017,-61.304,0,'script'),(230,9499,888.472,-177.929,-42.962,0,'script'),(230,23872,891.839,-129.183,-49.660,0,'script');
-- boss_point_gen map 249
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 249;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (249,10184,-4.869,-217.171,-86.710,0,'loot+script+rank3');
-- boss_point_gen map 269
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 269;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (269,15608,-2025.300,7119.580,22.747,0,'rank3');
-- boss_point_gen map 289
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 289;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (289,10502,265.956,0.903,75.333,0,'loot'),(289,10503,268.223,73.633,95.924,0,'script'),(289,10504,178.724,-91.023,70.857,0,'loot'),(289,10505,86.663,-1.960,85.312,0,'loot'),(289,10507,103.305,-1.678,75.218,0,'loot'),(289,10508,-25.108,141.284,83.908,0,'loot'),(289,10901,274.877,1.334,85.312,0,'loot'),(289,11261,182.246,-95.437,85.312,0,'loot');
-- boss_point_gen map 309
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 309;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (309,11380,-11515.800,-1275.480,79.662,0,'loot+rank3'),(309,11382,-12167.800,-1927.250,153.730,0,'loot+script+rank3'),(309,14507,-12029.800,-1707.930,39.413,0,'loot+script+rank3'),(309,14509,-11700.800,-1998.940,62.416,0,'loot+script+rank3'),(309,14510,-12326.500,-1577.110,133.588,0,'loot+script+rank3'),(309,14517,-12291.900,-1380.080,144.902,0,'loot+script+rank3'),(309,14834,-11787.400,-1649.340,54.102,0,'loot+script+rank3');
-- boss_point_gen map 329
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 329;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (329,10436,3855.340,-3715.750,148.175,0,'script'),(329,10438,4035.810,-3647.780,135.738,0,'script'),(329,10812,3415.840,-3044.540,136.814,0,'script'),(329,10997,3573.570,-2937.310,125.085,0,'script');
-- boss_point_gen map 349
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 349;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (349,12201,27.898,83.193,-124.483,0,'loot'),(349,13282,1130.400,-191.342,-80.001,0,'script');
-- boss_point_gen map 389
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 389;
-- boss_point_gen map 409
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 409;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (409,11982,1144.630,-1020.480,-185.663,0,'loot+script+rank3'),(409,11988,793.248,-998.265,-206.762,0,'loot+script+rank3'),(409,12056,747.547,-981.676,-178.401,0,'loot+script+rank3'),(409,12057,679.838,-497.988,-213.733,0,'loot+script+rank3'),(409,12098,601.087,-1179.110,-195.882,0,'loot+script+rank3'),(409,12118,1000.203,-955.407,-179.583,0,'loot+script+rank3'),(409,12259,898.074,-545.870,-203.405,0,'loot+script+rank3'),(409,12264,583.490,-799.755,-205.356,0,'loot+script+rank3');
-- boss_point_gen map 429
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 429;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (429,14323,550.380,533.725,-25.319,0,'loot'),(429,14326,410.711,-3.150,-24.558,0,'loot');
-- boss_point_gen map 469
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 469;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (469,10162,-7588.270,-1261.920,482.030,0,'script+rank3'),(469,11981,-7407.940,-1031.040,477.350,0,'loot+script+rank3'),(469,11983,-7433.380,-923.829,465.354,0,'loot+script+rank3'),(469,12017,-7573.890,-1035.250,449.248,0,'loot+script+rank3'),(469,12435,-7571.700,-1088.250,413.465,0,'loot+script+rank3'),(469,13020,-7483.790,-1015.990,408.652,0,'loot+script+rank3'),(469,14020,-7515.340,-1029.620,476.730,0,'loot+script+rank3'),(469,14601,-7358.190,-994.320,477.350,0,'loot+script+rank3');
-- boss_point_gen map 489
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 489;
-- boss_point_gen map 509
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 509;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (509,15339,-9493.600,2030.270,105.480,0,'loot+script+rank3'),(509,15340,-8845.520,2260.140,21.470,0,'loot+script+rank3'),(509,15341,-9129.729,1602.503,26.544,0,'loot+rank3'),(509,15348,-8824.540,1629.520,20.446,0,'loot+script+rank3'),(509,15369,-9719.611,1514.752,27.552,0,'loot+script+rank3'),(509,15370,-9235.980,1234.070,-63.658,0,'loot+script+rank3');
-- boss_point_gen map 529
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 529;
-- boss_point_gen map 531
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 531;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (531,15263,-8346.050,2080.980,125.732,0,'loot+script+rank3'),(531,15275,-9023.670,1176.240,-104.226,0,'loot+script+rank3'),(531,15276,-8868.310,1205.970,-104.231,0,'loot+script+rank3'),(531,15299,-8000.180,928.603,-51.901,0,'loot+script+rank3'),(531,15378,-8652.150,2020.910,108.661,0,'rank3'),(531,15379,-8660.590,2022.340,108.661,0,'rank3'),(531,15380,-8663.460,2029.890,108.661,0,'rank3'),(531,15509,-8532.090,1696.530,-90.260,0,'loot+script+rank3'),(531,15510,-8085.390,1196.720,-91.970,0,'loot+script+rank3'),(531,15511,-8566.880,2177.170,-3.979,0,'loot+script+rank3'),(531,15516,-8281.883,1688.650,-25.941,0,'loot+script+rank3'),(531,15543,-8587.960,2174.210,-4.148,0,'loot+script+rank3'),(531,15544,-8544.090,2165.000,-3.477,0,'loot+script+rank3'),(531,15589,-8578.790,1986.180,100.304,0,'script+rank3'),(531,15727,-8578.650,1985.850,100.304,0,'loot+script+rank3'),(531,15963,-8953.300,1233.640,-99.718,0,'rank3');
-- boss_point_gen map 532
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 532;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (532,15687,-10982.700,-1877.930,81.812,0,'loot+script+rank3'),(532,15688,-11240.610,-1704.266,179.320,0,'loot+script+rank3'),(532,15689,-11089.400,-1615.260,279.362,0,'loot+script+rank3'),(532,15690,-10926.300,-2011.540,275.686,0,'loot+script+rank3'),(532,15691,-11194.230,-1875.336,153.544,0,'loot+script+rank3'),(532,16151,-11126.300,-1929.110,49.329,0,'script+rank3'),(532,16457,-10945.900,-2103.790,92.794,0,'loot+script+rank3'),(532,16524,-11164.500,-1909.560,232.009,0,'loot+script+rank3'),(532,16816,-11099.800,-1852.390,221.070,0,'rank3'),(532,17225,-11003.700,-1760.190,140.253,0,'loot+script+rank3');
-- boss_point_gen map 533
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 533;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (533,15928,3508.020,-2931.330,303.015,0,'loot+script+rank3'),(533,15929,3449.030,-2934.740,312.180,0,'script+rank3'),(533,15930,3508.850,-2994.080,312.180,0,'script+rank3'),(533,15931,3253.280,-3310.710,292.678,0,'script+rank3'),(533,15932,3283.093,-3156.956,297.788,0,'script+rank3'),(533,15936,2795.290,-3708.850,276.563,0,'script+rank3'),(533,15952,3503.040,-3919.220,297.600,0,'loot+script+rank3'),(533,15953,3353.251,-3620.096,261.080,0,'script+rank3'),(533,15954,2677.990,-3485.050,261.290,0,'script+rank3'),(533,15956,3316.470,-3476.230,287.260,0,'script+rank3'),(533,15990,3746.410,-5113.350,142.031,0,'loot+script+rank3'),(533,16011,2909.430,-3999.460,274.280,0,'loot+script+rank3'),(533,16028,3308.460,-3232.080,294.240,0,'script+rank3'),(533,16060,2642.200,-3388.390,285.600,0,'script+rank3'),(533,16061,2755.560,-3098.040,267.860,0,'script+rank3'),(533,16062,2524.320,-2951.280,245.633,0,'script+rank3'),(533,16063,2528.790,-2948.580,245.633,0,'script+rank3'),(533,16064,2520.500,-2955.380,245.635,0,'script+rank3'),(533,16065,2517.620,-2959.380,245.636,0,'script+rank3');
-- boss_point_gen map 534
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 534;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (534,17772,5084.070,-1789.030,1322.650,0,'rank3'),(534,17852,5450.540,-2723.970,1485.590,0,'rank3'),(534,17948,5184.970,-3383.560,1638.260,0,'rank3');
-- boss_point_gen map 540
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 540;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (540,16807,178.928,289.487,-8.187,0,'loot+script'),(540,16808,231.250,-83.645,5.023,0,'loot+script'),(540,16809,375.120,57.578,-7.216,0,'loot+script'),(540,20923,512.687,315.652,2.041,0,'loot');
-- boss_point_gen map 542
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 542;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (542,17256,274.133,-87.165,-137.368,0,'rank3#5'),(542,17377,326.503,-86.003,-24.577,0,'loot+script'),(542,17380,455.336,-1.829,9.630,0,'loot+script'),(542,17381,328.127,128.866,9.619,0,'loot'),(542,21174,320.912,-83.063,-133.307,0,'rank3');
-- boss_point_gen map 543
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 543;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (543,17306,-1164.290,1516.020,68.510,0,'loot+script'),(543,17307,-1363.894,1728.032,105.865,0,'script'),(543,17308,-1122.340,1718.410,89.431,0,'loot+script'),(543,17536,-1429.172,1749.129,84.348,22,'boss_nazan_and_vazruden.cpp:landingPhasePos'),(543,17537,-1410.520,1740.585,89.060,22,'boss_nazan_and_vazruden.cpp:landingPosition');
-- boss_point_gen map 544
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 544;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (544,17256,10.478,23.991,0.714,0,'rank3#5'),(544,17257,-18.701,2.241,-0.321,0,'loot+script+rank3'),(544,18829,36.449,2.030,45.139,0,'rank3#12');
-- boss_point_gen map 545
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 545;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (545,17796,-330.083,-121.505,-7.985,0,'loot+script'),(545,17797,88.397,-316.111,-7.787,0,'loot+script'),(545,17798,-95.419,-552.031,8.270,0,'loot+script');
-- boss_point_gen map 546
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 546;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (546,17770,-121.344,-388.626,36.866,0,'loot+script'),(546,17826,288.582,-121.831,29.703,0,'loot+script'),(546,17882,141.659,32.420,26.831,0,'loot+script'),(546,18105,278.241,-446.206,40.640,0,'loot');
-- boss_point_gen map 547
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 547;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (547,17941,49.476,-380.219,3.036,0,'loot'),(547,17942,-281.096,-667.139,9.402,0,'loot'),(547,17991,18.321,-448.448,3.056,0,'loot');
-- boss_point_gen map 548
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 548;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (548,21212,29.990,-922.409,42.985,0,'loot+script+rank3'),(548,21213,370.829,-723.939,-14.005,0,'loot+script+rank3'),(548,21214,456.869,-539.741,-7.464,0,'loot+script+rank3'),(548,21215,376.543,-438.631,29.608,0,'loot+script+rank3'),(548,21216,-239.843,-366.494,-0.745,0,'loot+script+rank3'),(548,21964,462.676,-546.957,-7.463,0,'script'),(548,21965,462.519,-533.391,-7.465,0,'script'),(548,21966,465.738,-540.036,-7.464,0,'script');
-- boss_point_gen map 550
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 550;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (550,18805,432.740,-373.645,18.014,0,'loot+script+rank3'),(550,19514,370.328,-32.595,44.086,0,'loot+script+rank3'),(550,19516,424.235,403.475,14.977,0,'loot+script+rank3'),(550,19622,795.408,-1.605,48.812,0,'loot+script+rank3'),(550,20060,785.782,-20.399,48.812,0,'script+rank3'),(550,20062,792.408,-13.242,48.812,0,'script+rank3'),(550,20063,792.725,12.775,48.812,0,'script+rank3'),(550,20064,785.807,19.486,48.812,0,'script+rank3');
-- boss_point_gen map 552
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 552;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (552,20870,275.788,-123.343,-10.123,0,'loot'),(552,20885,137.234,128.506,22.524,0,'loot+script'),(552,20886,136.200,168.310,22.524,0,'loot+script'),(552,20912,445.763,-191.639,44.640,0,'arcatraz.h:aSummonPosition');
-- boss_point_gen map 553
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 553;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (553,17975,116.326,455.570,-4.941,0,'loot+script'),(553,17976,125.729,321.185,-3.636,0,'loot'),(553,17977,63.841,391.882,-27.894,0,'loot+script'),(553,17978,4.949,596.578,-15.078,0,'loot+script'),(553,17980,-204.125,391.249,-11.194,0,'loot+script');
-- boss_point_gen map 554
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 554;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (554,19219,210.416,15.641,-2.192,0,'loot+script'),(554,19220,139.542,149.319,25.659,0,'mechanar.h:aBridgeEventLocs'),(554,19221,326.517,13.196,27.920,0,'loot+script');
-- boss_point_gen map 555
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 555;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (555,18667,-328.209,-39.050,12.689,0,'loot+script'),(555,18708,-157.895,-497.322,15.865,0,'loot+script'),(555,18731,-156.675,4.983,8.156,0,'loot+script'),(555,18732,-253.548,-263.646,17.170,0,'loot+script');
-- boss_point_gen map 556
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 556;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (556,18472,-144.827,173.557,1.769,0,'loot+script'),(556,18473,44.723,286.960,25.152,0,'loot+script');
-- boss_point_gen map 557
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 557;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (557,18341,-67.325,-120.090,-1.283,0,'loot+script'),(557,18343,-321.717,-222.183,-0.778,0,'loot'),(557,18344,-184.366,9.333,16.817,0,'loot+script'),(557,22930,-235.788,-13.005,17.140,0,'mana_tombs:22927 stasis chamber');
-- boss_point_gen map 558
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 558;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (558,18371,-26.245,-162.785,26.094,0,'loot+script'),(558,18373,66.766,-388.345,26.673,0,'loot+script');
-- boss_point_gen map 560
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 560;
-- boss_point_gen map 564
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 564;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (564,22841,449.595,401.194,118.621,0,'loot+script+rank3'),(564,22856,497.772,184.166,94.605,0,'script+rank3'),(564,22871,606.641,402.173,187.173,0,'loot+script+rank3'),(564,22887,434.943,739.254,15.070,0,'loot+script+rank3'),(564,22898,702.141,650.715,75.049,0,'loot+script+rank3'),(564,22917,705.732,304.988,353.925,0,'loot+script+rank3'),(564,22947,945.313,149.078,197.158,0,'loot+script+rank3'),(564,22948,744.302,277.077,63.839,0,'loot+script+rank3'),(564,22949,700.739,302.722,277.526,0,'loot+script+rank3'),(564,22950,700.792,307.192,277.526,0,'loot+script+rank3'),(564,22951,697.409,299.377,277.526,0,'loot+script+rank3'),(564,22952,697.495,310.651,277.527,0,'loot+script+rank3'),(564,23426,737.455,305.054,277.526,0,'rank3'),(564,23499,723.065,305.023,277.526,0,'rank3');
-- boss_point_gen map 565
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 565;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (565,18831,143.049,192.726,-11.215,0,'loot+script+rank3'),(565,18832,149.823,178.019,-10.593,0,'script+rank3'),(565,18834,146.521,185.358,-10.838,0,'script+rank3'),(565,18835,145.960,207.296,-8.671,0,'script+rank3'),(565,18836,144.731,199.921,-9.977,0,'script+rank3'),(565,19044,237.403,357.981,-3.408,0,'loot+script+rank3');
-- boss_point_gen map 566
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 566;
-- boss_point_gen map 568
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 568;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (568,23574,376.353,1407.340,75.531,0,'script+rank3'),(568,23576,16.962,1414.600,11.927,0,'script+rank3'),(568,23577,370.257,1135.740,6.549,0,'script+rank3'),(568,23578,-18.642,1150.460,18.795,0,'script+rank3'),(568,23863,119.981,674.245,51.824,0,'loot+script+rank3'),(568,23877,149.657,705.750,45.195,0,'rank3'),(568,23878,134.600,724.341,45.195,0,'rank3'),(568,23879,91.133,705.753,45.195,0,'rank3'),(568,23880,105.526,724.926,45.195,0,'rank3'),(568,24239,117.363,923.569,33.973,0,'loot+script+rank3');
-- boss_point_gen map 572
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 572;
-- boss_point_gen map 580
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 580;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (580,24850,1704.215,924.758,53.161,0,'script+rank3'),(580,24882,1463.828,611.512,21.570,0,'loot+script+rank3'),(580,24892,1699.906,929.021,-74.284,0,'loot+script+rank3'),(580,25165,1814.271,626.452,33.487,0,'loot+script+rank3'),(580,25166,1818.212,625.044,33.487,0,'loot+script+rank3'),(580,25741,1816.401,625.894,69.689,0,'script+rank3'),(580,26046,1698.092,627.290,58.177,0,'rank3'),(580,26246,1721.726,648.482,27.757,0,'rank3'),(580,26247,1720.024,643.233,28.134,0,'rank3');
-- boss_point_gen map 585
DELETE FROM `ai_playerbot_boss_spawn` WHERE `map` = 585;
INSERT INTO `ai_playerbot_boss_spawn` (`map`,`entry`,`x`,`y`,`z`,`ord`,`source`) VALUES (585,24560,126.901,19.155,-19.922,0,'loot+script'),(585,24664,148.549,186.981,-16.644,0,'loot+script'),(585,24723,242.075,0.301,1.840,0,'loot+script'),(585,24744,231.367,-214.346,-6.323,0,'loot+script'),(585,25960,-24.611,-482.024,-22.129,0,'rank3'),(585,26579,-25.236,-599.946,-31.020,0,'rank3');
