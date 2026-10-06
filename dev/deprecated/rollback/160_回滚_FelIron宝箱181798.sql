-- =====================================================================================
-- 160 回滚：把 181798「Fel Iron Chest」改回 dev/159 的版本（data1 = 21278，并删除 160 灌回的 96 行）。
-- =====================================================================================

UPDATE `gameobject_template` SET `data1` = 21278 WHERE `entry` = 181798 AND `data1` = 181798;
DELETE FROM `gameobject_loot_template` WHERE `entry` = 181798;

SELECT `entry`, `name`, `data1` FROM `gameobject_template` WHERE `entry` = 181798;
