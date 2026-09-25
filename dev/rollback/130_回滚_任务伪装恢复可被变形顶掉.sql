-- =====================================================================
-- 回滚 dev/130_任务伪装不再被变形顶掉.sql
--
-- 作用：把 38225/38227「Illidari Disguise」的 AuraInterruptFlags 恢复成带
--       32768 (AURA_INTERRUPT_FLAG_SHAPESHIFTING)，即"变形会把伪装顶掉"的原始行为。
--
-- 执行对象：world 库（tbcmangos）
-- 幂等：是（带守卫）
-- =====================================================================

UPDATE `spell_template`
SET `AuraInterruptFlags` = `AuraInterruptFlags` | 32768
WHERE `Id` IN (38225, 38227)
  AND (`AuraInterruptFlags` & 32768) = 0;
