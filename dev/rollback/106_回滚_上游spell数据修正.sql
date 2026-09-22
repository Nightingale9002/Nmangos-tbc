-- =============================================================
-- dev/rollback/106 回滚：dev/106 上游 spell_template 数据修正
-- 说明：全静态、幂等；回到"补丁前"的库内取值
-- 生效：需重启 mangosd
-- =============================================================

UPDATE `spell_template` SET `AttributesServerSide` = 0
WHERE `Id` = 32578 AND `AttributesServerSide` = 4;

UPDATE `spell_template` SET `AttributesServerSide` = 0
WHERE `Id` = 39153 AND `AttributesServerSide` = 4;

UPDATE `spell_template` SET `Attributes` = 192, `AttributesEx5` = 0
WHERE `Id` IN (37401, 37402) AND `Attributes` = 128 AND `AttributesEx5` = 536870912;
