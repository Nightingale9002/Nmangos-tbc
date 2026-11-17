-- Character database (tbccharacters). 夸格米拉的**距离兜底**间距。
--
-- ⚠️ 口径纠正（2026-11-17，站长）：夸格米拉走 tracked_cone，分散是**按角度**算的
--   （`ai_playerbot_strategy_profile.separation_degrees`，见 dev/258）；
--   `ai_playerbot_encounter_tactics.separation` 是按**距离**分散，只有通用阵型
--   （MODE_ROLE_BANDS/FRONTAL 那条 `Compute()` 路径）才会用，布莱卡特就是这种。
--   本条只作为"执行器没跑/退回通用阵型"时的兜底，不是这场的主旋钮。
--
-- 背景：线上 8 场（11-17 08:42–09:03）酸液喷射 38163 命中 138 次 / 10.4 万，
--   多人同时吃锥。原来这里写的是 4 码（我在 dev/256 里配的），等于没有距离分散。
--
-- 只影响站位，不改技能数值；tactics 有 5 秒缓存，落库即生效，不需要重启。

UPDATE `ai_playerbot_encounter_tactics`
   SET `separation`=20
 WHERE `map`=547 AND `boss_entry` IN (17942,19894) AND `separation`=4;

SELECT `map`,`boss_entry`,`ranged_boss_distance`,`separation` FROM `ai_playerbot_encounter_tactics` WHERE `map`=547;
