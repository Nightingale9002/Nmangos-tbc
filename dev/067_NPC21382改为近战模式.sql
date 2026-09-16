-- NPC 21382 Wyrmcult Zealot（及可选同类）改为近战：去掉 EventAI 的远程模式（2026-09-16）
--
-- 背景：creature_ai_scripts 2138201（aggro 事件）action1 = 57 ACTION_T_SET_RANGED_MODE，
--       param1=2 即 RangeModeType TYPE_PROXIMITY、param2=35 → SetRangedMode(true, 35, PROXIMITY)
--       → 怪停在 35 码；而其"main spell"取法术表首位（32009 Cutdown，近战技），
--       Fireball(20714/9053) 只在 EventAI 的 range 事件里 → 表现为"停在远程距离却不攻击"。
--       站长定案：按近战怪处理 → param1 改成 0（TYPE_NONE=近战模式）。
--       实测参照：2163703（Wyrmcult Scout）的 action 57 param1=0 即注释里的 "Enable Melee Mode"。
--
-- 幂等，可重复执行

UPDATE tbcmangos.creature_ai_scripts
   SET `action1_param1` = 0,
       `comment` = 'Wyrmcult Zealot - Enable Melee Mode and Set Phase 1 on Aggro'
 WHERE `id` = 2138201
   AND `creature_id` = 21382;

-- 可选（同营地同类，先不启用，需要时去掉注释即可）：
-- 21492 Wyrmcult Blessed 已确认缺 main spell（服务端日志 2026-09-16 16:11:30 有报错），
--   其 ranged mode 本来就不生效，如要统一也可以显式改成近战：
-- UPDATE tbcmangos.creature_ai_scripts SET action1_param1 = 0
--  WHERE creature_id = 21492 AND action1_type = 57;
