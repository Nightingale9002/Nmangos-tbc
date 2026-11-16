-- World database. Coilfang Technician (17940, Slave Pens normal) does not take slows.
-- MechanicImmuneMask 102895560 includes MECHANIC_SNARE (bit value 1024), so the
-- movement-slow effect of Frostbolt 116 / Hamstring / Wing Clip / Crippling Poison /
-- Earthbind is dropped by Creature::IsImmuneToSpellEffect while damage still lands.
-- Normal 63 elite trash should not be snare-immune: every other Slave Pens humanoid
-- trash is 0 (17938/17957/17959/17960/17961/17962), and the heroic twin 19891
-- (69206144) is not snare-immune either.
-- Remove only MECHANIC_SNARE (0x400); keep all other bits untouched so this patch
-- is limited to the reported symptom. Static guard applies once to the observed
-- value, so re-running is a no-op.
-- 21127 Coilfang Tempest carries the same 102895560 but is intentionally not
-- touched here; report it separately if the same fix is wanted.
UPDATE creature_template
SET MechanicImmuneMask = 102894536
WHERE Entry = 17940 AND MechanicImmuneMask = 102895560;
