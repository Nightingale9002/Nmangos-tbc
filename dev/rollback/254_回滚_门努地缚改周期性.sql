-- World database (tbcmangos). 回滚 dev/254：把地缚图腾法术 31983 还原成一次性（瞬发、无冷却）。
UPDATE `spell_template`
   SET `CastingTimeIndex`=1, `RecoveryTime`=0
 WHERE `Id`=31983 AND `CastingTimeIndex`=4 AND `RecoveryTime`=10000;

SELECT `Id`,`SpellName`,`CastingTimeIndex`,`RecoveryTime` FROM `spell_template` WHERE `Id`=31983;
