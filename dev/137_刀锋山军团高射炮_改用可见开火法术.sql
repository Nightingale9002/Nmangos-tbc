-- ============================================================================
-- 137 刀锋山「军团高射炮」(creature 23076) 开火法术改为正式服的 40075
-- ============================================================================
-- 站长报告：*"刀锋山的军团高射炮还是不会开火"*，随后补充正式服战斗记录作为权威依据。
--
-- 【一、为什么"不开火"：原法术结构上就没有任何表现】
--   creature_ai_scripts.id=2307601（23076 唯一动作）原本施放 **41598**：
--     41598「Knockdown Felcannon: The Bolt Pair」的 **SpellVisual = 0**，
--     效果为 3=DUMMY + 6=APPLY_AURA(4=DUMMY) ⇒ 客户端不会有任何表现，
--     无论 EventAI 是否触发、施放是否成功。
--
-- 【二、正式服记录给出的正确答案（站长提供）】
--   ```
--   SPELL_CAST_SUCCESS ... 23082「军团高射炮」→ 40075「邪能高射炮」
--   SPELL_AURA_APPLIED/REMOVED ... 23082 → 41603「邪能高射炮」(DEBUFF, 反复出现)
--   ```
--   对照本库 `spell_template`（数值全部吻合）：
--
--   | 法术 | 参数 | 作用 |
--   |---|---|---|
--   | 40075「Fel Flak Fire」 | Effect1=108 DISPEL_MECHANIC(**misc 21 = MOUNTED**) + Effect2=98 **KNOCK_BACK**(49/150)；SpellVisual **9104**；半径 6 码(SpellRadius 29)；持续 10 秒 | **开火**：把玩家**打下坐骑**并击退 ⇒ 摔落伤害。与任务原文 *"Just don't let them shoot you down, too!"* 一致 |
--   | 41603「Fel Flak Fire」 | Effect1/2=129 **APPLY_AREA_AURA_ENEMY**（光环 77=MECHANIC_IMMUNITY(21) / 89=PERIODIC_DAMAGE_PERCENT(4)）；半径 6 码；持续 **5 秒**；目标=施法者自身 | 炮台脚下 6 码的"火场"光环，与记录里**反复 APPLIED/REMOVED**吻合 |
--
--   注：正式服记录里的生物是 **23082**（同名 Legion Flak Cannon），而本库实际刷出来的是
--   **23076**（22 个刷点 / faction 90 / AIName=EventAI；23082 是 0 刷点的另一条同名条目）。
--   两者共用同一套法术，改动落在 23076 上。
--
--   同族的 40109/40111/40112/40113/40119（"Knockdown Fel Cannon" 事件链）在 cmangos 从未实现
--   （`SpellAuras.cpp:1614`、`:7424` 只剩被注释掉的 case 40113 / 40119），本次不涉及。
--
-- 【三、本次改动】
--   1) 2307601 动作法术：41598 → **40075**（保留原事件 EVENT_T_OOC_LOS 敌对 60 码 / 7~10 秒、
--      目标 TARGET_T_ACTION_INVOKER=6、castFlags=2 CAST_TRIGGERED —— 触发式施法会跳过射程判定，
--      而 40075 的 RangeIndex=1，必须靠 triggered 才能远程施放）；
--   2) 新增 2307602：EVENT_T_TIMER_OOC 每 4~6 秒给**自身**挂一次 **41603**（复现正式服的周期光环）。
--
-- 【四、AI 绑定（最终形态）】
--   上面两条 EventAI 已不足以表达正式服行为，改由 ScriptDevAI 的 `npc_legion_flak_cannon`
--   接管（`blades_edge_mountains.cpp`）：
--     1) **只对空中的敌对玩家开火**（IsFlying/IsLevitating/IsHovering）—— 地面玩家不再被攻击；
--     2) **只对坐标施放**炮弹（SpellCastTargets 只设 dest、不带单位目标）⇒ 客户端不会把火焰/命中
--        特效贴到玩家身上（原来的 ACTION_T_CAST 必然带单位目标，炮弹打空也会在玩家身上留火）。
--   优先级：CreatureAISelector.cpp:42 先取 ScriptDevAI、再退回 AIName ⇒ 上面两条 EventAI 作为
--   **兜底**保留（脚本万一未加载时仍是旧行为）。
--
-- 【生效方式】重启 world，或 `.reload creature_ai_scripts`（ScriptName 改动需重启）
-- 【幂等】UPDATE 仅当动作为 41598 / 40109 / 40075；ScriptName 仅当不是目标值时更新。
-- 【回滚】dev/rollback/137_回滚_刀锋山军团高射炮_恢复41598.sql（含清空 ScriptName）
-- ============================================================================

UPDATE `tbcmangos`.`creature_template`
SET `ScriptName` = 'npc_legion_flak_cannon'
WHERE `Entry` = 23076
  AND `ScriptName` <> 'npc_legion_flak_cannon';

UPDATE `tbcmangos`.`creature_ai_scripts`
SET `action1_param1` = 40109,
    `action1_param2` = 6,
    `action1_param3` = 2,
    `action2_type`   = 0,
    `action2_param1` = 0,
    `action2_param2` = 0,
    `action2_param3` = 0
WHERE `id` = 2307601
  AND `action1_param1` IN (41598, 40075, 40109);

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` = 2307602;

INSERT INTO `tbcmangos`.`creature_ai_scripts`
    (`id`, `creature_id`, `event_type`, `event_inverse_phase_mask`, `event_chance`, `event_flags`,
     `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`,
     `action2_type`, `action2_param1`, `action2_param2`, `action2_param3`,
     `action3_type`, `action3_param1`, `action3_param2`, `action3_param3`, `comment`)
VALUES
    (2307602, 23076, 1 /*EVENT_T_TIMER_OOC*/, 0, 100, 1 /*EFLAG_REPEATABLE*/,
     1000, 2000, 4000, 6000, 0, 0,
     11 /*ACTION_T_CAST*/, 41603, 0 /*TARGET_T_SELF*/, 2 /*CAST_TRIGGERED*/,
     0, 0, 0, 0,
     0, 0, 0, 0,
     '正式服记录: 军团高射炮周期性给自己挂 41603 邪能高射炮(6码区域光环, 持续5秒)');

-- ---------- 核对 ----------
SELECT `id`, `creature_id`, `event_type`, `action1_type`, `action1_param1`, `action1_param2`, `action1_param3`
  FROM `tbcmangos`.`creature_ai_scripts` WHERE `creature_id` = 23076 ORDER BY `id`;
