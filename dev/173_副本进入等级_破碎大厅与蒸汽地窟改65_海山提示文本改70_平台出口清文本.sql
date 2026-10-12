-- =====================================================================================
-- 173_副本进入等级_破碎大厅与蒸汽地窟改65_海山提示文本改70_平台出口清文本.sql
-- 日期：2026-10-12        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景·重要】本表两列来源不同，一直没人对过账：
--   · `required_level` 来自 TBCDB base（Blizzard 血统，原 2.4.3 数据）
--   · `status_failed_text` 是 cmangos 贡献者 **2022-03-30 后补**的
--     （`Nmangos-tbc-db/Updates/0191_areatrigger_teleport_messages.sql`，提交 `f7e16ecb`），
--     写的是**现在怀旧服（TBC Classic）的口径** ⇒ 才会出现"55 的等级配 65 的提示"。
--   上游自己处理同类矛盾时是**以提示文本为准**（2019 `fb481f2b [CDB][2335] ... even sometimes
--   directly in conflict with the status_failed_text`），但那次只修了旧世界，TBC 行至今悬空。
--
-- 【口径】站长 2026-10-10 拍板 = **照现在怀旧服（玩家预期）**：
--   破碎大厅 65 / 蒸汽地窟 65 / 暗影迷宫 65 / 生态船·禁魔监狱·能源舰 65 / 卡拉赞 68 /
--   黑色沼泽 66 / 海加尔山 70。
--
-- 【本次实际改动 4 行】
--   ① 破碎大厅(4151, map 540)：`required_level` 55 → **65**
--      依据：2021-07-01 怀旧服暗改把【破碎大厅 / 蒸汽地窟 / 暗影迷宫】进本等级统一提到 65
--      （报道：163《TBC怀旧服暗改，破碎等副本要65级才能进了》2021-07-02、17173 同日《破碎要65级才能进了》；
--       该改动未写进更新说明）。本行自身的提示文本本来就写 65 ⇒ 改数据即自洽 ✓
--   ② 蒸汽地窟(4364, map 545)：55 → **65**（同上一次暗改；文本已是 65）✓
--   ③ 海加尔山之战(4319, map 534)：数据 `required_level = 70` 本来就是对的（与本表其它 70 档团本
--      4416/4470/4598/4889 一致），只有提示文本错写成 65（疑似从 65 档团本 4153/4535 抄来）
--      ⇒ **只改文本 65 → 70，等级列不动** ✓
--   ④ 魔导师平台**出口**触发器(4885, target_map 530)：`required_level = 0`（出口本就不该有门槛）✓，
--      但带着一句"at least level 65"的入场文案 ⇒ 按本表其它出口/无提示行的风格（4156/4311-4313/4887
--      均为 NULL）清成 **NULL**。纯文案，无功能影响（等级 0 + 无钥匙 ⇒ 该文案永不显示）。
--
-- 【未改·已确认正确】暗影迷宫(4407) = 65 ✓、生态船/禁魔监狱/能源舰(4467/4468/4469) = 65（dev/172）✓、
--   卡拉赞主门/侧门(4131/4135) = 68（dev/003，且官方 dump 里主门写 70、侧门写 68 —— 站长口径取 68）✓、
--   黑色沼泽(4320) = 66 + 前置任务 10285 ✓（站长确认"66 级 + 前置任务"）。
--
-- 【钥匙类硬门槛·已核对存在】客户端 `Lock.dbc`：lockid 1687 = 破碎大厅钥匙(28395) →
--   GO 184912 "The Shattered Halls"（map 530, guid 25826）✓；lockid 1700 = 主钥匙(24490) →
--   GO 176694 Karazhan Side Entrance + 184164 Karazhan Gatehouse Portcullis ✓。蒸汽地窟无钥匙要求 ✓。
--
-- 【生效】`areatrigger_teleport` 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/173_回滚_副本进入等级与文案.sql
-- =====================================================================================

-- ① 破碎大厅 55 → 65（收敛式守卫：幂等）
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 65
 WHERE `id` = 4151 AND `required_level` <> 65;

-- ② 蒸汽地窟 55 → 65
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `required_level` = 65
 WHERE `id` = 4364 AND `required_level` <> 65;

-- ③ 海加尔山之战：只把提示文本里的 65 改成 70（等级列 70 不动）
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `status_failed_text` = 'You must be at least level 70 and in a raid group to enter. You must also have The Burning Crusade installed.'
 WHERE `id` = 4319
   AND (`status_failed_text` IS NULL
        OR `status_failed_text` <> 'You must be at least level 70 and in a raid group to enter. You must also have The Burning Crusade installed.');

-- ④ 魔导师平台出口：清掉入场文案（出口无门槛）
UPDATE `tbcmangos`.`areatrigger_teleport`
   SET `status_failed_text` = NULL
 WHERE `id` = 4885 AND `status_failed_text` IS NOT NULL;

-- ---------- 核对 ----------
-- 期望：
--   4151 = 65 + 文本 "level 65"；4364 = 65 + 文本 "level 65"；
--   4319 = 70 + 文本 "level 70 ... and in a raid group"；4885 = 0 + 文本 NULL
SELECT `id`, `name`, `required_level`, `target_map`, `heroic_key`, `status_failed_text`
  FROM `tbcmangos`.`areatrigger_teleport`
 WHERE `id` IN (4151, 4364, 4319, 4885) ORDER BY `id`;
