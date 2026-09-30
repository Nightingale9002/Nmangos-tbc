-- 146 回滚：还原被清理的两处静态脏数据
--   ① dbscripts_on_relay 5550007 的删除队形行改回原来的 5550015
--   ② spawn_group_spawn 恢复 156139 / 156135 两行（组 9100 / 9101，SlotId 1，Chance 0）

UPDATE `tbcmangos`.`dbscripts_on_relay`
   SET `datalong2` = 5550015
 WHERE `id` = 5550007 AND `command` = 51 AND `datalong` = 151 AND `delay` = 20000;

DELETE FROM `tbcmangos`.`spawn_group_spawn` WHERE `Guid` IN (156139, 156135);
INSERT INTO `tbcmangos`.`spawn_group_spawn` (`Id`, `Guid`, `SlotId`, `Chance`) VALUES
(9100, 156139, 1, 0),
(9101, 156135, 1, 0);
