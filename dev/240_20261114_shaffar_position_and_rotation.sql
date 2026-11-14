-- Nexus-Prince Shaffar: remove unsupported facing and legacy DPS rotation rules.
-- Character DB only. No world/boss spell changes; no reload or server operation.
-- boss_nexusprince_shaffarAI casts single-target bolts, radial Frost Nova,
-- Blink and beacon summons; it has no frontal cone requiring a permanent rear slot.
USE `tbccharacters`;

UPDATE `ai_playerbot_boss_ability`
SET `category` = 'role_bands',
    `avoid_sectors` = '',
    `generic_handling` = 'position: usable heal range',
    `note` = 'Shaffar: no frontal cone, keep safe usable position, heal tank within range/LOS'
WHERE `map` = 557 AND `boss_entry` = 18344 AND `owner_entry` = 18344
  AND `spell_id` = 0 AND `category` = 'frontal' AND `avoid_sectors` = 'front'
  AND `facing_mode` = 'away_group';

-- These broad DPS rules do not identify beacons, can retarget every tick and
-- resolve attack -> melee even for casters. Native target priority/FSM owns DPS.
-- Keep the Frost Nova dispel rule and all common survival/support rules intact.
DELETE FROM `ai_playerbot_custom_strategy`
WHERE `owner` = 0 AND `name` = 'boss_18344'
  AND ((`idx` = 1 AND `action_line` = 'val::and::{trigger::has attackers,is dps}>attack least hp target!70')
    OR (`idx` = 2 AND `action_line` = 'val::and::{trigger::target critical health,is dps}>attack!75'));
