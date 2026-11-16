-- Character database (tbccharacters). 夸格米拉（547/17942）酸液喷射的锥角按真实伤害技能校正。
--
-- 证据（dev/quagmirran_audit_20261114 的只读核查，DBC 与本地逐文件 MD5 一致）：
--   父技能 38153 是引导，实际伤害来自子技能 38163：EffectRadiusIndex=21 → 35 码，spell_cone = 82°。
-- 现状问题：`ai_playerbot_strategy_profile` id=1（Quagmirran - tracked acid spray）里
--   cone_degrees 只有 60°，比真实伤害锥窄 22° ⇒ 非点名成员站在 60°~82° 的扇区里时
--   不被判定为"危险"，不会被改派，于是连续吃 38163（复测里恢复萨连吃 3 次）。
--
-- 只改锥角；radius_effect=1 已经表示"用伤害技能的半径"，separation/radial/search 不动。
-- 幂等：带旧值守卫（=60 才改），重复执行 0 行。

UPDATE `ai_playerbot_strategy_profile`
   SET `cone_degrees`=82
 WHERE `id`=1 AND `executor`='tracked_cone' AND `cone_degrees`=60;

SELECT `id`,`name`,`executor`,`channel_spell`,`damage_spell`,`radius_effect`,`cone_degrees`,`separation_degrees`
  FROM `ai_playerbot_strategy_profile` WHERE `id`=1;
