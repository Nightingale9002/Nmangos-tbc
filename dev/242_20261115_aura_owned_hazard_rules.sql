-- Character database. Data-only binding for named-player aura separation.
-- Only the aura holder actively moves; other party members stay as positional
-- constraints. Real damage radius comes from the triggered damage spell, with
-- each receiving member's combat reach and the configured margin added.
CREATE TABLE IF NOT EXISTS `ai_playerbot_aura_hazard` (
  `map` INT UNSIGNED NOT NULL,
  `boss_entry` INT UNSIGNED NOT NULL,
  `aura_spell` INT UNSIGNED NOT NULL,
  `damage_spell` INT UNSIGNED NOT NULL,
  `effect_index` TINYINT UNSIGNED NOT NULL,
  `margin` FLOAT NOT NULL DEFAULT 0.75,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`map`,`boss_entry`,`aura_spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

START TRANSACTION;
DELETE FROM `ai_playerbot_aura_hazard`
WHERE `map`=555 AND `boss_entry`=18708 AND `aura_spell` IN (33711,38794);
INSERT INTO `ai_playerbot_aura_hazard`
(`map`,`boss_entry`,`aura_spell`,`damage_spell`,`effect_index`,`margin`,`enabled`)
VALUES (555,18708,33711,33686,1,0.75,1),
       (555,18708,38794,33686,1,0.75,1);
COMMIT;
