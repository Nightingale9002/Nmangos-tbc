-- TBC: remove only the WotLK-only racial action from two existing Boss rules.
-- Evidence: ActionContext.h -> ActionContext(), every_man_for_himself is guarded
-- by MANGOSBOT_TWO. Retain the existing TBC action names, order and priorities.
-- World database only. Exact old-value predicates preserve manual edits.
-- Local validation first; this file is not authorization to apply on cloud.
START TRANSACTION;
UPDATE ai_playerbot_custom_strategy
SET action_line = 'feared>will of the forsaken!95'
WHERE id = 1863 AND name = 'boss_common' AND owner = 0 AND idx = 1
  AND action_line = 'feared>every_man_for_himself!96,will of the forsaken!95';
UPDATE ai_playerbot_custom_strategy
SET action_line = 'has aura::spellid::30923>will of the forsaken!95,use trinket!90'
WHERE id = 1879 AND name = 'boss_17381' AND owner = 0 AND idx = 1
  AND action_line = 'has aura::spellid::30923>every_man_for_himself!96,will of the forsaken!95,use trinket!90';
COMMIT;
