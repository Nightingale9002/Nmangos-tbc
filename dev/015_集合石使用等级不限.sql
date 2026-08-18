-- ============================================================
-- 集合石使用等级不限
-- 目标：让 GAMEOBJECT_TYPE_MEETINGSTONE(type=23) 集合石不受等级限制
-- 做法：minLevel(data0)=1, maxLevel(data1)=255(uint8上限，彻底不限)
-- 影响：云端+本地所有 type=23 集合石(37个)
-- ============================================================

-- 修改前预览
SELECT entry, name, type, data0 AS old_minLevel, data1 AS old_maxLevel
FROM tbcmangos.gameobject_template WHERE type=23 ORDER BY entry;

-- 实际修改 (幂等)
UPDATE tbcmangos.gameobject_template
SET data0 = 1, data1 = 255
WHERE type = 23 AND (data0 != 1 OR data1 != 255);

SELECT ROW_COUNT() AS updated_rows;

-- 验证
SELECT entry, name, data0 AS new_minLevel, data1 AS new_maxLevel
FROM tbcmangos.gameobject_template WHERE type=23 ORDER BY data0;
