-- Character database (tbccharacters). 夸格米拉（547/17942、英雄 19894）的远程站位覆盖。
--
-- 背景（dev/_agent_tmp/quagmirran_pos_test_20261116 五轮实测）：
--   远程自己只往外走（法师 chase 请求 0 条），全部 <12 码反例都来自 tracked_cone 向外路径；
--   坦克与远程只隔 6~10 码、boss 顶点在坦克身上 ⇒ 开战 10~20 秒必然出现"远程在近战范围"，
--   30 秒后为 0。行为侧已加"开战 10 秒先站位（15 码）再输出"。
--   这里补的是**数据侧的距离**：把远程槽位下限从 8 码抬到 20 码（离 boss），让队伍不在坦克身上叠。
--
-- 实现：PartyPositionCoordinator.h → ComputeTrackedCone() 在算槽位时读
--   encountertactics::For(map, boss).rangedBossDistance；配了才生效（0 表示不覆盖）。
-- 口径：只对远程/中距/治疗生效；坦克与近战不受影响；不改变任何技能数值。
-- 幂等：带旧值守卫，重复执行 0 行。

INSERT INTO `ai_playerbot_encounter_tactics`
 (`map`,`boss_entry`,`ranged_boss_distance`,`separation`,`prefer_wall`,`heal_floor`,`opening_cooldowns`,`enabled`)
VALUES
 (547,17942,20,4,0,0,0,1),
 (547,19894,20,4,0,0,0,1)
ON DUPLICATE KEY UPDATE
 `ranged_boss_distance`=VALUES(`ranged_boss_distance`),
 `separation`=VALUES(`separation`),
 `enabled`=1;

SELECT `map`,`boss_entry`,`ranged_boss_distance`,`separation`,`enabled`
  FROM `ai_playerbot_encounter_tactics` WHERE `map`=547 ORDER BY `boss_entry`;
