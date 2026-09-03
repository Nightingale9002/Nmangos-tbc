-- =============================================================
-- 051 矿脉组 MaxCount 1→2（增加同时存在的矿数）
-- 背景：见 dev/050_矿点三方对比分析.md —— 矿少根因是 spawn_group
--       MaxCount=1（215/265 组同一时间只有 1 个矿）+ 整组空才刷。
-- 本脚本：把矿脉组（含矿 entry 的组）中 MaxCount=1 的组改为 2，
--       同时存在的矿数立即翻倍（位置/Chance/刷新时间不动）。
-- 执行：本地直接执行；云端在停机/热加载窗口执行后需加载 spawn_group
--       （内存缓存），确认方式见文末。
-- 回滚：备份表 spawn_group_bak_maxcount_20260829（本脚本自动建）
-- =============================================================

-- 0) 执行前快照（可回滚）
CREATE TABLE IF NOT EXISTS spawn_group_bak_maxcount_20260829 AS
SELECT * FROM spawn_group
WHERE Id IN (
    SELECT DISTINCT sge.Id FROM spawn_group_entry sge
    WHERE sge.Entry IN (1731,1732,1733,1734,1735,2040,2047,324,175404)
) AND MaxCount = 1;

-- 1) 改动前统计（应输出：MaxCount=1 -> 215 组）
SELECT MaxCount, COUNT(*) AS `groups`
FROM spawn_group
WHERE Id IN (
    SELECT DISTINCT sge.Id FROM spawn_group_entry sge
    WHERE sge.Entry IN (1731,1732,1733,1734,1735,2040,2047,324,175404)
)
GROUP BY MaxCount ORDER BY MaxCount;

-- 2) 矿脉组 MaxCount 1→2
UPDATE spawn_group SET MaxCount = 2
WHERE MaxCount = 1
  AND Id IN (
    SELECT DISTINCT sge.Id FROM spawn_group_entry sge
    WHERE sge.Entry IN (1731,1732,1733,1734,1735,2040,2047,324,175404)
);

-- 3) 改动后统计（应输出：MaxCount=2 -> 215 组，无 MaxCount=1）
SELECT MaxCount, COUNT(*) AS `groups`
FROM spawn_group
WHERE Id IN (
    SELECT DISTINCT sge.Id FROM spawn_group_entry sge
    WHERE sge.Entry IN (1731,1732,1733,1734,1735,2040,2047,324,175404)
)
GROUP BY MaxCount ORDER BY MaxCount;

-- 4) 回滚方式（如需还原）：
--    DELETE FROM spawn_group WHERE Id IN (SELECT Id FROM spawn_group_bak_maxcount_20260829);
--    INSERT INTO spawn_group SELECT * FROM spawn_group_bak_maxcount_20260829;
--    （或用备份表 UPDATE 回 MaxCount=1）

-- 生效方式：spawn_group 在 ObjectMgr 内存缓存，.reload 若支持
--    spawn_group 子命令则热加载；否则需重启 mangosd。
