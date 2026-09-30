-- 147 回滚：把能源舰 Mechanar Tinkerer (guid 5540055) 的路径点 4 高度改回原值 9.80615

UPDATE `tbcmangos`.`creature_movement`
   SET `PositionZ` = 9.80615
 WHERE `Id` = 5540055 AND `Point` = 4 AND ABS(`PositionZ` - 0.005) < 0.001;
