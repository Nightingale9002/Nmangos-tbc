-- Character database (tbccharacters). 夸格米拉是**按角度分散**（不是布莱卡特那种按距离）。
--
-- 口径纠正（站长 2026-11-17）：
--   · 布莱卡特（555/18667）：`ai_playerbot_encounter_tactics.separation` 是按**距离**分散（21.5 码）；
--   · 夸格米拉（547/17942）：走 `tracked_cone` 执行器，分散量是
--     `PartyPositionCoordinator.h → ComputeTrackedCone()` 里的
--        separation = TrackedConeAngle(rule) * 0.5 + rule.separationDegrees
--     即"锥角的一半 + profile 的角度增量"。
--
-- 现状：cone_degrees=82 ⇒ 锥半角 41°，separation_degrees=4 ⇒ 实际最小角间距只有 **45°**。
--   82° 的锥本身跨 82°，45° 的间距不足以把队员送出锥外（两人可同时落在 ±41° 内）。
-- 本次：separation_degrees 4 → 20 ⇒ 最小角间距 61°；5 人 × 61° = 305° < 360°，仍可排布。
--
-- 只改角度参数，不改技能数值；encounter strategy 快照有 5 秒缓存，落库即生效，不需要重启。

UPDATE `ai_playerbot_strategy_profile`
   SET `separation_degrees`=20
 WHERE `id`=1 AND `executor`='tracked_cone' AND `separation_degrees`=4;

SELECT `id`,`name`,`cone_degrees`,`separation_degrees` FROM `ai_playerbot_strategy_profile` WHERE `id`=1;
