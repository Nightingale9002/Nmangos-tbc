-- =====================================================================================
-- 160_FelIron宝箱181798改回旧版.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】dev/159 把 21 个副本宝箱按 dev/117 自带回滚文件的旧值还原时，181798「Fel Iron Chest」被还原成
--   21278（5 行 reference 结构）。但站长 2026-10-06 定案：这个箱子用**之前的版本**，即改前快照
--   tbcmangos_orig 里那份：data1 = 181798、掉落为 96 行直接掉落（含 6 条 reference），
--   这 96 行在 dev/117 里被 `DELETE FROM gameobject_loot_template WHERE entry = 181798` 删掉了。
-- 【做法】① data1 指回 181798（守卫：仅当当前为 21278）；
--         ② 把快照 tbcmangos_orig 的那 96 行按原样灌回 gameobject_loot_template。
--   其余 20 个副本箱保持 dev/159 的结果不变。
-- 【生效】掉落/模板为启动时载入 ⇒ 需重启（云端随夜间重启）。
-- 【回滚】dev/rollback/160_回滚_FelIron宝箱181798.sql（data1 回 21278 并删除这 96 行）
-- =====================================================================================

-- ① data1 指回 181798
UPDATE `gameobject_template` SET `data1` = 181798 WHERE `entry` = 181798 AND `data1` = 21278;

-- ② 灌回快照里的掉落行（先清空同表以防重复执行）
DELETE FROM `gameobject_loot_template` WHERE `entry` = 181798;
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,1710,5.0,0,2,4,0,'Greater Healing Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,2772,2.0,0,2,4,0,'Iron Ore');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,3395,0.01,0,1,1,0,'Recipe: Limited Invulnerability Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,3827,9.0,0,2,4,0,'Mana Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,3858,8.0,0,2,3,0,'Mithril Ore');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,3864,1.0,0,1,1,0,'Citrine');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,3928,12.0,0,2,3,0,'Superior Healing Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,4235,4.0,0,1,1,0,'Heavy Hide');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,4304,4.0,0,1,3,0,'Thick Leather');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,4305,1.0,0,1,1,0,'Bolt of Silk Cloth');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,4306,1.0,0,2,2,0,'Silk Cloth');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,4338,1.0,0,1,1,0,'Mageweave Cloth');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,6037,2.0,0,1,2,0,'Truesilver Bar');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,6149,14.0,0,2,3,0,'Greater Mana Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,7910,1.0,0,1,1,0,'Star Ruby');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,7911,2.0,0,1,2,0,'Truesilver Ore');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8766,39.0,0,1,3,0,'Morning Glory Dew');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8831,2.0,0,1,2,0,'Purple Lotus');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8838,2.0,0,1,2,0,'Sungrass');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8839,2.0,0,1,1,0,'Blindweed');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8932,10.0,0,1,2,0,'Alterac Swiss');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8948,19.0,0,1,2,0,'Dried King Bolete');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8950,24.0,0,1,2,0,'Homemade Cherry Pie');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8952,8.0,0,1,2,0,'Roasted Quail');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,8953,4.0,0,1,2,0,'Deep Fried Plantains');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,11226,0.01,0,1,1,0,'Formula: Enchant Gloves - Riding Skill');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12682,0.01,0,1,1,0,'Plans: Thorium Armor');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12683,0.01,0,1,1,0,'Plans: Thorium Belt');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12684,0.01,0,1,1,0,'Plans: Thorium Bracers');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12685,0.01,0,1,1,0,'Plans: Radiant Belt');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12689,0.01,0,1,1,0,'Plans: Radiant Breastplate');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12691,0.01,0,1,1,0,'Plans: Wildthorn Mail');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12692,0.01,0,1,1,0,'Plans: Thorium Shield Spike');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12693,0.01,0,1,1,0,'Plans: Thorium Boots');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12694,0.01,0,1,1,0,'Plans: Thorium Helm');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12695,0.01,0,1,1,0,'Plans: Radiant Gloves');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12697,0.01,0,1,1,0,'Plans: Radiant Boots');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12702,0.01,0,1,1,0,'Plans: Radiant Circlet');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12703,0.01,0,1,1,0,'Plans: Storm Gauntlets');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12704,0.01,0,1,1,0,'Plans: Thorium Leggings');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12711,0.01,0,1,1,0,'Plans: Whitesoul Helm');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,12713,0.01,0,1,1,0,'Plans: Radiant Leggings');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13463,4.0,0,1,1,0,'Dreamfoil');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13464,2.0,0,1,1,0,'Golden Sansam');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13465,1.0,0,1,1,0,'Mountain Silversage');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13486,0.01,0,1,1,0,'Recipe: Transmute Undeath to Water');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13487,0.01,0,1,1,0,'Recipe: Transmute Water to Undeath');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13488,0.01,0,1,1,0,'Recipe: Transmute Life to Earth');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13489,0.01,0,1,1,0,'Recipe: Transmute Earth to Life');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13490,0.01,0,1,1,0,'Recipe: Greater Stoneshield Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13492,0.01,0,1,1,0,'Recipe: Purification Potion');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13493,0.01,0,1,1,0,'Recipe: Greater Arcane Elixir');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,13518,0.01,0,1,1,0,'Recipe: Flask of Petrification');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14466,0.01,0,1,1,0,'Pattern: Frostweave Tunic');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14467,0.01,0,1,1,0,'Pattern: Frostweave Robe');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14470,0.01,0,1,1,0,'Pattern: Runecloth Tunic');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14474,0.01,0,1,1,0,'Pattern: Frostweave Gloves');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14478,0.01,0,1,1,0,'Pattern: Brightcloth Robe');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14479,0.01,0,1,1,0,'Pattern: Brightcloth Gloves');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14484,0.01,0,1,1,0,'Pattern: Brightcloth Cloak');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14489,0.01,0,1,1,0,'Pattern: Frostweave Pants');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14491,0.01,0,1,1,0,'Pattern: Runecloth Pants');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14492,0.01,0,1,1,0,'Pattern: Felcloth Boots');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14494,0.01,0,1,1,0,'Pattern: Brightcloth Pants');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14496,0.01,0,1,1,0,'Pattern: Felcloth Hood');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14497,0.01,0,1,1,0,'Pattern: Mooncloth Leggings');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14498,0.01,0,1,1,0,'Pattern: Runecloth Headband');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14499,0.01,0,1,1,0,'Pattern: Mooncloth Bag');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14501,0.01,0,1,1,0,'Pattern: Mooncloth Vest');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14504,0.01,0,1,1,0,'Pattern: Runecloth Shoulders');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14506,0.01,0,1,1,0,'Pattern: Felcloth Robe');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14507,0.01,0,1,1,0,'Pattern: Mooncloth Shoulders');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,14508,0.01,0,1,1,0,'Pattern: Felcloth Shoulders');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15731,0.01,0,1,1,0,'Pattern: Runic Leather Gauntlets');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15737,0.01,0,1,1,0,'Pattern: Chimeric Boots');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15742,0.01,0,1,1,0,'Pattern: Warbear Harness');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15743,0.01,0,1,1,0,'Pattern: Heavy Scorpid Belt');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15745,0.01,0,1,1,0,'Pattern: Runic Leather Belt');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15746,0.01,0,1,1,0,'Pattern: Chimeric Leggings');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15755,0.01,0,1,1,0,'Pattern: Chimeric Vest');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15757,0.01,0,1,1,0,'Pattern: Wicked Leather Pants');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,15765,0.01,0,1,1,0,'Pattern: Runic Leather Pants');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16043,0.01,0,1,1,0,'Schematic: Thorium Rifle');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16051,0.01,0,1,1,0,'Schematic: Thorium Shells');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16055,0.01,0,1,1,0,'Schematic: Arcane Bomb');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16215,0.01,0,1,1,0,'Formula: Enchant Boots - Greater Stamina');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16218,0.01,0,1,1,0,'Formula: Enchant Bracer - Superior Spirit');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16220,0.01,0,1,1,0,'Formula: Enchant Boots - Spirit');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16245,0.01,0,1,1,0,'Formula: Enchant Boots - Greater Agility');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,16251,0.01,0,1,1,0,'Formula: Enchant Bracer - Superior Stamina');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60008,45.0,0,-60008,1,0,'NPC LOOT (Grey World Drop) - (Item Levels: 51-60) - (NPC Levels: 51-63) - VANILLA NPC ONLY');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60198,24.0,0,-60198,1,0,'NPC LOOT (Green World Drop) - (Item Levels: 56-60) - (NPC Levels: 57)');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60274,0.99,0,-60274,1,0,'NPC LOOT (Blue World Drop) - (Item Levels: 55-65) - (NPC Levels: 57)');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60334,0.01,0,-60334,1,0,'NPC LOOT (Purple World Drop) - (Item Levels: 55-60) - (NPC Levels: 57)');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60445,0.2,0,-60445,1,0,'NPC LOOT (White World Drop) - (Item Levels: 45 (14 Slot Bag)) - (NPC Levels: 41-60)');
INSERT INTO `gameobject_loot_template` (`entry`,`item`,`ChanceOrQuestChance`,`groupid`,`mincountOrRef`,`maxcount`,`condition_id`,`comments`) VALUES (181798,60446,0.3,0,-60446,1,0,'16 Slot Bag - (NPC Levels: 48+)');

-- ---------- 核对 ----------
SELECT `entry`, `name`, `data1` FROM `gameobject_template` WHERE `entry` = 181798;
SELECT COUNT(*) AS rows_n, SUM(`mincountOrRef` < 0) AS refs, SUM(`item` = 29434) AS badge
  FROM `gameobject_loot_template` WHERE `entry` = 181798;
