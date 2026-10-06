-- =====================================================================================
-- 157 回滚：把沃尔皮尔(18732) intro 台词的中文去掉，恢复成只有英文原文。
-- =====================================================================================

UPDATE `tbcmangos`.`script_texts` SET `content_loc4` = NULL WHERE `entry` = -1555028;

SELECT `entry`, `content_default`, `content_loc4` FROM `tbcmangos`.`script_texts` WHERE `entry` = -1555028;
