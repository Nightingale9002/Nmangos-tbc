-- 任务 10911「开火！」：任务物品 31807（自然能量炮弹）使用后无效果（2026-09-16）
--
-- 根因（本地打点实测确认，证据链完整）：
--   31807 使用 → 法术 39219（Effect1 = APPLY_AURA；EffectApplyAuraName = 6 = SPELL_AURA_MOD_CHARM；
--   目标 38 = TARGET_UNIT_SCRIPT_NEAR_CASTER，经 spell_script_target 39219 → 22443 死亡之门邪能火炮）
--   → 但火炮 creature_template.StaticFlags3 = 2097216 = 0x200040，含 **0x200000 = IMMUNE_TO_PLAYER_BUFFS**
--     （CreatureDefines.h:126）
--   → Spell::EffectApplyAura（SpellEffects.cpp:3149-3152）判定
--     "玩家控制的施法者 + 生物目标 + 免疫玩家增益 + 该 aura 为增益" → **直接 return，aura 根本不创建**
--   → 因此 Aura::HandleModCharm / Unit::TakeCharmOf / Player::CharmSpellInitialize 全都不执行，
--     玩家拿不到火炮控制权；而 AI 的 SpellHit 回调照旧触发，表现为"火炮转一下头然后没反应"。
--
--   实测日志（本地 x64_Debug，2026-09-16 19:04~19:05）：
--     [CANNONDBG] 39219 landed on Creature (Entry: 22443 ...): charmer=none hasAura39219=0   ← 命中了
--     （且**没有任何 [CHARMDBG] 行** → 魅惑链路一步都没走）
--
--   为何被判为"增益"：IsPositiveAuraEffect（SpellMgr.h:1489）——该法术 AttributesEx4 无 AURA_IS_BUFF、
--   Attributes 无 AURA_IS_DEBUFF，且目标 38（TARGET_UNIT_SCRIPT_NEAR_CASTER）不属于负面目标 →
--   返回 true（增益）。而 39219 并未列入 IsPositiveEffect 的硬编码特例表。
--
-- 修法：清掉 22443 的 IMMUNE_TO_PLAYER_BUFFS 位（保留 0x40 = NO_FRIENDLY_AREA_AURAS，无害）。
--   副作用说明：该炮从此可以被玩家的增益/治疗 aura 命中（原本设计是"免疫玩家增益"）；
--   它是任务交互对象，可接受。若要保持"免疫增益"语义，可改为代码层放行 charm/possess 类 aura
--   （SpellEffects.cpp:3149 的条件里排除 SPELL_AURA_MOD_CHARM / MOD_POSSESS / MOD_POSSESS_PET），
--   需另行确认。
--
-- 幂等，可重复执行

UPDATE tbcmangos.creature_template
   SET `StaticFlags3` = `StaticFlags3` & ~2097152
 WHERE `entry` = 22443;
