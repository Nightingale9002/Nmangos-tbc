-- 拍卖师克雷斯克表弟（2026-08-23）
-- 背景：克雷斯克(9858)外派外域(map530 guid 5850237)；藏宝海湾旧点(guid 568)换表弟(29096)充数
-- 表弟：无拍卖师功能(NpcFlags=1 仅GOSSIP)，第一人称对话
-- 可重复执行（幂等）

-- 1. npc_text（表弟对话）
INSERT INTO tbcmangos.npc_text (ID, text0_0, lang0, prob0) VALUES (16500000, '克雷斯克表哥被外派到外域去了。我呢，作为他的表弟，凭着亲戚关系被招进来充数——可说实话，我对拍卖师的业务一窍不通，连这锤子该怎么敲都还没学会。你要真想寄卖东西，还是去外域找他吧。', 0, 100)
ON DUPLICATE KEY UPDATE text0_0=VALUES(text0_0);

-- 2. gossip_menu
INSERT INTO tbcmangos.gossip_menu (entry, text_id, script_id, condition_id) VALUES (60002, 16500000, 0, 0)
ON DUPLICATE KEY UPDATE text_id=16500000;

-- 3. creature_template 29096（复制 9858 + 改名/标志/对话）
-- 若不存在则复制：
SET @ne = 29096;
SET @exists = (SELECT COUNT(*) FROM tbcmangos.creature_template WHERE entry=@ne);
INSERT INTO tbcmangos.creature_template (`Entry`,`Name`,`NpcFlags`,`GossipMenuId`,`SubName`,`IconName`,`MinLevel`,`MaxLevel`,`HeroicEntry`,`DisplayId1`,`DisplayId2`,`DisplayId3`,`DisplayId4`,`DisplayIdProbability1`,`DisplayIdProbability2`,`DisplayIdProbability3`,`DisplayIdProbability4`,`Faction`,`Scale`,`Family`,`CreatureType`,`InhabitType`,`RegenerateStats`,`RacialLeader`,`UnitFlags`,`DynamicFlags`,`ExtraFlags`,`CreatureTypeFlags`,`StaticFlags1`,`StaticFlags2`,`StaticFlags3`,`StaticFlags4`,`SpeedWalk`,`SpeedRun`,`Detection`,`CallForHelp`,`Pursuit`,`Leash`,`Timeout`,`UnitClass`,`Rank`,`Expansion`,`HealthMultiplier`,`PowerMultiplier`,`DamageMultiplier`,`DamageVariance`,`ArmorMultiplier`,`ExperienceMultiplier`,`StrengthMultiplier`,`AgilityMultiplier`,`StaminaMultiplier`,`IntellectMultiplier`,`SpiritMultiplier`,`MinLevelHealth`,`MaxLevelHealth`,`MinLevelMana`,`MaxLevelMana`,`MinMeleeDmg`,`MaxMeleeDmg`,`MinRangedDmg`,`MaxRangedDmg`,`Armor`,`MeleeAttackPower`,`RangedAttackPower`,`MeleeBaseAttackTime`,`RangedBaseAttackTime`,`DamageSchool`,`MinLootGold`,`MaxLootGold`,`LootId`,`PickpocketLootId`,`SkinningLootId`,`KillCredit1`,`KillCredit2`,`MechanicImmuneMask`,`SchoolImmuneMask`,`ResistanceHoly`,`ResistanceFire`,`ResistanceNature`,`ResistanceFrost`,`ResistanceShadow`,`ResistanceArcane`,`PetSpellDataId`,`MovementType`,`TrainerType`,`TrainerSpell`,`TrainerClass`,`TrainerRace`,`TrainerTemplateId`,`VendorTemplateId`,`ScriptName`)
SELECT @ne,'克雷斯克的表弟',1,@ne,`SubName`,`IconName`,`MinLevel`,`MaxLevel`,`HeroicEntry`,`DisplayId1`,`DisplayId2`,`DisplayId3`,`DisplayId4`,`DisplayIdProbability1`,`DisplayIdProbability2`,`DisplayIdProbability3`,`DisplayIdProbability4`,`Faction`,`Scale`,`Family`,`CreatureType`,`InhabitType`,`RegenerateStats`,`RacialLeader`,`UnitFlags`,`DynamicFlags`,`ExtraFlags`,`CreatureTypeFlags`,`StaticFlags1`,`StaticFlags2`,`StaticFlags3`,`StaticFlags4`,`SpeedWalk`,`SpeedRun`,`Detection`,`CallForHelp`,`Pursuit`,`Leash`,`Timeout`,`UnitClass`,`Rank`,`Expansion`,`HealthMultiplier`,`PowerMultiplier`,`DamageMultiplier`,`DamageVariance`,`ArmorMultiplier`,`ExperienceMultiplier`,`StrengthMultiplier`,`AgilityMultiplier`,`StaminaMultiplier`,`IntellectMultiplier`,`SpiritMultiplier`,`MinLevelHealth`,`MaxLevelHealth`,`MinLevelMana`,`MaxLevelMana`,`MinMeleeDmg`,`MaxMeleeDmg`,`MinRangedDmg`,`MaxRangedDmg`,`Armor`,`MeleeAttackPower`,`RangedAttackPower`,`MeleeBaseAttackTime`,`RangedBaseAttackTime`,`DamageSchool`,`MinLootGold`,`MaxLootGold`,`LootId`,`PickpocketLootId`,`SkinningLootId`,`KillCredit1`,`KillCredit2`,`MechanicImmuneMask`,`SchoolImmuneMask`,`ResistanceHoly`,`ResistanceFire`,`ResistanceNature`,`ResistanceFrost`,`ResistanceShadow`,`ResistanceArcane`,`PetSpellDataId`,`MovementType`,`TrainerType`,`TrainerSpell`,`TrainerClass`,`TrainerRace`,`TrainerTemplateId`,`VendorTemplateId`,`ScriptName`)
FROM tbcmangos.creature_template WHERE entry=9858 AND @exists=0;

-- 4. 藏宝海湾旧点(guid 568)切换到表弟
UPDATE tbcmangos.creature SET id=29096 WHERE guid=568;
