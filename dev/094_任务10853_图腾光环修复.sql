-- 094_任务10853_图腾光环修复.sql
-- 任务 10853「Spirit Calling」（刀锋山 3522，67 级）进度永远不涨 —— 一次性修复（两个改动同属一个问题）。
-- 幂等，可重复执行。
--
-- ============================ 现象与链条 ============================
--   任务需求：收集物品 31656「Lesser Nether Drake Spirit」× 8
--     31656 来源：次级虚空龙 21004 的任务专属掉落（creature_loot_template: ChanceOrQuestChance = -100）
--        该掉落行挂了 condition_id = 1183 = 「玩家身上有光环 38778（Spirit Calling）」
--           38778 应由「Spirit Calling Totem」图腾怪 22318 施放：
--              spell 38778 = Effect 128（APPLY_AREA_AURA_OWNER）+ target CASTER
--              → 光环落到【图腾的主人（玩家）】身上，正好满足 condition 1183
--           图腾由物品 31663 的使用法术 38780 召唤（Effect 28 SUMMON, EffectMiscValue = 22318）
--
-- ============================ 两个断点 ============================
--   (1) 图腾法术列表缺失
--       引擎对图腾走 legacy 规则取法术列表（Entities/Totem.cpp:68-71）：
--           SetSpellList(cinfo->Entry * 100 + 0)   →  22318 ⇒ Id = 2231800
--       而 creature_spell_list 与 creature_spell_list_entry 里都没有这一组 →
--       Totem::GetSpell() 返回 0 → 图腾没有可施放的法术。
--   (2) 召唤属性不是"图腾"
--       EffectSummonType 按 summon_prop（spell_template.EffectMiscValueB1 → SummonProperties.dbc）分派，
--       只有图腾属性才走 DoSummonTotem（→ Totem 对象 → TotemAI → Totem::Summon 施放列表法术），
--       否则落到守护者/宠物那条路（会跟随主人，也不会有 Totem::Summon 里的光环）。
--       实测玩家图腾的属性值：地缚 2484=81、战栗 8143=81、灼热 3599=63、根基 8177=83；
--       而 38780 原来是 121 → 所以召唤出来的是"普通召唤物"。
--
--   (1)+(2) 合起来：图腾既不是真图腾、又没有法术 → 38778 永远不施放 → condition 1183 永不满足
--          → 31656 永不掉落 → 任务进度永远不动。
--
-- ============================ 修复 ============================
--   (1) 补图腾法术列表（列表头 + 法术行两张表都要写，缺表头加载器会报
--       "Invalid creature_spell_list <id> list does not exist. Skipping."）
--   (2) 把召唤属性对齐成地缚图腾那种（81）→ 成为真图腾：
--       38780 → DoSummonTotem → Totem(被动) → Totem::Summon() 遍历法术列表
--       → TOTEM_PASSIVE 分支 CastSpell(nullptr, 38778) → 光环转给主人（玩家），图腾原地不动。
--
-- 验证（本地实测通过）：
--   日志 [TOTEMDBG] entry=22318 summon: type=0(被动) spells=1 owner=Player
--              spellId=38778 → 主人身上出现 38778（dummy 光环不在 buff 栏显示图标，属正常）
--              → 次级虚空龙掉 31656，任务进度 +1。
--   注意：GM 模式（.gm on）下光环/增益不生效，验证前先 .gm off。

-- (1) 图腾法术列表：Id = entry * 100 = 2231800
DELETE FROM creature_spell_list WHERE Id = 2231800;
DELETE FROM creature_spell_list_entry WHERE Id = 2231800;

INSERT INTO creature_spell_list_entry (Id, Name, ChanceSupportAction, ChanceRangedAttack)
VALUES (2231800, 'Spirit Calling Totem 22318 (quest 10853)', 0, 0);

INSERT INTO creature_spell_list
    (Id, Position, SpellId, Flags, CombatCondition, TargetId, ScriptId,
     Availability, Probability, InitialMin, InitialMax, RepeatMin, RepeatMax, Comments)
VALUES
    (2231800, 0, 38778, 0, -1, 2, 0, 100, 1, 1000, 2000, 8000, 10000,
     'Spirit Calling Totem 22318 - 38778 Spirit Calling (owner aura, quest 10853)');

-- (2) 召唤属性：121（非图腾）→ 81（同地缚图腾 2484 / 战栗图腾 8143）
UPDATE spell_template SET EffectMiscValueB1 = 81 WHERE Id = 38780;
