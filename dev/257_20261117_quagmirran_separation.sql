-- Character database (tbccharacters). 夸格米拉的分散间距。
--
-- 背景：线上 8 场（11-17 08:42–09:03）里酸液喷射 38163 命中 138 次 / 10.4 万伤害，
--   多人同时吃锥。`ai_playerbot_encounter_tactics.separation` 是"队员之间的最小间距（码）"，
--   `PartyPositionCoordinator.h` 用它 `Dist2d(x,y,s.x,s.y) < rule.separation → reject`。
--   我在 dev/256 里把它写成了 4 码（等于没有分散），这里改成 20 码，和布莱卡特（21.5）同一量级。
--
-- 只影响站位，不改技能数值；tactics 有 5 秒缓存，落库即生效，不需要重启。

UPDATE `ai_playerbot_encounter_tactics`
   SET `separation`=20
 WHERE `map`=547 AND `boss_entry` IN (17942,19894) AND `separation`=4;

SELECT `map`,`boss_entry`,`ranged_boss_distance`,`separation` FROM `ai_playerbot_encounter_tactics` WHERE `map`=547;
