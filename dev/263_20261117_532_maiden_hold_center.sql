-- [2026-11-17] 532（卡拉赞）贞洁圣女：坦克把 BOSS 拉在场地中间。
--
-- 背景：`DpsFsm`/`BossArena.h` 已有数据化机制（表 ai_playerbot_boss_arena）：
--   kind='hold'   → 坦克偏离该点超过 tol 就回去（BOSS 靠仇恨跟过来）；
--   kind='bounds' → 场地圆（圆心+半径，tol 即半径）：自己不追杀出圈，越圈就回 hold 点。
-- 贞洁圣女（Maiden of Virtue, entry 16457）本体刷点就是大厅中央：
--   (-10945.9, -2103.79, 92.7942)，因此 hold = 该点、bounds 以该点为心、半径 25 码。
--
-- 幂等：PRIMARY KEY (map,boss_entry,kind,role,idx)；BossArena::Load() 每 300 秒刷新一次，无需重启。
INSERT INTO `ai_playerbot_boss_arena`
  (`map`, `boss_entry`, `kind`, `role`, `idx`, `x`, `y`, `z`, `tol`, `note`) VALUES
  (532, 16457, 'hold',   'tank', 0, -10945.9, -2103.79, 92.7942,  5, 'Maiden of Virtue: tank holds boss at hall centre'),
  (532, 16457, 'bounds', 'all',  0, -10945.9, -2103.79, 92.7942, 25, 'Maiden of Virtue: hall centre/radius')
ON DUPLICATE KEY UPDATE
  `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `tol` = VALUES(`tol`), `note` = VALUES(`note`);
