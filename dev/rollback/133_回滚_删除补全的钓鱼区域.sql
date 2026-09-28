-- =====================================================================================
-- 133_回滚_删除补全的钓鱼区域.sql
-- 对应：dev/133_钓鱼_补全skill_fishing_base_level缺失区域.sql
-- 日期：2026-09-27        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 注意：**只回滚数据不构成完整回滚**。这 6 行是为"DB 优先"补的；若同时要回到旧的
-- 硬编码优先行为，还必须 git revert 掉 Spell.cpp 的钓鱼门槛改动并重新编译部署。
-- 删掉这 6 行后：DB 里没有这些子区 ⇒ 代码回退硬编码表（Terokkar 子区回到 430、
-- 赞加子区回到 305/355），行为与改造前一致。
--
-- 同时清理 2026-09-27 那次误插入的 8 个"副本 id"（它们其实是 mapId，不是 area：
-- 48/329 会被加载器判为不存在，43/189/289/309/349/429 会命中无关的同号 area）。
-- =====================================================================================

-- 1) 本文件补的 6 个外域子区
DELETE FROM `tbcmangos`.`skill_fishing_base_level`
 WHERE `entry` IN (3655,3659,3720,3680,3693,3975);

-- 2) 误插入的 8 个副本 mapId（必须清掉，否则会给无关 area 加门槛）
DELETE FROM `tbcmangos`.`skill_fishing_base_level`
 WHERE `entry` IN (43,48,189,289,309,329,349,429);

-- 核对：期望两行都是 0
SELECT
  (SELECT COUNT(*) FROM `tbcmangos`.`skill_fishing_base_level`
    WHERE entry IN (3655,3659,3720,3680,3693,3975)) AS subareas_left,
  (SELECT COUNT(*) FROM `tbcmangos`.`skill_fishing_base_level`
    WHERE entry IN (43,48,189,289,309,329,349,429)) AS instance_ids_left;
