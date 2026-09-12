-- ============================================================
-- 065 任务进度（ReqSpellCast / spell_scripts）修复
-- 目标库: tbcmangos (world)
-- 创建: 2026-09-12
-- ============================================================
-- 判定链（src/game/Entities/Player.cpp）
--   CastedCreatureOrGO(entry, guid, spell_id)   // 施法/使用物品路径
--     L14440  if (!qInfo->HasSpecialFlag(QUEST_SPECIAL_FLAG_KILL_OR_CAST)) continue;  -- ReqCreatureOrGOId 非 0 时自动置位
--     L14451  if (qInfo->ReqSpell[j] != spell_id) continue;                          -- 必须与传入 spell_id 严格相等
--     L14472  if (reqTarget != entry) continue;
--   KilledMonsterCredit(entry, guid)            // 击杀/脚本给分路径
--     L14391  if (qInfo->ReqCreatureOrGOId[j] <= 0) continue;                        -- 跳过 GO 目标
--     L14395  if (qInfo->ReqSpell[j] != 0) continue;                                 -- 跳过"对生物施法"型目标
--   => ReqSpellCast = 0 表示「击杀型目标」（只有 spell_id==0 的施法路径与击杀/脚本给分能命中）；
--      对「用物品@目标」型目标，ReqSpellCast 必须等于该物品法术ID。
--
-- ============================================================
-- 问题1: 任务 10457「自我保护」——对 5 处活木林树苗(184631)使用莉娜的树枝(29952)，点一次加 2 点进度
--   物品 29952 spellid_1 = 36030（DB 名: Rina's Bough；Effect1=59 OPEN_LOCK_ITEM,
--   Effect2=86 ACTIVATE_OBJECT 且 EffectMiscValue2=8=GameObjectActions::OPEN，TargetA1/A2=23 GAMEOBJECT_TARGET）
--   该法术的 2 个效果都会去调 GameObject::Use():
--     Effect1 → Spell::EffectOpenLock → Spell::SendLoot → gameObjTarget->Use(m_caster)
--     Effect2 → Spell::EffectActivateObject(OPEN) → gameObjTarget->Use(m_caster, spellInfo)
--   而 GameObject::Use 的 GOOBER 分支中 player->RewardPlayerAndGroupAtCast(this) 用默认 spellid = 0，
--   正好命中 ReqSpellCast1 = 0 → 一次点击被计 2 次。
--   修复: ReqSpellCast1 = 36030（只由 Spell::DoAllEffectOnTarget(GOTargetInfo*) 计 1 次）
-- ============================================================
UPDATE `quest_template` SET `ReqSpellCast1` = 36030 WHERE `entry` = 10457 AND `ReqCreatureOrGOId1` = -184631;

-- ============================================================
-- 问题2: 任务 10506「严峻的形势」——对血槌巨狼使用莉娜的缩小粉尘(30251/@36310)完全不给进度
--   目标写的是 21176「Bloodmaul Dire Wolf Trigger」(击杀型, ReqSpellCast1 必须保持 0)
--   进度由 ScriptDevAI 法术脚本给:
--     src/game/AI/ScriptDevAI/scripts/outland/blades_edge_mountains.cpp:1577 RinasDiminutionPowder
--     OnEffectExecute(EFFECT_INDEX_1): caster->KilledMonsterCredit(21176) + 狼转友善 + 60s 后 Reset
--   但该脚本之前"定义了从未注册"，且 spell_scripts 无 36310 行 ——
--   SpellScriptMgr::LoadScripts()（src/game/Spells/Scripts/SpellScript.cpp:80）是
--     SELECT Id, ScriptName FROM spell_scripts → 再按名字找 RegisterSpellScript 注册的 C++ 对象，
--   两者缺一即 "script does not exist. Skipping."，脚本永不执行 → 进度永远为 0。
--   代码侧修复: AddSC_blades_edge_mountains() 增加
--     RegisterSpellScript<RinasDiminutionPowder>("spell_rinas_diminution_powder");
--   DB 侧修复（本文件）: 补 spell_scripts 映射行。
--   注意: 击杀 20058 Bloodmaul Dire Wolf 不给进度是设计如此（目标生物是触发器 21176），
--         必须对狼使用缩小粉尘。ReqSpellCast1 保持 0 不要动。
-- ============================================================
INSERT INTO `spell_scripts` (`Id`, `ScriptName`) VALUES (36310, 'spell_rinas_diminution_powder')
ON DUPLICATE KEY UPDATE `ScriptName` = VALUES(`ScriptName`);

-- ============================================================
-- 问题3: 10457 点完树枝后"该出现的树人卫士/雷云特效没出现"
--   原因A: GO 184631 的 goober spellId = 36024 在 spell_template 里不存在
--          （库里 29349 条，36015-36040 段唯独缺 36024）→ 每次点都刷
--          "ERROR:WORLD: unknown spell id 36024 at use action for gameobject"。
--          换成实际存在的 36037「Rina's Bough Lightning Cloud Visual」
--          （Effect1=27 PERSISTENT_AREA_AURA，ImplicitTargetA1=18 DEST_CASTER → 在施法者脚下起雷云）。
--   原因B: 树人卫士 21072 Living Grove Defender 在全服 0 刷点，也没有任何法术/脚本指向它
--          （只有 27 个触发器 21074 是刷出来的）。用 GO 模板脚本补召唤：
--          command 10 TEMP_SPAWN_CREATURE, datalong=21072, datalong2=120000(2分钟),
--          dataint=1(setRun)；x/y/z 全 0 → 依 Entities/Object.cpp:2138 会刷在施法者身边。
--          （该表无主键，用 DELETE + INSERT 保证可重复执行）
-- ============================================================
UPDATE `gameobject_template` SET `data10` = 36037 WHERE `entry` = 184631 AND `data10` = 36024;

DELETE FROM `dbscripts_on_go_template_use` WHERE `id` = 184631;
INSERT INTO `dbscripts_on_go_template_use`
    (`id`, `delay`, `priority`, `command`, `datalong`, `datalong2`, `datalong3`, `dataint`, `data_flags`, `x`, `y`, `z`, `o`, `comments`)
VALUES
    (184631, 0, 0, 10, 21072, 120000, 0, 1, 0, 0, 0, 0, 0, 'Grove Seedling (184631): temp summon Living Grove Defender 21072, 120s');

-- ---------- 校验 ----------
-- 期望: 10457 => ReqCreatureOrGOId1=-184631 / 5 / ReqSpellCast1=36030
--       10506 => ReqCreatureOrGOId1=21176   / 5 / ReqSpellCast1=0
--       spell_scripts => 36310 / spell_rinas_diminution_powder
SELECT `entry`, `ReqCreatureOrGOId1`, `ReqCreatureOrGOCount1`, `ReqSpellCast1`
FROM `quest_template` WHERE `entry` IN (10457, 10506);
SELECT * FROM `spell_scripts` WHERE `Id` = 36310;
SELECT `entry`, `data10` FROM `gameobject_template` WHERE `entry` = 184631;
SELECT * FROM `dbscripts_on_go_template_use` WHERE `id` = 184631;

-- ---------- 回滚 ----------
-- UPDATE `quest_template` SET `ReqSpellCast1` = 0 WHERE `entry` = 10457;
-- DELETE FROM `spell_scripts` WHERE `Id` = 36310;
-- UPDATE `gameobject_template` SET `data10` = 36024 WHERE `entry` = 184631;
-- DELETE FROM `dbscripts_on_go_template_use` WHERE `id` = 184631;
