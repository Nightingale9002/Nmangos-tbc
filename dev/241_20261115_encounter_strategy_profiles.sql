-- Character database (tbccharacters). Idempotent; only this profile/bindings are seeded.
-- After the new binary is installed, live edits are polled every 5 seconds.
-- Change related rows in ONE transaction. No .reload command is required.
CREATE TABLE IF NOT EXISTS `ai_playerbot_strategy_profile` (
  `id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(96) NOT NULL,
  `executor` VARCHAR(32) NOT NULL,
  `channel_spell` INT UNSIGNED NOT NULL,
  `damage_spell` INT UNSIGNED NOT NULL,
  `radius_effect` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `cone_degrees` FLOAT NOT NULL DEFAULT 60 COMMENT 'Fallback if spell_cone is absent; actual spell geometry wins',
  `separation_degrees` FLOAT NOT NULL DEFAULT 4 COMMENT 'Extra angular separation beyond half cone',
  `radial_degrees` FLOAT NOT NULL DEFAULT 2,
  `search_step` FLOAT NOT NULL DEFAULT 0.75,
  `search_distance` FLOAT NOT NULL DEFAULT 45,
  `directions` SMALLINT UNSIGNED NOT NULL DEFAULT 48,
  `plan_ms` INT UNSIGNED NOT NULL DEFAULT 150,
  `poison_totem` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `poison_aura` INT UNSIGNED NOT NULL DEFAULT 0,
  `heroic_poison_aura` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ai_playerbot_encounter_binding` (
  `map` INT UNSIGNED NOT NULL,
  `entry` INT UNSIGNED NOT NULL,
  `profile_id` INT UNSIGNED NOT NULL,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`map`,`entry`),
  KEY `profile_id` (`profile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

START TRANSACTION;
DELETE FROM `ai_playerbot_encounter_binding` WHERE `map`=547 AND `entry` IN (17942,19894);
DELETE FROM `ai_playerbot_strategy_profile` WHERE `id`=1;
INSERT INTO `ai_playerbot_strategy_profile`
(`id`,`name`,`executor`,`channel_spell`,`damage_spell`,`radius_effect`,`cone_degrees`,
 `separation_degrees`,`radial_degrees`,`search_step`,`search_distance`,`directions`,`plan_ms`,
 `poison_totem`,`poison_aura`,`heroic_poison_aura`)
VALUES (1,'Quagmirran - tracked acid spray','tracked_cone',38153,38163,1,60,4,2,0.75,45,48,150,1,34780,39340);
INSERT INTO `ai_playerbot_encounter_binding` (`map`,`entry`,`profile_id`,`enabled`)
VALUES (547,17942,1,1),(547,19894,1,1);
COMMIT;
