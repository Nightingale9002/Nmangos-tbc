-- =====================================================================================
-- 158_炼金三专精互斥_挂RequiredCondition.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】站长完成「药水大师」后，仍能接「药剂大师」（或转化大师）的任务，三系专精不互斥。
-- 【根因】三系专精共 6 个任务模板 —— 联盟侧 10897(药水)/10902(药剂)/10899(转化)、
--   部落侧 10905(药水)/10906(药剂)/10907(转化) —— quest_template.RequiredCondition **全是 0**。
--   （tbcmangos / tbcmangos_orig / tbcdb_ref / wotlkmangos 四库一致，不是我们改坏的。）
--   核心侧 Player::SatisfyQuestExclusiveGroup（Player.cpp:14070-14080）只拦"同 ExclusiveGroup 里
--   另一个任务处于 QUEST_STATUS_INCOMPLETE / COMPLETE（在日志里未交付）"，
--   **已交付(rewarded)的不参与判断** ⇒ 交付完一个专精后 ExclusiveGroup 失效，另一个任务重新可接。
-- 【库中已有现成条件，无需新建】
--   conditions 261 = NOT ( has spell 28677 OR 28672 OR 28675 )   ← 「目前没有学过任何炼金专精」
--   （相关家族：247/248/249 = 学过某专精法术；250/251/252 = 某专精任务已交付；
--     255/256 = 三者的 OR；257/258 = 技能/等级门槛；259/260/261 = 法术侧的 OR 与 NOT；
--     262 = 261 AND 258 —— gossip_menu_option 7571/8540/8542 的「Please teach me how to become a
--     Master of X」用的就是 262，即"已经解锁过专精系统 + 当前没有专精 + 炼金>=350 + 等级>=68"，
--     这正是「先遗忘、再换专精」的设计路径。）
-- 【修复】给这 6 个任务挂上 RequiredCondition = 261：
--   ⇒ 学过任一专精后，另外两个专精任务不再提供；用 gossip 的「I wish to unlearn X Mastery」
--     （condition 248/249/247，消耗专精法术）遗忘后 261 重新成立，换专精的原设计不受影响。
--   不新增条件、不改核心、不动 gossip。
-- 【生效】quest_template 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/158_回滚_炼金专精互斥.sql
-- =====================================================================================

UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 261
 WHERE `entry` IN (10897, 10899, 10902, 10905, 10906, 10907)
   AND (`RequiredCondition` = 0 OR `RequiredCondition` = 261);

-- ---------- 核对 ----------
-- 期望：6 行，RequiredCondition 全部 = 261（ExclusiveGroup 保持 10897 / 10905 不变）
SELECT `entry`, `Title`, `RequiredCondition`, `ExclusiveGroup`, `RewSpell`, `ReqSpellCast1`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (10897, 10899, 10902, 10905, 10906, 10907)
 ORDER BY `entry`;
-- 期望：261 的定义 = NOT(28672 OR 28675 OR 28677)
SELECT `condition_entry`, `type`, `value1`, `value2`, `comments`
  FROM `tbcmangos`.`conditions` WHERE `condition_entry` IN (259, 260, 261);
