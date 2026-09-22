-- =============================================================
-- dev/rollback/107 回滚：dev/107 34700 过敏反应 SpellScript 接线
-- 说明：删除接线行即可（代码里的 SpellScript 留着无害，只是没人用）
-- 生效：需重启 mangosd
-- =============================================================

DELETE FROM `spell_scripts` WHERE `Id` = 34700 AND `ScriptName` = 'spell_allergic_reaction';
