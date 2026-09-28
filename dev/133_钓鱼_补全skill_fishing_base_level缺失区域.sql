-- =====================================================================================
-- 133_钓鱼_补全skill_fishing_base_level缺失区域.sql
-- 日期：2026-09-27        适用库：tbcmangos（world 库，**注意不是角色库**）
-- 类型：静态 / 幂等（可重复执行）
-- -------------------------------------------------------------------------------------
-- 【背景】站长定案：钓鱼技能门槛改为 **DB 优先** —— `skill_fishing_base_level` 成为权威数据源。
--   它同时也是 GameObject.cpp 里"渔获 / 垃圾几率"用的那张表（chance = skill - zone_skill + 5），
--   而 Spell.cpp 里另有一张上游硬编码表（9b83559700「Spell: Add all per-zone area fishing
--   requirements」），两张表互相矛盾：硬编码把**暴风城(1519) 写进 55 档**，而 DB 及三个参考库
--   （tbcmangos_orig / classicmangos_ref / acore_world）里 1519 一律是 **-20**（与奥格 1637、
--   幽暗 1497、雷霆崖 1638 同档）⇒ 站长实测"暴风城运河提示钓鱼等级不够"。
--
-- 【本文件干什么】改用 DB 优先后，DB 里没有记录的区域会回退到硬编码表（代码里有兜底）；
--   但实测这些**外域子区**在四个参考库里都从来没有记录，且硬编码表给的值比同 zone 的其它
--   子区更高 ⇒ 补进 DB，避免它们退化成 zone 的默认档：
--     3655 / 3659（赞加沼泽）→ 305（= zone 3521 的值，与硬编码表默认档一致）
--     3720（赞加沼泽 · 毒蛇湖一带）→ 355（与 3653 / 3656 / 3658 同值）
--     3680 / 3693 / 3975（泰罗卡森林）→ 405（与 3690 / 3691 / 3692 同值）
--     ⚠️ 硬编码表原来把泰罗卡这几个给的是 **430**（DB 表里根本没有 430 档，最高就是 405）。
--        若站长想保持原样，把下面 3 个 405 改成 430 即可。
--
-- 【⚠️ 不要去补"副本"】副本/团本的门槛是 **地图级** 的（硬编码表里 switch 的是 mapId：
--   43 哀嚎 / 48 黑暗深渊 / 189 血色 / 289 通灵 / 309 祖格 / 329 斯坦索姆 / 349 玛拉顿 /
--   429 厄运，以及 534/545/546/547/548/560/568/580/585），而本表按 **area id** 索引、
--   加载时用 AreaTable.dbc 校验（ObjectMgr.cpp:9187）。2026-09-27 实测踩坑：
--     - 48 / 329 插入后被加载器判为 "AreaId ... does not exist"（它们不是 area）；
--     - 43 / 189 / 289 / 309 / 349 / 429 **恰好存在同号 area**（完全无关的区域）⇒
--       会给那些无辜区域凭空加门槛。
--   ⇒ 副本门槛继续留在 Spell.cpp 的 mapId 分支里（代码已加 `mapLevelRequirement` 保护，
--     DB 不再覆盖这些地图）。
--
-- 【生效方式】world 库数据 ⇒ 重启 mangosd（或 `.reload skill_fishing_base_level`）。
-- 【验证】
--   SELECT entry, skill FROM tbcmangos.skill_fishing_base_level
--    WHERE entry IN (3655,3659,3720,3680,3693,3975);            -- 期望 6 行
--   SELECT COUNT(*) FROM tbcmangos.skill_fishing_base_level;     -- 期望 87（81 + 6）
--   重启日志应出现：`>> Loaded 87 areas for fishing base skill level`，且**没有**
--   "AreaId ... does not exist" 的报错。
-- 【回滚】dev/rollback/133_回滚_删除补全的钓鱼区域.sql
-- =====================================================================================

-- 外域子区（6）—— 与同 zone 兄弟区域同值
INSERT IGNORE INTO `tbcmangos`.`skill_fishing_base_level` (`entry`, `skill`) VALUES
  (3655, 305), -- Zangarmarsh 子区
  (3659, 305), -- Zangarmarsh 子区
  (3720, 355), -- Zangarmarsh 子区（与 3653/3656/3658 同档）
  (3680, 405), -- Terokkar Forest 子区
  (3693, 405), -- Terokkar Forest 子区
  (3975, 405); -- Terokkar Forest 子区

-- ---------- 核对 ----------
-- 期望 6 行
SELECT entry, skill FROM `tbcmangos`.`skill_fishing_base_level`
 WHERE entry IN (3655,3659,3720,3680,3693,3975) ORDER BY entry;

-- 期望 87 行
SELECT COUNT(*) AS rows_total FROM `tbcmangos`.`skill_fishing_base_level`;

-- 期望 0：表里不允许出现 skill = 0（代码把 0 当"没有记录"）
SELECT COUNT(*) AS zero_rows FROM `tbcmangos`.`skill_fishing_base_level` WHERE skill = 0;

-- 期望 8：**确认副本 id 没有被写进本表**（43/48/189/289/309/329/349/429 必须是 0 行）
SELECT COUNT(*) AS instance_ids_in_table FROM `tbcmangos`.`skill_fishing_base_level`
 WHERE entry IN (43,48,189,289,309,329,349,429);
