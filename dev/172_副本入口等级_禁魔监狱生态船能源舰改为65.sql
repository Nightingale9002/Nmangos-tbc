-- =====================================================================================
-- 172_副本入口等级_禁魔监狱生态船能源舰改为65.sql
-- 日期：2026-10-10        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】站长：禁魔监狱(The Arcatraz 552)、生态船(The Botanica 553)、能源舰(The Mechanar 554)
--   的"需要等级"应该是 **65**。
-- 【证据】`areatrigger_teleport` 这 3 行 `required_level = 68`，而**它们自己的失败提示文本**写的是
--   "You must be at least level 65 to enter." ⇒ 数据与提示自相矛盾 ✓
--   对照同表其它 TBC 副本：塞泰克大厅(555) = 65 ✓、旧希尔斯布莱德(560) = 66 ✓、
--   卡拉赞/时光之穴(548/550/585) = 70 ✓、地狱火三本+幽暗沼泽等 = 55 ✓。
-- 【修复】把 target_map 552/553/554 三行的 `required_level` 由 68 改为 **65**（只动这一个字段，其它不动）。
-- 【生效】areatrigger_teleport 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/172_回滚_副本入口等级.sql
-- =====================================================================================

UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 65
 WHERE `target_map` IN (552, 553, 554) AND `required_level` = 68;

-- ---------- 核对 ----------
-- 期望：Arcatraz/Botanica/Mechanar 三行 required_level = 65，且提示文本仍是 "level 65"
SELECT `id`, `name`, `required_level`, `target_map`, `required_item`, `status_failed_text`
  FROM `tbcmangos`.`areatrigger_teleport`
 WHERE `target_map` IN (552, 553, 554) ORDER BY `target_map`;
