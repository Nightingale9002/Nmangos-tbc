-- =====================================================================================
-- 172_回滚_副本入口等级.sql
-- 回滚 dev/172_副本入口等级_禁魔监狱生态船能源舰改为65.sql
-- 日期：2026-10-10        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 把 552/553/554 的 `required_level` 由 65 改回原值 68。
-- 【生效】areatrigger_teleport 启动时载入 ⇒ 需重启。
-- =====================================================================================

UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 68
 WHERE `target_map` IN (552, 553, 554) AND `required_level` = 65;

-- ---------- 核对 ----------
SELECT `id`, `name`, `required_level`, `target_map`
  FROM `tbcmangos`.`areatrigger_teleport`
 WHERE `target_map` IN (552, 553, 554) ORDER BY `target_map`;
