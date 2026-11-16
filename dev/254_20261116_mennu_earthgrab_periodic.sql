-- World database (tbcmangos). 门努（17941）的被污染的地缚图腾 18176：把一次性定身改成周期性。
--
-- 现状（dev/253 那轮核查的证据）：
--   * 召唤法术 31981 持续 30 秒（DurationIndex 9），图腾法术 31983 Earthgrab 瞬发（CastingTimeIndex 1）、
--     RecoveryTime=0、根须 8 秒（DurationIndex 31）、10 码、139/2 秒物理伤害。
--   * 瞬发 ⇒ `Totem::SetTypeBySummonSpell()` 判 `TOTEM_PASSIVE` ⇒ `TotemAI::UpdateAI()` 首句就 return，
--     效果只来自 `Totem::Summon()` 的那一次 `CastSpell(nullptr, GetSpell())` ⇒ **30 秒寿命里只定身 8 秒，后 22 秒空转**。
--
-- 为什么不是 EventAI/脚本：
--   `TotemAI::UpdateAI()` 只调 `UpdateEventTimers()`，从不 `ProcessEvents()` ⇒ 给被动图腾加 creature_ai_scripts
--   定时事件不会执行；把 AIName 换成 EventAI 又会让它走 `CreatureEventAI::UpdateAI()` 的近战分支。
--   而 `Totem::SetTypeBySummonSpell()` 判 ACTIVE 的唯一依据是**图腾法术有读条时间**，所以改这两个字段：
--     CastingTimeIndex 1(0 ms) → 4(1000 ms)：让它成为 ACTIVE 图腾，TotemAI 才会周期施放；
--     RecoveryTime 0 → 10000：给周期一个节流（否则 ACTIVE 图腾每个 tick 都会重放，根须将永不脱身）。
--   结果：30 秒寿命内约 3 次（t≈0 / 11 / 22 秒）定身，每次 8 秒 —— 8 秒定身 + 约 2 秒自由。
--
-- 边界：这会改到共享的 spell_template 行（客户端 DBC 仍是旧值，读条由服务端封包驱动，显示层差异可接受）；
--   若日后找到零售的同技能脚本证据，应以证据为准并回滚本条。回滚见 dev/rollback/254_*。
--
-- 幂等：带旧值守卫，重复执行 0 行。

UPDATE `spell_template`
   SET `CastingTimeIndex`=4, `RecoveryTime`=10000
 WHERE `Id`=31983 AND `CastingTimeIndex`=1 AND `RecoveryTime`=0;

-- 验收：期望 CastingTimeIndex=4 / RecoveryTime=10000
SELECT `Id`,`SpellName`,`CastingTimeIndex`,`RecoveryTime`,`DurationIndex` FROM `spell_template` WHERE `Id`=31983;
