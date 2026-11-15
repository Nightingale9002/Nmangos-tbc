-- Character database (tbccharacters). Data-only priority for Vorpil's travelers.
-- Both templates are normal-rank enemies: the shared priority-5 executor can
-- kill them without waiting for tank threat. Boss mechanics remain unchanged.
START TRANSACTION;
DELETE FROM `ai_playerbot_priority_target` WHERE `entry` IN (19226,20664);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`) VALUES
(19226,5,'observed','Vorpil: intercept Void Traveler before Shadow Nova heals and empowers the boss'),
(20664,5,'observed','Vorpil heroic: intercept Void Traveler before Shadow Nova heals and empowers the boss');
COMMIT;
