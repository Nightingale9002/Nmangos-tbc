-- ============================================================================
-- 091_任务10961沼泽花击飞修复.sql（2026-09-19）
--
-- 站长反馈：任务 10961《觉醒之戒》摘沼泽花不被弹飞。
--
-- 链路诊断（逐环核对数据 + 核心代码）：
--   花 185500(goober) --linkedTrapId--> 185499(trap)
--   陷阱原本的法术 39558「Bogblossom Pollen」= 2×光环 + 召唤 Bogblossom Bunny(23104)
--   兔子的 EventAI 2310401：EVENT_T_SPAWNED -> CAST 40532 击飞
--   断点①：185499 这个陷阱全库没有任何实例（0 刷点、不在 spawn_group 29999 里，
--          上游 tbcdb_ref / FullDB 同样如此），而 GameObject::TriggerLinkedGameObject()
--          只找"已存在的同 entry 地物（0.5 码内）"→ 陷阱不会被 Use() → 花粉不会施放。
--   断点②：即使花粉被施放、兔子被召唤，兔子那条 AI 的 action1_param2 = 15
--          = TARGET_T_NONE（EventAI 目标枚举里的"无目标"）→ 40532 以 nullptr 为目标施放，
--          Spell::EffectKnockBack() 首行 `if (!unitTarget) return;` 直接返回。
--          → 这条 AI 数据本身有问题，"花粉→兔子→AI"链打不到玩家。
--
-- 本次修法：把陷阱 185499 的法术直接改成真正做事的 **40532 击飞**，绕开上面那条链。
--   （配合核心侧兜底：源码 GameObject.cpp::TriggerLinkedGameObject() 在找不到已放置的陷阱时，
--     直接按模板把它的法术打在使用者身上 —— 陷阱没被摆进世界也能生效。）
--
-- 明确【不改】：宝箱版 185497（掉任务物品 31950 的那朵）的联动陷阱保持 185502「无害版」
--   （无 spell）—— 站长确认"宝箱版不会击飞是对的"。所以只有 goober 版（185500）那朵会弹人。
--
-- 幂等：UPDATE 带原值条件（data3 = 39558），重跑匹配 0 行。
-- 生效方式：gameobject_template 在启动时载入 → 应用后需重启（随夜间重启）。
-- ============================================================================

USE tbcmangos;

-- 陷阱法术：花粉（会走那条打不到人的链）-> 直接击飞
UPDATE gameobject_template
   SET data3 = 40532
 WHERE entry = 185499
   AND data3 = 39558;

-- ---------------------------------------------------------------------------
-- 校验
-- ---------------------------------------------------------------------------
SELECT entry, type, data3 AS trapSpell, data7 AS linkedTrap, data12
  FROM gameobject_template WHERE entry IN (185497, 185499, 185500, 185502) ORDER BY entry;

SELECT 'trap 185499 spell (expect 40532)' AS check_name, data3 AS spell FROM gameobject_template WHERE entry = 185499;
SELECT 'chest 185497 linked trap (expect 185502 = harmless, unchanged)' AS check_name, data7 AS linked FROM gameobject_template WHERE entry = 185497;
