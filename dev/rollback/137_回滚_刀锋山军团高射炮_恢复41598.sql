-- ============================================================================
-- 137 回滚: 刀锋山军团高射炮 (23076) 恢复原来的 41598，并删除新增的 41603 光环事件
-- ============================================================================
-- 幂等: 仅当当前值为 40075（或中间版本的 40109）时才改回 41598。
-- 注意: 41598 的 SpellVisual=0，改回后炮口将再次没有任何表现（回到"不开火"的原始状态）。
-- ============================================================================

UPDATE `tbcmangos`.`creature_ai_scripts`
SET `action1_param1` = 41598
WHERE `id` = 2307601
  AND `action1_param1` IN (40075, 40109);

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` = 2307602;

-- ---------- 核对 ----------
SELECT `id`, `creature_id`, `action1_type`, `action1_param1` FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 23076 ORDER BY `id`;
