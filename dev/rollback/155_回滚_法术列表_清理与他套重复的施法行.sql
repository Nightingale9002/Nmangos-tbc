-- =====================================================================================
-- 155_回滚_法术列表_清理与他套重复的施法行.sql
-- 对应：dev/155_法术列表_清理与他套重复的施法行.sql    日期：2026-10-06    类型：静态 / 幂等
-- 原样放回被删的行（Comments 列 NOT NULL 无默认值，必须显式给出）。
-- =====================================================================================

INSERT INTO `tbcmangos`.`creature_spell_list`
 (`Id`, `Position`, `SpellId`, `Flags`, `CombatCondition`, `TargetId`, `ScriptId`,
  `Availability`, `Probability`, `InitialMin`, `InitialMax`, `RepeatMin`, `RepeatMax`, `Comments`) VALUES(945101,4,18100,0,-1,0,0,100,1,0,0,0,0,'Scarlet Archmage - Frost Armor'),
(1468201,0,16508,0,-1,1,0,100,0,5000,20000,30000,60000,'Shadowfang Keep - Sever - Intimidating Roar'),
(1468201,1,17745,0,-1,1,0,100,0,5000,8000,8000,16000,'Shadowfang Keep - Sever - Diseased Spit'),
(1468601,0,16838,0,-1,1,0,100,0,0,20000,20000,20000,'Razorfen Downs - Lady Falther''ess - Banshee Shriek'),
(1468601,1,17105,0,-1,1,0,100,0,0,30000,12000,30000,'Razorfen Downs - Lady Falther''ess - Banshee Curse'),
(1468601,2,22743,0,-1,1,0,100,0,0,25000,5000,25000,'Razorfen Downs - Lady Falther''ess - Ribbon of Souls'),
(1468601,3,7645,0,-1,100,0,100,0,10000,30000,30000,60000,'Razorfen Downs - Lady Falther''ess - Dominate Mind'),
(1469701,0,16790,0,-1,1,0,100,0,0,17000,17000,17000,'Scourge Invasion - Lumbering Horror - Knockdown'),
(1469701,1,5568,0,-1,0,0,100,0,5000,10000,5000,10000,'Scourge Invasion - Lumbering Horror - Trample'),
(1508401,0,24649,0,-1,1,0,100,1,4000,8000,7000,12000,'Renataki - Thousand Blades on Current'),
(1508401,3,3391,0,-1,1,0,100,1,10000,15000,10000,15000,'Renataki - Thrash on Current'),
(1555001,1,29833,0,-1,2,0,100,0,30000,30000,30000,30000,'Attumen the Huntsman - Intangible Presence - self'),
(1555001,2,29850,0,-1,1,0,100,0,6000,9000,22000,30000,'Attumen the Huntsman - Upercut - current'),
(1555001,3,29832,0,-1,1,0,100,0,10000,16000,22000,30000,'Attumen the Huntsman - Shadow Cleave - current'),
(1593101,1,28240,0,-1,0,0,100,1,20000,25000,15000,15000,'Grobbulus - Poison Cloud'),
(1614101,0,7367,0,-1,1,0,100,50,6000,12000,6000,12000,'Scourge Invasion - Ghoul Berserker - Infected Bite'),
(1615101,1,29714,0,541,0,0,0,0,0,0,0,0,'Midnight - Summon Attumen - under 95%'),
(1615101,2,29711,0,-1,1,0,100,0,6000,9000,25000,35000,'Midnight - Knockdown - current'),
(1615201,1,29833,0,-1,2,0,100,0,30000,30000,30000,30000,'Attumen the Huntsman - Intangible Presence - self'),
(1615201,2,29847,0,-1,101,0,100,0,20000,20000,12000,20000,'Attumen the Huntsman - Charge - random not tank'),
(1615201,3,29711,0,-1,1,0,100,0,6000,9000,22000,30000,'Attumen the Huntsman - Knockdown - current'),
(1615201,4,29832,0,-1,1,0,100,0,10000,16000,22000,30000,'Attumen the Huntsman - Shadow Cleave - current'),
(1629801,0,16244,0,-1,0,0,100,50,0,20000,20000,20000,'Scourge Invasion - Spectral Soldier - Demoralizing Shout'),
(1629801,1,21081,0,-1,1,0,100,50,6000,12000,6000,12000,'Scourge Invasion - Spectral Soldier - Sunder Armor'),
(1629901,0,17014,0,-1,0,0,100,0,0,16000,16000,16000,'Scourge Invasion - Skeletal Shocktrooper - Bone Shards'),
(1637901,0,22884,0,-1,0,0,100,0,1000,12000,6000,12000,'Scourge Invasion - Spirit of the Damned - Psychic Scream'),
(1637901,1,16243,2,-1,1,0,100,0,1000,6000,3000,6000,'Scourge Invasion - Spirit of the Damned - Ribbon of Souls'),
(1638001,1,20720,2,-1,1,0,100,0,1000,3000,3000,3000,'Scourge Invasion - Bone Witch - Arcane Bolt'),
(1643801,0,589,0,-1,1,0,100,0,1000,9000,9000,18000,'Scourge Invasion - Skeletal Trooper - Shadow Word: Pain (Rank 1)'),
(1831901,1,32689,0,-1,5,0,100,0,0,5000,5000,10000,'Time-Lost Scryer - Arcane Destruction - eligible friendly missing buff'),
(1849801,1,32828,0,-1,122,0,100,0,6000,18000,10000,22000,'Unliving Soldier - Shield Bash - random player casting'),
(1858401,0,31705,0,-1,100,0,100,0,5000,15000,15000,30000,'Sal''salabim - Magnetic Pull'),
(1962201,1,36815,0,-1,0,0,100,10,60000,60000,60000,60000,'Kael''thas Sunstrider - Shock Barrier (starts pyro sequence)'),
(1963301,2,34809,0,-1,5,0,100,0,9600,16900,14500,22900,'Bloodwarder Mender - Holy Fury - friendly missing buff'),
(2032101,1,32828,0,-1,122,0,100,0,6000,18000,10000,22000,'Unliving Soldier - Shield Bash - random player casting'),
(2069701,1,32689,0,-1,5,0,100,0,0,5000,5000,10000,'Time-Lost Scryer - Arcane Destruction - eligible friendly missing buff'),
(2154701,2,34809,0,-1,5,0,100,0,9600,16900,14500,22900,'Bloodwarder Mender - Holy Fury - friendly missing buff'),
(2155101,1,34803,0,-1,0,5530011,100,0,60000,60000,60000,60000,'Commander Sarannis - Summon Reinforcement');

SELECT COUNT(*) AS total_rows FROM `tbcmangos`.`creature_spell_list`;