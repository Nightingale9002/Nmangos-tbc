-- ============================================================================
-- 140 刀锋山高射炮：为 40075「Fel Flak Fire」注册位置型效果脚本
-- ============================================================================
-- 站长报告：*"高射炮开火我只能看到高射炮冒火，没有看到别的效果"*；并指出
--   *"这个技能确实应该对位置释放 而不是对单位"* —— 判断正确。
--
-- 【一、为什么施放成功却什么都没有】
--   法术 40075 的两条效果目标都是**位置**：
--     Effect1 = 108 SPELL_EFFECT_DISPEL_MECHANIC（misc 21 = MECHANIC_MOUNTED）
--               → EffectImplicitTargetA1 = 18 = TARGET_LOCATION_CASTER_DEST
--     Effect2 = 98  SPELL_EFFECT_KNOCK_BACK（misc 150 / base points 49）
--               → EffectImplicitTargetA2 = 22 = TARGET_LOCATION_CASTER_SRC
--     两者半径都是 EffectRadiusIndex 29 = 6 码（SpellRadius.dbc）。
--   正式服战斗记录里该法术也确实**没有单位目标**（dest = nil，只有一个坐标）。
--
--   但本核心把 98/108 登记为 TARGET_TYPE_UNIT（SpellTargets.cpp:229 / :239），而
--   Spell::EffectDispelMechanic（SpellEffects.cpp:4371）与 Spell::EffectKnockBack（:7834）
--   都是开头 `if (!unitTarget) return;` —— **位置型目标永远拿不到 unitTarget**
--   ⇒ 施放成功（实测 `[FCANDBG] CAST ... spell=40075 castResult=0`）但两条效果一次都不执行。
--
-- 【二、本次改动】
--   新增 SD2 法术脚本 `spell_fel_flak_fire`（src/game/AI/ScriptDevAI/scripts/world/spell_scripts.cpp
--   内的 `struct FelFlakFire : public SpellScript`，在 `AddSC_spell_scripts()` 中注册），
--   用本文件把 `spell_scripts` 表指向它。脚本在施法结束时：
--     1) 取爆心：有落点(dest)用落点，否则用该法术的单位目标位置，再否则用施法者位置；
--     2) 半径取法术自身的 EffectRadiusIndex（6 码），不写死；
--     3) 遍历该地图玩家，对**爆心半径内的敌对玩家**：
--        a. `RemoveSpellsCausingAura(SPELL_AURA_MOUNTED)` —— 击落。
--           依据：所有坐骑法术都带 `Mechanic=21`(MOUNTED) + 光环 78(SPELL_AURA_MOUNTED)
--           （已核实 32235 Golden Gryphon / 28828 Nether Drake / 458 Brown Horse 等），
--           而 `Unit::Unmount()` 只清显示与坐骑标记，**移除光环才是真正的下坐骑**
--           （本库既有注释：blades_edge_mountains.cpp:3367-3370）；
--        b. `KnockBackFrom(caster, misc/10, basePoints/10)` —— 与核心
--           `Spell::EffectKnockBack` 完全相同的参数口径（15.0 水平 / 5.0 垂直）。
--
--   脚本名注册在 C++ 侧（`RegisterSpellScript<FelFlakFire>("spell_fel_flak_fire")`），
--   本文件只负责把法术 id 与脚本名关联起来。
--
-- 【生效方式】重启 world（脚本名在加载 spell_scripts 表时解析）。
-- 【幂等】仅在 (Id=40075) 不存在时插入。
-- 【回滚】dev/rollback/140_回滚_取消40075脚本注册.sql
-- ============================================================================

INSERT INTO `tbcmangos`.`spell_scripts` (`Id`, `ScriptName`)
SELECT 40109, 'spell_fel_flak_fire'
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM (SELECT `Id` FROM `tbcmangos`.`spell_scripts` WHERE `Id` = 40109) t);

-- ---------- 核对 ----------
SELECT `Id`, `ScriptName` FROM `tbcmangos`.`spell_scripts` WHERE `Id` = 40109;
