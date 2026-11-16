-- World database. Coilfang Technician (17940, Slave Pens normal) does not take slows.
-- MechanicImmuneMask 102895560 includes MECHANIC_SNARE (bit value 1024), so the
-- movement-slow effect of Frostbolt 116 / Hamstring / Wing Clip / Crippling Poison /
-- Earthbind is dropped by Creature::IsImmuneToSpellEffect while damage still lands.
-- The whole mask is dirty data for this normal 63 elite trash: every other Slave Pens
-- humanoid trash is 0 (17938/17959/17960/17961/17962), and the heroic twin 19891
-- (69206144) has no real CC immunity. The stale set also covered ROOT/STUN/SILENCE/
-- INTERRUPT, contradicting the normal Rain-of-Fire interrupt.
-- Clear the whole field to 0. Guard accepts the original value or the earlier
-- snare-only value 102894536 (applied locally by the first revision of this patch),
-- so this file is safe to replay and a second run is a no-op.
-- 21127 Coilfang Tempest carries the same 102895560 but is intentionally not
-- touched here; report it separately if the same fix is wanted.
UPDATE creature_template
SET MechanicImmuneMask = 0
WHERE Entry = 17940 AND MechanicImmuneMask IN (102895560, 102894536);
