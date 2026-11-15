-- Character database. Passive encounter adds become urgent inside boss radius.
CREATE TABLE IF NOT EXISTS `ai_playerbot_encounter_add_range` (
 `map` SMALLINT UNSIGNED NOT NULL,
 `add_entry` INT UNSIGNED NOT NULL,
 `boss_entry` INT UNSIGNED NOT NULL,
 `radius` FLOAT NOT NULL,
 `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
 PRIMARY KEY (`map`,`add_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
START TRANSACTION;
DELETE FROM `ai_playerbot_encounter_add_range` WHERE `map`=555 AND `add_entry` IN (19226,20664);
INSERT INTO `ai_playerbot_encounter_add_range` (`map`,`add_entry`,`boss_entry`,`radius`) VALUES
(555,19226,18732,30),(555,20664,18732,30);
COMMIT;
