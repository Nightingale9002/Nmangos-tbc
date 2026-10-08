-- =====================================================================================
-- 166_幽暗沼泽泥沼巨人_激怒事件按官方清单对齐.sql
-- 日期：2026-10-07        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】站长：幽暗沼泽泥沼巨人「HP 0–30% 激怒 + 喊话」现在没有（英雄难度实测）。
-- 【根因】不是数据被删 —— 事件行 1772301 一直在（本地=云端=上游 tbcmangos_orig 逐字段一致），
--   问题是 **event_flags = 1027 = 0x403**：
--     0x01 EFLAG_REPEATABLE（可重复）
--     0x02 EFLAG_NORMAL     —— "Event only occurs in Normal instance difficulty"
--     0x400 EFLAG_COMBAT_ACTION（第一个动作必须先成功；等价于你贴的 "After Event #3 才喊话"）
--   而 CreatureEventAI.cpp:123-134 只要带了 NORMAL/HEROIC 任一位就按难度过滤：
--     `(1 << (GetSpawnMode() + 1)) & event_flags`
--     普通 spawnMode=0 ⇒ 需要 0x02（命中 ✓）；英雄 spawnMode=1 ⇒ 需要 **0x04**（0x403 里没有 ✗）
--   ⇒ **英雄难度下整条事件被跳过：既不激怒、也不喊话**（普通难度正常）。
--   数据侧其余都齐：cast 8599(=Enrage) target self；action2 = TEXT 2384；
--   broadcast_text 2384 的 zhCN = "%s变得愤怒了！"（游戏内显示"泥沼巨人变得愤怒了！"）。
-- 【修复】按站长贴的清单对齐这一行（改 event_flags 与 action1_param3 两项）：
--   event_flags  1027 → **1030**（0x406 = EFLAG_NORMAL | EFLAG_HEROIC | EFLAG_COMBAT_ACTION）
--     · 加 EFLAG_HEROIC(0x04) ⇒ 普通+英雄都生效
--     · 去掉 EFLAG_REPEATABLE(0x01) ⇒ 每场战斗只激怒一次（CreatureEventAI.cpp:628-629：
--       可重复事件类型缺该位即 holder.enabled=false）
--   action1_param3  0 → **32**（CAST_INTERRUPT_PREVIOUS，激怒时打断当前施法）
--   保留：event_param1/2 = 30/0（0–30% 生命）、action2 = TEXT 2384；
--         event_param3/4 = 120000/120000 在"不可重复"下不再参与判定（留档，代表原 2 分钟间隔）。
-- 【对照】AC(wotlk) smart_scripts 17723：id3 = HP 0–30% Cast Enrage（event_flags=3：No Repeat+普通）
--   + id4 = event 61「After Event #3」Say Line 0；本改动与之一致（并额外把英雄难度也纳入）。
-- 【不影响】英雄版模板 20164 的 AIName 仍为空 —— 但 EventAI 按 **普通 entry** 取脚本
--   （Creature::UpdateEntry 写 SetEntry(Entry)=普通 entry，Creature.cpp:405-406；
--    CreatureEventAI.cpp:186 用 GetEntry()）⇒ 挂在 17723 的行普通+英雄都吃得到，
--   本行改 flag 后英雄难度即可生效，无需给 20164 另建行。
-- 【生效】creature_ai_scripts 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/166_回滚_泥沼巨人激怒对齐.sql
-- =====================================================================================

-- ---------- 对齐 1772301（守卫：仅当仍是原值时才改，幂等） ----------
UPDATE `tbcmangos`.`creature_ai_scripts`
   SET `event_flags` = 1030,
       `action1_param3` = 32,
       `comment` = 'Bog Giant - Enrage at 0-30% HP (normal+heroic, once, interrupt current cast)'
 WHERE `id` = 1772301
   AND `creature_id` = 17723
   AND `event_flags` IN (1027, 1030)
   AND `action1_param3` IN (0, 32);

-- ---------- 核对 ----------
-- 期望：event_flags=1030（0x406）、action1_param3=32、event_param1/2=30/0、
--       action1=11/8599/0/32、action2=1/2384
SELECT `id`, `creature_id`, `event_type`, `event_chance`, `event_flags`,
       `event_param1`, `event_param2`, `event_param3`, `event_param4`,
       `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
       `action2_type`, `action2_param1`, `comment`
  FROM `tbcmangos`.`creature_ai_scripts`
 WHERE `creature_id` = 17723
 ORDER BY `id`;
