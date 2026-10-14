-- 回滚 dev/174：恐惧魔(22204) 光环还原为 NULL 并恢复两条定时 EventAI；深渊烈焰行者(19973) 恢复 37633
-- 幂等：可重复执行

-- ① 22204 光环还原
UPDATE creature_template_addon SET auras = NULL WHERE entry = 22204;

-- ② 22204 两条 EventAI 还原（先删后插，保证可重复执行）
DELETE FROM creature_ai_scripts WHERE id IN (2220401, 2220402);
INSERT INTO creature_ai_scripts
  (id, creature_id, event_type, event_inverse_phase_mask, event_chance, event_flags,
   event_param1, event_param2, event_param3, event_param4, event_param5, event_param6,
   action1_type, action1_param1, action1_param2, action1_param3,
   action2_type, action2_param1, action2_param2, action2_param3,
   action3_type, action3_param1, action3_param2, action3_param3, comment)
VALUES
  (2220401, 22204, 0, 0, 100, 1025, 6000, 12000, 13000, 27000, 0, 0,
   11, 36248, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Fear Fiend - Cast Fel Flames'),
  (2220402, 22204, 0, 0, 100, 1025, 15000, 23000, 35000, 47000, 0, 0,
   11, 34259, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Fear Fiend - Cast Fear');

-- ③ 19973 的 1997301 还原为"战斗中定时施放 37633 Abyssal Strike"
UPDATE creature_ai_scripts
   SET event_type = 0, event_inverse_phase_mask = 0, event_chance = 100, event_flags = 1025,
       event_param1 = 0, event_param2 = 5000, event_param3 = 18000, event_param4 = 28000,
       event_param5 = 0, event_param6 = 0,
       action1_type = 11, action1_param1 = 37633, action1_param2 = 1, action1_param3 = 0,
       action2_type = 0,  action2_param1 = 0,     action2_param2 = 0, action2_param3 = 0,
       action3_type = 0,  action3_param1 = 0,     action3_param2 = 0, action3_param3 = 0,
       comment = 'Abyssal Flamebringer - Cast Abyssal Strike'
 WHERE id = 1997301 AND creature_id = 19973;
