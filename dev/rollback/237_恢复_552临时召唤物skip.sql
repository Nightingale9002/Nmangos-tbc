-- 237 的反向脚本：把三条“临时召唤物不该打”的数据加回去（仅在确认要恢复旧行为时使用）
-- 注意：这三条的 note 原文必须逐字一致，否则 237 的精确删除不会命中。
START TRANSACTION;

REPLACE INTO `ai_playerbot_skip_entry` (`map`, `entry`, `note`) VALUES
(552, 20864, 'Arcatraz Protean Nightmare: temporary protean add (despawns) - do not attack, wait'),
(552, 20865, 'Arcatraz Protean Horror: temporary protean add (despawns) - do not attack, wait'),
(552, 21395, 'Arcatraz Protean Spawn: protean summon (despawns) - do not attack, wait');

COMMIT;
