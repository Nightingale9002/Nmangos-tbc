-- World database. Big Bad Wolf (17521): enable normal MMAP pathfinding.
-- Remove only MMAP_FORCE_DISABLE (0x4000); retain INSTANCE_BIND and AGGRO_ZONE.
-- Static guard preserves unexpected future template changes. Safe to repeat.
UPDATE creature_template SET ExtraFlags = 513 WHERE Entry = 17521 AND ExtraFlags = 16897;
