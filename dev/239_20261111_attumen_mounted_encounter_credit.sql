-- World database: Attumen encounter credit belongs to the final mounted form.
-- 15550 is death-prevented during phase two; the final killed creature is 16152.
-- Encounter 652 -> bit 0 -> worldstate 2315 gates the stable trash on map reload.
UPDATE instance_encounters SET creditEntry = 16152
WHERE entry = 652 AND creditType = 0 AND creditEntry = 15550;
