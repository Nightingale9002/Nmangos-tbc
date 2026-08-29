-- 038_矿脉刷新加速.sql (v2: 300/600 -> 45/90, 按 pfQuest 矿脉频率 45s 调整)
-- 目的：加快矿脉刷新频率（挖掉后 45-90 秒重新出现，原主流 600s/部分 7 天）。
-- 原理：spawn_group 的 RespawnOverrideMin/Max 覆盖矿脉组刷新时间
--       （SpawnGroup.cpp:80 组空时用 override 时间调度），只影响矿脉组，
--       不动草药占位点；同时覆盖 78 个 604800s(7天) 的矿脉占位点坑。
-- 生效：本地重启 mangosd 立即生效；云端改库后需重启 mangosd 生效（或 .reload spawn_group）。

UPDATE spawn_group SET RespawnOverrideMin = 45, RespawnOverrideMax = 90
WHERE Id IN (
    SELECT DISTINCT Id FROM spawn_group_entry
    WHERE Entry IN (
        1731,1732,1733,1734,1735,2040,2047,324,175404,
        181555,181556,181557,181569,
        73940,73941,123309,123310,123848,177388,185557,
        165658,19903,150079,150080,150081,150082,181108,181109,176643,176645
    )
);
