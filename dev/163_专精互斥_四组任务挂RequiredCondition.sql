-- =====================================================================================
-- 163_专精互斥_四组任务挂RequiredCondition.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】站长问「其他专业有没有专精互斥？」→ 全库普查结论：
--   1) gossip 发放口（NPC 的「请让我成为…」）本来就有复合条件，含 NOT(已学同族其它分支)：
--        20492 锻造主（=20490 NOT(9788|9787) + 20491 技能/已奖励）
--        20479 锻造子（=20473 NOT(17039|17040|17041) + 20478 等级/技能/已学 9787）
--        11004 工程（=11003 + ...，其中 11001 = NOT 20219 AND NOT 20222）
--        937   裁缝（=933 已奖励/技能 + 936 NOT(26801|26797|26798)）
--        262   炼金（=261 + 258；261 已由 dev/158 挂到任务上）
--   2) 任务奖励/任务脚本发放口**没有**否定条件，且 ExclusiveGroup 挡不住：
--      Player::SatisfyQuestExclusiveGroup（Player.cpp:14070-14080）只认
--      QUEST_STATUS_COMPLETE / INCOMPLETE（还在日志里），**不认 REWARDED**
--      ⇒ 交付完一个专精后，同族另一个任务重新可接 ⇒ 制皮/裁缝/工程/锻造可"多修"。
--      （对照 dev/158 炼金：同样是这个原因，靠挂 RequiredCondition 修好。）
-- 【修复】给四组任务挂 RequiredCondition（接任务即拦：Player::SatisfyQuestCondition，Player.cpp:13776-13788）：
--   · 制皮 5141/5143/5144（联盟）+ 5145/5146/5148（部落） → 903006（本文件新建）
--   · 裁缝 10831/10832/10833                              → 936（复用现成否定条件）
--   · 工程 3639/3641/3643                                → 11001（复用；注意不能挂 11003，它含"本任务链已奖励"自指）
--   · 锻造 5283/5284（联盟）+ 5301/5302（部落）           → 20490（复用）
--   新建条件只有制皮一条链（CONDITION_OR 只支持两个操作数，故嵌套）：
--     903001 = 已学 10656（龙鳞制皮）
--     903002 = 已学 10658（元素制皮）
--     903003 = 已学 10660（部族制皮）
--     903004 = 903002 OR 903003
--     903005 = 903001 OR 903004
--     903006 = NOT 903005        ← 挂给制皮三系任务
--   （判定对象用 Effect1=47 的"专精标记法术"10656/10658/10660，与 936/261/20490/20473 同一口径；
--     任务实际奖励的是 Effect1=36 的包装法术 10657/10659/10661，由 DBC 学入标记法术。）
-- 【说明】锻造的 dbscripts_on_quest_end 5283→9790 / 5284→9789 暂不动（站长 2026-10-06 定）；
--   挂上 20490 后该脚本路径同样被互斥拦住，不需要改历史脚本。
-- 【残留】RequiredCondition 只在"接任务"时校验 ⇒ 仍存在"接任务时无专精 → 之后学会 A 专精 → 再交付 B"的时间窗，
--   炼金（dev/158）同样如此；站长已定核心层不再加"同族第二分支"判定（KNOWN_ISSUES「制造专业分支技能」章）。
-- 【生效】conditions / quest_template 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/163_回滚_专精互斥.sql
-- =====================================================================================

-- ---------- A. 制皮：新建否定条件（先删后插，幂等） ----------
DELETE FROM `tbcmangos`.`conditions` WHERE `condition_entry` IN (903001, 903002, 903003, 903004, 903005, 903006);

INSERT INTO `tbcmangos`.`conditions`
  (`condition_entry`, `type`, `value1`, `value2`, `value3`, `value4`, `flags`, `comments`)
VALUES
  (903001, 17, 10656, 0,     0, 0, 0, 'Player Has Learned Spell: 10656 (Dragonscale Leatherworking)'),
  (903002, 17, 10658, 0,     0, 0, 0, 'Player Has Learned Spell: 10658 (Elemental Leatherworking)'),
  (903003, 17, 10660, 0,     0, 0, 0, 'Player Has Learned Spell: 10660 (Tribal Leatherworking)'),
  (903004, -2, 903002, 903003, 0, 0, 0, '(Elemental OR Tribal Leatherworking)'),
  (903005, -2, 903001, 903004, 0, 0, 0, '(Dragonscale OR (Elemental OR Tribal) Leatherworking)'),
  (903006, -3, 903005, 0,     0, 0, 0, 'NOT any leatherworking specialization');

-- ---------- B. 四组任务挂条件（只动 RequiredCondition 仍为 0 或已等于目标值的行） ----------
-- 制皮（联盟 5141/5143/5144 + 部落 5145/5146/5148）
UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 903006
 WHERE `entry` IN (5141, 5143, 5144, 5145, 5146, 5148)
   AND (`RequiredCondition` = 0 OR `RequiredCondition` = 903006);

-- 裁缝三系
UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 936
 WHERE `entry` IN (10831, 10832, 10833)
   AND (`RequiredCondition` = 0 OR `RequiredCondition` = 936);

-- 工程两系
UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 11001
 WHERE `entry` IN (3639, 3641, 3643)
   AND (`RequiredCondition` = 0 OR `RequiredCondition` = 11001);

-- 锻造主分支（联盟 5283/5284 + 部落 5301/5302）
UPDATE `tbcmangos`.`quest_template`
   SET `RequiredCondition` = 20490
 WHERE `entry` IN (5283, 5284, 5301, 5302)
   AND (`RequiredCondition` = 0 OR `RequiredCondition` = 20490);

-- ---------- 核对 ----------
-- 期望：16 行，RequiredCondition 分别为 903006(制皮6) / 936(裁缝3) / 11001(工程3) / 20490(锻造4)
SELECT `entry`, `Title`, `ExclusiveGroup`, `RequiredCondition`, `RewSpell`, `RewSpellCast`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (5141, 5143, 5144, 5145, 5146, 5148, 10831, 10832, 10833, 3639, 3641, 3643, 5283, 5284, 5301, 5302)
 ORDER BY `RequiredCondition`, `entry`;

-- 期望：制皮链 6 行（903001~903006），903006 的 comments = NOT any leatherworking specialization
SELECT `condition_entry`, `type`, `value1`, `value2`, `value3`, `comments`
  FROM `tbcmangos`.`conditions`
 WHERE `condition_entry` BETWEEN 903001 AND 903006
 ORDER BY `condition_entry`;

-- 期望：复用的现成条件（936 裁缝否定 / 11001 工程否定 / 20490 锻造否定 / 261 炼金否定）
SELECT `condition_entry`, `type`, `value1`, `value2`, `value3`, `comments`
  FROM `tbcmangos`.`conditions`
 WHERE `condition_entry` IN (936, 11001, 20490, 261)
 ORDER BY `condition_entry`;
