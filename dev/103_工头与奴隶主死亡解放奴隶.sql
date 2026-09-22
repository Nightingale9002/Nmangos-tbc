-- dev/103 「工头/奴隶主死亡 → 周围奴隶脱战 + 变友善」家族总修复
-- ===============================================================================
-- 站长 2026-09-22 定案。全库普查（26 组"工头×附近奴隶"，见 KNOWN_ISSUES 同名章节）后确认：
--   TBC 里"打死工头→解放奴隶"只有 3 处，本文件一次修完其中需要动的 2 处（17959 本来就完整）。
--
-- ── A. 17058 伊利达雷工头（赞加沼泽） ──────────────────────────────────────────
-- 现状（上游原样，本库/tbcmangos_orig/tbcdb_ref/云端四处逐字段一致）：
--   1705802（死亡）: CAST 29460 + THROW_AI_EVENT(事件 6, 半径 15)
--   1693701（16937 地卜师接收）: 25 FLEE(0) 恐慌乱跑（**仍在战斗**）+ 5 EMOTE(0) + 22 SET_PHASE(2)
--   1693802（16938 苦工接收）  : 同上
--   1693702 / 1693803（反相位掩码 3 = 只有相位 ≥2 才跑）:
--       UPDATE_TEMPLATE → 20157/19477「Fleeing Dreghood」(Faction 774，对玩家无敌意)
--       + THREAT_ALL%(-100) 清仇恨 + FORCE_DESPAWN(9000)
-- 两个问题（站长游戏内实测："没有变友善，只是脱战一次，我还是能打他"）：
--   ① 动作选型：用 FLEE（恐慌）而非 EVADE，"脱战"实际靠下一秒换模板，不稳。
--   ② **半径 15 够不着巡逻圈**：17 个工头里 59461(8 点)/59464(9 点) 有 creature_movement 路径，
--      巡逻圈到最近苦工最远 **34.2 / 34.4 码** ⇒ 半径 15 只覆盖 2/8、3/9 个巡逻位置，
--      在圈外击杀 = 完全没反应。半径 40 覆盖 8/8、9/9；且**半径 15~100 都只有这两个 entry 会被命中**（零副作用）。
--
-- ── B. 17805 盘牙奴隶主（蒸汽地窟 map 545 = CoilfangPumping） ──────────────────
-- 断链：17799 Dreghood Slave 监听的"事件 5 / 7"**没有任何人抛**（17805 无抛事件行、无 dbscripts）
--       ⇒ 打死奴隶主，旁边 15 个德莱尼奴隶照旧打你（事件 7 只会在 17805 被控时由核心发）。
-- AZ 端 `acore_world.smart_scripts` 同 NPC 的零售行为：
--   On Aggro → "Assist me slaves!"；**On Just Died → Set Data 2 2（"Free Stored Slaves"）**。
-- 注：同族的 17959 Coilfang Slavehandler（奴隶围栏 map 547 = CoilfangDraenei）本来就完整，不动。
--
-- ⛔ 本文件是【全静态 SQL】：只有写死的字面量，无 JOIN/子查询/聚合/CASE 计算。
-- 幂等：UPDATE 带旧值判据、INSERT 用固定主键 + IGNORE，重跑 0 行变更。
-- 回滚：dev/rollback/103_回滚_工头与奴隶主解放奴隶.sql
-- 生效：`creature_ai_scripts` 在 mangosd 启动时载入 ⇒ **需重启**（随夜间窗口）。
-- ===============================================================================

-- ── A1. 17058 的接收动作：FLEE + 停表情 → EVADE + 改阵营友善（相位链 action3=SET_PHASE(2) 不变）──
UPDATE `creature_ai_scripts`
SET `action1_type` = 24, `action1_param1` = 0, `action1_param2` = 0, `action1_param3` = 0,
    `action2_type` = 2,  `action2_param1` = 35, `action2_param2` = 0, `action2_param3` = 0,
    `comment` = 'Dreghood Geomancer - Evade, Set Faction friendly, Set Phase 2 on Receive AI Event 6'
WHERE `id` = 1693701 AND `action1_type` = 25;

UPDATE `creature_ai_scripts`
SET `action1_type` = 24, `action1_param1` = 0, `action1_param2` = 0, `action1_param3` = 0,
    `action2_type` = 2,  `action2_param1` = 35, `action2_param2` = 0, `action2_param3` = 0,
    `comment` = 'Dreghood Brute - Evade, Set Faction friendly, Set Phase 2 on Receive AI Event 6'
WHERE `id` = 1693802 AND `action1_type` = 25;

-- ── A2. 17058 死亡广播半径 15 → 40（覆盖两条巡逻全程）──
UPDATE `creature_ai_scripts`
SET `action2_param2` = 40,
    `comment` = 'Illidari Taskmaster - Cast Darkcrest Taskmaster Slain and Send AI Event 6 on Death (radius 40)'
WHERE `id` = 1705802 AND `action2_param2` = 15;

-- ── B1. 17805 死亡时抛事件 6（解放奴隶）──
INSERT IGNORE INTO `creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_flags`, `event_chance`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1780511, 17805, 6, 0, 0, 100, 0, 0, 0, 0, 0, 0,
 45, 6, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Coilfang Slavemaster - Send AI Event 6 (free the slaves) on Death');

-- ── B2. 17805 仇恨时抛事件 5（"叫奴隶来帮忙"；让原本永远跑不到的 1779903 复活）──
INSERT IGNORE INTO `creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_flags`, `event_chance`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1780512, 17805, 4, 0, 0, 100, 0, 0, 0, 0, 0, 0,
 45, 5, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Coilfang Slavemaster - Send AI Event 5 (call the slaves for help) on Aggro');

-- ── B3. 17799 德莱尼奴隶收到"事件 6 / 来自 17805"→ 脱战 + 变友善 + 逃跑喊话 ──
--     掩码 0（任意相位；原本的事件 7 那两条是掩码 1 = 只在相位 ≥1，死亡瞬间可能还在相位 0）
INSERT IGNORE INTO `creature_ai_scripts`
(`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_flags`, `event_chance`,
 `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
 `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
 `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
 `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
(1779907, 17799, 30, 0, 1, 100, 6, 17805, 0, 0, 0, 0,
 24, 0, 0, 0, 2, 35, 0, 0, 53, 5450002, 0, 0,
 'Dreghood Slave - Evade, Set Faction friendly, Relay escape on Receive AI Event 6 (slavemaster died)');

-- 核对（可选）：
-- SELECT id, creature_id, action1_type, action1_param1, action2_type, action2_param1, action3_type, action3_param1
--   FROM creature_ai_scripts WHERE id IN (1693701, 1693802);                    -- 24/0 + 2/35 + 22/2
-- SELECT id, action1_type, action1_param1, action2_type, action2_param1, action2_param2
--   FROM creature_ai_scripts WHERE id = 1705802;                              -- 11/29460 + 45/6/40
-- SELECT id, creature_id, event_type, event_param1, event_param2, action1_type, action1_param1, action1_param2
--   FROM creature_ai_scripts WHERE id IN (1780511, 1780512, 1779907);
