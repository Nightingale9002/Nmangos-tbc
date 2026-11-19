-- Character database. Static, idempotent, narrow budget raise.
--
-- Only the two Karazhan spread rules that still carry the old default
-- search_budget = 20000 are raised to 200000. A row an operator already tuned to
-- any other value does not match the WHERE clause and is left untouched, so this
-- file never silently overwrites custom configuration. Re-running is a no-op
-- (the second run matches 0 rows).
--
-- Apply on the character DB only. Verify with:
--   SELECT map, boss_entry, search_budget FROM ai_playerbot_spread_rule
--    WHERE map = 532 AND boss_entry IN (15691, 16457);
UPDATE ai_playerbot_spread_rule
   SET search_budget = 200000
 WHERE map = 532
   AND boss_entry IN (15691, 16457)
   AND search_budget = 20000;
