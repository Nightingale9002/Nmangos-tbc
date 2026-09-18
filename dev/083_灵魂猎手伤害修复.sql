-- ============================================================================
-- 083_灵魂猎手伤害修复.sql（2026-09-18）
--
-- 站长反馈："任务 10540 召唤的灵魂猎手伤害很低，好像没有武器技能"
--
-- ── 结论：不是武器技能问题，是这条 creature_template 的伤害倍率被写成了 0.7% ──
--
-- 链路（已逐行核对代码）：
--   · 任务物品/技能 **36620 "Spirit Hunter"**（`spell_template.Effect1 = 28` 召唤，
--     `EffectMiscValue1 = 21332`）召唤生物 **21332 Spirit Hunter（灵魂猎手）**；
--   · 召唤走 `Spell::DoSummonGuardian()` → `GUARDIAN_PET` → `Pet::InitStatsForLevel(level)` →
--     `Creature::SelectLevel(level)`；
--   · 等级：`Spell::EffectSummonType()` 里对护卫型用的是
--     `creatureLevel = max(min(petInvoker->GetLevel(), cInfo->MaxLevel), cInfo->MinLevel)`，
--     即**被钳在模板的 [MinLevel, MaxLevel] = [70,70]** → 永远是 70 级，
--     所以**武器技能是正常的**（`Unit::GetUnitMeleeSkill()` = 等级×5 = 350），不会大量未命中。
--   · 伤害（`Creature::SelectLevel` + `Creature::UpdateDamagePhysical`）：
--       基础武器伤害 = cCLS->BaseDamage × (1 ± DamageVariance/2)        ← 来自 creature_template_classlevelstats
--       最终每击     = 基础武器伤害 × (DamageMultiplier × _GetDamageMod(rank)) + AP/14
--     70 级 / UnitClass 2 / Expansion 1 的 `BaseDamage = 261.316`，AP = 286 → AP/14 ≈ 20.4；
--     模板里 **`DamageMultiplier = 0.00702369`** → 261 × 0.007 ≈ 1.8 → **每击只有约 22 点**。
--
-- 为什么说这条值是坏的（同类对照，全部同库实测）：
--   同为「70 级 / HealthMultiplier = 5 / Rank = 0」的护卫型生物：
--     22862 Anchorite Caalen 1.0034 ｜ 21685 Oronok Torn-heart 1.6269
--     21789 Nakansi          1.8304 ｜ 21790 Plexi           2.0068
--   只有 21332 是 **0.007**（低 200 倍以上）；而且它自己的
--   `MinMeleeDmg/MaxMeleeDmg = 249/346` 是**真实数值**（不是占位 2/2），说明原意就是"每击 249~346"。
--   全库所有 `DamageMultiplier < 0.1` 的 133 个生物里，只有它同时带真实伤害字段，其余全是
--   隐形/机械/helper NPC（Astral Flare、Void Portal、Arena Event Controller…）。
--
-- 修法：把倍率改成 **1.07** —— 按它自己 249~346 的意图反算：
--     209.05 × 1.07 + 20.4 = 244.1 ～ 313.58 × 1.07 + 20.4 = 356.0
--   （新体系每击约 244~356，与模板原先声明的 249~346 基本重合）
--
-- 幂等：`WHERE entry = 21332 AND DamageMultiplier < 0.1` → 改完再跑影响 0 行（本地已复跑验证）。
-- 生效：`creature_template` 是 **mangosd 启动时载入**（`.reload` 只支持 classlevelstats，
--       不支持 creature_template）→ **必须重启**。
--
-- 备注：本地 `Rate.Creature.Normal.Damage = 0.75` 而云端是 `1`，本地测伤害会整体偏弱 25%，
--       比较伤害数字时请留意（本文件只改模板倍率，不动全局配置）。
-- ============================================================================

USE tbcmangos;

-- 改前
SELECT entry, name, ROUND(DamageMultiplier, 8) AS dmg_mult_before,
       MinMeleeDmg, MaxMeleeDmg, MeleeAttackPower
  FROM creature_template WHERE entry = 21332;

UPDATE creature_template
   SET DamageMultiplier = 1.07
 WHERE entry = 21332 AND DamageMultiplier < 0.1;

-- 改后 + 按新体系的每击估算
SELECT entry, name, ROUND(DamageMultiplier, 6) AS dmg_mult_after,
       ROUND(261.316 * (1 - 0.2) * DamageMultiplier + MeleeAttackPower / 14, 1) AS est_min_hit,
       ROUND(261.316 * (1 + 0.2) * DamageMultiplier + MeleeAttackPower / 14, 1) AS est_max_hit,
       MinMeleeDmg AS intent_min, MaxMeleeDmg AS intent_max
  FROM creature_template WHERE entry = 21332;

-- 幂等自检：再跑一次本文件的 UPDATE 应为 0 行（这里用等价条件验证）
SELECT COUNT(*) AS should_be_zero
  FROM creature_template WHERE entry = 21332 AND DamageMultiplier < 0.1;
