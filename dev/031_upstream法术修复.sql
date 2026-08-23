-- =============================================================
-- 卡布奇诺 TBC - upstream 法术修复增量 SQL（2026-08-23 合并）
-- 来源: cmangos/mangos-tbc upstream 4 个提交（9bb249766/ac6a89508/9802b03ba/f44f0ca1f）
-- 说明: 幂等（可重复执行），仅改 spell_template 指定行
-- 生效: 需重启 mangosd（spell_template 启动时加载）或 .reload spell_template
-- =============================================================

USE tbcmangos;

-- 1. 大地之盾 +治疗系数修正（974/32593/32594 -> 0.286）
UPDATE spell_template SET EffectBonusCoefficient1=0.286 WHERE Id IN (974,32593,32594);

-- 2. 寒冰箭 Winter's Chill 不独立叠加（12579 -> AttributesEx|0x800）
UPDATE spell_template SET AttributesEx=AttributesEx|0x00000800 WHERE Id IN(12579);

-- 3. 温莎狂暴 15167 不被 Evade 移除（AttributesServerSide|0x04）
UPDATE `spell_template` SET `AttributesServerSide` = `AttributesServerSide`|0x00000004 WHERE `Id` = 15167;

-- 4. 风怒 32912 不被 Evade 移除（AttributesServerSide|0x04）
UPDATE `spell_template` SET `AttributesServerSide` = `AttributesServerSide`|0x00000004 WHERE `Id` = 32912;

