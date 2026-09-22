-- dev/105 修两处「相位不可达」死行（上游数据 bug，三库一致）
-- ===============================================================
-- 背景：全库 19,373 行 `creature_ai_scripts` 做「相位可达性」普查（BFS，判据见 KNOWN_ISSUES 同名章节），
--   47 行为"要求的相位永远到不了"的死行；其中这两处是**真问题**（其余为历史残留 / 发送侧根本不抛事件）。
--
-- ① Perry Gatner（19228，说笑话的 NPC）—— 40 行永不播
--    `1922801`（事件 11 SPAWNED）= `ACTION_T_RANDOM_PHASE(30)`，参数 `(1, 2, 1)`
--    ⇒ `m_Phase = GetRandActionParam(rnd, p1, p2, p3)` 只可能得到 **1 或 2**；
--    而"Phase 3"整套段子（`1922882~19228121`，共 40 行，反相位掩码 7 = 只在相位 ≥3 跑）**永远不执行**。
--    ⇒ 把 p3 由 1 改成 3：`RANDOM_PHASE(1,2,3)`，三套段子各 1/3 概率。
--
-- ② Zaxxis Raider（18875，虚空风暴）—— 2 行互相死锁
--    `1887501`：掩码 5（屏蔽相位 0、2 ⇒ 只在相位 1/3/4… 跑）→ 设相位 2
--    `1887502`：掩码 3（屏蔽相位 0、1 ⇒ 只在相位 ≥2 跑）→ 设表情 28 + 设相位 1
--    初始相位是 **0**，两条都被自己屏蔽 ⇒ 谁都不先跑，表情循环完全没生效。
--    ⇒ 把 `1887502` 的掩码由 3 改成 **2**（只屏蔽相位 1），让它能在相位 0 起跑：
--      相位 0 →(1887502) 相位 1 →(1887501) 相位 2 →(1887502) 相位 1 → … 正常循环。
--
-- ⛔ 本文件是【全静态 SQL】：只有写死的字面量，无 JOIN/子查询/聚合/计算。
-- 幂等：分别带 `AND action1_param3 = 1` / `AND event_inverse_phase_mask = 3`，重跑匹配 0 行。
-- 回滚：dev/rollback/105_回滚_两处相位死行还原.sql
-- 生效：`creature_ai_scripts` 在 mangosd 启动时载入 ⇒ **需重启**（随夜间窗口）。
-- ===============================================================

UPDATE `creature_ai_scripts`
SET `action1_param3` = 3
WHERE `id` = 1922801 AND `action1_param3` = 1;

UPDATE `creature_ai_scripts`
SET `event_inverse_phase_mask` = 2
WHERE `id` = 1887502 AND `event_inverse_phase_mask` = 3;

-- 核对（可选）：
-- SELECT id, event_inverse_phase_mask, action1_type, action1_param1, action1_param2, action1_param3
--   FROM creature_ai_scripts WHERE id IN (1922801, 1887502);   -- 期望 1922801 的 p3 = 3；1887502 掩码 = 2
