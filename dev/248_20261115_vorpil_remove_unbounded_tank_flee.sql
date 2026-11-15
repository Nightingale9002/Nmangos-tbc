-- Character database. Remove the incorrectly imported floor-avoidance rule.
-- A permanent add-triggered flee is not a ground-hazard observation and competes
-- with actual ground-hazard escape/working range.
-- Remove only the observed legacy tank rule; priority-five Traveler focus remains.
START TRANSACTION;
DELETE FROM `ai_playerbot_custom_strategy`
WHERE `owner`=0 AND `name`='boss_18732'
  AND `action_line`='val::and::{trigger::has nearest adds,is tank}>flee!20';
COMMIT;
