-- 146：两处静态脏数据清理（都属于"每次启动/每 27 秒刷错误日志"）
--
-- ① dbscripts_on_relay 5550007（暗影迷宫「秘教死誓者」的队形脚本，每 27 秒由 EventAI 5550124 启动）：
--    command 51 的 subcommand 150（SetFormation）打的是组 5550013（注释即 "Group 011 - Create Formation"，
--    而 5550013 = "Shadow Labyrinth - Group 011 - Cabal Familiar (5)"），
--    但同脚本 delay 20000 的 subcommand 151（Remove formation）写成了 5550015 ⇒ 笔误。
--    后果：每轮都报
--      "formation create(1) failed. Target group(5550013) have already a formation!"
--      "formation remove(2) failed. Target group(5550015) have already a formation!"
--    并且 5550013 上的动态队形永远不被清理（魔宠会一直保持单列队形状态）。
--    全库扫描确认：150/151 成对出现的只有这一处，其它都是只建不删的巡逻队形（有意为之）。
--
-- ② spawn_group_spawn 里 156139 / 156135 指向既不存在的 creature guid 也不存在的 gameobject guid
--    （组 9100 "Ashenvale - Saltspittle Puddlejumper Formation" / 9101 "Ashenvale - Forsaken Thug Formation"）
--    ⇒ 每次启动 LoadSpawnGroups 报 "Invalid spawn_group_spawn guid ... Skipping."。删除这两行即可
--    （队形组由其余成员继续工作）。
-- 幂等：先删后插 / 直接 UPDATE。

UPDATE `tbcmangos`.`dbscripts_on_relay`
   SET `datalong2` = 5550013
 WHERE `id` = 5550007 AND `command` = 51 AND `datalong` = 151 AND `delay` = 20000;

DELETE FROM `tbcmangos`.`spawn_group_spawn` WHERE `Guid` IN (156139, 156135);
