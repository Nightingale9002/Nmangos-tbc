-- =====================================================================================
-- 167_EventAI难度位修正_第二批.sql
-- 日期：2026-10-07        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】dev/166 修了泥沼巨人「30% 激怒」只在普通难度生效的问题（event_flags 缺 EFLAG_HEROIC）。
--   本条按同一判据做第二批：① 英雄侧该有却没有的事件；② 永远触发不了的死行。
--   全库普查口径：该生物有刷点 + 事件带难度位（共 193 行）→ 其中 124 行是**故意分难度**
--   （同一能力在另一难度有同族行、注释写明 Normal/Heroic），不在此列；剩下的就是下面这几条。
-- 【逐条依据】
--   1) 10899 Goraluk Anvilcrack（黑石塔，map 229，spawnMask=1 只有普通）
--      · 行 1089903「Cast Strike」flags=1205 里同时含 **EFLAG_DEBUG_ONLY(0x80)** 与 **EFLAG_HEROIC(0x04)**
--        ⇒ release 构建直接跳过（CreatureEventAI.cpp:120-121）、且该生物没有英雄刷点 ⇒ 双重死行。
--        wowhead SmartAI 三个事件全是「Normal Dungeon」：Strike(首放 5-7s / 循环 4-6s)、
--        Head Crack(5-10s / 20s)、Backhand(10s / 10s)；AC(acore_world.smart_scripts 10899) 同样给
--        Strike=15580 param 5000/7000 repeat 4000/6000、Backhand=6253 param 10000/10000。
--      · 同生物另两行（1089901 Backhand、1089902 Head Crack）用的是 flags=1025（REPEATABLE|COMBAT_ACTION，
--        不含难度位 ⇒ 两种难度都生效）⇒ 把 Strike 行统一为 1025，并校正 Strike/Backhand 的定时。
--   2) 3338 Sergra Darkthorn（贫瘠之地世界 NPC，map 1，spawnMask=1）
--      · 行 333802「Cast Whirlwind」flags=1029（只带 HEROIC）⇒ 世界地图只允许不带难度位或 EFLAG_NORMAL
--        （CreatureEventAI.cpp:88-92）⇒ **永远放不出旋风斩**；同生物另两行都是 1025 ⇒ 改回 1025。
--   3) 17734 Underbog Lord（幽暗沼泽，map 546，spawnMask=3）
--      · 行 1773403「HP 0-30% 放 8599 激怒」flags=1027（普通 only）⇒ 英雄难度整条被跳过（与泥沼巨人同款）。
--        AC 同位置写的是「Cast Enrage (No Repeat) (Normal Dungeon) + Say Line 0」⇒ 采用 No Repeat；
--        按站长口径（wowhead 显示英雄也有）⇒ flags 改 1030（NORMAL|HEROIC|COMBAT_ACTION，去掉可重复位）。
--      · 它的「生长」不缺：英雄法术列表 2018701 里有 40318（本库 = 上游，未被 dev/153 动过）。
--   4) 17976 Commander Sarannis（生态船，map 553，spawnMask=3）
--      · 行 1797606「HP 55% 放 34803 召唤增援 + relay」flags=1026（普通 only）⇒ 英雄不召唤；加英雄位 ⇒ 1030。
--   5) 17400 Felguard Annihilator（血熔炉，map 542，spawnMask=3）
--      · 行 1740001「战斗每 12s Reset Threat」flags=1027（普通 only）；AC 对应行（id3 Reset All Threat）
--        flags=0 = 无难度限制 ⇒ 补英雄位 ⇒ 1031。
-- 【生效】creature_ai_scripts 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/167_回滚_EventAI难度位修正.sql
-- =====================================================================================

-- ① 古拉鲁克：Strike 行去掉 DEBUG_ONLY/HEROIC 死位，统一 1025，并校正定时（wowhead 与 AC 一致）
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1025, `event_param1` = 5000, `event_param2` = 7000,
       `event_param3` = 4000, `event_param4` = 6000
 WHERE `id` = 1089903 AND `creature_id` = 10899 AND `event_flags` IN (1205, 1025);

-- ①b 古拉鲁克：Backhand 定时改 10s/10s
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_param1` = 10000, `event_param2` = 10000, `event_param3` = 10000, `event_param4` = 10000
 WHERE `id` = 1089901 AND `creature_id` = 10899 AND `event_flags` = 1025;

-- ② Sergra Darkthorn：旋风斩行去掉 HEROIC（世界 NPC 永远用不到），统一 1025
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1025
 WHERE `id` = 333802 AND `creature_id` = 3338 AND `event_flags` IN (1029, 1025);

-- ③ Underbog Lord：激怒加英雄难度 + 去可重复位（与泥沼巨人口径一致）
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1030,
       `comment` = 'Underbog Lord - Enrage at 0-30% HP (normal+heroic, once)'
 WHERE `id` = 1773403 AND `creature_id` = 17734 AND `event_flags` IN (1027, 1030);

-- ④ Commander Sarannis：召唤增援加英雄难度（保留"不重复"与 COMBAT_ACTION）
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1030,
       `comment` = 'Commander Sarannis - Cast Summon Reinforcement and start relay script at 55% HP (normal+heroic)'
 WHERE `id` = 1797606 AND `creature_id` = 17976 AND `event_flags` IN (1026, 1030);

-- ⑤ Felguard Annihilator：Reset Threat 加英雄难度（保留可重复）
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1031,
       `comment` = 'Felguard Annihilator - Reset Threat (normal+heroic)'
 WHERE `id` = 1740001 AND `creature_id` = 17400 AND `event_flags` IN (1027, 1031);

-- ---------- 核对 ----------
-- 期望：1089903 flags=1025(5000/7000/4000/6000)、1089901 param 10000/10000/10000/10000、
--       333802 flags=1025、1773403 flags=1030、1797606 flags=1030、1740001 flags=1031
SELECT `id`, `creature_id`, `event_type`, `event_flags`, `event_param1`, `event_param2`,
       `event_param3`, `event_param4`, `action1_param1`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts`
 WHERE `id` IN (1089901, 1089902, 1089903, 333801, 333802, 333803, 1773403, 1797606, 1740001)
 ORDER BY `id`;
