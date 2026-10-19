-- dev/174 恐惧魔(Fear Fiend 22204) 补"恐惧触发"光环；深渊烈焰行者(Abyssal Flamebringer 19973) 改官方技能
-- 依据（2026-10-14，站长口径"按官方来"）：
--   ① 22204 的官方机制是 10% 概率的 proc 光环：35408 "Fear Proc"
--      (EffectApplyAuraName1 = 42 PROC_TRIGGER_SPELL → EffectTriggerSpell1 = 34259 Fear，ProcChance = 10，DurationIndex = 21)
--      但 creature_template_addon.auras 是 NULL ⇒ 光环从未挂上 ⇒ 恐惧永不触发。
--      对照 AzerothCore 同款修复：fix(DB/Creature): Add Fear proc aura to Fear Fiend (#17735)。
--   ② 22204 原有 EventAI 定时施放 36248(邪能烈焰) 是错的：该法术是"给自己挂光环 + 每秒周期性触发 36820"的
--      **引导型自我增益**（Effect1=142 Trigger Spell with Value → 36820；Effect2=6 Apply Aura(23 周期触发, 每 1000ms) → 36820），
--      当成"对目标定时施放"会出现一次施法里"直伤 + 每秒跳伤"叠加 ⇒ 站长反馈"邪能烈焰伤害过高"；
--      且网上数据库的 Fear Fiend 技能表里并没有这条。
--      同时"定时施放 34259 恐惧"被上面的 proc 机制取代 ⇒ 一并移除。
--   ③ 19973 原本只用 37633 Abyssal Strike(Effect1=32 Trigger Missile → 45015，基础伤害仅 89≈90)
--      ⇒ 站长反馈"Abyssal Meteor Fall 伤害过低"。同名怪 25001 Abyssal Flamewalker 的官方行是
--      spawn 时施放 12743(献祭) + 45227(Abyssal Meteor Fall) ⇒ 照此把 1997301 改成 spawn 形态
--      （保留 1997302 = 死亡时移除献祭 12743，与 creature_template_addon.auras='12743' 配套）。
-- 全部语句幂等，可重复执行；rollback 见 dev/rollback/174_回滚_恐惧魔与深渊烈焰行者技能.sql

-- ① 补 proc 光环（原值为 NULL）
UPDATE creature_template_addon SET auras = '35408' WHERE entry = 22204;

-- ② 移除不属于该怪的定时邪能烈焰(36248)与被 proc 取代的定时恐惧(34259)
DELETE FROM creature_ai_scripts WHERE id IN (2220401, 2220402);

-- ③ 19973：改为 spawn 时施放 献祭(12743) + 深渊流星(45227)，字段组合照抄官方行 2500101
UPDATE creature_ai_scripts
   SET event_type = 11, event_inverse_phase_mask = 0, event_chance = 100, event_flags = 0,
       event_param1 = 0, event_param2 = 0, event_param3 = 0, event_param4 = 0, event_param5 = 0, event_param6 = 0,
       action1_type = 11, action1_param1 = 12743, action1_param2 = 0,  action1_param3 = 34,
       action2_type = 11, action2_param1 = 45227, action2_param2 = 15, action2_param3 = 34,
       action3_type = 0,  action3_param1 = 0,    action3_param2 = 0,  action3_param3 = 0,
       comment = 'Abyssal Flamebringer - Cast Immolation and Abyssal Meteor Fall on Spawn'
 WHERE id = 1997301 AND creature_id = 19973;
