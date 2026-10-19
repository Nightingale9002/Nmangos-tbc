-- =====================================================================================
-- 164_锻造专精奖励改走RewSpellCast_收口脚本路径.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【起因】站长问「最后奖励新专精时有没有校验当前的父专业技能？」→ 复查核心守门（两处，均在）：
--   ① 交付那刻：Player::RewardQuest（Player.cpp:13617）= 若奖励法术属于制造专业/专精
--      （GrantsProfessionTradeSkill，Player.cpp:13434-13453）则必须仍满足本任务的
--      RequiredSkill/RequiredSkillValue（SatisfyQuestSkill，Player.cpp:13756-13774），
--      不满足就**跳过奖励法术**（物品/金钱/声望照给）。
--   ② 学习那刻：Player::learnSpell（Player.cpp:3658-3666）= 所有路径（任务奖励 cast / dbscripts
--      command 15 / gossip cast / 训练师 / .learn）都经 Spell::EffectLearnSpell
--      （SpellEffects.cpp:4339-4340）汇入此处，专精法术（Effect=47 且 misc 全 0 + 有 spell_chain）
--      要求父专业技能 != 0，否则拒绝并记日志。
-- 【漏洞】`dbscripts_on_quest_end 5283/5284` 是**脚本直接 cast**（command 15），**不过 RewardQuest**
--   ⇒ 只有 ② 生效（父专业 != 0，即"锻造掉到 1 点"也能拿），① 的等级档校验被绕过。
-- 【修法】与 wotlkmangos 数据完全一致：把奖励写成 **quest_template.RewSpellCast**
--   （5283 → 9790 防具锻造包装、5284 → 9789 武器锻造包装；RewSpell 保持 0），
--   并删掉那 2 行脚本（否则会双次 cast）。
--   改完后两条路都齐：RewardQuest 查"锻造 ≥ 200"（本任务 RequiredSkillValue=164/200）
--   + EffectLearnSpell → learnSpell 兜底"锻造 != 0"。部落侧 5301/5302 本来就不发奖
--   （发放口是 gossip 20492，条件自带"锻造 >= 225"），不动。
-- 【对照】wotlkmangos：5283/5284 RewSpell=0、RewSpellCast=9790/9789（与本文件同款）；
--   classicmangos_ref：RewSpell=9788/9787 + RewSpellCast=9790/9789。
-- 【生效】quest_template / dbscripts 均为启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/164_回滚_锻造专精奖励.sql
-- =====================================================================================

-- ---------- A. 奖励法术改走 quest_template（优先于脚本，且过核心两层校验） ----------
UPDATE `tbcmangos`.`quest_template`
   SET `RewSpellCast` = 9790
 WHERE `entry` = 5283
   AND `RewSpellCast` IN (0, 9790);

UPDATE `tbcmangos`.`quest_template`
   SET `RewSpellCast` = 9789
 WHERE `entry` = 5284
   AND `RewSpellCast` IN (0, 9789);

-- ---------- B. 删掉绕过校验的 2 行脚本（命令 15 = CAST_SPELL） ----------
DELETE FROM `tbcmangos`.`dbscripts_on_quest_end`
 WHERE `id` IN (5283, 5284)
   AND `command` = 15
   AND `datalong` IN (9790, 9789);

-- ---------- 核对 ----------
-- 期望：5283 → RewSpellCast 9790、5284 → 9789；RewSpell 均 0；RequiredSkill 164 / RequiredSkillValue 200
SELECT `entry`, `Title`, `RewSpell`, `RewSpellCast`, `RequiredSkill`, `RequiredSkillValue`, `RequiredCondition`
  FROM `tbcmangos`.`quest_template`
 WHERE `entry` IN (5283, 5284, 5301, 5302)
 ORDER BY `entry`;

-- 期望：0 行（脚本已删）
SELECT `id`, `command`, `datalong`, `comments`
  FROM `tbcmangos`.`dbscripts_on_quest_end`
 WHERE `id` IN (5283, 5284);

-- 期望：9790 → 9788(防具锻造) / 9789 → 9787(武器锻造)，即包装法术仍指向 Effect=47 的标记法术
SELECT `Id`, `SpellName`, `Effect1`, `EffectTriggerSpell1`
  FROM `tbcmangos`.`spell_template`
 WHERE `Id` IN (9790, 9789, 9788, 9787)
 ORDER BY `Id`;
