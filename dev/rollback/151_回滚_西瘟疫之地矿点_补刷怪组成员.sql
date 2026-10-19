-- dev/rollback/151 回滚：西瘟疫之地矿点补刷怪组成员
--
-- 这 13 个组（21..33）在本库里原有成员行数就是 0，因此按组范围删除即可完全还原成改动前的状态。
-- 核对：SELECT COUNT(*) FROM spawn_group_spawn WHERE Id BETWEEN 21 AND 33;  期望 0

DELETE FROM `spawn_group_spawn` WHERE `Id` BETWEEN 21 AND 33;
