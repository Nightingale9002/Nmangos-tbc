-- Character database (tbccharacters). Blackheart tank backs against a live wall.
-- Tank-only executor selects a reachable position at runtime; no offline points.
-- Remove conflicting permanent formations for this boss only. Native knockback,
-- charge, charm and threat-reset behavior are unchanged.
START TRANSACTION;
DELETE FROM `ai_playerbot_boss_ability`
WHERE `map`=555 AND `boss_entry`=18667 AND `owner_entry` IN (0,18667)
  AND `spell_id`=0 AND `category` IN ('knockback','spread','wall','tank_wall');
INSERT INTO `ai_playerbot_boss_ability`
(`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`facing_mode`,`generic_handling`,`source`,`note`)
VALUES (555,18667,18667,0,'tank_wall','away_group','tank_back_to_wall','observed',
'Blackheart: tank backs against reachable terrain to limit War Stomp knockback; other roles keep working positions');
COMMIT;
