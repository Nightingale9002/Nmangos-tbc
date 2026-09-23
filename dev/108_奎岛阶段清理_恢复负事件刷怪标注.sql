-- dev/108 恢复「负事件号」刷怪标注：让上一阶段的敌对 NPC 在阶段推进时停止刷新
-- ===============================================================
-- 现象：奎岛（日境）推进到新阶段后，上一阶段的敌对 NPC（Dawnblade / Wretched / Erratic 等）
--       仍然持续刷新，永不消失。
-- 原因：cmangos 用 `game_event_creature.event` 的【负数】表示「该刷点存在到事件 N 开始为止」——
--       事件 N 启动时 GameEventMgr::ApplyNewEvent() 会执行 GameEventUnspawn(-N)，把这些刷点整体移除。
--       奎岛正是靠 -302/-303/-307/-310 清理上一阶段的敌人。
--       而本库 `game_event_creature` 里 **负数行一条都没有**（参考库 tbcmangos_orig / tbcdb_ref 有 262 条），
--       逐行比对（guid+event）确认：本库相对参考库只少这 262 行，多 0 行。
--       所以阶段事件照常启动，只是「没有任何刷点被标记为需要清理」。
--
-- 来源：262 行逐字取自参考库 tbcmangos_orig（= 上游原始数据），非自创；
--       262 个 guid 在本库 `creature` 表中全部存在，PK(guid,event) 无冲突。
--
-- ⛔ 本文件是【全静态 SQL】：只有写死的字面量，无 JOIN/子查询/聚合/计算。
-- 幂等：使用 INSERT IGNORE，重复执行不会重复插入、不会报错。
-- 生效：`game_event_creature` 在 mangosd 启动时载入 ⇒ **需重启**；
--       且负数行是在「对应事件被 Apply」的那一刻执行清理，
--       因此对**当前已激活**的阶段事件，需重启（启动时会带 resume 走一遍 Apply）或 `.event stop/start` 重放一次。
-- 回滚：dev/rollback/108_回滚_恢复负事件刷怪标注.sql
-- 核对：见文件末尾 SELECT（期望：负数行合计 262；分事件行数见各段注释）
-- ===============================================================

-- ---------------------------------------------------------------
-- 一、奎岛阶段清理（本段即修复「旧敌对 NPC 不停刷」的问题，共 112 行）
-- ---------------------------------------------------------------

-- 事件 -310（阶段4 开始时清理：日境港 / 军械库外围剩余的黎明刃与召唤者）开始时移除 51 个刷点：
--   entry 24979 Dawnblade Marksman x22
--   entry 24976 Dawnblade Blood Knight x17
--   entry 24978 Dawnblade Summoner x12
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (5300295,-310), (5300296,-310), (5300297,-310), (5300298,-310), (5300299,-310), (5300300,-310), (5300301,-310), (5300302,-310),
  (5300303,-310), (5300304,-310), (5300305,-310), (5300306,-310), (5300307,-310), (5300308,-310), (5300310,-310), (5300311,-310),
  (5300312,-310), (5300355,-310), (5300356,-310), (5300357,-310), (5300358,-310), (5300359,-310), (5300360,-310), (5300361,-310),
  (5300362,-310), (5300363,-310), (5300364,-310), (5300366,-310), (5300367,-310), (5300388,-310), (5300389,-310), (5300390,-310),
  (5300391,-310), (5300392,-310), (5300393,-310), (5300394,-310), (5300395,-310), (5300396,-310), (5300398,-310), (5300399,-310),
  (5300400,-310), (5300403,-310), (5300404,-310), (5300405,-310), (5300406,-310), (5300407,-310), (5300408,-310), (5300409,-310),
  (5300410,-310), (5300413,-310), (5300415,-310);

-- 事件 -307（阶段3 永久 开始时清理：军械库一带的黎明刃召唤者等）开始时移除 29 个刷点：
--   entry 25001 Abyssal Flamewalker x11
--   entry 25002 Unleashed Hellion x11
--   entry 24999 Irespeaker x6
--   entry 24978 Dawnblade Summoner x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (5300365,-307), (5300460,-307), (5300461,-307), (5300462,-307), (5300463,-307), (5300464,-307), (5300465,-307), (5300471,-307),
  (5300472,-307), (5300473,-307), (5300474,-307), (5300475,-307), (5300476,-307), (5300477,-307), (5300478,-307), (5300479,-307),
  (5300480,-307), (5300481,-307), (5300493,-307), (5300494,-307), (5300495,-307), (5300496,-307), (5300497,-307), (5300498,-307),
  (5300499,-307), (5300500,-307), (5300501,-307), (5300502,-307), (5300503,-307);

-- 事件 -303（阶段2 永久 开始时清理：上一批黎明刃 / 破碎残阳哨兵残留）开始时移除 19 个刷点：
--   entry 24976 Dawnblade Blood Knight x6
--   entry 24979 Dawnblade Marksman x5
--   entry 24978 Dawnblade Summoner x3
--   entry 25115 Shattered Sun Warrior x3
--   entry 24938 Shattered Sun Marksman x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (5300086,-303), (5300087,-303), (5300293,-303), (5300294,-303), (5300309,-303), (5300313,-303), (5300314,-303), (5300315,-303),
  (5300368,-303), (5300369,-303), (5300370,-303), (5300401,-303), (5300402,-303), (5300411,-303), (5300412,-303), (5300414,-303),
  (5301085,-303), (5301086,-303), (5301087,-303);

-- 事件 -302（阶段2 Only 开始时清理：日境圣所一带的黎明刃部队（旧阶段敌人））开始时移除 13 个刷点：
--   entry 24976 Dawnblade Blood Knight x4
--   entry 25115 Shattered Sun Warrior x3
--   entry 24938 Shattered Sun Marksman x2
--   entry 24978 Dawnblade Summoner x2
--   entry 24979 Dawnblade Marksman x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (5300086,-302), (5300087,-302), (5300293,-302), (5300294,-302), (5300309,-302), (5300315,-302), (5300369,-302), (5300370,-302),
  (5300401,-302), (5300402,-302), (5301085,-302), (5301086,-302), (5301087,-302);

-- ---------------------------------------------------------------
-- 二、其它事件的同类缺失（同一批丢失，共 150 行；与奎岛现象同源）
-- ---------------------------------------------------------------

-- 事件 -123（安其拉战事·第4阶段10小时战争(123)开始）开始时移除 96 个刷点：
--   entry 8147 Camp Mojache Brave x8
--   entry 3240 Stormsnout x6
--   entry 9460 Gadgetzan Bruiser x6
--   entry 3255 Sunscale Screecher x5
--   entry 3238 Stormhide x4
--   entry 3239 Thunderhead x4
--   entry 3245 Ornery Plainstrider x4
--   entry 4248 Pesterhide Hyena x4
--   entry 5426 Blisterpaw Hyena x4
--   entry 12296 Sickly Gazelle x3
--   entry 3463 Wandering Barrens Giraffe x3
--   entry 3242 Zhevra Runner x3
--   entry 3244 Greater Plainstrider x3
--   entry 4143 Sparkleshell Snapper x3
--   entry 5419 Glasshide Basilisk x3
--   entry 4128 Hecklefang Stalker x2
--   entry 3466 Zhevra Courser x2
--   entry 3256 Sunscale Scytheclaw x2
--   entry 4124 Needles Cougar x2
--   entry 4249 Pesterhide Snarler x2
--   entry 5427 Rabid Blisterpaw x2
--   entry 11738 Sand Skitterer x2
--   entry 14720 High Overlord Saurfang x1
--   entry 3415 Savannah Huntress x1
--   entry 3426 Zhevra Charger x1
--   entry 3456 Razormane Pathfinder x1
--   entry 3234 Lost Barrens Kodo x1
--   entry 3246 Fleeting Plainstrider x1
--   entry 3249 Greater Thunderhawk x1
--   entry 3254 Sunscale Lashtail x1
--   entry 4111 Gravelsnout Kobold x1
--   entry 4118 Venomous Cloud Serpent x1
--   entry 4139 Scorpid Terror x1
--   entry 4144 Sparkleshell Borer x1
--   entry 4150 Saltstone Gazer x1
--   entry 4151 Saltstone Crystalhide x1
--   entry 5420 Glasshide Gazer x1
--   entry 5421 Glasshide Petrifier x1
--   entry 5422 Scorpid Hunter x1
--   entry 5425 Starving Blisterpaw x1
--   entry 4158 Salt Flats Vulture x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (6499,-123), (13122,-123), (13131,-123), (13149,-123), (13497,-123), (13502,-123), (14124,-123), (14271,-123),
  (14446,-123), (15004,-123), (15022,-123), (15028,-123), (15050,-123), (15056,-123), (15107,-123), (15148,-123),
  (15161,-123), (15162,-123), (15188,-123), (15203,-123), (15228,-123), (15235,-123), (15242,-123), (17420,-123),
  (17421,-123), (17422,-123), (17425,-123), (17430,-123), (17435,-123), (18321,-123), (18654,-123), (18661,-123),
  (19287,-123), (19291,-123), (19293,-123), (19377,-123), (19419,-123), (19443,-123), (19454,-123), (19617,-123),
  (19715,-123), (19815,-123), (19902,-123), (19940,-123), (19970,-123), (19980,-123), (19984,-123), (20040,-123),
  (20041,-123), (21162,-123), (21194,-123), (21255,-123), (21266,-123), (21343,-123), (21433,-123), (21436,-123),
  (21437,-123), (21445,-123), (21484,-123), (21533,-123), (21595,-123), (21630,-123), (21631,-123), (21640,-123),
  (21656,-123), (21659,-123), (21831,-123), (21880,-123), (21918,-123), (22036,-123), (22115,-123), (22147,-123),
  (22406,-123), (22427,-123), (22510,-123), (22511,-123), (22530,-123), (22634,-123), (22660,-123), (23560,-123),
  (23570,-123), (23574,-123), (23575,-123), (23588,-123), (23596,-123), (32584,-123), (45585,-123), (45586,-123),
  (51378,-123), (51379,-123), (51380,-123), (51407,-123), (51409,-123), (51410,-123), (51411,-123), (51412,-123);

-- 事件 -100（「暴风前夕·远征开启」事件(100)开始）开始时移除 3 个刷点：
--   entry 16841 Watch Commander Relthorn Netherwane x1
--   entry 16840 Advisor Sevel x1
--   entry 19254 Warlord Dar'toon x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (2723,-100), (2724,-100), (2725,-100);

-- 事件 -84（暗月马戏团·艾尔文森林·开张(84)开始）开始时移除 1 个刷点：
--   entry 30 Forest Spider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (80700,-84);

-- 事件 -83（暗月马戏团·艾尔文森林·搭建阶段2(83)开始）开始时移除 1 个刷点：
--   entry 30 Forest Spider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (80700,-83);

-- 事件 -82（暗月马戏团·艾尔文森林·搭建阶段1(82)开始）开始时移除 1 个刷点：
--   entry 30 Forest Spider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (80700,-82);

-- 事件 -81（暗月马戏团·莫高雷·开张(81)开始）开始时移除 3 个刷点：
--   entry 3035 Flatland Cougar x2
--   entry 2957 Elder Plainstrider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (25324,-81), (26719,-81), (26751,-81);

-- 事件 -80（暗月马戏团·莫高雷·搭建阶段2(80)开始）开始时移除 3 个刷点：
--   entry 3035 Flatland Cougar x2
--   entry 2957 Elder Plainstrider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (25324,-80), (26719,-80), (26751,-80);

-- 事件 -79（暗月马戏团·莫高雷·搭建阶段1(79)开始）开始时移除 3 个刷点：
--   entry 3035 Flatland Cougar x2
--   entry 2957 Elder Plainstrider x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (25324,-79), (26719,-79), (26751,-79);

-- 事件 -78（暗月马戏团·泰罗卡·开张(78)开始）开始时移除 2 个刷点：
--   entry 18464 Warp Stalker x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (66153,-78), (66157,-78);

-- 事件 -77（暗月马戏团·泰罗卡·搭建阶段2(77)开始）开始时移除 2 个刷点：
--   entry 18464 Warp Stalker x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (66153,-77), (66157,-77);

-- 事件 -76（暗月马戏团·泰罗卡·搭建阶段1(76)开始）开始时移除 2 个刷点：
--   entry 18464 Warp Stalker x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (66153,-76), (66157,-76);

-- 事件 -27（夜晚(27)开始：只在白天出现的刷点（到夜里消失））开始时移除 14 个刷点：
--   entry 95 Defias Smuggler x3
--   entry 12372 Brown Ram x1
--   entry 12373 Gray Ram x1
--   entry 14547 Swift White Ram x1
--   entry 4772 Ultham Ironhorn x1
--   entry 12374 White Riding Ram x1
--   entry 14548 Swift Gray Ram x1
--   entry 14546 Swift Brown Ram x1
--   entry 8666 Lil Timmy x1
--   entry 7386 White Kitten x1
--   entry 504 Defias Trapper x1
--   entry 547 Great Goretusk x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (4147,-27), (4148,-27), (4149,-27), (4150,-27), (4154,-27), (4155,-27), (4156,-27), (45501,-27),
  (53705,-27), (89875,-27), (89879,-27), (90018,-27), (90128,-27), (90130,-27);

-- 事件 -26（啤酒节(26)开始：被替换掉的啤酒节装饰/物件刷点）开始时移除 14 个刷点：
--   entry 3100 Elder Mottled Boar x6
--   entry 721 Rabbit x2
--   entry 3127 Venomtail Scorpid x2
--   entry 3225 Corrupted Mottled Boar x1
--   entry 3227 Corrupted Bloodtalon Scythemaw x1
--   entry 3300 Adder x1
--   entry 5951 Hare x1
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (147,-26), (1735,-26), (21020,-26), (21022,-26), (21024,-26), (21026,-26), (21034,-26), (21036,-26),
  (22181,-26), (22188,-26), (22451,-26), (22473,-26), (24976,-26), (38608,-26);

-- 事件 -12（万圣节(12)开始：被替换掉的万圣节装饰/物件刷点）开始时移除 5 个刷点：
--   entry 299 Young Wolf x3
--   entry 525 Mangy Wolf x2
INSERT IGNORE INTO `game_event_creature` (`guid`, `event`) VALUES
  (79648,-12), (80341,-12), (80342,-12), (80343,-12), (80351,-12);

-- ===============================================================
-- 核对（可选）：
-- SELECT COUNT(*) AS neg_rows FROM game_event_creature WHERE event < 0;                      -- 期望 262
-- SELECT event, COUNT(*) AS n FROM game_event_creature WHERE event < 0 GROUP BY event ORDER BY event;
-- SELECT COUNT(*) AS qd_rows FROM game_event_creature WHERE event IN (-302,-303,-307,-310);  -- 期望 112
-- ===============================================================
