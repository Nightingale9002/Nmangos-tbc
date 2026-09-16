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
SELECT @ne,'克雷斯克的表弟',1,@ne,`SubName`,`IconName`,`MinLevel`,`MaxLevel`,`HeroicEntry`,`DisplayId1`,`DisplayId2`,`DisplayId3`,`DisplayId4`,`DisplayIdProbability1`,`DisplayIdProbability2`,`DisplayIdProbability3`,`DisplayIdProbability4`,`Faction`,`Scale`,`Family`,`CreatureType`,`InhabitType`,`RegenerateStats`,`RacialLeader`,`UnitFlags`,`DynamicFlags`,`ExtraFlags`,`CreatureTypeFlags`,`StaticFlags1`,`StaticFlags2`,`StaticFlags3`,`StaticFlags4`,`SpeedWalk`,`SpeedRun`,`Detection`,`CallForHelp`,`Pursuit`,`Leash`,`Timeout`,`UnitClass`,`Rank`,`Expansion`,`HealthMultiplier`,`PowerMultiplier`,`DamageMultiplier`,`DamageVariance`,`ArmorMultiplier`,`ExperienceMultiplier`,`StrengthMultiplier`,`AgilityMultiplier`,`StaminaMultiplier`,`IntellectMultiplier`,`SpiritMultiplier`,`MinLevelHealth`,`MaxLevelHealth`,`MinLevelMana`,`MaxLevelMana`,`MinMeleeDmg`,`MaxMeleeDmg`,`MinRangedDmg`,`MaxRangedDmg`,`Armor`,`MeleeAttackPower`,`RangedAttackPower`,`MeleeBaseAttackTime`,`RangedBaseAttackTime`,`DamageSchool`,`MinLootGold`,`MaxLootGold`,`LootId`,`PickpocketLootId`,`SkinningLootId`,`KillCredit1`,`KillCredit2`,`MechanicImmuneMask`,`SchoolImmuneMask`,`ResistanceHoly`,`ResistanceFire`,`ResistanceNature`,`ResistanceFrost`,`ResistanceShadow`,`ResistanceArcane`,`PetSpellDataId`,`MovementType`,`TrainerType`,`TrainerSpell`,`TrainerClass`,`TrainerRace`,`TrainerTemplateId`,`VendorTemplateId`,`ScriptName`
FROM tbcmangos.creature_template WHERE entry=9858 AND @exists=0;

-- 4. 藏宝海湾旧点(guid 568)切换到表弟
UPDATE tbcmangos.creature SET id=29096 WHERE guid=568;

-- 5. 外域刷新点(map530 沙塔斯城·贫民窟)位置微调（2026-09-16）
--    背景：原先该刷新点是手工直接入库、未进 SQL（库/脚本漂移），此处补录为幂等语句。
--    目标坐标来自站内 .gps：X -1923.665649 Y 5164.205566 Z -37.795090 O 1.573792
--    （原坐标 X -1925.56 Y 5167.69 Z -40.2094 O 1.30439：向东北约 4 码、抬高约 2.4 码）
--    ⚠️ 不要硬编码 guid：云端该刷新点占用了 5850237，但本地库 5850237 已被
--       Nal'taszar(4066, map0) 占用——直接 INSERT 会覆盖别人的刷新点。

-- 5.1 已有克雷斯克外域刷新点 → 就地改坐标（云端 guid 5850237 走这条）
UPDATE tbcmangos.creature
   SET `position_x` = -1923.665649,
       `position_y` = 5164.205566,
       `position_z` = -37.795090,
       `orientation` = 1.573792
 WHERE `id` = 9858 AND `map` = 530;

-- 5.2 该刷新点缺失 → 用空闲 guid 新建（不占用可能被他人使用的 guid）
SET @kresky_exists = (SELECT COUNT(*) FROM tbcmangos.creature WHERE `id` = 9858 AND `map` = 530);
SET @kresky_guid   = (SELECT IFNULL(MAX(`guid`), 0) + 1 FROM tbcmangos.creature);
INSERT INTO tbcmangos.creature
  (`guid`,`id`,`map`,`spawnMask`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecsmin`,`spawntimesecsmax`,`spawndist`,`MovementType`)
SELECT @kresky_guid, 9858, 530, 1, -1923.665649, 5164.205566, -37.795090, 1.573792, 25, 25, 0, 0
  FROM DUAL
 WHERE @kresky_exists = 0;
