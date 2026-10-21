-- ============================================================================
-- 201_boss_18473_spell40425_卡视野.sql（2026-10-19 站长口径）
--
-- 赛泰克大厅 · 利爪之王艾吉斯（NPC 18473 Talon King Ikiss）
-- 当它施放 40425（Arcane Explosion）时，bot 使用 flee 动作找“无视线”落点
-- （FleeManager 用 `possible targets no los` 选点），即卡视野/躲柱子。
-- 依赖：EnemyCastingTrigger 支持 `spellid::` 限定词（本次代码改动）。
-- 幂等：按 (name, action_line) 判重。
-- ============================================================================
SET NAMES utf8mb4;
USE `tbcmangos`;

INSERT INTO `ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`)
SELECT 'boss_18473', 3, 0, 'enemy casting::spellid::40425>flee!90'
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM `ai_playerbot_custom_strategy`
  WHERE `name` = 'boss_18473' AND `owner` = 0
    AND `action_line` LIKE '%enemy casting::spellid::40425%'
);

-- 复核：
--   SELECT name, idx, action_line FROM tbcmangos.ai_playerbot_custom_strategy
--   WHERE name='boss_18473' ORDER BY idx;
