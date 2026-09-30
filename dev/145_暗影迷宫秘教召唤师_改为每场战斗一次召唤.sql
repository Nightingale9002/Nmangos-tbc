-- 145：暗影迷宫「秘教召唤师」(creature 18634) 改为每场战斗一次召唤
-- 站长 2026-09-30 定案：现在的表现是"一直召唤"，正确行为见参考 SmartAI ——
--   On Aggro 时各自 50% 几率召唤一次（召唤秘教侍僧 33507 / 召唤秘教死誓者 33506），不重复。
--
-- 根因（数据层，非我们改动）：creature_spell_list 1863401(N)/2064801(H) 把两个召唤放在 Position 1/2，
--   而三行的 Probability 全为 0 ⇒ UnitAI 走"按位置优先级"（UnitAI.cpp:1219/1269），
--   位置 1/2 永远压过 Position 3 的火球；且位置 1/2 的 RepeatMin/Max = 12~27 秒
--   ⇒ 冷却一到就再召一次（Creature::GetSpellCooldown = urand(RepeatMin, RepeatMax)，每 1.2 秒轮询一次）。
--   已核对：本行数据与 tbcdb_ref / tbcmangos_orig / wotlkmangos 四个库完全一致（不是我们改坏的）。
--
-- 做法：两个召唤法术从法术列表移除（列表只剩火球，普通 14034 / 英雄 15228 原样保留），
--       改用 EventAI 两条 On Aggro 50% 施放（castFlags = 1 = Interrupt current cast，目标 self）。
-- 幂等：先删后插。

DELETE FROM `tbcmangos`.`creature_spell_list` WHERE `Id` IN (1863401, 2064801) AND `SpellId` IN (33506, 33507);

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` IN (1863410, 1863411);
INSERT INTO `tbcmangos`.`creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1863410, 18634, 4, 0, 50, 0, 0, 0, 0, 0, 0, 0, 11, 33507, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - On Aggro - 50% Summon Cabal Acolyte'),
(1863411, 18634, 4, 0, 50, 0, 0, 0, 0, 0, 0, 0, 11, 33506, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Cabal Summoner - On Aggro - 50% Summon Cabal Deathsworn');
