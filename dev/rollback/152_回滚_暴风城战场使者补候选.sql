-- dev/rollback/152 回滚：暴风城战场使者组（19980）补候选 entry
-- 本组原先 spawn_group_entry 行数为 0，删掉即可完全还原成改动前状态。
-- 核对：SELECT COUNT(*) FROM spawn_group_entry WHERE Id = 19980;  期望 0

DELETE FROM `spawn_group_entry` WHERE `Id` = 19980;
