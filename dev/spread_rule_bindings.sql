-- Character database. Static, idempotent bindings for the two locally tuned
-- Karazhan spread rules only. No other table is touched.
--
-- No-overwrite strategy: ON DUPLICATE KEY UPDATE assigns the primary-key column
-- to itself, so an existing row (including operator-tuned values that are not
-- known here) is left byte-for-byte unchanged; only a missing row is inserted
-- with the explicit constants below. Re-running this file is therefore a no-op.
-- Rows: map 532 / entry 16457 (Maiden ring) and 532 / entry 15691 (Curator local).

INSERT INTO ai_playerbot_spread_rule
  (map, boss_entry, enabled, layout, distance_mode, angular_mode,
   radius_min, radius_max, preferred_radius, min_separation, bounce_distance,
   cone_angle_deg, cone_range, max_affected, pair_distance_max,
   move_role_mask, count_role_mask, pair_los, arrival_tolerance, replan_distance,
   sample_step, search_budget, center_set, center_x, center_y, center_z,
   tank_bearing_deg, boss_tolerance, dps_boss_range_max, healer_member_range_max)
VALUES
  (532, 16457, 1, 'ring', 1, 0,
   14, 30, 18, 10, 8,
   0, 0, 1, 0,
   28, 28, 0, 0.5, 3,
   2, 200000, 1, -10945.9, -2103.79, 92.7942,
   0, 2, 35, 40),
  (532, 15691, 1, 'local', 1, 0,
   0, 35, 18, 12, 10,
   0, 0, 1, 0,
   28, 28, 0, 0.5, 3,
   2, 200000, 1, -11070, -1830, 165.765,
   0, 2, 35, 40)
ON DUPLICATE KEY UPDATE map = map;
