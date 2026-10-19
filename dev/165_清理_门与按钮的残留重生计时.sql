-- =====================================================================================
-- 165_清理_门与按钮的残留重生计时.sql
-- 日期：2026-10-07        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【背景】源头上游 bug：GO_FLAG_NODESPAWN(0x20) 从未被核心兑现 —— 带自动关闭时间的门/按钮
--   在自动关闭后被移出世界，并按 spawntimesecs 排重生（破碎大厅门 184912 / guid 25826 为 181 秒）。
--   核心修复见 commit `f5ca11d17`（src/game/Entities/GameObject.cpp，本地已编译，云端未同步）。
-- 【本文件做什么】清掉这个 bug 在**角色库** characters.gameobject_respawn 里留下的"未来时间"行。
--   这些行会在门加载时把门按旧计时藏起来（例如刚点过的门要等 181 秒才回来）。
--   ⚠️ 本文件操作的是 **characters 库**（不是 world），故用 `tbccharacters.` 前缀限定；
--     云端与本地同名（云端 world=tbcmangos / char=tbccharacters，已核实）。
-- 【幂等】只删"仍是未来时间"且属于 NODESPAWN 门/按钮刷点的行；重跑删不到东西。
-- 【回滚】无需回滚（删的是本 bug 产生的过期垃圾行，核心修复后不会再产生）；
--   详见 dev/rollback/165_回滚_清理残留重生计时.sql
-- =====================================================================================

-- ---------- 清理前：先看有哪些行会被删（期望：只含门/按钮） ----------
SELECT r.guid, r.respawntime, FROM_UNIXTIME(r.respawntime) AS 到期时间, r.instance,
       g.map, g.id AS entry, t.type, t.name
  FROM `tbccharacters`.`gameobject_respawn` r
  JOIN `tbcmangos`.`gameobject` g          ON g.guid = r.guid
  JOIN `tbcmangos`.`gameobject_template` t ON t.entry = g.id
 WHERE (t.flags & 0x20) AND t.type IN (0, 1) AND r.respawntime > UNIX_TIMESTAMP()
 ORDER BY r.respawntime;

-- ---------- 清理 ----------
DELETE r
  FROM `tbccharacters`.`gameobject_respawn` r
  JOIN `tbcmangos`.`gameobject` g          ON g.guid = r.guid
  JOIN `tbcmangos`.`gameobject_template` t ON t.entry = g.id
 WHERE (t.flags & 0x20) AND t.type IN (0, 1) AND r.respawntime > UNIX_TIMESTAMP();

-- ---------- 核对：期望 0 行 ----------
SELECT COUNT(*) AS 残留行
  FROM `tbccharacters`.`gameobject_respawn` r
  JOIN `tbcmangos`.`gameobject` g          ON g.guid = r.guid
  JOIN `tbcmangos`.`gameobject_template` t ON t.entry = g.id
 WHERE (t.flags & 0x20) AND t.type IN (0, 1) AND r.respawntime > UNIX_TIMESTAMP();
