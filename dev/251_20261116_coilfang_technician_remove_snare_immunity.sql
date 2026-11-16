-- World database. Slave Pens normal trash with stale mechanic immunity.
--
-- 1) Coilfang Technician (17940) does not take slows.
-- MechanicImmuneMask 102895560 includes MECHANIC_SNARE (bit value 1024), so the
-- movement-slow effect of Frostbolt 116 / Hamstring / Wing Clip / Crippling Poison /
-- Earthbind is dropped by Creature::IsImmuneToSpellEffect while damage still lands.
-- The whole mask is dirty data for this normal 63 elite trash: every other Slave Pens
-- humanoid trash is 0 (17938/17959/17960/17961/17962), and the heroic twin 19891
-- (69206144) has no real CC immunity. The stale set also covered ROOT/STUN/SILENCE/
-- INTERRUPT, contradicting the normal Rain-of-Fire interrupt.
-- Guard accepts the original value or the earlier snare-only value 102894536
-- (applied locally by the first revision of this patch), so replay is a no-op.
--
-- 2) Coilfang Defender (17958) still resists Frost Nova.
-- MechanicImmuneMask 15205328 sets MECHANIC_ROOT (bit value 64), so Frost Nova 122's
-- root aura (EffectMechanic 7) is dropped while its damage lands. The same dirty
-- field also blocks FEAR/SILENCE/SLEEP/SHACKLE/TURN/HORROR on a normal naga trash
-- mob; no spawn aura or creature_immunities row provides it, only the template.
-- Its spell list is Shield Slam 15655 + Spell Reflection 31554, neither root-related.
--
-- The rest of Slave Pens normal trash is 0. Boss entries (17941/17942/17991) keep
-- their boss masks and are not touched. 21127 Coilfang Tempest carries the old
-- 102895560 but is intentionally not touched here; report it separately if wanted.
UPDATE creature_template
SET MechanicImmuneMask = 0
WHERE Entry = 17940 AND MechanicImmuneMask IN (102895560, 102894536);

UPDATE creature_template
SET MechanicImmuneMask = 0
WHERE Entry = 17958 AND MechanicImmuneMask = 15205328;
