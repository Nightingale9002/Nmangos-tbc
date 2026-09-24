-- dev/114 埃博尔（Empoor 18482）被击败时，他的保镖（18483）同时变友善并不再攻击
-- ===============================================================
-- 站长报告（2026-09-24）：打败埃博尔时，埃博尔的保镖没有同时变友善。
--
-- 现状（本地/上游同源）：
--   * 18482 Empoor 的 EventAI 已有完整流程：
--       1848201 生成时 → 17 SET_UNIT_FIELD(168 UNIT_NPC_FLAGS, 2 可对话)
--       1848202 进战斗 → 42 免死（invincible）
--       1848204 血量到 5% → 24 EVADE（脱战）＋17 设置可对话 ＋ 2 SET_FACTION(35 友善)
--       1848205 脱战(EVENT_T_EVADE=7) → 41 延时 40 秒消失 ＋ 42 免死
--     ⇒ 埃博尔本人会脱战、变友善、可对话，40 秒后消失。
--   * **18483 Empoor's Bodyguard 只有两条战斗技能**（11977 撕裂 / 13730 挫志怒吼），
--     没有任何"变友善/脱战"的处理 ⇒ 埃博尔投降后保镖仍然敌对、继续打玩家。
--
-- 修法（只用 EventAI，与 dev/110「卡利鸟协战」同一套机制）：
--   1) 复用 1848205 里**空着的第 3 个动作槽**：抛出 AI 事件 A（45 THROW_AI_EVENT，
--      EventType=5(AI_EVENT_CUSTOM_EVENTAI_A)、Radius=30、Target=0 自身）
--      ⇒ 事件 invoker = 埃博尔自己，附近 30 码内的单位都能收到。
--   2) 新增保镖行 1848303：收到"来自发送者 18482 的事件 5"时 →
--      先 24 EVADE（脱离战斗、走回原位，不再打玩家），再 2 SET_FACTION(35, flags=0)
--      （与埃博尔同一个友善阵营；flags=0 = 不因脱战恢复，等刷点重生时自然还原）。
--
-- 幂等：第 1 条带 `AND action3_type <> 45`；第 2 条用 `INSERT IGNORE`（主键 id=1848303）。
-- 生效：creature_ai_scripts 启动载入 ⇒ 需重启。
-- 回滚：`dev/rollback/114_回滚_保镖不跟随变友善.sql`
-- ===============================================================

-- 1) 埃博尔脱战时抛出 AI 事件 A（半径 30 码）
UPDATE `creature_ai_scripts`
SET `action3_type` = 45, `action3_param1` = 5, `action3_param2` = 30, `action3_param3` = 0,
    `comment` = 'Empoor - Delayed Despawn, Invincible and Throw AI Event A to Bodyguards on Evade'
WHERE `id` = 1848205 AND `action3_type` <> 45;

-- 2) 保镖：收到事件后脱战 + 变友善
INSERT IGNORE INTO `creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1848303, 18483, 30, 0, 100, 0,
 5, 18482, 0, 0, 0, 0,
 24, 0, 0, 0,
 2, 35, 0, 0,
 0, 0, 0, 0,
 'Empoor''s Bodyguard - on AI event A from Empoor: evade then turn friendly (faction 35)');
