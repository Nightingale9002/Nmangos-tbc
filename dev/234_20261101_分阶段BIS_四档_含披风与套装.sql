-- ---------------------------------------------------------------
-- 234_20261101_分阶段BIS_四档_含披风与套装.sql
-- 由 `_agent_tmp/bis/gen_bis_v5.py` 生成。数据源：item_template / spell_template /
-- ItemSet.dbc（SetID → 成员物品[]、(件数 → 加成 spellId)）/ [DUMMY] 实测伤害占比。
-- 明细见同目录 bis_build_report.json / damage_share.json。
--
-- 相对 dev/233 的三点变化：
--   ① `ai_playerbot_bis_gear` 新增 `phase`（0=团本前 1=P1-T4 2=P2-T5 3=P4-SWP），
--      主键改为 (cls, spec, phase, slot) —— 否则四档互相覆盖、ON DUPLICATE 不幂等；
--   ② 补 **slot 14（披风）**：v4 的 InventoryType→slot 映射漏了 16=CLOAK（CASE 落 NULL 被过滤），
--      披风恒空 ⇒ 每次重启回落到随机披风（实测同 bot sp 1065→1093 漂移、污染 A/B）；
--   ③ 认套装：套装价值 = 占比 × 提升（DBC 的 `EffectBasePoints+1` 就是百分比，
--      已与站长样例对上：4T6 术士 6%、奥法 2T5 奥冲 20%）。
--
-- 覆盖清单（必须穿，优先级高于分数）：
--   p0 arcane         提瑞斯法 x2  2T5保底(奥冲+20%)
--   p1 arcane         提瑞斯法 x2  2T5保底(奥冲+20%)
--   p2 arcane         提瑞斯法 x4  P2起4T5
--   p3 arcane         提瑞斯法 x4  P2起4T5(138~151也保留)
--   p3 destro         凶星 x4  4T6必出(暗影箭/烧尽+6%)
--   p0 balance        诺达希尔法衣 x4  4T5一直戴到最高档
--   p1 balance        诺达希尔法衣 x4  4T5一直戴到最高档
--   p2 balance        诺达希尔法衣 x4  4T5一直戴到最高档
--   p3 balance        诺达希尔法衣 x4  4T5一直戴到最高档
--   p3 balance        雷霆之心法衣 x4  后期4T5+4T6混搭
--   p3 elemental      破天法衣 x4  4T6必出
--   p1 combat         虚空刀锋 x2  T4阶段2T4
--   p2 combat         死亡阴影 x4  T5之后4T5
--   p3 combat         死亡阴影 x4  T5之后4T5
--   p1 assassination  虚空刀锋 x2  T4阶段2T4
--   p2 assassination  死亡阴影 x4  T5之后4T5
--   p3 assassination  死亡阴影 x4  T5之后4T5
--   p0 bm             巨兽之王 x4  4D3过渡(跳T4套)
--   p1 bm             巨兽之王 x4  4D3过渡(跳T4套)
--   p2 bm             裂隙追猎者 x2  2T5优先于T6
--   p3 bm             裂隙追猎者 x2  2T5优先于T6
-- 否决清单（不计该套装加成、也不为凑它牺牲属性件）：
--   arcane         tier [6] ⇒ 排除套装 [671]
--   ret            tier [6] ⇒ 排除套装 [680]
--   arms           tier [6] ⇒ 排除套装 [672]
--   fury           tier [6] ⇒ 排除套装 [672]
--   shadow         tier [6] ⇒ 排除套装 [674]
--   resto_druid    tier [6]（本表无此专精，规则记录在案）
--
-- 本表用到的 tier 套装（setId 套装名 / tier / 定位）：
--   621  虚空刀锋                     tier 4  melee
--   622  死亡阴影                     tier 5  melee
--   632  飓风法衣                     tier 4  healer
--   635  灾难法衣                     tier 5  healer
--   636  灾难甲胄                     tier 5  melee
--   643  诺达希尔法衣                   tier 5  caster
--   645  虚空之心                     tier 4  caster
--   646  腐蚀者                      tier 5  caster
--   648  奥尔多魔装                    tier 4  caster
--   649  提瑞斯法                     tier 5  caster
--   650  巨兽之王                     tier D3 melee
--   651  恶魔追猎者                    tier 4  melee
--   652  裂隙追猎者                    tier 5  melee
--   655  战神战甲                     tier 4  melee
--   657  毁灭者战甲                    tier 5  melee
--   664  化身法衣                     tier 4  caster
--   666  神使法衣                     tier 5  caster
--   669  戈隆追猎者                    tier 6  melee
--   670  凶星                       tier 6  caster
--   671  风暴                       tier 6  caster
--   674  赦免法衣                     tier 6  caster
--   677  雷霆之心法衣                   tier 6  caster
--   684  破天法衣                     tier 6  caster
--
-- 幂等：INSERT ... ON DUPLICATE KEY UPDATE，重复执行行数不变。
-- ⚠️ 前两条 ALTER 是**一次性**的（按站长口径静态写死、不加 information_schema 守卫）：
--    重复执行整个文件会报 duplicate column；只重跑 INSERT 部分行数不变。
-- ⚠️ 读取方（SimScenario.cpp 的 `SELECT slot, item_id ... WHERE cls=%u AND spec=...`）
--    现在每个 (cls,spec,slot) 有 4 行（每 phase 一行）⇒ 必须加 `AND phase=<当前档>`，
--    否则一件 bot 会按 4 倍件数排队穿装（本 SQL 不改代码）。
--
-- =============== 配套 mangosd.conf 片段（AiPlayerbot.GearProgressionSystem） ===============
-- 槽位语义 = **装备槽**（0=头 1=颈 2=肩 4=胸 5=腰 6=腿 7=脚 8=腕 9=手 10/11=戒指
--            12/13=饰品 14=披风 15=主手 16=副手 17=远程）；spec = 天赋树序号（0..3）
-- 阶段装等区间：`UpdateGearAction::GetProgressionLevel` 从 phase **1** 开始逐档比对，
-- 都不命中就回 0 ⇒ phase 0 = "装等低于 115"，Min/Max 写了也不参与判定；
-- phase 3 的 Max 写 999 是为了让 ilvl 152+ 的太阳井件也落到 3 档（否则会掉回 0 档）。
--   AiPlayerbot.GearProgressionSystem.0.MinItemLevel = 0
--   AiPlayerbot.GearProgressionSystem.0.MaxItemLevel = 114
--   AiPlayerbot.GearProgressionSystem.1.MinItemLevel = 115
--   AiPlayerbot.GearProgressionSystem.1.MaxItemLevel = 124
--   AiPlayerbot.GearProgressionSystem.2.MinItemLevel = 125
--   AiPlayerbot.GearProgressionSystem.2.MaxItemLevel = 137
--   AiPlayerbot.GearProgressionSystem.3.MinItemLevel = 138
--   AiPlayerbot.GearProgressionSystem.3.MaxItemLevel = 999
--
-- [arcane / cls=8 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.8.0.0 = 30206   (头 Cowl of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.0.8.0.1 = 24114   (颈 Braided Eternium Chain)
-- AiPlayerbot.GearProgressionSystem.0.8.0.2 = 30210   (肩 Mantle of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.0.8.0.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.8.0.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.8.0.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.0.8.0.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.8.0.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.8.0.9 = 34808   (手 Gloves of Arcane Acuity)
-- AiPlayerbot.GearProgressionSystem.0.8.0.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.8.0.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.8.0.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.8.0.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.8.0.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.8.0.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.8.0.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [arcane / cls=8 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.8.0.0 = 30206   (头 Cowl of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.1.8.0.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.8.0.2 = 30210   (肩 Mantle of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.1.8.0.4 = 30196   (胸 Robes of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.1.8.0.5 = 27795   (腰 Sash of Serpentra)
-- AiPlayerbot.GearProgressionSystem.1.8.0.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.1.8.0.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.8.0.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.8.0.9 = 30205   (手 Gloves of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.1.8.0.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.8.0.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.8.0.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.8.0.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.8.0.14 = 34792   (披风 Cloak of the Betrayed)
-- AiPlayerbot.GearProgressionSystem.1.8.0.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.8.0.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [arcane / cls=8 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.8.0.0 = 30206   (头 Cowl of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.0.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.8.0.2 = 30024   (肩 Mantle of the Elven Kings)
-- AiPlayerbot.GearProgressionSystem.2.8.0.4 = 30196   (胸 Robes of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.0.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.8.0.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.0.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.8.0.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.8.0.9 = 30205   (手 Gloves of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.0.10 = 34095   (戒指1 Indalamar's Ring of 100 Hit Rating)
-- AiPlayerbot.GearProgressionSystem.2.8.0.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.8.0.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.8.0.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.8.0.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.8.0.15 = 32053   (主手 Merciless Gladiator's Spellblade)
-- AiPlayerbot.GearProgressionSystem.2.8.0.16 = 28825   (副手 Aldori Legacy Defender)
-- [arcane / cls=8 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.8.0.0 = 30206   (头 Cowl of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.3.8.0.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.8.0.2 = 30210   (肩 Mantle of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.3.8.0.4 = 30196   (胸 Robes of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.3.8.0.5 = 32256   (腰 Waistwrap of Infinity)
-- AiPlayerbot.GearProgressionSystem.3.8.0.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.3.8.0.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.8.0.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.8.0.9 = 30205   (手 Gloves of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.3.8.0.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.8.0.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.8.0.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.8.0.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.8.0.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.8.0.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.8.0.16 = 32361   (副手 Blind-Seers Icon)
-- [fire / cls=8 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.8.1.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.8.1.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.8.1.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.8.1.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.8.1.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.8.1.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.8.1.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.8.1.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.8.1.9 = 21847   (手 Spellfire Gloves)
-- AiPlayerbot.GearProgressionSystem.0.8.1.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.8.1.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.8.1.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.8.1.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.8.1.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.8.1.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.8.1.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [fire / cls=8 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.8.1.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.8.1.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.8.1.2 = 24554   (肩 Gladiator's Dreadweave Mantle)
-- AiPlayerbot.GearProgressionSystem.1.8.1.4 = 27799   (胸 Vermillion Robes of the Dominant)
-- AiPlayerbot.GearProgressionSystem.1.8.1.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.8.1.6 = 29078   (腿 Legwraps of the Aldor)
-- AiPlayerbot.GearProgressionSystem.1.8.1.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.8.1.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.8.1.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.8.1.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.8.1.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.8.1.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.8.1.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.8.1.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.8.1.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.8.1.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [fire / cls=8 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.8.1.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.8.1.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.8.1.2 = 30024   (肩 Mantle of the Elven Kings)
-- AiPlayerbot.GearProgressionSystem.2.8.1.4 = 30196   (胸 Robes of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.1.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.8.1.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.1.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.8.1.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.8.1.9 = 30205   (手 Gloves of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.1.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.8.1.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.8.1.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.8.1.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.8.1.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.8.1.15 = 32053   (主手 Merciless Gladiator's Spellblade)
-- AiPlayerbot.GearProgressionSystem.2.8.1.16 = 28825   (副手 Aldori Legacy Defender)
-- [fire / cls=8 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.8.1.0 = 32525   (头 Cowl of the Illidari High Lord)
-- AiPlayerbot.GearProgressionSystem.3.8.1.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.8.1.2 = 32338   (肩 Blood-cursed Shoulderpads)
-- AiPlayerbot.GearProgressionSystem.3.8.1.4 = 30913   (胸 Robes of Rhonin)
-- AiPlayerbot.GearProgressionSystem.3.8.1.5 = 32256   (腰 Waistwrap of Infinity)
-- AiPlayerbot.GearProgressionSystem.3.8.1.6 = 31058   (腿 Leggings of the Tempest)
-- AiPlayerbot.GearProgressionSystem.3.8.1.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.8.1.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.8.1.9 = 31055   (手 Gloves of the Tempest)
-- AiPlayerbot.GearProgressionSystem.3.8.1.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.8.1.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.8.1.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.8.1.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.8.1.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.8.1.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.8.1.16 = 32361   (副手 Blind-Seers Icon)
-- [frost / cls=8 spec=2 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.8.2.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.8.2.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.8.2.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.8.2.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.8.2.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.8.2.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.8.2.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.8.2.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.8.2.9 = 21847   (手 Spellfire Gloves)
-- AiPlayerbot.GearProgressionSystem.0.8.2.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.8.2.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.8.2.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.8.2.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.8.2.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.8.2.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.8.2.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [frost / cls=8 spec=2 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.8.2.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.8.2.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.8.2.2 = 24554   (肩 Gladiator's Dreadweave Mantle)
-- AiPlayerbot.GearProgressionSystem.1.8.2.4 = 27799   (胸 Vermillion Robes of the Dominant)
-- AiPlayerbot.GearProgressionSystem.1.8.2.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.8.2.6 = 29078   (腿 Legwraps of the Aldor)
-- AiPlayerbot.GearProgressionSystem.1.8.2.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.8.2.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.8.2.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.8.2.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.8.2.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.8.2.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.8.2.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.8.2.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.8.2.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.8.2.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [frost / cls=8 spec=2 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.8.2.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.8.2.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.8.2.2 = 30024   (肩 Mantle of the Elven Kings)
-- AiPlayerbot.GearProgressionSystem.2.8.2.4 = 30196   (胸 Robes of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.2.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.8.2.6 = 30207   (腿 Leggings of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.2.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.8.2.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.8.2.9 = 30205   (手 Gloves of Tirisfal)
-- AiPlayerbot.GearProgressionSystem.2.8.2.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.8.2.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.8.2.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.8.2.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.8.2.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.8.2.15 = 32053   (主手 Merciless Gladiator's Spellblade)
-- AiPlayerbot.GearProgressionSystem.2.8.2.16 = 28825   (副手 Aldori Legacy Defender)
-- [frost / cls=8 spec=2 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.8.2.0 = 32525   (头 Cowl of the Illidari High Lord)
-- AiPlayerbot.GearProgressionSystem.3.8.2.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.8.2.2 = 32338   (肩 Blood-cursed Shoulderpads)
-- AiPlayerbot.GearProgressionSystem.3.8.2.4 = 30913   (胸 Robes of Rhonin)
-- AiPlayerbot.GearProgressionSystem.3.8.2.5 = 32256   (腰 Waistwrap of Infinity)
-- AiPlayerbot.GearProgressionSystem.3.8.2.6 = 31058   (腿 Leggings of the Tempest)
-- AiPlayerbot.GearProgressionSystem.3.8.2.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.8.2.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.8.2.9 = 31055   (手 Gloves of the Tempest)
-- AiPlayerbot.GearProgressionSystem.3.8.2.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.8.2.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.8.2.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.8.2.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.8.2.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.8.2.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.8.2.16 = 32361   (副手 Blind-Seers Icon)
-- [affliction / cls=9 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.9.0.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.9.0.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.9.0.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.9.0.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.9.0.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.9.0.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.9.0.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.9.0.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.9.0.9 = 21847   (手 Spellfire Gloves)
-- AiPlayerbot.GearProgressionSystem.0.9.0.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.9.0.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.9.0.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.9.0.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.9.0.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.9.0.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.9.0.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [affliction / cls=9 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.9.0.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.9.0.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.9.0.2 = 28967   (肩 Voidheart Mantle)
-- AiPlayerbot.GearProgressionSystem.1.9.0.4 = 28964   (胸 Voidheart Robe)
-- AiPlayerbot.GearProgressionSystem.1.9.0.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.9.0.6 = 28966   (腿 Voidheart Leggings)
-- AiPlayerbot.GearProgressionSystem.1.9.0.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.9.0.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.9.0.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.9.0.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.9.0.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.9.0.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.9.0.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.9.0.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.9.0.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.9.0.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [affliction / cls=9 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.9.0.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.9.0.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.9.0.2 = 30215   (肩 Mantle of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.0.4 = 30214   (胸 Robe of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.0.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.9.0.6 = 30213   (腿 Leggings of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.0.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.9.0.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.9.0.9 = 30211   (手 Gloves of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.0.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.9.0.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.9.0.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.9.0.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.9.0.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.9.0.15 = 32053   (主手 Merciless Gladiator's Spellblade)
-- AiPlayerbot.GearProgressionSystem.2.9.0.16 = 32027   (副手 Merciless Gladiator's Quickblade)
-- [affliction / cls=9 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.9.0.0 = 32525   (头 Cowl of the Illidari High Lord)
-- AiPlayerbot.GearProgressionSystem.3.9.0.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.9.0.2 = 31054   (肩 Mantle of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.0.4 = 30913   (胸 Robes of Rhonin)
-- AiPlayerbot.GearProgressionSystem.3.9.0.5 = 32256   (腰 Waistwrap of Infinity)
-- AiPlayerbot.GearProgressionSystem.3.9.0.6 = 32367   (腿 Leggings of Devastation)
-- AiPlayerbot.GearProgressionSystem.3.9.0.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.9.0.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.9.0.9 = 31050   (手 Gloves of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.0.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.9.0.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.9.0.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.9.0.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.9.0.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.9.0.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.9.0.16 = 32361   (副手 Blind-Seers Icon)
-- [destro / cls=9 spec=2 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.9.2.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.9.2.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.9.2.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.9.2.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.9.2.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.9.2.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.9.2.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.9.2.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.9.2.9 = 21847   (手 Spellfire Gloves)
-- AiPlayerbot.GearProgressionSystem.0.9.2.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.9.2.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.9.2.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.9.2.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.9.2.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.9.2.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.9.2.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [destro / cls=9 spec=2 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.9.2.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.9.2.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.9.2.2 = 28967   (肩 Voidheart Mantle)
-- AiPlayerbot.GearProgressionSystem.1.9.2.4 = 28964   (胸 Voidheart Robe)
-- AiPlayerbot.GearProgressionSystem.1.9.2.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.9.2.6 = 28966   (腿 Voidheart Leggings)
-- AiPlayerbot.GearProgressionSystem.1.9.2.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.9.2.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.9.2.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.9.2.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.9.2.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.9.2.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.9.2.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.9.2.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.9.2.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.9.2.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [destro / cls=9 spec=2 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.9.2.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.9.2.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.9.2.2 = 30215   (肩 Mantle of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.2.4 = 30214   (胸 Robe of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.2.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.9.2.6 = 30213   (腿 Leggings of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.2.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.9.2.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.9.2.9 = 30211   (手 Gloves of the Corruptor)
-- AiPlayerbot.GearProgressionSystem.2.9.2.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.9.2.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.9.2.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.9.2.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.9.2.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.9.2.15 = 32053   (主手 Merciless Gladiator's Spellblade)
-- AiPlayerbot.GearProgressionSystem.2.9.2.16 = 32027   (副手 Merciless Gladiator's Quickblade)
-- [destro / cls=9 spec=2 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.9.2.0 = 31051   (头 Hood of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.9.2.2 = 31054   (肩 Mantle of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.4 = 31052   (胸 Robe of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.5 = 34541   (腰 Belt of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.6 = 31053   (腿 Leggings of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.7 = 34564   (脚 Boots of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.9.2.9 = 31050   (手 Gloves of the Malefic)
-- AiPlayerbot.GearProgressionSystem.3.9.2.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.9.2.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.9.2.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.9.2.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.9.2.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.9.2.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.9.2.16 = 32361   (副手 Blind-Seers Icon)
-- [shadow / cls=5 spec=2 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.5.2.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.5.2.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.5.2.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.5.2.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.5.2.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.5.2.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.5.2.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.5.2.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.5.2.9 = 21847   (手 Spellfire Gloves)
-- AiPlayerbot.GearProgressionSystem.0.5.2.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.5.2.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.5.2.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.5.2.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.5.2.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.5.2.15 = 32190   (主手 Chancellor's Spellblade)
-- AiPlayerbot.GearProgressionSystem.0.5.2.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [shadow / cls=5 spec=2 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.5.2.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.5.2.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.5.2.2 = 24554   (肩 Gladiator's Dreadweave Mantle)
-- AiPlayerbot.GearProgressionSystem.1.5.2.4 = 29056   (胸 Shroud of the Incarnate)
-- AiPlayerbot.GearProgressionSystem.1.5.2.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.5.2.6 = 30734   (腿 Leggings of the Seventh Circle)
-- AiPlayerbot.GearProgressionSystem.1.5.2.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.5.2.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.5.2.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.5.2.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.5.2.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.5.2.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.5.2.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.5.2.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.5.2.15 = 30723   (主手 Talon of the Tempest)
-- AiPlayerbot.GearProgressionSystem.1.5.2.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [shadow / cls=5 spec=2 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.5.2.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.5.2.1 = 30008   (颈 Pendant of the Lost Ages)
-- AiPlayerbot.GearProgressionSystem.2.5.2.2 = 30024   (肩 Mantle of the Elven Kings)
-- AiPlayerbot.GearProgressionSystem.2.5.2.4 = 30159   (胸 Shroud of the Avatar)
-- AiPlayerbot.GearProgressionSystem.2.5.2.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.5.2.6 = 30162   (腿 Leggings of the Avatar)
-- AiPlayerbot.GearProgressionSystem.2.5.2.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.5.2.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.5.2.9 = 30160   (手 Handguards of the Avatar)
-- AiPlayerbot.GearProgressionSystem.2.5.2.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.5.2.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.5.2.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.5.2.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.5.2.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.5.2.15 = 33283   (主手 Amani Punisher)
-- AiPlayerbot.GearProgressionSystem.2.5.2.16 = 33334   (副手 Fetish of the Primal Gods)
-- [shadow / cls=5 spec=2 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.5.2.0 = 32525   (头 Cowl of the Illidari High Lord)
-- AiPlayerbot.GearProgressionSystem.3.5.2.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.5.2.2 = 32338   (肩 Blood-cursed Shoulderpads)
-- AiPlayerbot.GearProgressionSystem.3.5.2.4 = 30913   (胸 Robes of Rhonin)
-- AiPlayerbot.GearProgressionSystem.3.5.2.5 = 32256   (腰 Waistwrap of Infinity)
-- AiPlayerbot.GearProgressionSystem.3.5.2.6 = 32367   (腿 Leggings of Devastation)
-- AiPlayerbot.GearProgressionSystem.3.5.2.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.5.2.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.5.2.9 = 31061   (手 Handguards of Absolution)
-- AiPlayerbot.GearProgressionSystem.3.5.2.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.5.2.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.5.2.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.5.2.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.5.2.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.5.2.15 = 30910   (主手 Tempest of Chaos)
-- AiPlayerbot.GearProgressionSystem.3.5.2.16 = 32361   (副手 Blind-Seers Icon)
-- [balance / cls=11 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.11.0.0 = 30233   (头 Nordrassil Headpiece)
-- AiPlayerbot.GearProgressionSystem.0.11.0.1 = 24114   (颈 Braided Eternium Chain)
-- AiPlayerbot.GearProgressionSystem.0.11.0.2 = 30235   (肩 Nordrassil Wrath-Mantle)
-- AiPlayerbot.GearProgressionSystem.0.11.0.4 = 30231   (胸 Nordrassil Chestpiece)
-- AiPlayerbot.GearProgressionSystem.0.11.0.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.11.0.6 = 30234   (腿 Nordrassil Wrath-Kilt)
-- AiPlayerbot.GearProgressionSystem.0.11.0.7 = 25686   (脚 Fel Leather Boots)
-- AiPlayerbot.GearProgressionSystem.0.11.0.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.11.0.9 = 29503   (手 Cobrascale Gloves)
-- AiPlayerbot.GearProgressionSystem.0.11.0.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.11.0.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.11.0.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.11.0.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.11.0.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.11.0.15 = 30832   (主手 Gavel of Unearthed Secrets)
-- AiPlayerbot.GearProgressionSystem.0.11.0.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [balance / cls=11 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.11.0.0 = 30233   (头 Nordrassil Headpiece)
-- AiPlayerbot.GearProgressionSystem.1.11.0.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.11.0.2 = 30235   (肩 Nordrassil Wrath-Mantle)
-- AiPlayerbot.GearProgressionSystem.1.11.0.4 = 30231   (胸 Nordrassil Chestpiece)
-- AiPlayerbot.GearProgressionSystem.1.11.0.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.11.0.6 = 30234   (腿 Nordrassil Wrath-Kilt)
-- AiPlayerbot.GearProgressionSystem.1.11.0.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.11.0.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.11.0.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.11.0.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.11.0.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.11.0.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.11.0.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.11.0.14 = 34792   (披风 Cloak of the Betrayed)
-- AiPlayerbot.GearProgressionSystem.1.11.0.15 = 32450   (主手 Gladiator's Gavel)
-- AiPlayerbot.GearProgressionSystem.1.11.0.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [balance / cls=11 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.11.0.0 = 30233   (头 Nordrassil Headpiece)
-- AiPlayerbot.GearProgressionSystem.2.11.0.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.11.0.2 = 30235   (肩 Nordrassil Wrath-Mantle)
-- AiPlayerbot.GearProgressionSystem.2.11.0.4 = 30231   (胸 Nordrassil Chestpiece)
-- AiPlayerbot.GearProgressionSystem.2.11.0.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.11.0.6 = 30234   (腿 Nordrassil Wrath-Kilt)
-- AiPlayerbot.GearProgressionSystem.2.11.0.7 = 30039   (脚 Boots of Utter Darkness)
-- AiPlayerbot.GearProgressionSystem.2.11.0.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.11.0.9 = 30232   (手 Nordrassil Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.11.0.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.11.0.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.11.0.12 = 30450   (饰品1 Warp-Spring Coil)
-- AiPlayerbot.GearProgressionSystem.2.11.0.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.11.0.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.11.0.15 = 33283   (主手 Amani Punisher)
-- AiPlayerbot.GearProgressionSystem.2.11.0.16 = 28825   (副手 Aldori Legacy Defender)
-- [balance / cls=11 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.11.0.0 = 30233   (头 Nordrassil Headpiece)
-- AiPlayerbot.GearProgressionSystem.3.11.0.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.11.0.2 = 30235   (肩 Nordrassil Wrath-Mantle)
-- AiPlayerbot.GearProgressionSystem.3.11.0.4 = 30231   (胸 Nordrassil Chestpiece)
-- AiPlayerbot.GearProgressionSystem.3.11.0.5 = 34555   (腰 Thunderheart Cord)
-- AiPlayerbot.GearProgressionSystem.3.11.0.6 = 30234   (腿 Nordrassil Wrath-Kilt)
-- AiPlayerbot.GearProgressionSystem.3.11.0.7 = 34572   (脚 Thunderheart Footwraps)
-- AiPlayerbot.GearProgressionSystem.3.11.0.8 = 34446   (腕 Thunderheart Bands)
-- AiPlayerbot.GearProgressionSystem.3.11.0.9 = 31035   (手 Thunderheart Handguards)
-- AiPlayerbot.GearProgressionSystem.3.11.0.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.11.0.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.11.0.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.11.0.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.11.0.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.11.0.15 = 33687   (主手 Vengeful Gladiator's Gavel)
-- AiPlayerbot.GearProgressionSystem.3.11.0.16 = 32361   (副手 Blind-Seers Icon)
-- [elemental / cls=7 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.7.0.0 = 24266   (头 Spellstrike Hood)
-- AiPlayerbot.GearProgressionSystem.0.7.0.1 = 24116   (颈 Eye of the Night)
-- AiPlayerbot.GearProgressionSystem.0.7.0.2 = 21869   (肩 Frozen Shadoweave Shoulders)
-- AiPlayerbot.GearProgressionSystem.0.7.0.4 = 31297   (胸 Robe of the Crimson Order)
-- AiPlayerbot.GearProgressionSystem.0.7.0.5 = 30460   (腰 Netherflame Belt)
-- AiPlayerbot.GearProgressionSystem.0.7.0.6 = 24262   (腿 Spellstrike Pants)
-- AiPlayerbot.GearProgressionSystem.0.7.0.7 = 21870   (脚 Frozen Shadoweave Boots)
-- AiPlayerbot.GearProgressionSystem.0.7.0.8 = 29240   (腕 Bands of Negation)
-- AiPlayerbot.GearProgressionSystem.0.7.0.9 = 34808   (手 Gloves of Arcane Acuity)
-- AiPlayerbot.GearProgressionSystem.0.7.0.10 = 29172   (戒指1 Ashyen's Gift)
-- AiPlayerbot.GearProgressionSystem.0.7.0.11 = 31920   (戒指2 Shaffar's Band of Brutality)
-- AiPlayerbot.GearProgressionSystem.0.7.0.12 = 29370   (饰品1 Icon of the Silver Crescent)
-- AiPlayerbot.GearProgressionSystem.0.7.0.13 = 38290   (饰品2 Dark Iron Smoking Pipe)
-- AiPlayerbot.GearProgressionSystem.0.7.0.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.7.0.15 = 30832   (主手 Gavel of Unearthed Secrets)
-- AiPlayerbot.GearProgressionSystem.0.7.0.16 = 29269   (副手 Sapphiron's Wing Bone)
-- [elemental / cls=7 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.7.0.0 = 28744   (头 Uni-Mind Headdress)
-- AiPlayerbot.GearProgressionSystem.1.7.0.1 = 28530   (颈 Brooch of Unquenchable Fury)
-- AiPlayerbot.GearProgressionSystem.1.7.0.2 = 24554   (肩 Gladiator's Dreadweave Mantle)
-- AiPlayerbot.GearProgressionSystem.1.7.0.4 = 27799   (胸 Vermillion Robes of the Dominant)
-- AiPlayerbot.GearProgressionSystem.1.7.0.5 = 30673   (腰 Inferno Waist Cord)
-- AiPlayerbot.GearProgressionSystem.1.7.0.6 = 29036   (腿 Cyclone Legguards)
-- AiPlayerbot.GearProgressionSystem.1.7.0.7 = 28585   (脚 Ruby Slippers)
-- AiPlayerbot.GearProgressionSystem.1.7.0.8 = 27462   (腕 Crimson Bracers of Gloom)
-- AiPlayerbot.GearProgressionSystem.1.7.0.9 = 30668   (手 Grasp of the Dead)
-- AiPlayerbot.GearProgressionSystem.1.7.0.10 = 32779   (戒指1 Band of Frigid Elements)
-- AiPlayerbot.GearProgressionSystem.1.7.0.11 = 30667   (戒指2 Ring of Unrelenting Storms)
-- AiPlayerbot.GearProgressionSystem.1.7.0.12 = 28223   (饰品1 Arcanist's Stone)
-- AiPlayerbot.GearProgressionSystem.1.7.0.13 = 29132   (饰品2 Scryer's Bloodgem)
-- AiPlayerbot.GearProgressionSystem.1.7.0.14 = 30642   (披风 Drape of the Righteous)
-- AiPlayerbot.GearProgressionSystem.1.7.0.15 = 32450   (主手 Gladiator's Gavel)
-- AiPlayerbot.GearProgressionSystem.1.7.0.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [elemental / cls=7 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.7.0.0 = 33453   (头 Hood of Hexing)
-- AiPlayerbot.GearProgressionSystem.2.7.0.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.7.0.2 = 30024   (肩 Mantle of the Elven Kings)
-- AiPlayerbot.GearProgressionSystem.2.7.0.4 = 33965   (胸 Hauberk of the Furious Elements)
-- AiPlayerbot.GearProgressionSystem.2.7.0.5 = 30064   (腰 Cord of Screaming Terrors)
-- AiPlayerbot.GearProgressionSystem.2.7.0.6 = 30172   (腿 Cataclysm Leggings)
-- AiPlayerbot.GearProgressionSystem.2.7.0.7 = 30050   (脚 Boots of the Shifting Nightmare)
-- AiPlayerbot.GearProgressionSystem.2.7.0.8 = 29918   (腕 Mindstorm Wristbands)
-- AiPlayerbot.GearProgressionSystem.2.7.0.9 = 30170   (手 Cataclysm Handgrips)
-- AiPlayerbot.GearProgressionSystem.2.7.0.10 = 33995   (戒指1 Indalamar's Ring of Healer Ownage)
-- AiPlayerbot.GearProgressionSystem.2.7.0.11 = 33996   (戒指2 Indalamar's Ring of 234 Spell Damage)
-- AiPlayerbot.GearProgressionSystem.2.7.0.12 = 33829   (饰品1 Hex Shrunken Head)
-- AiPlayerbot.GearProgressionSystem.2.7.0.13 = 35700   (饰品2 Figurine - Crimson Serpent)
-- AiPlayerbot.GearProgressionSystem.2.7.0.14 = 28766   (披风 Ruby Drape of the Mysticant)
-- AiPlayerbot.GearProgressionSystem.2.7.0.15 = 33283   (主手 Amani Punisher)
-- AiPlayerbot.GearProgressionSystem.2.7.0.16 = 31958   (副手 Merciless Gladiator's Bonecracker)
-- [elemental / cls=7 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.7.0.0 = 31014   (头 Skyshatter Headguard)
-- AiPlayerbot.GearProgressionSystem.3.7.0.1 = 32349   (颈 Translucent Spellthread Necklace)
-- AiPlayerbot.GearProgressionSystem.3.7.0.2 = 32338   (肩 Blood-cursed Shoulderpads)
-- AiPlayerbot.GearProgressionSystem.3.7.0.4 = 31017   (胸 Skyshatter Breastplate)
-- AiPlayerbot.GearProgressionSystem.3.7.0.5 = 34542   (腰 Skyshatter Cord)
-- AiPlayerbot.GearProgressionSystem.3.7.0.6 = 31020   (腿 Skyshatter Legguards)
-- AiPlayerbot.GearProgressionSystem.3.7.0.7 = 30894   (脚 Blue Suede Shoes)
-- AiPlayerbot.GearProgressionSystem.3.7.0.8 = 32270   (腕 Focused Mana Bindings)
-- AiPlayerbot.GearProgressionSystem.3.7.0.9 = 31008   (手 Skyshatter Gauntlets)
-- AiPlayerbot.GearProgressionSystem.3.7.0.10 = 34889   (戒指1 Fused Nethergon Band)
-- AiPlayerbot.GearProgressionSystem.3.7.0.11 = 32247   (戒指2 Ring of Captured Storms)
-- AiPlayerbot.GearProgressionSystem.3.7.0.12 = 32483   (饰品1 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.7.0.13 = 32496   (饰品2 Memento of Tyrande)
-- AiPlayerbot.GearProgressionSystem.3.7.0.14 = 32590   (披风 Nethervoid Cloak)
-- AiPlayerbot.GearProgressionSystem.3.7.0.15 = 33687   (主手 Vengeful Gladiator's Gavel)
-- AiPlayerbot.GearProgressionSystem.3.7.0.16 = 32361   (副手 Blind-Seers Icon)
-- [enhance / cls=7 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.7.1.0 = 27888   (头 Dream-Wing Helm)
-- AiPlayerbot.GearProgressionSystem.0.7.1.1 = 29381   (颈 Choker of Vile Intent)
-- AiPlayerbot.GearProgressionSystem.0.7.1.2 = 32137   (肩 Chancellor's Chain Spaulders)
-- AiPlayerbot.GearProgressionSystem.0.7.1.4 = 34799   (胸 Hauberk of the War Bringer)
-- AiPlayerbot.GearProgressionSystem.0.7.1.5 = 25789   (腰 Rune-Engraved Belt)
-- AiPlayerbot.GearProgressionSystem.0.7.1.6 = 28173   (腿 Mag'hari Huntsman's Leggings)
-- AiPlayerbot.GearProgressionSystem.0.7.1.7 = 29262   (脚 Boots of the Endless Hunt)
-- AiPlayerbot.GearProgressionSystem.0.7.1.8 = 29517   (腕 Ebon Netherscale Bracers)
-- AiPlayerbot.GearProgressionSystem.0.7.1.9 = 30951   (手 Ar'tor's Mainstay)
-- AiPlayerbot.GearProgressionSystem.0.7.1.10 = 29281   (戒指1 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.7.1.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.7.1.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.7.1.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.7.1.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.7.1.15 = 29360   (主手 Vileblade of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.0.7.1.16 = 32188   (副手 Chancellor's Left Ripper)
-- [enhance / cls=7 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.7.1.0 = 28671   (头 Steelspine Faceguard)
-- AiPlayerbot.GearProgressionSystem.1.7.1.1 = 29335   (颈 Talon Lord's Collar)
-- AiPlayerbot.GearProgressionSystem.1.7.1.2 = 28344   (肩 Wyrmfury Pauldrons)
-- AiPlayerbot.GearProgressionSystem.1.7.1.4 = 29515   (胸 Ebon Netherscale Breastplate)
-- AiPlayerbot.GearProgressionSystem.1.7.1.5 = 28656   (腰 Girdle of the Prowler)
-- AiPlayerbot.GearProgressionSystem.1.7.1.6 = 30739   (腿 Scaled Greaves of the Marksman)
-- AiPlayerbot.GearProgressionSystem.1.7.1.7 = 27450   (脚 Wild Stalker Boots)
-- AiPlayerbot.GearProgressionSystem.1.7.1.8 = 27494   (腕 Emerald Eye Bracer)
-- AiPlayerbot.GearProgressionSystem.1.7.1.9 = 28519   (手 Gloves of Quickening)
-- AiPlayerbot.GearProgressionSystem.1.7.1.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.7.1.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.7.1.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.7.1.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.7.1.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.7.1.15 = 28313   (主手 Gladiator's Right Ripper)
-- AiPlayerbot.GearProgressionSystem.1.7.1.16 = 28302   (副手 Gladiator's Bonecracker)
-- [enhance / cls=7 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.7.1.0 = 32474   (头 Surestrike Goggles v2.0)
-- AiPlayerbot.GearProgressionSystem.2.7.1.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.7.1.2 = 33206   (肩 Pauldrons of Primal Fury)
-- AiPlayerbot.GearProgressionSystem.2.7.1.4 = 34614   (胸 Tunic of the Ranger Lord)
-- AiPlayerbot.GearProgressionSystem.2.7.1.5 = 30046   (腰 Belt of the Black Eagle)
-- AiPlayerbot.GearProgressionSystem.2.7.1.6 = 30192   (腿 Cataclysm Legplates)
-- AiPlayerbot.GearProgressionSystem.2.7.1.7 = 33482   (脚 Cobra-Lash Boots)
-- AiPlayerbot.GearProgressionSystem.2.7.1.8 = 30026   (腕 Bands of the Celestial Archer)
-- AiPlayerbot.GearProgressionSystem.2.7.1.9 = 33528   (手 Gauntlets of Sniping)
-- AiPlayerbot.GearProgressionSystem.2.7.1.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.7.1.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.7.1.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.7.1.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.7.1.14 = 24528   (披风 130 Epic Warrior Cloak)
-- AiPlayerbot.GearProgressionSystem.2.7.1.15 = 29962   (主手 Heartrazor)
-- AiPlayerbot.GearProgressionSystem.2.7.1.16 = 33640   (副手 Fury)
-- [enhance / cls=7 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.7.1.0 = 32376   (头 Forest Prowler's Helm)
-- AiPlayerbot.GearProgressionSystem.3.7.1.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.7.1.2 = 32264   (肩 Shoulders of the Hidden Predator)
-- AiPlayerbot.GearProgressionSystem.3.7.1.4 = 30907   (胸 Mail of Fevered Pursuit)
-- AiPlayerbot.GearProgressionSystem.3.7.1.5 = 32346   (腰 Boneweave Girdle)
-- AiPlayerbot.GearProgressionSystem.3.7.1.6 = 34914   (腿 Leggings of the Pursuit)
-- AiPlayerbot.GearProgressionSystem.3.7.1.7 = 32510   (脚 Softstep Boots of Tracking)
-- AiPlayerbot.GearProgressionSystem.3.7.1.8 = 32574   (腕 Bindings of Lightning Reflexes)
-- AiPlayerbot.GearProgressionSystem.3.7.1.9 = 32234   (手 Fists of Mukoa)
-- AiPlayerbot.GearProgressionSystem.3.7.1.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.7.1.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.7.1.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.7.1.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.7.1.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.7.1.15 = 30865   (主手 Tracker's Blade)
-- AiPlayerbot.GearProgressionSystem.3.7.1.16 = 34950   (副手 Vanir's Left Fist of Savagery)
-- [feral / cls=11 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.11.1.0 = 8345   (头 Wolfshead Helm)
-- AiPlayerbot.GearProgressionSystem.0.11.1.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.11.1.2 = 25790   (肩 Expedition Scout's Epaulets)
-- AiPlayerbot.GearProgressionSystem.0.11.1.4 = 30933   (胸 Hauberk of Karabor)
-- AiPlayerbot.GearProgressionSystem.0.11.1.5 = 29247   (腰 Girdle of the Deathdealer)
-- AiPlayerbot.GearProgressionSystem.0.11.1.6 = 31545   (腿 Oilcloth Breeches)
-- AiPlayerbot.GearProgressionSystem.0.11.1.7 = 30939   (脚 Felboar Hide Shoes)
-- AiPlayerbot.GearProgressionSystem.0.11.1.8 = 29246   (腕 Nightfall Wristguards)
-- AiPlayerbot.GearProgressionSystem.0.11.1.9 = 29503   (手 Cobrascale Gloves)
-- AiPlayerbot.GearProgressionSystem.0.11.1.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.11.1.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.11.1.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.11.1.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.11.1.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.11.1.15 = 29359   (主手 Feral Staff of Lashing)
-- [feral / cls=11 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.11.1.0 = 8345   (头 Wolfshead Helm)
-- AiPlayerbot.GearProgressionSystem.1.11.1.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.11.1.2 = 29147   (肩 Talbuk Hide Spaulders)
-- AiPlayerbot.GearProgressionSystem.1.11.1.4 = 29525   (胸 Primalstrike Vest)
-- AiPlayerbot.GearProgressionSystem.1.11.1.5 = 29526   (腰 Primalstrike Belt)
-- AiPlayerbot.GearProgressionSystem.1.11.1.6 = 29131   (腿 Retainer's Leggings)
-- AiPlayerbot.GearProgressionSystem.1.11.1.7 = 28669   (脚 Rapscallion Boots)
-- AiPlayerbot.GearProgressionSystem.1.11.1.8 = 29527   (腕 Primalstrike Bracers)
-- AiPlayerbot.GearProgressionSystem.1.11.1.9 = 30644   (手 Grips of Deftness)
-- AiPlayerbot.GearProgressionSystem.1.11.1.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.11.1.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.11.1.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.11.1.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.11.1.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.11.1.15 = 28476   (主手 Gladiator's Maul)
-- [feral / cls=11 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.11.1.0 = 8345   (头 Wolfshead Helm)
-- AiPlayerbot.GearProgressionSystem.2.11.1.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.11.1.2 = 34613   (肩 Shoulderpads of the Silvermoon Retainer)
-- AiPlayerbot.GearProgressionSystem.2.11.1.4 = 30101   (胸 Bloodsea Brigand's Vest)
-- AiPlayerbot.GearProgressionSystem.2.11.1.5 = 30040   (腰 Belt of Deep Shadow)
-- AiPlayerbot.GearProgressionSystem.2.11.1.6 = 33538   (腿 Shallow-grave Trousers)
-- AiPlayerbot.GearProgressionSystem.2.11.1.7 = 30039   (脚 Boots of Utter Darkness)
-- AiPlayerbot.GearProgressionSystem.2.11.1.8 = 33540   (腕 Master Assassin Wristwraps)
-- AiPlayerbot.GearProgressionSystem.2.11.1.9 = 33539   (手 Trickster's Stickyfingers)
-- AiPlayerbot.GearProgressionSystem.2.11.1.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.11.1.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.11.1.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.11.1.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.11.1.14 = 24528   (披风 130 Epic Warrior Cloak)
-- AiPlayerbot.GearProgressionSystem.2.11.1.15 = 32014   (主手 Merciless Gladiator's Maul)
-- [feral / cls=11 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.11.1.0 = 8345   (头 Wolfshead Helm)
-- AiPlayerbot.GearProgressionSystem.3.11.1.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.11.1.2 = 32377   (肩 Mantle of Darkness)
-- AiPlayerbot.GearProgressionSystem.3.11.1.4 = 30905   (胸 Midnight Chestguard)
-- AiPlayerbot.GearProgressionSystem.3.11.1.5 = 34929   (腰 Belt of the Silent Path)
-- AiPlayerbot.GearProgressionSystem.3.11.1.6 = 34928   (腿 Trousers of the Scryers' Retainer)
-- AiPlayerbot.GearProgressionSystem.3.11.1.7 = 30891   (脚 Black Featherlight Boots)
-- AiPlayerbot.GearProgressionSystem.3.11.1.8 = 30863   (腕 Deadly Cuffs)
-- AiPlayerbot.GearProgressionSystem.3.11.1.9 = 32347   (手 Grips of Damnation)
-- AiPlayerbot.GearProgressionSystem.3.11.1.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.11.1.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.11.1.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.11.1.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.11.1.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.11.1.15 = 33716   (主手 Vengeful Gladiator's Staff)
-- [combat / cls=4 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.4.1.0 = 31281   (头 Mask of Veiled Death)
-- AiPlayerbot.GearProgressionSystem.0.4.1.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.4.1.2 = 25790   (肩 Expedition Scout's Epaulets)
-- AiPlayerbot.GearProgressionSystem.0.4.1.4 = 30933   (胸 Hauberk of Karabor)
-- AiPlayerbot.GearProgressionSystem.0.4.1.5 = 29247   (腰 Girdle of the Deathdealer)
-- AiPlayerbot.GearProgressionSystem.0.4.1.6 = 31545   (腿 Oilcloth Breeches)
-- AiPlayerbot.GearProgressionSystem.0.4.1.7 = 30939   (脚 Felboar Hide Shoes)
-- AiPlayerbot.GearProgressionSystem.0.4.1.8 = 29246   (腕 Nightfall Wristguards)
-- AiPlayerbot.GearProgressionSystem.0.4.1.9 = 29503   (手 Cobrascale Gloves)
-- AiPlayerbot.GearProgressionSystem.0.4.1.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.4.1.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.4.1.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.4.1.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.4.1.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.4.1.15 = 22736   (主手 Andonisus, Reaper of Souls)
-- AiPlayerbot.GearProgressionSystem.0.4.1.16 = 32188   (副手 Chancellor's Left Ripper)
-- [combat / cls=4 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.4.1.0 = 29044   (头 Netherblade Facemask)
-- AiPlayerbot.GearProgressionSystem.1.4.1.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.4.1.2 = 29147   (肩 Talbuk Hide Spaulders)
-- AiPlayerbot.GearProgressionSystem.1.4.1.4 = 29525   (胸 Primalstrike Vest)
-- AiPlayerbot.GearProgressionSystem.1.4.1.5 = 29526   (腰 Primalstrike Belt)
-- AiPlayerbot.GearProgressionSystem.1.4.1.6 = 29046   (腿 Netherblade Breeches)
-- AiPlayerbot.GearProgressionSystem.1.4.1.7 = 28669   (脚 Rapscallion Boots)
-- AiPlayerbot.GearProgressionSystem.1.4.1.8 = 29527   (腕 Primalstrike Bracers)
-- AiPlayerbot.GearProgressionSystem.1.4.1.9 = 29048   (手 Netherblade Gloves)
-- AiPlayerbot.GearProgressionSystem.1.4.1.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.4.1.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.4.1.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.4.1.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.4.1.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.4.1.15 = 30733   (主手 Hope Ender)
-- AiPlayerbot.GearProgressionSystem.1.4.1.16 = 28302   (副手 Gladiator's Bonecracker)
-- [combat / cls=4 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.4.1.0 = 30146   (头 Deathmantle Helm)
-- AiPlayerbot.GearProgressionSystem.2.4.1.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.4.1.2 = 34613   (肩 Shoulderpads of the Silvermoon Retainer)
-- AiPlayerbot.GearProgressionSystem.2.4.1.4 = 30144   (胸 Deathmantle Chestguard)
-- AiPlayerbot.GearProgressionSystem.2.4.1.5 = 30040   (腰 Belt of Deep Shadow)
-- AiPlayerbot.GearProgressionSystem.2.4.1.6 = 30148   (腿 Deathmantle Legguards)
-- AiPlayerbot.GearProgressionSystem.2.4.1.7 = 30039   (脚 Boots of Utter Darkness)
-- AiPlayerbot.GearProgressionSystem.2.4.1.8 = 33540   (腕 Master Assassin Wristwraps)
-- AiPlayerbot.GearProgressionSystem.2.4.1.9 = 30145   (手 Deathmantle Handguards)
-- AiPlayerbot.GearProgressionSystem.2.4.1.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.4.1.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.4.1.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.4.1.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.4.1.14 = 24528   (披风 130 Epic Warrior Cloak)
-- AiPlayerbot.GearProgressionSystem.2.4.1.15 = 29962   (主手 Heartrazor)
-- AiPlayerbot.GearProgressionSystem.2.4.1.16 = 33640   (副手 Fury)
-- [combat / cls=4 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.4.1.0 = 30146   (头 Deathmantle Helm)
-- AiPlayerbot.GearProgressionSystem.3.4.1.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.4.1.2 = 32377   (肩 Mantle of Darkness)
-- AiPlayerbot.GearProgressionSystem.3.4.1.4 = 30144   (胸 Deathmantle Chestguard)
-- AiPlayerbot.GearProgressionSystem.3.4.1.5 = 34929   (腰 Belt of the Silent Path)
-- AiPlayerbot.GearProgressionSystem.3.4.1.6 = 30148   (腿 Deathmantle Legguards)
-- AiPlayerbot.GearProgressionSystem.3.4.1.7 = 30891   (脚 Black Featherlight Boots)
-- AiPlayerbot.GearProgressionSystem.3.4.1.8 = 30863   (腕 Deadly Cuffs)
-- AiPlayerbot.GearProgressionSystem.3.4.1.9 = 30145   (手 Deathmantle Handguards)
-- AiPlayerbot.GearProgressionSystem.3.4.1.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.4.1.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.4.1.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.4.1.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.4.1.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.4.1.15 = 30865   (主手 Tracker's Blade)
-- AiPlayerbot.GearProgressionSystem.3.4.1.16 = 34950   (副手 Vanir's Left Fist of Savagery)
-- [assassination / cls=4 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.4.0.0 = 31281   (头 Mask of Veiled Death)
-- AiPlayerbot.GearProgressionSystem.0.4.0.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.4.0.2 = 25790   (肩 Expedition Scout's Epaulets)
-- AiPlayerbot.GearProgressionSystem.0.4.0.4 = 30933   (胸 Hauberk of Karabor)
-- AiPlayerbot.GearProgressionSystem.0.4.0.5 = 29247   (腰 Girdle of the Deathdealer)
-- AiPlayerbot.GearProgressionSystem.0.4.0.6 = 31545   (腿 Oilcloth Breeches)
-- AiPlayerbot.GearProgressionSystem.0.4.0.7 = 30939   (脚 Felboar Hide Shoes)
-- AiPlayerbot.GearProgressionSystem.0.4.0.8 = 29246   (腕 Nightfall Wristguards)
-- AiPlayerbot.GearProgressionSystem.0.4.0.9 = 29503   (手 Cobrascale Gloves)
-- AiPlayerbot.GearProgressionSystem.0.4.0.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.4.0.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.4.0.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.4.0.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.4.0.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.4.0.15 = 29360   (主手 Vileblade of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.0.4.0.16 = 28187   (副手 Star-Heart Lamp)
-- [assassination / cls=4 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.4.0.0 = 29044   (头 Netherblade Facemask)
-- AiPlayerbot.GearProgressionSystem.1.4.0.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.4.0.2 = 29147   (肩 Talbuk Hide Spaulders)
-- AiPlayerbot.GearProgressionSystem.1.4.0.4 = 29525   (胸 Primalstrike Vest)
-- AiPlayerbot.GearProgressionSystem.1.4.0.5 = 29526   (腰 Primalstrike Belt)
-- AiPlayerbot.GearProgressionSystem.1.4.0.6 = 29046   (腿 Netherblade Breeches)
-- AiPlayerbot.GearProgressionSystem.1.4.0.7 = 28669   (脚 Rapscallion Boots)
-- AiPlayerbot.GearProgressionSystem.1.4.0.8 = 29527   (腕 Primalstrike Bracers)
-- AiPlayerbot.GearProgressionSystem.1.4.0.9 = 29048   (手 Netherblade Gloves)
-- AiPlayerbot.GearProgressionSystem.1.4.0.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.4.0.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.4.0.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.4.0.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.4.0.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.4.0.15 = 28312   (主手 Gladiator's Shanker)
-- AiPlayerbot.GearProgressionSystem.1.4.0.16 = 28734   (副手 Jewel of Infinite Possibilities)
-- [assassination / cls=4 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.4.0.0 = 30146   (头 Deathmantle Helm)
-- AiPlayerbot.GearProgressionSystem.2.4.0.1 = 33296   (颈 Brooch of Deftness)
-- AiPlayerbot.GearProgressionSystem.2.4.0.2 = 34613   (肩 Shoulderpads of the Silvermoon Retainer)
-- AiPlayerbot.GearProgressionSystem.2.4.0.4 = 30144   (胸 Deathmantle Chestguard)
-- AiPlayerbot.GearProgressionSystem.2.4.0.5 = 30040   (腰 Belt of Deep Shadow)
-- AiPlayerbot.GearProgressionSystem.2.4.0.6 = 30148   (腿 Deathmantle Legguards)
-- AiPlayerbot.GearProgressionSystem.2.4.0.7 = 30039   (脚 Boots of Utter Darkness)
-- AiPlayerbot.GearProgressionSystem.2.4.0.8 = 33540   (腕 Master Assassin Wristwraps)
-- AiPlayerbot.GearProgressionSystem.2.4.0.9 = 30145   (手 Deathmantle Handguards)
-- AiPlayerbot.GearProgressionSystem.2.4.0.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.4.0.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.4.0.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.4.0.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.4.0.14 = 24528   (披风 130 Epic Warrior Cloak)
-- AiPlayerbot.GearProgressionSystem.2.4.0.15 = 29962   (主手 Heartrazor)
-- AiPlayerbot.GearProgressionSystem.2.4.0.16 = 28825   (副手 Aldori Legacy Defender)
-- [assassination / cls=4 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.4.0.0 = 30146   (头 Deathmantle Helm)
-- AiPlayerbot.GearProgressionSystem.3.4.0.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.4.0.2 = 32377   (肩 Mantle of Darkness)
-- AiPlayerbot.GearProgressionSystem.3.4.0.4 = 30144   (胸 Deathmantle Chestguard)
-- AiPlayerbot.GearProgressionSystem.3.4.0.5 = 34929   (腰 Belt of the Silent Path)
-- AiPlayerbot.GearProgressionSystem.3.4.0.6 = 30148   (腿 Deathmantle Legguards)
-- AiPlayerbot.GearProgressionSystem.3.4.0.7 = 30891   (脚 Black Featherlight Boots)
-- AiPlayerbot.GearProgressionSystem.3.4.0.8 = 30863   (腕 Deadly Cuffs)
-- AiPlayerbot.GearProgressionSystem.3.4.0.9 = 30145   (手 Deathmantle Handguards)
-- AiPlayerbot.GearProgressionSystem.3.4.0.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.4.0.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.4.0.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.4.0.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.4.0.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.4.0.15 = 30865   (主手 Tracker's Blade)
-- AiPlayerbot.GearProgressionSystem.3.4.0.16 = 34952   (副手 The Mutilator)
-- [arms / cls=1 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.1.0.0 = 31105   (头 Overlord's Helmet of Second Sight)
-- AiPlayerbot.GearProgressionSystem.0.1.0.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.1.0.2 = 32073   (肩 Spaulders of Dementia)
-- AiPlayerbot.GearProgressionSystem.0.1.0.4 = 28483   (胸 Breastplate of Kings)
-- AiPlayerbot.GearProgressionSystem.0.1.0.5 = 30962   (腰 Borak's Belt of Bravery)
-- AiPlayerbot.GearProgressionSystem.0.1.0.6 = 32414   (腿 Tom's Legs A)
-- AiPlayerbot.GearProgressionSystem.0.1.0.7 = 27788   (脚 Bloodsworn Warboots)
-- AiPlayerbot.GearProgressionSystem.0.1.0.8 = 23537   (腕 Black Felsteel Bracers)
-- AiPlayerbot.GearProgressionSystem.0.1.0.9 = 30375   (手 Gauntlets of the Vanquisher)
-- AiPlayerbot.GearProgressionSystem.0.1.0.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.1.0.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.1.0.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.1.0.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.1.0.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.1.0.15 = 22736   (主手 Andonisus, Reaper of Souls)
-- AiPlayerbot.GearProgressionSystem.0.1.0.16 = 28187   (副手 Star-Heart Lamp)
-- [arms / cls=1 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.1.0.0 = 29021   (头 Warbringer Battle-Helm)
-- AiPlayerbot.GearProgressionSystem.1.1.0.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.1.0.2 = 30740   (肩 Ripfiend Shoulderplates)
-- AiPlayerbot.GearProgressionSystem.1.1.0.4 = 27906   (胸 Crimsonforge Breastplate)
-- AiPlayerbot.GearProgressionSystem.1.1.0.5 = 28385   (腰 General's Plate Belt)
-- AiPlayerbot.GearProgressionSystem.1.1.0.6 = 32417   (腿 Tom's Legs 1)
-- AiPlayerbot.GearProgressionSystem.1.1.0.7 = 32954   (脚 Tom's Boots 1)
-- AiPlayerbot.GearProgressionSystem.1.1.0.8 = 32957   (腕 Tom's Bracer 1)
-- AiPlayerbot.GearProgressionSystem.1.1.0.9 = 29020   (手 Warbringer Gauntlets)
-- AiPlayerbot.GearProgressionSystem.1.1.0.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.1.0.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.1.0.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.1.0.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.1.0.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.1.0.15 = 28476   (主手 Gladiator's Maul)
-- [arms / cls=1 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.1.0.0 = 29983   (头 Fel-Steel Warhelm)
-- AiPlayerbot.GearProgressionSystem.2.1.0.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.1.0.2 = 30122   (肩 Destroyer Shoulderblades)
-- AiPlayerbot.GearProgressionSystem.2.1.0.4 = 28484   (胸 Bulwark of Kings)
-- AiPlayerbot.GearProgressionSystem.2.1.0.5 = 24537   (腰 130 Epic Warrior Waistband)
-- AiPlayerbot.GearProgressionSystem.2.1.0.6 = 30121   (腿 Destroyer Greaves)
-- AiPlayerbot.GearProgressionSystem.2.1.0.7 = 32955   (脚 Tom's Boots 2)
-- AiPlayerbot.GearProgressionSystem.2.1.0.8 = 32958   (腕 Tom's Bracer 2)
-- AiPlayerbot.GearProgressionSystem.2.1.0.9 = 24529   (手 130 Epic Warrior Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.1.0.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.1.0.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.1.0.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.1.0.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.1.0.14 = 28777   (披风 Cloak of the Pit Stalker)
-- AiPlayerbot.GearProgressionSystem.2.1.0.15 = 32014   (主手 Merciless Gladiator's Maul)
-- [arms / cls=1 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.1.0.0 = 32373   (头 Helm of the Illidari Shatterer)
-- AiPlayerbot.GearProgressionSystem.3.1.0.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.1.0.2 = 30866   (肩 Blood-stained Pauldrons)
-- AiPlayerbot.GearProgressionSystem.3.1.0.4 = 32365   (胸 Heartshatter Breastplate)
-- AiPlayerbot.GearProgressionSystem.3.1.0.5 = 30915   (腰 Belt of Seething Fury)
-- AiPlayerbot.GearProgressionSystem.3.1.0.6 = 30903   (腿 Legguards of Endless Rage)
-- AiPlayerbot.GearProgressionSystem.3.1.0.7 = 32956   (脚 Tom's Boots 3)
-- AiPlayerbot.GearProgressionSystem.3.1.0.8 = 32959   (腕 Tom's Bracer 3)
-- AiPlayerbot.GearProgressionSystem.3.1.0.9 = 32608   (手 Pillager's Gauntlets)
-- AiPlayerbot.GearProgressionSystem.3.1.0.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.1.0.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.1.0.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.1.0.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.1.0.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.1.0.15 = 34891   (主手 The Blade of Harbingers)
-- [fury / cls=1 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.1.1.0 = 31105   (头 Overlord's Helmet of Second Sight)
-- AiPlayerbot.GearProgressionSystem.0.1.1.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.1.1.2 = 32073   (肩 Spaulders of Dementia)
-- AiPlayerbot.GearProgressionSystem.0.1.1.4 = 28483   (胸 Breastplate of Kings)
-- AiPlayerbot.GearProgressionSystem.0.1.1.5 = 30962   (腰 Borak's Belt of Bravery)
-- AiPlayerbot.GearProgressionSystem.0.1.1.6 = 32414   (腿 Tom's Legs A)
-- AiPlayerbot.GearProgressionSystem.0.1.1.7 = 27788   (脚 Bloodsworn Warboots)
-- AiPlayerbot.GearProgressionSystem.0.1.1.8 = 23537   (腕 Black Felsteel Bracers)
-- AiPlayerbot.GearProgressionSystem.0.1.1.9 = 30375   (手 Gauntlets of the Vanquisher)
-- AiPlayerbot.GearProgressionSystem.0.1.1.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.1.1.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.1.1.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.1.1.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.1.1.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.1.1.15 = 22736   (主手 Andonisus, Reaper of Souls)
-- AiPlayerbot.GearProgressionSystem.0.1.1.16 = 28187   (副手 Star-Heart Lamp)
-- [fury / cls=1 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.1.1.0 = 29021   (头 Warbringer Battle-Helm)
-- AiPlayerbot.GearProgressionSystem.1.1.1.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.1.1.2 = 30740   (肩 Ripfiend Shoulderplates)
-- AiPlayerbot.GearProgressionSystem.1.1.1.4 = 27906   (胸 Crimsonforge Breastplate)
-- AiPlayerbot.GearProgressionSystem.1.1.1.5 = 28385   (腰 General's Plate Belt)
-- AiPlayerbot.GearProgressionSystem.1.1.1.6 = 32417   (腿 Tom's Legs 1)
-- AiPlayerbot.GearProgressionSystem.1.1.1.7 = 32954   (脚 Tom's Boots 1)
-- AiPlayerbot.GearProgressionSystem.1.1.1.8 = 32957   (腕 Tom's Bracer 1)
-- AiPlayerbot.GearProgressionSystem.1.1.1.9 = 29020   (手 Warbringer Gauntlets)
-- AiPlayerbot.GearProgressionSystem.1.1.1.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.1.1.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.1.1.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.1.1.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.1.1.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.1.1.15 = 30733   (主手 Hope Ender)
-- AiPlayerbot.GearProgressionSystem.1.1.1.16 = 28302   (副手 Gladiator's Bonecracker)
-- [fury / cls=1 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.1.1.0 = 29983   (头 Fel-Steel Warhelm)
-- AiPlayerbot.GearProgressionSystem.2.1.1.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.1.1.2 = 30122   (肩 Destroyer Shoulderblades)
-- AiPlayerbot.GearProgressionSystem.2.1.1.4 = 28484   (胸 Bulwark of Kings)
-- AiPlayerbot.GearProgressionSystem.2.1.1.5 = 24537   (腰 130 Epic Warrior Waistband)
-- AiPlayerbot.GearProgressionSystem.2.1.1.6 = 30121   (腿 Destroyer Greaves)
-- AiPlayerbot.GearProgressionSystem.2.1.1.7 = 32955   (脚 Tom's Boots 2)
-- AiPlayerbot.GearProgressionSystem.2.1.1.8 = 32958   (腕 Tom's Bracer 2)
-- AiPlayerbot.GearProgressionSystem.2.1.1.9 = 24529   (手 130 Epic Warrior Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.1.1.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.1.1.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.1.1.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.1.1.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.1.1.14 = 28777   (披风 Cloak of the Pit Stalker)
-- AiPlayerbot.GearProgressionSystem.2.1.1.15 = 28433   (主手 Wicked Edge of the Planes)
-- AiPlayerbot.GearProgressionSystem.2.1.1.16 = 31958   (副手 Merciless Gladiator's Bonecracker)
-- [fury / cls=1 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.1.1.0 = 32373   (头 Helm of the Illidari Shatterer)
-- AiPlayerbot.GearProgressionSystem.3.1.1.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.1.1.2 = 30866   (肩 Blood-stained Pauldrons)
-- AiPlayerbot.GearProgressionSystem.3.1.1.4 = 32365   (胸 Heartshatter Breastplate)
-- AiPlayerbot.GearProgressionSystem.3.1.1.5 = 30915   (腰 Belt of Seething Fury)
-- AiPlayerbot.GearProgressionSystem.3.1.1.6 = 30903   (腿 Legguards of Endless Rage)
-- AiPlayerbot.GearProgressionSystem.3.1.1.7 = 32956   (脚 Tom's Boots 3)
-- AiPlayerbot.GearProgressionSystem.3.1.1.8 = 32959   (腕 Tom's Bracer 3)
-- AiPlayerbot.GearProgressionSystem.3.1.1.9 = 32608   (手 Pillager's Gauntlets)
-- AiPlayerbot.GearProgressionSystem.3.1.1.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.1.1.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.1.1.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.1.1.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.1.1.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.1.1.15 = 30881   (主手 Blade of Infamy)
-- AiPlayerbot.GearProgressionSystem.3.1.1.16 = 34015   (副手 Vengeful Gladiator's Chopper)
-- [ret / cls=2 spec=2 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.2.2.0 = 31105   (头 Overlord's Helmet of Second Sight)
-- AiPlayerbot.GearProgressionSystem.0.2.2.1 = 31695   (颈 Natasha's Choker)
-- AiPlayerbot.GearProgressionSystem.0.2.2.2 = 32073   (肩 Spaulders of Dementia)
-- AiPlayerbot.GearProgressionSystem.0.2.2.4 = 28483   (胸 Breastplate of Kings)
-- AiPlayerbot.GearProgressionSystem.0.2.2.5 = 30962   (腰 Borak's Belt of Bravery)
-- AiPlayerbot.GearProgressionSystem.0.2.2.6 = 32414   (腿 Tom's Legs A)
-- AiPlayerbot.GearProgressionSystem.0.2.2.7 = 27788   (脚 Bloodsworn Warboots)
-- AiPlayerbot.GearProgressionSystem.0.2.2.8 = 23537   (腕 Black Felsteel Bracers)
-- AiPlayerbot.GearProgressionSystem.0.2.2.9 = 30375   (手 Gauntlets of the Vanquisher)
-- AiPlayerbot.GearProgressionSystem.0.2.2.10 = 32942   (戒指1 Ring of the Overseer)
-- AiPlayerbot.GearProgressionSystem.0.2.2.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.2.2.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.2.2.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.2.2.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.2.2.15 = 29171   (主手 Earthwarden)
-- [ret / cls=2 spec=2 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.2.2.0 = 23521   (头 Ragesteel Helm)
-- AiPlayerbot.GearProgressionSystem.1.2.2.1 = 34679   (颈 Shattered Sun Pendant of Might)
-- AiPlayerbot.GearProgressionSystem.1.2.2.2 = 30740   (肩 Ripfiend Shoulderplates)
-- AiPlayerbot.GearProgressionSystem.1.2.2.4 = 27906   (胸 Crimsonforge Breastplate)
-- AiPlayerbot.GearProgressionSystem.1.2.2.5 = 28385   (腰 General's Plate Belt)
-- AiPlayerbot.GearProgressionSystem.1.2.2.6 = 32417   (腿 Tom's Legs 1)
-- AiPlayerbot.GearProgressionSystem.1.2.2.7 = 32954   (脚 Tom's Boots 1)
-- AiPlayerbot.GearProgressionSystem.1.2.2.8 = 32957   (腕 Tom's Bracer 1)
-- AiPlayerbot.GearProgressionSystem.1.2.2.9 = 23520   (手 Ragesteel Gloves)
-- AiPlayerbot.GearProgressionSystem.1.2.2.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.2.2.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.2.2.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.2.2.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.2.2.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.2.2.15 = 28476   (主手 Gladiator's Maul)
-- [ret / cls=2 spec=2 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.2.2.0 = 29983   (头 Fel-Steel Warhelm)
-- AiPlayerbot.GearProgressionSystem.2.2.2.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.2.2.2 = 24534   (肩 130 Epic Warrior Pauldrons)
-- AiPlayerbot.GearProgressionSystem.2.2.2.4 = 28484   (胸 Bulwark of Kings)
-- AiPlayerbot.GearProgressionSystem.2.2.2.5 = 24537   (腰 130 Epic Warrior Waistband)
-- AiPlayerbot.GearProgressionSystem.2.2.2.6 = 32418   (腿 Tom's Legs 2)
-- AiPlayerbot.GearProgressionSystem.2.2.2.7 = 32955   (脚 Tom's Boots 2)
-- AiPlayerbot.GearProgressionSystem.2.2.2.8 = 32958   (腕 Tom's Bracer 2)
-- AiPlayerbot.GearProgressionSystem.2.2.2.9 = 24529   (手 130 Epic Warrior Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.2.2.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.2.2.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.2.2.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.2.2.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.2.2.14 = 28777   (披风 Cloak of the Pit Stalker)
-- AiPlayerbot.GearProgressionSystem.2.2.2.15 = 32014   (主手 Merciless Gladiator's Maul)
-- [ret / cls=2 spec=2 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.2.2.0 = 32373   (头 Helm of the Illidari Shatterer)
-- AiPlayerbot.GearProgressionSystem.3.2.2.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.2.2.2 = 30866   (肩 Blood-stained Pauldrons)
-- AiPlayerbot.GearProgressionSystem.3.2.2.4 = 32365   (胸 Heartshatter Breastplate)
-- AiPlayerbot.GearProgressionSystem.3.2.2.5 = 30915   (腰 Belt of Seething Fury)
-- AiPlayerbot.GearProgressionSystem.3.2.2.6 = 30903   (腿 Legguards of Endless Rage)
-- AiPlayerbot.GearProgressionSystem.3.2.2.7 = 32956   (脚 Tom's Boots 3)
-- AiPlayerbot.GearProgressionSystem.3.2.2.8 = 32959   (腕 Tom's Bracer 3)
-- AiPlayerbot.GearProgressionSystem.3.2.2.9 = 32608   (手 Pillager's Gauntlets)
-- AiPlayerbot.GearProgressionSystem.3.2.2.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.2.2.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.2.2.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.2.2.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.2.2.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.2.2.15 = 34891   (主手 The Blade of Harbingers)
-- [bm / cls=3 spec=0 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.3.0.0 = 28275   (头 Beast Lord Helm)
-- AiPlayerbot.GearProgressionSystem.0.3.0.1 = 29381   (颈 Choker of Vile Intent)
-- AiPlayerbot.GearProgressionSystem.0.3.0.2 = 27994   (肩 Mantle of Three Terrors)
-- AiPlayerbot.GearProgressionSystem.0.3.0.4 = 28228   (胸 Beast Lord Cuirass)
-- AiPlayerbot.GearProgressionSystem.0.3.0.5 = 25789   (腰 Rune-Engraved Belt)
-- AiPlayerbot.GearProgressionSystem.0.3.0.6 = 27874   (腿 Beast Lord Leggings)
-- AiPlayerbot.GearProgressionSystem.0.3.0.7 = 29262   (脚 Boots of the Endless Hunt)
-- AiPlayerbot.GearProgressionSystem.0.3.0.8 = 29517   (腕 Ebon Netherscale Bracers)
-- AiPlayerbot.GearProgressionSystem.0.3.0.9 = 27474   (手 Beast Lord Handguards)
-- AiPlayerbot.GearProgressionSystem.0.3.0.10 = 29281   (戒指1 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.3.0.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.3.0.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.3.0.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.3.0.14 = 27892   (披风 Cloak of the Inciter)
-- AiPlayerbot.GearProgressionSystem.0.3.0.15 = 22736   (主手 Andonisus, Reaper of Souls)
-- AiPlayerbot.GearProgressionSystem.0.3.0.17 = 27526   (远程 Skyfire Hawk-Bow)
-- [bm / cls=3 spec=0 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.3.0.0 = 28275   (头 Beast Lord Helm)
-- AiPlayerbot.GearProgressionSystem.1.3.0.1 = 28509   (颈 Worgen Claw Necklace)
-- AiPlayerbot.GearProgressionSystem.1.3.0.2 = 28344   (肩 Wyrmfury Pauldrons)
-- AiPlayerbot.GearProgressionSystem.1.3.0.4 = 28228   (胸 Beast Lord Cuirass)
-- AiPlayerbot.GearProgressionSystem.1.3.0.5 = 28656   (腰 Girdle of the Prowler)
-- AiPlayerbot.GearProgressionSystem.1.3.0.6 = 27874   (腿 Beast Lord Leggings)
-- AiPlayerbot.GearProgressionSystem.1.3.0.7 = 27450   (脚 Wild Stalker Boots)
-- AiPlayerbot.GearProgressionSystem.1.3.0.8 = 27494   (腕 Emerald Eye Bracer)
-- AiPlayerbot.GearProgressionSystem.1.3.0.9 = 27474   (手 Beast Lord Handguards)
-- AiPlayerbot.GearProgressionSystem.1.3.0.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.3.0.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.3.0.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.3.0.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.3.0.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.3.0.15 = 28476   (主手 Gladiator's Maul)
-- AiPlayerbot.GearProgressionSystem.1.3.0.17 = 28504   (远程 Steelhawk Crossbow)
-- [bm / cls=3 spec=0 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.3.0.0 = 32474   (头 Surestrike Goggles v2.0)
-- AiPlayerbot.GearProgressionSystem.2.3.0.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.3.0.2 = 33206   (肩 Pauldrons of Primal Fury)
-- AiPlayerbot.GearProgressionSystem.2.3.0.4 = 30139   (胸 Rift Stalker Hauberk)
-- AiPlayerbot.GearProgressionSystem.2.3.0.5 = 30046   (腰 Belt of the Black Eagle)
-- AiPlayerbot.GearProgressionSystem.2.3.0.6 = 30142   (腿 Rift Stalker Leggings)
-- AiPlayerbot.GearProgressionSystem.2.3.0.7 = 33482   (脚 Cobra-Lash Boots)
-- AiPlayerbot.GearProgressionSystem.2.3.0.8 = 30026   (腕 Bands of the Celestial Archer)
-- AiPlayerbot.GearProgressionSystem.2.3.0.9 = 30140   (手 Rift Stalker Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.3.0.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.3.0.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.3.0.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.3.0.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.3.0.14 = 28777   (披风 Cloak of the Pit Stalker)
-- AiPlayerbot.GearProgressionSystem.2.3.0.15 = 32014   (主手 Merciless Gladiator's Maul)
-- AiPlayerbot.GearProgressionSystem.2.3.0.17 = 29949   (远程 Arcanite Steam-Pistol)
-- [bm / cls=3 spec=0 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.3.0.0 = 32376   (头 Forest Prowler's Helm)
-- AiPlayerbot.GearProgressionSystem.3.3.0.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.3.0.2 = 32264   (肩 Shoulders of the Hidden Predator)
-- AiPlayerbot.GearProgressionSystem.3.3.0.4 = 30139   (胸 Rift Stalker Hauberk)
-- AiPlayerbot.GearProgressionSystem.3.3.0.5 = 32346   (腰 Boneweave Girdle)
-- AiPlayerbot.GearProgressionSystem.3.3.0.6 = 30142   (腿 Rift Stalker Leggings)
-- AiPlayerbot.GearProgressionSystem.3.3.0.7 = 32510   (脚 Softstep Boots of Tracking)
-- AiPlayerbot.GearProgressionSystem.3.3.0.8 = 32574   (腕 Bindings of Lightning Reflexes)
-- AiPlayerbot.GearProgressionSystem.3.3.0.9 = 32234   (手 Fists of Mukoa)
-- AiPlayerbot.GearProgressionSystem.3.3.0.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.3.0.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.3.0.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.3.0.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.3.0.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.3.0.15 = 34891   (主手 The Blade of Harbingers)
-- AiPlayerbot.GearProgressionSystem.3.3.0.17 = 34892   (远程 Crossbow of Relentless Strikes)
-- [marks / cls=3 spec=1 / 团本前]
-- AiPlayerbot.GearProgressionSystem.0.3.1.0 = 27888   (头 Dream-Wing Helm)
-- AiPlayerbot.GearProgressionSystem.0.3.1.1 = 29381   (颈 Choker of Vile Intent)
-- AiPlayerbot.GearProgressionSystem.0.3.1.2 = 32137   (肩 Chancellor's Chain Spaulders)
-- AiPlayerbot.GearProgressionSystem.0.3.1.4 = 34799   (胸 Hauberk of the War Bringer)
-- AiPlayerbot.GearProgressionSystem.0.3.1.5 = 25789   (腰 Rune-Engraved Belt)
-- AiPlayerbot.GearProgressionSystem.0.3.1.6 = 28173   (腿 Mag'hari Huntsman's Leggings)
-- AiPlayerbot.GearProgressionSystem.0.3.1.7 = 29262   (脚 Boots of the Endless Hunt)
-- AiPlayerbot.GearProgressionSystem.0.3.1.8 = 29517   (腕 Ebon Netherscale Bracers)
-- AiPlayerbot.GearProgressionSystem.0.3.1.9 = 30951   (手 Ar'tor's Mainstay)
-- AiPlayerbot.GearProgressionSystem.0.3.1.10 = 29281   (戒指1 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.3.1.11 = 29281   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.0.3.1.12 = 29383   (饰品1 Bloodlust Brooch)
-- AiPlayerbot.GearProgressionSystem.0.3.1.13 = 38287   (饰品2 Empty Mug of Direbrew)
-- AiPlayerbot.GearProgressionSystem.0.3.1.14 = 24259   (披风 Vengeance Wrap)
-- AiPlayerbot.GearProgressionSystem.0.3.1.15 = 22736   (主手 Andonisus, Reaper of Souls)
-- AiPlayerbot.GearProgressionSystem.0.3.1.17 = 27526   (远程 Skyfire Hawk-Bow)
-- [marks / cls=3 spec=1 / P1(T4)]
-- AiPlayerbot.GearProgressionSystem.1.3.1.0 = 29081   (头 Demon Stalker Greathelm)
-- AiPlayerbot.GearProgressionSystem.1.3.1.1 = 28509   (颈 Worgen Claw Necklace)
-- AiPlayerbot.GearProgressionSystem.1.3.1.2 = 28344   (肩 Wyrmfury Pauldrons)
-- AiPlayerbot.GearProgressionSystem.1.3.1.4 = 29515   (胸 Ebon Netherscale Breastplate)
-- AiPlayerbot.GearProgressionSystem.1.3.1.5 = 28656   (腰 Girdle of the Prowler)
-- AiPlayerbot.GearProgressionSystem.1.3.1.6 = 29083   (腿 Demon Stalker Greaves)
-- AiPlayerbot.GearProgressionSystem.1.3.1.7 = 27450   (脚 Wild Stalker Boots)
-- AiPlayerbot.GearProgressionSystem.1.3.1.8 = 27494   (腕 Emerald Eye Bracer)
-- AiPlayerbot.GearProgressionSystem.1.3.1.9 = 29085   (手 Demon Stalker Gauntlets)
-- AiPlayerbot.GearProgressionSystem.1.3.1.10 = 30738   (戒指1 Ring of Reciprocity)
-- AiPlayerbot.GearProgressionSystem.1.3.1.11 = 29282   (戒指2 Violet Signet)
-- AiPlayerbot.GearProgressionSystem.1.3.1.12 = 24128   (饰品1 Figurine - Nightseye Panther)
-- AiPlayerbot.GearProgressionSystem.1.3.1.13 = 32654   (饰品2 Crystalforged Trinket)
-- AiPlayerbot.GearProgressionSystem.1.3.1.14 = 30729   (披风 Black-Iron Battlecloak)
-- AiPlayerbot.GearProgressionSystem.1.3.1.15 = 28476   (主手 Gladiator's Maul)
-- AiPlayerbot.GearProgressionSystem.1.3.1.17 = 28504   (远程 Steelhawk Crossbow)
-- [marks / cls=3 spec=1 / P2(T5)]
-- AiPlayerbot.GearProgressionSystem.2.3.1.0 = 32474   (头 Surestrike Goggles v2.0)
-- AiPlayerbot.GearProgressionSystem.2.3.1.1 = 30059   (颈 Choker of Animalistic Fury)
-- AiPlayerbot.GearProgressionSystem.2.3.1.2 = 33206   (肩 Pauldrons of Primal Fury)
-- AiPlayerbot.GearProgressionSystem.2.3.1.4 = 30139   (胸 Rift Stalker Hauberk)
-- AiPlayerbot.GearProgressionSystem.2.3.1.5 = 30046   (腰 Belt of the Black Eagle)
-- AiPlayerbot.GearProgressionSystem.2.3.1.6 = 30142   (腿 Rift Stalker Leggings)
-- AiPlayerbot.GearProgressionSystem.2.3.1.7 = 33482   (脚 Cobra-Lash Boots)
-- AiPlayerbot.GearProgressionSystem.2.3.1.8 = 30026   (腕 Bands of the Celestial Archer)
-- AiPlayerbot.GearProgressionSystem.2.3.1.9 = 30140   (手 Rift Stalker Gauntlets)
-- AiPlayerbot.GearProgressionSystem.2.3.1.10 = 33997   (戒指1 Indalamar's Ring of 400 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.3.1.11 = 34094   (戒指2 Indalamar's Ring of 200 Attack Power)
-- AiPlayerbot.GearProgressionSystem.2.3.1.12 = 33831   (饰品1 Berserker's Call)
-- AiPlayerbot.GearProgressionSystem.2.3.1.13 = 35702   (饰品2 Figurine - Shadowsong Panther)
-- AiPlayerbot.GearProgressionSystem.2.3.1.14 = 28777   (披风 Cloak of the Pit Stalker)
-- AiPlayerbot.GearProgressionSystem.2.3.1.15 = 32014   (主手 Merciless Gladiator's Maul)
-- AiPlayerbot.GearProgressionSystem.2.3.1.17 = 29949   (远程 Arcanite Steam-Pistol)
-- [marks / cls=3 spec=1 / P4(SWP)]
-- AiPlayerbot.GearProgressionSystem.3.3.1.0 = 32376   (头 Forest Prowler's Helm)
-- AiPlayerbot.GearProgressionSystem.3.3.1.1 = 32260   (颈 Choker of Endless Nightmares)
-- AiPlayerbot.GearProgressionSystem.3.3.1.2 = 32264   (肩 Shoulders of the Hidden Predator)
-- AiPlayerbot.GearProgressionSystem.3.3.1.4 = 30907   (胸 Mail of Fevered Pursuit)
-- AiPlayerbot.GearProgressionSystem.3.3.1.5 = 32346   (腰 Boneweave Girdle)
-- AiPlayerbot.GearProgressionSystem.3.3.1.6 = 31005   (腿 Gronnstalker's Leggings)
-- AiPlayerbot.GearProgressionSystem.3.3.1.7 = 32510   (脚 Softstep Boots of Tracking)
-- AiPlayerbot.GearProgressionSystem.3.3.1.8 = 32574   (腕 Bindings of Lightning Reflexes)
-- AiPlayerbot.GearProgressionSystem.3.3.1.9 = 32234   (手 Fists of Mukoa)
-- AiPlayerbot.GearProgressionSystem.3.3.1.10 = 32497   (戒指1 Stormrage Signet Ring)
-- AiPlayerbot.GearProgressionSystem.3.3.1.11 = 29997   (戒指2 Band of the Ranger-General)
-- AiPlayerbot.GearProgressionSystem.3.3.1.12 = 32505   (饰品1 Madness of the Betrayer)
-- AiPlayerbot.GearProgressionSystem.3.3.1.13 = 32483   (饰品2 The Skull of Gul'dan)
-- AiPlayerbot.GearProgressionSystem.3.3.1.14 = 32323   (披风 Shadowmoon Destroyer's Drape)
-- AiPlayerbot.GearProgressionSystem.3.3.1.15 = 34891   (主手 The Blade of Harbingers)
-- AiPlayerbot.GearProgressionSystem.3.3.1.17 = 34892   (远程 Crossbow of Relentless Strikes)
-- ===============================================================================

ALTER TABLE `ai_playerbot_bis_gear` ADD COLUMN `phase` TINYINT NOT NULL DEFAULT 0;
ALTER TABLE `ai_playerbot_bis_gear` DROP PRIMARY KEY, ADD PRIMARY KEY (`cls`, `spec`, `phase`, `slot`);

-- 清掉 dev/233 留下的旧行（它们默认 phase=0，槽位集合与本版不同：
-- 老行没有 slot 14、有的专精多/少槽位；不清会在 phase 0 里和本版行混在一起）
DELETE FROM `ai_playerbot_bis_gear` WHERE `spec` IN ('arcane','fire','frost','affliction','destro','shadow','balance','elemental','enhance','feral','combat','assassination','arms','fury','ret','bm','marks');

INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,0,30206,'Cowl of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,1,24114,'Braided Eternium Chain',102,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,2,30210,'Mantle of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,9,34808,'Gloves of Arcane Acuity',110,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,0,30206,'Cowl of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,2,30210,'Mantle of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,4,30196,'Robes of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,5,27795,'Sash of Serpentra',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,9,30205,'Gloves of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,14,34792,'Cloak of the Betrayed',115,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,0,30206,'Cowl of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,2,30024,'Mantle of the Elven Kings',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,4,30196,'Robes of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,9,30205,'Gloves of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,10,34095,'Indalamar''s Ring of 100 Hit Rating',130,100) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,15,32053,'Merciless Gladiator''s Spellblade',136,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',2,16,28825,'Aldori Legacy Defender',125,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,0,30206,'Cowl of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,2,30210,'Mantle of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,4,30196,'Robes of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,5,32256,'Waistwrap of Infinity',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,9,30205,'Gloves of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'arcane',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,9,21847,'Spellfire Gloves',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,2,24554,'Gladiator''s Dreadweave Mantle',123,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,4,27799,'Vermillion Robes of the Dominant',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,6,29078,'Legwraps of the Aldor',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,2,30024,'Mantle of the Elven Kings',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,4,30196,'Robes of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,9,30205,'Gloves of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,15,32053,'Merciless Gladiator''s Spellblade',136,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',2,16,28825,'Aldori Legacy Defender',125,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,0,32525,'Cowl of the Illidari High Lord',151,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,2,32338,'Blood-cursed Shoulderpads',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,4,30913,'Robes of Rhonin',151,27) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,5,32256,'Waistwrap of Infinity',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,6,31058,'Leggings of the Tempest',146,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,9,31055,'Gloves of the Tempest',146,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'fire',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,9,21847,'Spellfire Gloves',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,2,24554,'Gladiator''s Dreadweave Mantle',123,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,4,27799,'Vermillion Robes of the Dominant',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,6,29078,'Legwraps of the Aldor',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,2,30024,'Mantle of the Elven Kings',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,4,30196,'Robes of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,6,30207,'Leggings of Tirisfal',133,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,9,30205,'Gloves of Tirisfal',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,15,32053,'Merciless Gladiator''s Spellblade',136,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',2,16,28825,'Aldori Legacy Defender',125,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,0,32525,'Cowl of the Illidari High Lord',151,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,2,32338,'Blood-cursed Shoulderpads',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,4,30913,'Robes of Rhonin',151,27) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,5,32256,'Waistwrap of Infinity',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,6,31058,'Leggings of the Tempest',146,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,9,31055,'Gloves of the Tempest',146,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (8,'frost',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,9,21847,'Spellfire Gloves',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,2,28967,'Voidheart Mantle',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,4,28964,'Voidheart Robe',120,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,6,28966,'Voidheart Leggings',120,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,2,30215,'Mantle of the Corruptor',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,4,30214,'Robe of the Corruptor',133,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,6,30213,'Leggings of the Corruptor',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,9,30211,'Gloves of the Corruptor',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,15,32053,'Merciless Gladiator''s Spellblade',136,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',2,16,32027,'Merciless Gladiator''s Quickblade',136,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,0,32525,'Cowl of the Illidari High Lord',151,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,2,31054,'Mantle of the Malefic',146,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,4,30913,'Robes of Rhonin',151,27) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,5,32256,'Waistwrap of Infinity',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,6,32367,'Leggings of Devastation',141,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,9,31050,'Gloves of the Malefic',146,11) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'affliction',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,9,21847,'Spellfire Gloves',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,2,28967,'Voidheart Mantle',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,4,28964,'Voidheart Robe',120,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,6,28966,'Voidheart Leggings',120,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,2,30215,'Mantle of the Corruptor',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,4,30214,'Robe of the Corruptor',133,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,6,30213,'Leggings of the Corruptor',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,9,30211,'Gloves of the Corruptor',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,15,32053,'Merciless Gladiator''s Spellblade',136,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',2,16,32027,'Merciless Gladiator''s Quickblade',136,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,0,31051,'Hood of the Malefic',146,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,2,31054,'Mantle of the Malefic',146,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,4,31052,'Robe of the Malefic',146,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,5,34541,'Belt of the Malefic',154,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,6,31053,'Leggings of the Malefic',146,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,7,34564,'Boots of the Malefic',154,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,9,31050,'Gloves of the Malefic',146,11) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (9,'destro',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,9,21847,'Spellfire Gloves',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,15,32190,'Chancellor''s Spellblade',105,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,2,24554,'Gladiator''s Dreadweave Mantle',123,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,4,29056,'Shroud of the Incarnate',120,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,6,30734,'Leggings of the Seventh Circle',120,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,15,30723,'Talon of the Tempest',120,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,1,30008,'Pendant of the Lost Ages',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,2,30024,'Mantle of the Elven Kings',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,4,30159,'Shroud of the Avatar',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,6,30162,'Leggings of the Avatar',133,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,9,30160,'Handguards of the Avatar',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,15,33283,'Amani Punisher',132,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',2,16,33334,'Fetish of the Primal Gods',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,0,32525,'Cowl of the Illidari High Lord',151,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,2,32338,'Blood-cursed Shoulderpads',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,4,30913,'Robes of Rhonin',151,27) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,5,32256,'Waistwrap of Infinity',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,6,32367,'Leggings of Devastation',141,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,9,31061,'Handguards of Absolution',146,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,15,30910,'Tempest of Chaos',151,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (5,'shadow',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,0,30233,'Nordrassil Headpiece',133,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,1,24114,'Braided Eternium Chain',102,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,2,30235,'Nordrassil Wrath-Mantle',133,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,4,30231,'Nordrassil Chestpiece',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,6,30234,'Nordrassil Wrath-Kilt',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,7,25686,'Fel Leather Boots',112,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,9,29503,'Cobrascale Gloves',105,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,15,30832,'Gavel of Unearthed Secrets',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,0,30233,'Nordrassil Headpiece',133,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,2,30235,'Nordrassil Wrath-Mantle',133,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,4,30231,'Nordrassil Chestpiece',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,6,30234,'Nordrassil Wrath-Kilt',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,14,34792,'Cloak of the Betrayed',115,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,15,32450,'Gladiator''s Gavel',123,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,0,30233,'Nordrassil Headpiece',133,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,2,30235,'Nordrassil Wrath-Mantle',133,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,4,30231,'Nordrassil Chestpiece',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,6,30234,'Nordrassil Wrath-Kilt',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,7,30039,'Boots of Utter Darkness',128,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,9,30232,'Nordrassil Gauntlets',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,12,30450,'Warp-Spring Coil',128,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,15,33283,'Amani Punisher',132,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',2,16,28825,'Aldori Legacy Defender',125,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,0,30233,'Nordrassil Headpiece',133,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,2,30235,'Nordrassil Wrath-Mantle',133,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,4,30231,'Nordrassil Chestpiece',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,5,34555,'Thunderheart Cord',154,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,6,30234,'Nordrassil Wrath-Kilt',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,7,34572,'Thunderheart Footwraps',154,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,8,34446,'Thunderheart Bands',154,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,9,31035,'Thunderheart Handguards',146,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,15,33687,'Vengeful Gladiator''s Gavel',146,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'balance',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,0,24266,'Spellstrike Hood',105,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,1,24116,'Eye of the Night',114,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,2,21869,'Frozen Shadoweave Shoulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,4,31297,'Robe of the Crimson Order',112,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,5,30460,'Netherflame Belt',110,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,6,24262,'Spellstrike Pants',105,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,7,21870,'Frozen Shadoweave Boots',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,8,29240,'Bands of Negation',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,9,34808,'Gloves of Arcane Acuity',110,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,10,29172,'Ashyen''s Gift',105,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,11,31920,'Shaffar''s Band of Brutality',100,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,12,29370,'Icon of the Silver Crescent',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,13,38290,'Dark Iron Smoking Pipe',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,15,30832,'Gavel of Unearthed Secrets',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',0,16,29269,'Sapphiron''s Wing Bone',110,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,0,28744,'Uni-Mind Headdress',115,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,1,28530,'Brooch of Unquenchable Fury',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,2,24554,'Gladiator''s Dreadweave Mantle',123,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,4,27799,'Vermillion Robes of the Dominant',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,5,30673,'Inferno Waist Cord',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,6,29036,'Cyclone Legguards',120,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,7,28585,'Ruby Slippers',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,8,27462,'Crimson Bracers of Gloom',115,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,9,30668,'Grasp of the Dead',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,10,32779,'Band of Frigid Elements',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,11,30667,'Ring of Unrelenting Storms',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,12,28223,'Arcanist''s Stone',115,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,13,29132,'Scryer''s Bloodgem',115,32) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,14,30642,'Drape of the Righteous',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,15,32450,'Gladiator''s Gavel',123,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,0,33453,'Hood of Hexing',133,31) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,2,30024,'Mantle of the Elven Kings',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,4,33965,'Hauberk of the Furious Elements',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,5,30064,'Cord of Screaming Terrors',128,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,6,30172,'Cataclysm Leggings',133,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,7,30050,'Boots of the Shifting Nightmare',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,8,29918,'Mindstorm Wristbands',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,9,30170,'Cataclysm Handgrips',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,10,33995,'Indalamar''s Ring of Healer Ownage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,11,33996,'Indalamar''s Ring of 234 Spell Damage',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,12,33829,'Hex Shrunken Head',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,13,35700,'Figurine - Crimson Serpent',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,14,28766,'Ruby Drape of the Mysticant',125,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,15,33283,'Amani Punisher',132,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',2,16,31958,'Merciless Gladiator''s Bonecracker',136,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,0,31014,'Skyshatter Headguard',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,1,32349,'Translucent Spellthread Necklace',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,2,32338,'Blood-cursed Shoulderpads',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,4,31017,'Skyshatter Breastplate',146,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,5,34542,'Skyshatter Cord',154,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,6,31020,'Skyshatter Legguards',146,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,7,30894,'Blue Suede Shoes',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,8,32270,'Focused Mana Bindings',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,9,31008,'Skyshatter Gauntlets',146,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,10,34889,'Fused Nethergon Band',141,28) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,11,32247,'Ring of Captured Storms',141,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,12,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,13,32496,'Memento of Tyrande',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,14,32590,'Nethervoid Cloak',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,15,33687,'Vengeful Gladiator''s Gavel',146,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'elemental',3,16,32361,'Blind-Seers Icon',141,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,0,27888,'Dream-Wing Helm',112,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,1,29381,'Choker of Vile Intent',110,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,2,32137,'Chancellor''s Chain Spaulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,4,34799,'Hauberk of the War Bringer',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,5,25789,'Rune-Engraved Belt',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,6,28173,'Mag''hari Huntsman''s Leggings',103,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,7,29262,'Boots of the Endless Hunt',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,8,29517,'Ebon Netherscale Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,9,30951,'Ar''tor''s Mainstay',109,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,10,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,15,29360,'Vileblade of the Betrayer',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',0,16,32188,'Chancellor''s Left Ripper',105,8) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,0,28671,'Steelspine Faceguard',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,1,29335,'Talon Lord''s Collar',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,2,28344,'Wyrmfury Pauldrons',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,4,29515,'Ebon Netherscale Breastplate',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,5,28656,'Girdle of the Prowler',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,6,30739,'Scaled Greaves of the Marksman',120,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,7,27450,'Wild Stalker Boots',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,8,27494,'Emerald Eye Bracer',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,9,28519,'Gloves of Quickening',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,15,28313,'Gladiator''s Right Ripper',123,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',1,16,28302,'Gladiator''s Bonecracker',123,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,0,32474,'Surestrike Goggles v2.0',127,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,2,33206,'Pauldrons of Primal Fury',128,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,4,34614,'Tunic of the Ranger Lord',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,5,30046,'Belt of the Black Eagle',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,6,30192,'Cataclysm Legplates',133,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,7,33482,'Cobra-Lash Boots',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,8,30026,'Bands of the Celestial Archer',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,9,33528,'Gauntlets of Sniping',128,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,14,24528,'130 Epic Warrior Cloak',130,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,15,29962,'Heartrazor',134,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',2,16,33640,'Fury',132,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,0,32376,'Forest Prowler''s Helm',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,2,32264,'Shoulders of the Hidden Predator',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,4,30907,'Mail of Fevered Pursuit',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,5,32346,'Boneweave Girdle',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,6,34914,'Leggings of the Pursuit',141,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,7,32510,'Softstep Boots of Tracking',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,8,32574,'Bindings of Lightning Reflexes',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,9,32234,'Fists of Mukoa',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,15,30865,'Tracker''s Blade',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (7,'enhance',3,16,34950,'Vanir''s Left Fist of Savagery',146,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,0,8345,'Wolfshead Helm',45,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,2,25790,'Expedition Scout''s Epaulets',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,4,30933,'Hauberk of Karabor',109,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,5,29247,'Girdle of the Deathdealer',110,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,6,31545,'Oilcloth Breeches',109,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,7,30939,'Felboar Hide Shoes',109,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,8,29246,'Nightfall Wristguards',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,9,29503,'Cobrascale Gloves',105,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',0,15,29359,'Feral Staff of Lashing',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,0,8345,'Wolfshead Helm',45,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,2,29147,'Talbuk Hide Spaulders',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,4,29525,'Primalstrike Vest',120,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,5,29526,'Primalstrike Belt',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,6,29131,'Retainer''s Leggings',115,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,7,28669,'Rapscallion Boots',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,8,29527,'Primalstrike Bracers',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,9,30644,'Grips of Deftness',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',1,15,28476,'Gladiator''s Maul',123,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,0,8345,'Wolfshead Helm',45,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,2,34613,'Shoulderpads of the Silvermoon Retainer',125,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,4,30101,'Bloodsea Brigand''s Vest',128,27) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,5,30040,'Belt of Deep Shadow',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,6,33538,'Shallow-grave Trousers',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,7,30039,'Boots of Utter Darkness',128,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,8,33540,'Master Assassin Wristwraps',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,9,33539,'Trickster''s Stickyfingers',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,14,24528,'130 Epic Warrior Cloak',130,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',2,15,32014,'Merciless Gladiator''s Maul',136,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,0,8345,'Wolfshead Helm',45,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,2,32377,'Mantle of Darkness',141,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,4,30905,'Midnight Chestguard',151,29) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,5,34929,'Belt of the Silent Path',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,6,34928,'Trousers of the Scryers'' Retainer',141,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,7,30891,'Black Featherlight Boots',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,8,30863,'Deadly Cuffs',141,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,9,32347,'Grips of Damnation',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (11,'feral',3,15,33716,'Vengeful Gladiator''s Staff',146,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,0,31281,'Mask of Veiled Death',106,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,2,25790,'Expedition Scout''s Epaulets',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,4,30933,'Hauberk of Karabor',109,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,5,29247,'Girdle of the Deathdealer',110,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,6,31545,'Oilcloth Breeches',109,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,7,30939,'Felboar Hide Shoes',109,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,8,29246,'Nightfall Wristguards',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,9,29503,'Cobrascale Gloves',105,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,15,22736,'Andonisus, Reaper of Souls',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',0,16,32188,'Chancellor''s Left Ripper',105,8) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,0,29044,'Netherblade Facemask',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,2,29147,'Talbuk Hide Spaulders',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,4,29525,'Primalstrike Vest',120,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,5,29526,'Primalstrike Belt',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,6,29046,'Netherblade Breeches',120,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,7,28669,'Rapscallion Boots',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,8,29527,'Primalstrike Bracers',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,9,29048,'Netherblade Gloves',120,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,15,30733,'Hope Ender',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',1,16,28302,'Gladiator''s Bonecracker',123,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,0,30146,'Deathmantle Helm',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,2,34613,'Shoulderpads of the Silvermoon Retainer',125,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,4,30144,'Deathmantle Chestguard',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,5,30040,'Belt of Deep Shadow',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,6,30148,'Deathmantle Legguards',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,7,30039,'Boots of Utter Darkness',128,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,8,33540,'Master Assassin Wristwraps',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,9,30145,'Deathmantle Handguards',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,14,24528,'130 Epic Warrior Cloak',130,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,15,29962,'Heartrazor',134,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',2,16,33640,'Fury',132,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,0,30146,'Deathmantle Helm',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,2,32377,'Mantle of Darkness',141,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,4,30144,'Deathmantle Chestguard',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,5,34929,'Belt of the Silent Path',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,6,30148,'Deathmantle Legguards',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,7,30891,'Black Featherlight Boots',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,8,30863,'Deadly Cuffs',141,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,9,30145,'Deathmantle Handguards',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,15,30865,'Tracker''s Blade',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'combat',3,16,34950,'Vanir''s Left Fist of Savagery',146,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,0,31281,'Mask of Veiled Death',106,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,2,25790,'Expedition Scout''s Epaulets',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,4,30933,'Hauberk of Karabor',109,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,5,29247,'Girdle of the Deathdealer',110,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,6,31545,'Oilcloth Breeches',109,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,7,30939,'Felboar Hide Shoes',109,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,8,29246,'Nightfall Wristguards',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,9,29503,'Cobrascale Gloves',105,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,15,29360,'Vileblade of the Betrayer',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',0,16,28187,'Star-Heart Lamp',112,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,0,29044,'Netherblade Facemask',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,2,29147,'Talbuk Hide Spaulders',115,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,4,29525,'Primalstrike Vest',120,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,5,29526,'Primalstrike Belt',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,6,29046,'Netherblade Breeches',120,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,7,28669,'Rapscallion Boots',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,8,29527,'Primalstrike Bracers',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,9,29048,'Netherblade Gloves',120,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,15,28312,'Gladiator''s Shanker',123,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',1,16,28734,'Jewel of Infinite Possibilities',115,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,0,30146,'Deathmantle Helm',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,1,33296,'Brooch of Deftness',128,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,2,34613,'Shoulderpads of the Silvermoon Retainer',125,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,4,30144,'Deathmantle Chestguard',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,5,30040,'Belt of Deep Shadow',128,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,6,30148,'Deathmantle Legguards',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,7,30039,'Boots of Utter Darkness',128,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,8,33540,'Master Assassin Wristwraps',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,9,30145,'Deathmantle Handguards',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,14,24528,'130 Epic Warrior Cloak',130,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,15,29962,'Heartrazor',134,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',2,16,28825,'Aldori Legacy Defender',125,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,0,30146,'Deathmantle Helm',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,2,32377,'Mantle of Darkness',141,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,4,30144,'Deathmantle Chestguard',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,5,34929,'Belt of the Silent Path',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,6,30148,'Deathmantle Legguards',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,7,30891,'Black Featherlight Boots',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,8,30863,'Deadly Cuffs',141,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,9,30145,'Deathmantle Handguards',133,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,15,30865,'Tracker''s Blade',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (4,'assassination',3,16,34952,'The Mutilator',146,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,0,31105,'Overlord''s Helmet of Second Sight',109,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,2,32073,'Spaulders of Dementia',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,4,28483,'Breastplate of Kings',107,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,5,30962,'Borak''s Belt of Bravery',109,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,6,32414,'Tom''s Legs A',105,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,7,27788,'Bloodsworn Warboots',112,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,8,23537,'Black Felsteel Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,9,30375,'Gauntlets of the Vanquisher',109,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,15,22736,'Andonisus, Reaper of Souls',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',0,16,28187,'Star-Heart Lamp',112,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,0,29021,'Warbringer Battle-Helm',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,2,30740,'Ripfiend Shoulderplates',120,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,4,27906,'Crimsonforge Breastplate',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,5,28385,'General''s Plate Belt',123,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,6,32417,'Tom''s Legs 1',115,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,7,32954,'Tom''s Boots 1',115,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,8,32957,'Tom''s Bracer 1',115,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,9,29020,'Warbringer Gauntlets',120,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',1,15,28476,'Gladiator''s Maul',123,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,0,29983,'Fel-Steel Warhelm',128,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,2,30122,'Destroyer Shoulderblades',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,4,28484,'Bulwark of Kings',127,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,5,24537,'130 Epic Warrior Waistband',130,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,6,30121,'Destroyer Greaves',133,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,7,32955,'Tom''s Boots 2',130,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,8,32958,'Tom''s Bracer 2',130,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,9,24529,'130 Epic Warrior Gauntlets',130,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,14,28777,'Cloak of the Pit Stalker',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',2,15,32014,'Merciless Gladiator''s Maul',136,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,0,32373,'Helm of the Illidari Shatterer',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,2,30866,'Blood-stained Pauldrons',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,4,32365,'Heartshatter Breastplate',141,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,5,30915,'Belt of Seething Fury',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,6,30903,'Legguards of Endless Rage',151,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,7,32956,'Tom''s Boots 3',145,38) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,8,32959,'Tom''s Bracer 3',145,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,9,32608,'Pillager''s Gauntlets',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'arms',3,15,34891,'The Blade of Harbingers',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,0,31105,'Overlord''s Helmet of Second Sight',109,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,2,32073,'Spaulders of Dementia',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,4,28483,'Breastplate of Kings',107,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,5,30962,'Borak''s Belt of Bravery',109,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,6,32414,'Tom''s Legs A',105,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,7,27788,'Bloodsworn Warboots',112,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,8,23537,'Black Felsteel Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,9,30375,'Gauntlets of the Vanquisher',109,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,15,22736,'Andonisus, Reaper of Souls',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',0,16,28187,'Star-Heart Lamp',112,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,0,29021,'Warbringer Battle-Helm',120,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,2,30740,'Ripfiend Shoulderplates',120,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,4,27906,'Crimsonforge Breastplate',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,5,28385,'General''s Plate Belt',123,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,6,32417,'Tom''s Legs 1',115,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,7,32954,'Tom''s Boots 1',115,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,8,32957,'Tom''s Bracer 1',115,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,9,29020,'Warbringer Gauntlets',120,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,15,30733,'Hope Ender',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',1,16,28302,'Gladiator''s Bonecracker',123,9) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,0,29983,'Fel-Steel Warhelm',128,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,2,30122,'Destroyer Shoulderblades',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,4,28484,'Bulwark of Kings',127,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,5,24537,'130 Epic Warrior Waistband',130,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,6,30121,'Destroyer Greaves',133,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,7,32955,'Tom''s Boots 2',130,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,8,32958,'Tom''s Bracer 2',130,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,9,24529,'130 Epic Warrior Gauntlets',130,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,14,28777,'Cloak of the Pit Stalker',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,15,28433,'Wicked Edge of the Planes',136,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',2,16,31958,'Merciless Gladiator''s Bonecracker',136,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,0,32373,'Helm of the Illidari Shatterer',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,2,30866,'Blood-stained Pauldrons',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,4,32365,'Heartshatter Breastplate',141,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,5,30915,'Belt of Seething Fury',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,6,30903,'Legguards of Endless Rage',151,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,7,32956,'Tom''s Boots 3',145,38) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,8,32959,'Tom''s Bracer 3',145,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,9,32608,'Pillager''s Gauntlets',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,15,30881,'Blade of Infamy',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (1,'fury',3,16,34015,'Vengeful Gladiator''s Chopper',146,8) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,0,31105,'Overlord''s Helmet of Second Sight',109,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,1,31695,'Natasha''s Choker',103,10) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,2,32073,'Spaulders of Dementia',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,4,28483,'Breastplate of Kings',107,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,5,30962,'Borak''s Belt of Bravery',109,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,6,32414,'Tom''s Legs A',105,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,7,27788,'Bloodsworn Warboots',112,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,8,23537,'Black Felsteel Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,9,30375,'Gauntlets of the Vanquisher',109,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,10,32942,'Ring of the Overseer',105,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',0,15,29171,'Earthwarden',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,0,23521,'Ragesteel Helm',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,1,34679,'Shattered Sun Pendant of Might',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,2,30740,'Ripfiend Shoulderplates',120,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,4,27906,'Crimsonforge Breastplate',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,5,28385,'General''s Plate Belt',123,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,6,32417,'Tom''s Legs 1',115,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,7,32954,'Tom''s Boots 1',115,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,8,32957,'Tom''s Bracer 1',115,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,9,23520,'Ragesteel Gloves',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',1,15,28476,'Gladiator''s Maul',123,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,0,29983,'Fel-Steel Warhelm',128,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,2,24534,'130 Epic Warrior Pauldrons',130,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,4,28484,'Bulwark of Kings',127,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,5,24537,'130 Epic Warrior Waistband',130,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,6,32418,'Tom''s Legs 2',130,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,7,32955,'Tom''s Boots 2',130,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,8,32958,'Tom''s Bracer 2',130,26) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,9,24529,'130 Epic Warrior Gauntlets',130,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,14,28777,'Cloak of the Pit Stalker',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',2,15,32014,'Merciless Gladiator''s Maul',136,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,0,32373,'Helm of the Illidari Shatterer',141,34) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,2,30866,'Blood-stained Pauldrons',141,23) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,4,32365,'Heartshatter Breastplate',141,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,5,30915,'Belt of Seething Fury',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,6,30903,'Legguards of Endless Rage',151,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,7,32956,'Tom''s Boots 3',145,38) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,8,32959,'Tom''s Bracer 3',145,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,9,32608,'Pillager''s Gauntlets',141,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (2,'ret',3,15,34891,'The Blade of Harbingers',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,0,28275,'Beast Lord Helm',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,1,29381,'Choker of Vile Intent',110,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,2,27994,'Mantle of Three Terrors',112,12) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,4,28228,'Beast Lord Cuirass',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,5,25789,'Rune-Engraved Belt',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,6,27874,'Beast Lord Leggings',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,7,29262,'Boots of the Endless Hunt',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,8,29517,'Ebon Netherscale Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,9,27474,'Beast Lord Handguards',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,10,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,14,27892,'Cloak of the Inciter',112,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,15,22736,'Andonisus, Reaper of Souls',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',0,17,27526,'Skyfire Hawk-Bow',112,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,0,28275,'Beast Lord Helm',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,1,28509,'Worgen Claw Necklace',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,2,28344,'Wyrmfury Pauldrons',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,4,28228,'Beast Lord Cuirass',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,5,28656,'Girdle of the Prowler',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,6,27874,'Beast Lord Leggings',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,7,27450,'Wild Stalker Boots',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,8,27494,'Emerald Eye Bracer',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,9,27474,'Beast Lord Handguards',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,15,28476,'Gladiator''s Maul',123,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',1,17,28504,'Steelhawk Crossbow',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,0,32474,'Surestrike Goggles v2.0',127,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,2,33206,'Pauldrons of Primal Fury',128,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,4,30139,'Rift Stalker Hauberk',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,5,30046,'Belt of the Black Eagle',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,6,30142,'Rift Stalker Leggings',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,7,33482,'Cobra-Lash Boots',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,8,30026,'Bands of the Celestial Archer',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,9,30140,'Rift Stalker Gauntlets',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,14,28777,'Cloak of the Pit Stalker',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,15,32014,'Merciless Gladiator''s Maul',136,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',2,17,29949,'Arcanite Steam-Pistol',134,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,0,32376,'Forest Prowler''s Helm',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,2,32264,'Shoulders of the Hidden Predator',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,4,30139,'Rift Stalker Hauberk',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,5,32346,'Boneweave Girdle',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,6,30142,'Rift Stalker Leggings',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,7,32510,'Softstep Boots of Tracking',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,8,32574,'Bindings of Lightning Reflexes',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,9,32234,'Fists of Mukoa',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,15,34891,'The Blade of Harbingers',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'bm',3,17,34892,'Crossbow of Relentless Strikes',146,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,0,27888,'Dream-Wing Helm',112,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,1,29381,'Choker of Vile Intent',110,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,2,32137,'Chancellor''s Chain Spaulders',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,4,34799,'Hauberk of the War Bringer',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,5,25789,'Rune-Engraved Belt',114,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,6,28173,'Mag''hari Huntsman''s Leggings',103,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,7,29262,'Boots of the Endless Hunt',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,8,29517,'Ebon Netherscale Bracers',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,9,30951,'Ar''tor''s Mainstay',109,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,10,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,11,29281,'Violet Signet',110,22) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,12,29383,'Bloodlust Brooch',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,13,38287,'Empty Mug of Direbrew',110,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,14,24259,'Vengeance Wrap',105,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,15,22736,'Andonisus, Reaper of Souls',100,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',0,17,27526,'Skyfire Hawk-Bow',112,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,0,29081,'Demon Stalker Greathelm',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,1,28509,'Worgen Claw Necklace',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,2,28344,'Wyrmfury Pauldrons',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,4,29515,'Ebon Netherscale Breastplate',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,5,28656,'Girdle of the Prowler',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,6,29083,'Demon Stalker Greaves',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,7,27450,'Wild Stalker Boots',115,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,8,27494,'Emerald Eye Bracer',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,9,29085,'Demon Stalker Gauntlets',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,10,30738,'Ring of Reciprocity',120,15) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,11,29282,'Violet Signet',120,24) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,12,24128,'Figurine - Nightseye Panther',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,13,32654,'Crystalforged Trinket',115,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,14,30729,'Black-Iron Battlecloak',120,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,15,28476,'Gladiator''s Maul',123,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',1,17,28504,'Steelhawk Crossbow',115,16) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,0,32474,'Surestrike Goggles v2.0',127,13) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,1,30059,'Choker of Animalistic Fury',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,2,33206,'Pauldrons of Primal Fury',128,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,4,30139,'Rift Stalker Hauberk',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,5,30046,'Belt of the Black Eagle',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,6,30142,'Rift Stalker Leggings',133,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,7,33482,'Cobra-Lash Boots',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,8,30026,'Bands of the Celestial Archer',128,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,9,30140,'Rift Stalker Gauntlets',133,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,10,33997,'Indalamar''s Ring of 400 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,11,34094,'Indalamar''s Ring of 200 Attack Power',130,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,12,33831,'Berserker''s Call',133,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,13,35702,'Figurine - Shadowsong Panther',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,14,28777,'Cloak of the Pit Stalker',125,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,15,32014,'Merciless Gladiator''s Maul',136,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',2,17,29949,'Arcanite Steam-Pistol',134,19) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,0,32376,'Forest Prowler''s Helm',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,1,32260,'Choker of Endless Nightmares',141,21) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,2,32264,'Shoulders of the Hidden Predator',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,4,30907,'Mail of Fevered Pursuit',151,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,5,32346,'Boneweave Girdle',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,6,31005,'Gronnstalker''s Leggings',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,7,32510,'Softstep Boots of Tracking',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,8,32574,'Bindings of Lightning Reflexes',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,9,32234,'Fists of Mukoa',141,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,10,32497,'Stormrage Signet Ring',151,30) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,11,29997,'Band of the Ranger-General',138,18) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,12,32505,'Madness of the Betrayer',141,20) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,13,32483,'The Skull of Gul''dan',151,25) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,14,32323,'Shadowmoon Destroyer''s Drape',141,17) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,15,34891,'The Blade of Harbingers',146,0) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
INSERT INTO `ai_playerbot_bis_gear` (cls, spec, phase, slot, item_id, item_name, ilvl, hit) VALUES (3,'marks',3,17,34892,'Crossbow of Relentless Strikes',146,14) ON DUPLICATE KEY UPDATE item_id=VALUES(item_id), item_name=VALUES(item_name), ilvl=VALUES(ilvl), hit=VALUES(hit);
