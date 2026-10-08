-- =====================================================================================
-- 169_阿弗鲁的宝珠_法术29764补召唤脚本.sql
-- 日期：2026-10-08        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】站长在地狱火半岛「哈尔什祭坛」(GO 181606, guid 22035) 用「阿弗鲁的宝珠」时，
--   角色**一直做施法动作**、什么结果都没有、也没有任何报错。
-- 【定位链】
--   · 物品 23580 Avruu's Orb：class=12(任务物品)、`spellid_1 = 29764`、`startquest = 9418`；
--   · 法术 29764「Avruu's Orb」：`Effect1 = 59 (SPELL_EFFECT_SCRIPT_EFFECT)`、
--     `EffectImplicitTargetA1 = 23 (TARGET_GAMEOBJECT)` ⇒ 对着目标物体(祭坛)施放；
--   · `Effect 59` 的执行入口 = `Spell::EffectScriptEffect` → `ScriptsStart(SCRIPT_TYPE_SPELL, spellId, caster, gameObjTarget)`
--     （SpellEffects.cpp:2829-2832）⇒ 查表 `dbscripts_on_spell`（scriptTableNames[2]，加载器 ScriptMgrDefines.h:29）；
--   · **该表里 id=29764 一行都没有**（本库 / tbcmangos_orig / tbcdb_ref / wotlkmangos 全为 0；
--     `spell_scripts` 这张"法术→C++脚本"映射表同样没有）⇒ `ScriptsStart` 找不到脚本**静默返回**，
--     法术照常"放完"但没有任何效果、也不打日志 —— 与现象完全吻合。
--   · 对照：**祭坛点击**那条链路是好的（`dbscripts_on_go_template_use 181606`：找得到 Aeranas 就中止、
--     否则 TEMP_SPAWN 17085），云端角色库里任务 9418 已有 6 个角色 rewarded=1 ⇒ 走点击路径的人能完成；
--     而客户端在"带钥匙物品点锁住的目标"时是**用物品对其施法**（就是那串施法动作）⇒ 走的是本文件补的这条路。
-- 【修复】照抄祭坛那条脚本的语义，给法术 29764 加两行 DB 脚本（`dbscripts_on_spell`，id=法术 id）：
--   ① delay 0 / priority 0 / command 31（TERMINATE_SCRIPT：20 码内已有活着的 17085 ⇒ 中止整条脚本，
--      data_flags=8 = SCRIPT_FLAG_COMMAND_ADDITIONAL ⇒ "找到就中止"）；
--   ② delay 1 / priority 1 / command 10（TEMP_SPAWN_CREATURE：生成 Aeranas 17085，180000ms 后消失，
--      data_flags=8 = "作为 active 对象召唤"）。
--   · 脚本行的 x/y/z=0 ⇒ `WorldObject::SummonCreature` 用**施法者(玩家)的位置**召唤（Object.cpp:2200）✓；
--   · 两行都带"找到就中止"的守卫 ⇒ 即使点击路径与施法路径同时触发，也只会有一只 Aeranas ✓。
-- 【生效】dbscripts_on_spell 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/169_回滚_阿弗鲁的宝珠召唤脚本.sql
-- =====================================================================================

-- 幂等：先删后插
DELETE FROM `tbcmangos`.`dbscripts_on_spell` WHERE `id` = 29764;

INSERT INTO `tbcmangos`.`dbscripts_on_spell`
  (`id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `datalong3`, `buddy_entry`, `search_radius`,
   `data_flags`, `dataint`, `dataint2`, `dataint3`, `dataint4`, `datafloat`, `x`, `y`, `z`, `o`, `speed`,
   `condition_id`, `comments`)
VALUES
  (29764, 0, 0, 31, 17085, 20, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   'Quest: Avruu''s Orb - spell 29764 - terminate script if Aeranas found and alive within 20y'),
  (29764, 1, 1, 10, 17085, 180000, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
   'Quest: Avruu''s Orb - spell 29764 - spawn Aeranas (180s) at caster position');

-- ---------- 核对 ----------
-- 期望：2 行（31 中止 + 10 召唤），datalong 都是 17085
SELECT `id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `data_flags`, `comments`
  FROM `tbcmangos`.`dbscripts_on_spell` WHERE `id` = 29764 ORDER BY `delay`, `priority`;
-- 对照：祭坛点击脚本（应仍为 2 行，未改动）
SELECT `id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `data_flags`, `comments`
  FROM `tbcmangos`.`dbscripts_on_go_template_use` WHERE `id` = 181606 ORDER BY `delay`, `priority`;
