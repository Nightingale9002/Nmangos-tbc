-- dev/110 斯克提斯「鸦爪战士呼救」修复：让卡利鸟临时改阵营并攻击玩家
-- ===============================================================
-- 现象（站长 2026-09-23 报告）：
--   斯克提斯鸦爪战士（21650）挨打后会把旁边的**黄名**小卡里鸟（21804）叫来，
--   但卡里鸟**不攻击玩家**，只是跟着鸦爪战士跑；鸦爪战士一死它就飞回去。
--
-- 根因（两层，均在数据侧）：
--   ① `creature_ai_scripts 2165001`（鸦爪战士·进战斗）第 3 个动作 = 45 抛 AI 事件：
--      EventType=5, Radius=25, **Target=0（TARGET_T_SELF）** ⇒ 事件携带的 invoker 是【鸦爪战士自己】。
--   ② `creature_ai_scripts 2180402`（卡里鸟·收到发送者 21650 的 AI 事件 5）= 55 攻击目标，
--      参数 = **10（TARGET_T_EVENT_SENDER）** ⇒ 它攻击的是【事件发送者 = 鸦爪战士】——自己的友军，
--      打不动 ⇒ 只表现为"跟着它跑"；鸦爪战士死后目标消失 ⇒ 飞回家。注释写的是 "Attack Invoker"，
--      说明作者本意就是打玩家，参数写错了。
--   ③ 另外：卡里鸟阵营 **1869（中立/黄名）**，而 `Unit::CanAttack` 要求 `IsEnemy(unit) || unit->IsEnemy(this)`
--      （`Relations.cpp:437`）⇒ 中立生物**结构上就打不了玩家**，所以就算把 ② 的目标改成玩家也只会"换个跟随对象"。
--
-- 修复（站长 2026-09-23 决定：**让呼喊改阵营 + 修目标链**）：
--   ① 抛事件的 invoker 由"自己"改成"当前目标(玩家)"：`action3_param3` 0 → 1（TARGET_T_HOSTILE）。
--   ② 卡里鸟收到召唤后：
--      - `action1` = 2（ACTION_T_SET_FACTION）factionId=**1862**（与鸦爪战士同阵营 ⇒ 对玩家敌对、可被玩家反击），
--        factionFlags=**2**（TEMPFACTION_RESTORE_COMBAT_STOP ⇒ 战斗结束自动还原成 1869 黄名，不需要额外脚本）；
--      - `action2` = 55（ACTION_T_ATTACK_START）目标 = **6**（TARGET_T_ACTION_INVOKER ⇒ 事件 invoker = 玩家）。
--   ③ 动作按 1→2→3 顺序执行（`CreatureEventAI.cpp:657` 起），所以先把阵营切过去，攻击判定才通得过。
--
-- 核对：该坏脚本在我们库、`tbcdb_ref`、`wotlkmangos` 三库**逐字段一致**（属上游 TBC-DB 数据），
--       全库仅此一处 `event_type=30 + action=55 + target=10` 针对中立生物的用法；本文件只改这 2 行。
--
-- ⛔ 全静态 SQL：只有写死字面量，无 JOIN / 子查询 / 聚合 / 计算。
-- 幂等：两条 UPDATE 都把"改前值"写进 WHERE，重跑匹配 0 行。
-- 生效：`creature_ai_scripts` 在 mangosd 启动时载入 ⇒ **需重启**。
-- 回滚：dev/rollback/110_回滚_斯克提斯卡利鸟协战.sql
-- ===============================================================

-- ① 鸦爪战士：抛出的 AI 事件，invoker 改为"当前仇恨目标"（即把它打进战斗的玩家）
UPDATE `creature_ai_scripts`
SET `action3_param3` = 1
WHERE `id` = 2165001
  AND `action3_type` = 45 AND `action3_param1` = 5 AND `action3_param3` = 0;

-- ② 卡里鸟：先切临时敌对阵营（战斗结束自动还原），再攻击事件 invoker（玩家）
UPDATE `creature_ai_scripts`
SET `action1_type` = 2,   `action1_param1` = 1862, `action1_param2` = 2, `action1_param3` = 0,
    `action2_type` = 55,  `action2_param1` = 6,    `action2_param2` = 0, `action2_param3` = 0
WHERE `id` = 2180402
  AND `event_type` = 30 AND `action1_type` = 55 AND `action1_param1` = 10;

-- 核对（可选）：
-- SELECT id, action1_type, action1_param1, action1_param2, action2_type, action2_param1, action3_type, action3_param1, action3_param3
--   FROM creature_ai_scripts WHERE id IN (2165001, 2180402);
--   期望：2165001 = (..., 45, 5, ..., 1)；2180402 = (2, 1862, 2, 55, 6, 0, 0, 0)
--
-- 游戏内验收（本地测试服）：
--   1. 去斯克提斯（泰罗卡森林）找一只**旁边有黄名卡里鸟**的斯克提斯鸦爪战士，打它；
--   2. 期望：卡里鸟**变红**并冲过来打你（不再是跟着鸦爪战士跑）；
--   3. 期望：战斗结束后卡里鸟**变回黄名**并飞回原位；打死它则正常掉落/消失。
