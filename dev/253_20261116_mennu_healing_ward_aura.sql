-- World database (tbcmangos). 门努（17941）的治疗图腾 20208 补回光环 34978。
--
-- 现象：这场战斗里治疗图腾从来不回血（本站一直在打「门努没有回血」）。
--
-- 根因（静态证据，见 _agent_tmp/mennu_totem_audit_20261116/REPORT.md）：
--   1. 召唤法术 34980 的 SummonProperties = 121，该 prop 的 Title = NONE（不是 TOTEM），
--      `Spell::EffectSummonType()` 因此走 `DoSummonWild()`，造出来的是 TemporarySpawn，
--      **不是 Totem 对象**；`Totem::Create()` / `Totem::Summon()` 那条"图腾法术"路径整条不执行。
--   2. 20208 在 `creature_template_addon` 里没有行 ⇒ 34978 这条永久光环从未被挂上 ⇒
--      每 2 秒触发 34977（治疗 2313–2688、10 码、排除自身）的链路根本不存在。
--
-- 修法：按"非 Totem 的野外召唤物靠 addon 光环生效"这条既有路径补光环。
--   `Creature::Create()` → `Creature::LoadCreatureAddon()` → 对 `cainfo->auras` 逐个
--   `CastSpell(this, *cAura)`；`Creature::GetCreatureAddon()` 会回退到
--   `ObjectMgr::GetCreatureTemplateAddon(GetEntry())`，所以模板行对召唤物同样有效。
--
-- 不动：召唤属性（仍是 retail 的 121）、法术数值、AIName。
--   AIName=TotemAI 在 20208 上不会被实例化 —— `TotemAI::Permissible()` 要求
--   `Creature::IsTotem()`（= `m_subtype == CREATURE_SUBTYPE_TOTEM`），而野外召唤的 subtype 是
--   TEMPORARY_SUMMON ⇒ 该 AI 被工厂拒绝，落到 NullCreatureAI，不构成 UB，故不改 AIName。
--
-- 幂等：重复执行零变更。

INSERT INTO `creature_template_addon` (`entry`,`auras`) VALUES (20208,'34978')
ON DUPLICATE KEY UPDATE `auras`=VALUES(`auras`);

-- 验收：期望 1 行，auras='34978'
SELECT `entry`,`auras` FROM `creature_template_addon` WHERE `entry`=20208;
