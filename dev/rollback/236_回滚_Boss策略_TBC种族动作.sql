-- Restore only rows still equal to the exact values written by dev/236.
START TRANSACTION;
UPDATE ai_playerbot_custom_strategy
SET action_line = 'feared>every_man_for_himself!96,will of the forsaken!95'
WHERE id = 1863 AND name = 'boss_common' AND owner = 0 AND idx = 1
  AND action_line = 'feared>will of the forsaken!95';
UPDATE ai_playerbot_custom_strategy
SET action_line = 'has aura::spellid::30923>every_man_for_himself!96,will of the forsaken!95,use trinket!90'
WHERE id = 1879 AND name = 'boss_17381' AND owner = 0 AND idx = 1
  AND action_line = 'has aura::spellid::30923>will of the forsaken!95,use trinket!90';
COMMIT;
