-- =====================================================================================
-- 156_暗影迷宫秘教召唤师_召唤时机改为生命50以下.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】暗影迷宫（map 555）的「秘教召唤师」(creature 18634) 一开打就召唤，
--   之后整场战斗不再召唤。站长 2026-10-06 口径：应该是**生命 <= 50% 时**才召唤。
-- 【由来】145（dev/145_暗影迷宫秘教召唤师_改为每场战斗一次召唤.sql）把两个召唤法术从
--   creature_spell_list 1863401(N)/2064801(H) 搬到 EventAI 时，事件类型写的是
--   event_type=4（EVENT_T_AGGRO）⇒ 一进战斗就掷骰触发，这才是"一开打就召唤"的原因。
-- 【修复】把 1863410 / 1863411 改为 event_type=2（EVENT_T_HP）：
--     event_param1 = 50 —— percentMax（字段顺序见 CreatureEventAI.h:641-648：percentMax/percentMin/
--                          repeatMin/repeatMax/allowOutOfCombat，与 event_param1..5 一一对应）；
--     event_param2 = 0  —— percentMin；
--     判定式 CreatureEventAI.cpp:349 `perc > percentMax || perc < percentMin` ⇒ 只有 0<=生命%<=50 才触发；
--     不设 EFLAG_REPEATABLE(0x01)、repeat 计时为 0 ⇒ 每场战斗只触发一次；
--     allowOutOfCombat=0 ⇒ 仍需处于战斗（CreatureEventAI.cpp:344）。
--   其余保持 145 的口径不变：event_chance=50（两个召唤各自 50% 掷骰）、
--     action 11(CAST) 目标 0(self) + castFlags 1(打断当前施法)。
--   event_flags=0 ⇒ CreatureEventAI.cpp:124 只在事件带 EFLAG_NORMAL|EFLAG_HEROIC 时才做难度过滤，
--     因此普通与英雄难度都生效（英雄本走 HeroicEntry 20648 取法术列表，但 EventAI 按
--     GetEntry()=18634 取脚本，见 153 的说明）。
-- 【生效】creature_ai_scripts 在服务器启动时载入 ⇒ 需重启（或 .reload creature_ai_scripts）。
-- 【回滚】dev/rollback/156_回滚_秘教召唤师召唤时机.sql（还原成 145 的"进战斗即召"版本）
-- =====================================================================================

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` IN (1863410, 1863411);
INSERT INTO `tbcmangos`.`creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1863410, 18634, 2, 0, 50, 0, 50, 0, 0, 0, 0, 0, 11, 33507, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - At HP<=50% - 50% Summon Cabal Acolyte'),
(1863411, 18634, 2, 0, 50, 0, 50, 0, 0, 0, 0, 0, 11, 33506, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - At HP<=50% - 50% Summon Cabal Deathsworn');

-- ---------- 核对 ----------
-- 期望：两行 event_type=2，event_param1=50、event_param2=0、event_chance=50、event_flags=0
SELECT `id`, `creature_id`, `event_type`, `event_chance`, `event_flags`,
       `event_param1`, `event_param2`, `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 18634 ORDER BY `id`;
-- 期望：creature_spell_list 1863401 只剩火球 14034（145 已删召唤），此处仅作旁证
SELECT `Id`, `Position`, `SpellId`, `TargetId`, `Comments`
  FROM `tbcmangos`.`creature_spell_list` WHERE `Id` IN (1863401, 2064801) ORDER BY `Id`, `Position`;
