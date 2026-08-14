-- =====================================================
-- 开放 .npc info 命令给所有玩家（2026-08-14）
--
-- 核心启动时会读取 world 库的 command 表覆盖源码中的
-- 硬编码权限（Chat.cpp: SELECT name,security,help FROM command）。
-- npc info 原为 security=3（管理员），改为 0（所有玩家可用）。
-- 命令本身只读，仅显示目标 NPC 的信息，无风险。
--
-- 生效方式：执行后重启服务器，或在游戏内用 GM 账号执行
-- .reload command（下次使用聊天命令时自动重新加载）。
-- =====================================================

UPDATE `command` SET `security` = 0 WHERE `name` = 'npc info';
