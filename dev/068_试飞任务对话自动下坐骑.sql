-- 试飞任务（10712 / 10711 / 10557）：与 Rally Zapnabber(21461) 对话时自动下坐骑 + 取消变形（2026-09-16）
--
-- 背景与机制：
--   gossip 8304（21461 Rally Zapnabber）→ dbscripts_on_gossip 10712/10711/10557
--   → 先施放 36801 "Cannon Charging (Port)"（传送法术，落点 spell_target_position = 1920.13/5581.9/270.426）
--   → 12 秒后施放 Soaring（37968/37910/36812 = 击退 98 + 飞行 aura 105，不是 taxi）
--   36801 自带 root，Soaring 施放前会特意移除它（见 spell_soaring 脚本注释）；
--   坐骑状态同样会压制击退/位移 → 玩家不会被正确送上试飞平台。
--
-- 代码改动（ScriptDev，随源码提交）：
--   src/game/AI/ScriptDevAI/scripts/outland/blades_edge_mountains.cpp
--   · npc_rally_zapnabberAI（空 AI，只为绑定脚本）
--   · GossipSelect_npc_rally_zapnabber：IsMounted → Unmount()；IsShapeShifted → RemoveAurasByType(SPELL_AURA_MOD_SHAPESHIFT)，随后 return false 让 DB gossip/dbscript 继续执行
--
-- 本 SQL 只负责把脚本绑到 NPC 上（否则钩子不会被调用：ScriptDevAIMgr::OnGossipSelect 按 ScriptId 取脚本）。
-- 幂等，可重复执行

UPDATE tbcmangos.creature_template
   SET `ScriptName` = 'npc_rally_zapnabber'
 WHERE `entry` = 21461;
