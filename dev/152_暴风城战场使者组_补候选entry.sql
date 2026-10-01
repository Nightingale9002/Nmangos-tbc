-- dev/152 暴风城「战场使者 x2」巡逻组（组 19980）补候选 entry：15103 Stormpike Emissary
--
-- 站长 2026-10-01 决定：该刷点现在游戏里看不到 NPC，"可以添加"。
--
-- 现象：启动自检 SPAWN-SANITY 报出 2 个 creature 刷点永远不生成：
--       guid 11559 / 11560（map 0，坐标完全重合 (-8351.66, 627.26, 95.24)，MovementType=0）
--       —— 它们属于刷怪组 19980「Stormwind - Battleground Emissary x2 - Patrol」
--       （MaxCount=0、Flags=10、WorldState=19998），组里有这两个成员，
--       但 spawn_group_entry 与 spawn_group_squad 都是 0 行 ⇒ entry 永远解析不出来。
--
-- 依据（决定性）：WotLK mangos 库（wotlkmangos）在**完全相同的坐标**
--   (-8351.66, 627.26, 95.24) 上摆的是两只 `15103 Stormpike Emissary`（奥山使者，guid 94010/94011，成对）；
--   本库、tbcmangos_orig、tbcdb_ref、classicmangos_ref 里这两行都是 id=0（从未定下 entry）。
--   组名里的 "x2" 与本组两个成员 guid 一致（两名使者）。
--   （同城另有两处四/三名使者是静态刷点 guid 190000..190013，不属任何刷怪组，与本组无关。）
--
-- 写法：与全库 2093 行同样的通用形态（Chance=0 = 等概率；只有一个候选时即必然选中），
--       组 MaxCount=0（不限）⇒ 两个成员都刷出 15103，正好"x2"。
-- 幂等：先删同组同 entry 再插。
-- 生效：spawn_group_entry 在 LoadSpawnGroups() 时读入 ⇒ 需要一次 mangosd 重启（nightly 自带）。
-- 核对：SELECT Id, Entry, MinCount, MaxCount, Chance FROM spawn_group_entry WHERE Id = 19980;  期望 1 行 (19980,15103,0,0,0)
--       启动自检应变为 `4 of 1189 creature …`（只剩 map 530 的 4 个待实地确认点）
--
-- 关联：dev/rollback/152_回滚_暴风城战场使者补候选.sql

DELETE FROM `spawn_group_entry` WHERE `Id` = 19980 AND `Entry` = 15103;

INSERT INTO `spawn_group_entry` (`Id`, `Entry`, `MinCount`, `MaxCount`, `Chance`) VALUES
(19980, 15103, 0, 0, 0);
