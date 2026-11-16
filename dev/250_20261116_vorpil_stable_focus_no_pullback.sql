-- Character database. One stable add focus; no unrelated retreat or formation.
START TRANSACTION;
DELETE FROM `ai_playerbot_boss_ability`
WHERE `map`=555 AND `boss_entry`=18732 AND `owner_entry`=18732
 AND `spell_id`=0 AND `category`='add_focus';
INSERT INTO `ai_playerbot_boss_ability`
(`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`facing_mode`,`generic_handling`,`source`,`note`) VALUES
(555,18732,18732,0,'add_focus','away_group','adds_then_boss_ground_only','observed',
 'Stable party focus on nearby Travelers, otherwise attack Vorpil. No extra pullback/flee/formation, actual ground hazard escape and legal ability range remain.');
COMMIT;
