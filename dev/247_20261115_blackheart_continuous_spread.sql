-- Character database. Live geometry only; no precomputed positions.
CREATE TABLE IF NOT EXISTS `ai_playerbot_encounter_tactics` (
  `map` SMALLINT UNSIGNED NOT NULL,
  `boss_entry` INT UNSIGNED NOT NULL,
  `ranged_boss_distance` FLOAT NOT NULL DEFAULT 0,
  `separation` FLOAT NOT NULL DEFAULT 0,
  `prefer_wall` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `heal_floor` FLOAT NOT NULL DEFAULT 0,
  `opening_cooldowns` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`map`,`boss_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `ai_playerbot_encounter_cooldown` (
  `map` SMALLINT UNSIGNED NOT NULL,
  `boss_entry` INT UNSIGNED NOT NULL,
  `class` TINYINT UNSIGNED NOT NULL,
  `spell_name` VARCHAR(64) NOT NULL,
  `priority` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`map`,`boss_entry`,`class`,`spell_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
START TRANSACTION;
-- 21.5 leaves a margin for the movement endpoint tolerance. Melee retain reach;
-- any pair containing a ranged/healer member observes the separation rule.
DELETE FROM `ai_playerbot_encounter_tactics` WHERE `map`=555 AND `boss_entry`=18667;
INSERT INTO `ai_playerbot_encounter_tactics`
(`map`,`boss_entry`,`ranged_boss_distance`,`separation`,`prefer_wall`,`heal_floor`,`opening_cooldowns`)
VALUES (555,18667,21.5,21.5,1,60,1);
DELETE FROM `ai_playerbot_encounter_cooldown` WHERE `map`=555 AND `boss_entry`=18667;
INSERT INTO `ai_playerbot_encounter_cooldown` (`map`,`boss_entry`,`class`,`spell_name`,`priority`) VALUES
(555,18667,1,'death wish',100),(555,18667,1,'recklessness',90),
(555,18667,2,'avenging wrath',100),
(555,18667,3,'rapid fire',100),(555,18667,3,'bestial wrath',90),
(555,18667,4,'adrenaline rush',100),(555,18667,4,'blade flurry',90),(555,18667,4,'cold blood',80),
(555,18667,5,'power infusion',100),(555,18667,5,'inner focus',90),
(555,18667,7,'bloodlust',100),(555,18667,7,'heroism',100),(555,18667,7,'elemental mastery',90),(555,18667,7,'nature''s swiftness',80),
(555,18667,8,'arcane power',100),(555,18667,8,'icy veins',90),(555,18667,8,'combustion',80),(555,18667,8,'presence of mind',70),
(555,18667,9,'amplify curse',100),
(555,18667,11,'nature''s swiftness',100);
COMMIT;
