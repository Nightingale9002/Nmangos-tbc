-- Character database (tbccharacters). No boss gameplay/encounter script changes.
-- Pause healing while Arcane Bubble is active; resume only after a live party tank
-- has recovered the victim and positive threat lead. Generic executor polls in 5s.
START TRANSACTION;
DELETE FROM `ai_playerbot_boss_ability`
WHERE `map`=556 AND `boss_entry` IN (18473,20706)
  AND `spell_id`=9438 AND `category`='heal_threat_pause';
INSERT INTO `ai_playerbot_boss_ability`
(`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`generic_handling`,`source`,`note`)
VALUES
(556,18473,0,9438,'heal_threat_pause','pause_until_tank_lead','observed','Arcane Bubble: pause heals through immunity and threat reset; wait for tank aggro'),
(556,20706,0,9438,'heal_threat_pause','pause_until_tank_lead','observed','Heroic Arcane Bubble: pause heals through immunity and threat reset; wait for tank aggro');
COMMIT;
