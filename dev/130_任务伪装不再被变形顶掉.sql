-- dev/130：任务 10776/10769 的「伪装」不再被变形类法术顶掉（清 spell_template 的 SHAPESHIFTING 中断位）—— 2026-09-26
-- ===============================================================
-- 起因（站长实测）：
--   德鲁伊变形（以及任何 MOD_SHAPESHIFT，含战士姿态）会把 38225/38227「Illidari Disguise」顶掉：
--   它们的 `AuraInterruptFlags` 带 32768 = AURA_INTERRUPT_FLAG_SHAPESHIFTING，形态切换时被
--   Unit::RemoveAurasWithInterruptFlags(AURA_INTERRUPT_FLAG_SHAPESHIFTING) 无条件移除。
--   而提供伪装的道具 31279「魔化伊利达雷战袍」是**一次性消耗品**（用一次即消失）⇒ 伪装被顶掉后
--   玩家无法再次伪装，任务 10776 的"伪装状态下击杀"体验直接断掉。
--
-- 本服法术数据来自 **DB 表 `spell_template`**（不是 DBC 文件）：
--   src/game/Server/SQLStorages.cpp:58 + src/game/World/World.cpp:936-937 + Globals/ObjectMgr.cpp:8274-8304
--   ⇒ 改数据即可生效，**无需重编译**（重启/重载后生效）。
--   退出形态时 Unit::RestoreDisplayId（src/game/Entities/Unit.cpp:10829-10855）会优先取
--   SPELL_AURA_TRANSFORM 的模型 ⇒ 外形自动恢复成伪装形态。
--
-- 影响面：38224（战袍的法术）全库只有物品 31279 使用 ⇒ 只影响 10776/10769 这一条任务链。
--
-- ⚠️ 发布方式：必须以**本编号文件**（sql/updates 走 apply_dev_sql.sh）发布；直接改 sql/base 的
--    DBC 原始数据会被重灌覆盖。
-- 幂等：带 `(AuraInterruptFlags & 32768) <> 0` 守卫的 UPDATE（重复应用 0 变更）
-- 执行对象：world 库（tbcmangos，表名不加库前缀）
-- ===============================================================

UPDATE `spell_template`
SET `AuraInterruptFlags` = `AuraInterruptFlags` & ~32768
WHERE `Id` IN (38225, 38227)
  AND (`AuraInterruptFlags` & 32768) <> 0;

-- 复核（应为两行、AuraInterruptFlags 不含 32768）：
-- SELECT Id, SpellName, AuraInterruptFlags FROM spell_template WHERE Id IN (38225,38227);
