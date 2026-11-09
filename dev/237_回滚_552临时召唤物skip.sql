-- 237 回滚 552 临时召唤物的错误 skip_entry（本地已执行，云端未同步）
-- 背景：2026-11-07 11 图 55 组 3600s 实测显示这些“会消失”的 Protean 召唤物并不消失，
--   552 共死 448 次，其中 Protean Horror(20865) 287 次；而 [EVADEFIX]/[UNREACH] 证明它们
--   脱战回满血、队伍打不死。原数据“do not attack, wait”前提不成立。
-- 说明：DungeonRoute.h 自 2026-10-26 起已不加载 ai_playerbot_skip_entry，本次仅清错误数据，
--   运行时行为不变，不需要重启/reload。保留 21186（Arcane Warder Target: 不可攻击脚本目标）。
START TRANSACTION;

DELETE FROM `ai_playerbot_skip_entry`
WHERE `map` = 552 AND `entry` = 20864
  AND `note` = 'Arcatraz Protean Nightmare: temporary protean add (despawns) - do not attack, wait';

DELETE FROM `ai_playerbot_skip_entry`
WHERE `map` = 552 AND `entry` = 20865
  AND `note` = 'Arcatraz Protean Horror: temporary protean add (despawns) - do not attack, wait';

DELETE FROM `ai_playerbot_skip_entry`
WHERE `map` = 552 AND `entry` = 21395
  AND `note` = 'Arcatraz Protean Spawn: protean summon (despawns) - do not attack, wait';

COMMIT;
