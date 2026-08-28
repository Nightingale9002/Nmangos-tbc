-- 037_关闭竞技场赛季事件.sql
-- 目的：永久关闭竞技场赛季 GameEvent 53-56（Arena PvP Season 1-4），
--       使赛季军需官不再自动刷出、竞技场装备不在前期提前开放。
--
-- 背景（为什么之前 `.event stop 56` 重启后又开）：
--   本 fork 的 game_event 用 schedule_type 字段控制事件调度（见
--   src/game/GameEvents/GameEventMgr.cpp）：
--     0 = GAME_EVENT_SCHEDULE_SERVERSIDE —— 事件 start/end 均置 FAR_FUTURE，
--         服务器正常运行中 Update() 对该类事件直接 continue 跳过（不自动开/关），
--         只由 GM 手动 `.event start/stop <id>` 控制；重启后不会自动开启
--         （CheckOneGameEvent 对 FAR_FUTURE 恒返回 false）。
--     1 = GAME_EVENT_SCHEDULE_DATE —— 按 game_event_time 表 start_time/end_time
--         每年周期自动开启。
--   原 53-56 为 1，故 56 在服务器重启后按时间自动重新开启。
--
-- 影响：
--   1) 改 0 后重启 mangosd，赛季军需官不再自动刷出，需 GM 手动 `.event start` 才出现。
--   2) 若想后期开放某赛季，可用 `.event start <id>`（53/54/55/56 对应 S1-S4）。
--   3) 重启日志可能出现
--        "`game_event` game event id (XX) has game_event_time but is not date scheduled - ignoring"
--      这是 game_event_time 里 53-56 的旧记录被忽略的正常提示，不影响功能。
--
-- 已应用：本地 tbcmangos（2026-09，本地测试正常）。
-- 待同步：云端 tbcmangos 需重放本文件后重启 mangosd。

UPDATE `tbcmangos`.`game_event` SET `schedule_type` = '0' WHERE (`entry` = '53');
UPDATE `tbcmangos`.`game_event` SET `schedule_type` = '0' WHERE (`entry` = '54');
UPDATE `tbcmangos`.`game_event` SET `schedule_type` = '0' WHERE (`entry` = '55');
UPDATE `tbcmangos`.`game_event` SET `schedule_type` = '0' WHERE (`entry` = '56');
