-- Character database (tbccharacters). Retire only the observed conflicting
-- nearest-add DPS rule; priority_target now selects real Void Travelers.
-- r4 logs show this rule immediately replacing the FSM's traveler victim with
-- Vorpil on consecutive ticks. Keep the tank's separate kite rule unchanged.
START TRANSACTION;
DELETE FROM `ai_playerbot_custom_strategy`
WHERE `owner`=0 AND `name`='boss_18732'
  AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack nearest add';
COMMIT;
