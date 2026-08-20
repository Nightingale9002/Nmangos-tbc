-- ============================================================
-- 017_达纳苏斯护卫跟随.sql
-- 目标：Huntress Nhemai(46414) / Huntress Yaeliura(46416) 跟随
--       Moon Priestess Amara(46394)
-- 机制：creature_linking FLAG_FOLLOW(0x200) + AGGRO_ON_AGGRO(0x1)
--       - 脱战：护卫跟随主人位置（主人巡逻/移动则跟上）
--       - 战斗：主人被攻击时护卫一起参战
-- 幂等：INSERT ... SELECT WHERE NOT EXISTS（可重复执行）
-- ============================================================

INSERT INTO creature_linking (guid, master_guid, flag)
SELECT 46414, 46394, 0x201
WHERE NOT EXISTS (SELECT 1 FROM creature_linking WHERE guid=46414 AND master_guid=46394);

INSERT INTO creature_linking (guid, master_guid, flag)
SELECT 46416, 46394, 0x201
WHERE NOT EXISTS (SELECT 1 FROM creature_linking WHERE guid=46416 AND master_guid=46394);

-- 验证
SELECT '-- 验证 creature_linking --' AS info;
SELECT cl.guid, cl.master_guid, cl.flag, c.id AS slave_entry, c2.id AS master_entry
FROM creature_linking cl
JOIN creature c ON c.guid=cl.guid
JOIN creature c2 ON c2.guid=cl.master_guid
WHERE cl.guid IN (46414,46416);
