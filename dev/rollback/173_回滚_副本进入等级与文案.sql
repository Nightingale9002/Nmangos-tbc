-- =====================================================================================
-- 173_回滚_副本进入等级与文案.sql
-- 日期：2026-10-10        适用库：tbcmangos        类型：静态 / 幂等
-- 【用途】撤销 `dev/173`：破碎大厅/蒸汽地窟的等级改回 55、海山提示文本改回 65、
--   魔导师平台出口的文案还原。
-- 【生效】areatrigger_teleport 启动时载入 ⇒ 需重启。
-- 【原始值来源】TBCDB base（`Nmangos-tbc-db/Full_DB/TBCDB_1.10.0_ReturnOfTheVengeance.sql`）
-- =====================================================================================

-- ① 破碎大厅 65 → 55
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 55
 WHERE `id` = 4151 AND `required_level` = 65;

-- ② 蒸汽地窟 65 → 55
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 55
 WHERE `id` = 4364 AND `required_level` = 65;

-- ③ 海加尔山之战：提示文本 70 → 65
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `status_failed_text` = 'You must be at least level 65 and in a raid group to enter. You must also have The Burning Crusade installed.'
 WHERE `id` = 4319
   AND `status_failed_text` = 'You must be at least level 70 and in a raid group to enter. You must also have The Burning Crusade installed.';

-- ④ 魔导师平台出口：还原入场文案
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `status_failed_text` = 'You must be at least level 65 to enter.'
 WHERE `id` = 4885 AND `status_failed_text` IS NULL;

-- ---------- 核对 ----------
-- 期望：4151 = 55、4364 = 55、4319 文本 = "level 65 ..."、4885 文本 = "You must be at least level 65 to enter."
SELECT `id`, `name`, `required_level`, `target_map`, `status_failed_text`
  FROM `tbcmangos`.`areatrigger_teleport`
 WHERE `id` IN (4151, 4364, 4319, 4885) ORDER BY `id`;
