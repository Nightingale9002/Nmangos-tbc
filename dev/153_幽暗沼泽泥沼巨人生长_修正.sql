-- =====================================================================================
-- 153_幽暗沼泽泥沼巨人生长_修正.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】幽暗沼泽（map 546）的泥沼巨人（Bog Giant，普通 entry 17723 / 英雄 entry 20164）
--   一进战斗就放「生长」(40318)，并且之后每 10 秒反复放；参考行为是「生命 <=50% 时只放一次」。
-- 【根因】英雄难度下取得的是 HeroicEntry 20164 的 SpellList = 2016401，其中 Position=1 为
--     SpellId=40318(生长) TargetId=2(self) InitialMin/Max=10000 RepeatMin/Max=10000 Availability=100
--   ⇒ 进战斗 10 秒必放、之后每 10 秒再放，全程没有任何血量条件（这就是"开局就放"）。
--   依据：Creature::InitEntry 只在英雄本把 m_creatureInfo 换成 HeroicEntry（Creature.cpp:391-406），
--         而 Creature.cpp:687 读的是 GetCreatureInfo()->SpellList ⇒ 英雄本用 2016401；
--         EventAI 脚本表按 GetEntry() 取、而 SetEntry 永远写普通 entry（Creature.cpp:405、
--         CreatureEventAI.cpp:186）⇒ EventAI 行要挂在 **17723** 上，普通+英雄都吃得到。
-- 【修复】
--   ① 删掉 2016401 的第 1 位（英雄版的循环"生长"）。
--   ② 给 17723 加一行 EventAI：生命 <=50% 时施放 40318，目标 self(0)，打断当前施法(32)，只放一次
--      （flags=6 = EFLAG_NORMAL|EFLAG_HEROIC；不设 0x01 可重复位 ⇒ 一次性）。
--   ③ 原有 1772301「30% 激怒 + 喊话」保持不变。
-- 【生效】creature_spell_list / creature_ai_scripts 均为启动时载入 ⇒ 需重启
--   （或 .reload creature_spell_list / .reload creature_ai_scripts）；云端随下一次夜间重启生效。
-- 【回滚】dev/rollback/153_回滚_幽暗沼泽泥沼巨人生长.sql
-- =====================================================================================

-- ① 移除英雄版法术列表里的循环「生长」（守卫：三项都对上才删）
DELETE FROM `tbcmangos`.`creature_spell_list`
 WHERE `Id` = 2016401 AND `Position` = 1 AND `SpellId` = 40318;

-- ② 新增 EventAI 行：<=50% 生命放一次生长（自己为目标，打断当前施法）
DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` = 1772302;
INSERT INTO `tbcmangos`.`creature_ai_scripts`
 (`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
  `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
  `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
  `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
  `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
 (1772302, 17723, 2, 0, 100, 6,
  50, 0, 0, 0, 0, 0,
  11, 40318, 0, 32,
  0, 0, 0, 0,
  0, 0, 0, 0,
  'Bog Giant - Cast Growth at <=50% HP (once, normal+heroic)');

-- ---------- 核对 ----------
-- 期望：2016401 只剩 Trample(15550) / Fungal Decay(32065)
SELECT `Id`, `Position`, `SpellId`, `TargetId`, `InitialMin`, `InitialMax`, `RepeatMin`, `RepeatMax`, `Comments`
  FROM `tbcmangos`.`creature_spell_list` WHERE `Id` = 2016401 ORDER BY `Position`;
-- 期望：17723 有两行 —— 1772301（30% 激怒）、1772302（50% 生长，flags=6）
SELECT `id`, `creature_id`, `event_type`, `event_flags`, `event_param1`, `event_param2`,
       `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 17723 ORDER BY `id`;
