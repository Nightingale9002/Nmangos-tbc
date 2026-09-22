-- =============================================================
-- dev/106 上游 spell_template 数据修正（批次2，2026-09-22 合并）
-- 来源：cmangos/mangos-tbc 上游提交 03938d00a / c54fbea31 / 140802b54 / 921115e06
-- 说明：全静态、幂等（每条都带"原值"条件，重跑匹配 0 行）
-- 生效：spell_template 在 mangosd 启动时载入 ⇒ 需重启（随夜间窗口）
-- 回滚：dev/rollback/106_回滚_上游spell数据修正.sql
-- =============================================================

-- ① 32578 Gor'drek's Ointment：脱战时不应被移除
--    AttributesServerSide 0x04 = SPELL_ATTR_SS_IGNORE_EVADE（SpellMgr.h:498 IsSpellRemovedOnEvade）
--    实测我们库里该值 = 0（上游已补，我们漏了），补成 4。
UPDATE `spell_template` SET `AttributesServerSide` = 4
WHERE `Id` = 32578 AND `AttributesServerSide` = 0;

-- ② 39153 Darkfury：同上（Ruul the Darkener 用）
--    ⚠ 上游提交 c54fbea31 写的是 39152，但 39152 在 spell_template 里根本不存在（上游/我们都没有），
--      是上游的 id 笔误：库里叫 Darkfury 的法术只有 39153，
--      唯一使用者就是 creature 21315 Ruul the Darkener（creature_ai_scripts 2131505 → action1 CAST_SPELL 39153）。
UPDATE `spell_template` SET `AttributesServerSide` = 4
WHERE `Id` = 39153 AND `AttributesServerSide` = 0;

-- ③ 术士 T5 四件套（自建服务端触发光环 37401/37402）叠层修复
--    AttributesEx5 = 0x20000000 → SPELL_ATTR_EX5_AURA_UNIQUE_PER_CASTER（Unit.cpp:5370 读此位）
--    Attributes     = 0xC0 → 0x80：去掉 PASSIVE，保留 DO_NOT_DISPLAY
--    上游先 140802b54 加 Ex5 位、再 921115e06 去 PASSIVE，此处合并为终态，一次写死。
UPDATE `spell_template` SET `Attributes` = 128, `AttributesEx5` = 536870912
WHERE `Id` IN (37401, 37402) AND `Attributes` = 192 AND `AttributesEx5` = 0;
