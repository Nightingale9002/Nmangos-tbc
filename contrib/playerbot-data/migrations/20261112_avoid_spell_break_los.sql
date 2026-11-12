-- Apply to the CHARACTER database only, before importing the updated package.
-- Precondition: the existing ai_playerbot_avoid_spell table has no break_los column.
-- Check SHOW COLUMNS first; skip this migration when the column is already present.
-- A fresh install creates the current schema from tbc/manifest.json and needs no ALTER.
ALTER TABLE ai_playerbot_avoid_spell
    ADD COLUMN break_los TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER note;
