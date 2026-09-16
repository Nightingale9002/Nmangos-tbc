-- 任务 10607「乌鸦之神的低语」中文名修复（2026-09-16）
--
-- ⚠️ 先纠正一个易踩的误判（2026-09-16 核实，别再"修"错）：
--   quest_template.10607.ReqCreatureOrGOId1..4 = 22798/22799/22800/22801 **是正确的**。
--   它们是 creature_template 里的 **[DND]Prophecy 1~4 Quest Credit**（隐形任务计数触发器），
--   且已 spawn 在四座神殿的同一坐标上：
--     22798 @ 3784.4/6729.3  ←→ GO 184950 The First Prophecy
--     22799 @ 3625.6/6541.6  ←→ GO 184967 The Second Prophecy
--     22800 @ 3734.7/6639.5  ←→ GO 184968 The Third Prophecy
--     22801 @ 3575.5/6666.4  ←→ GO 184969 The Fourth Prophecy
--   cmangos 规则：ReqCreatureOrGOId **正数=生物、负数=-GOId**（见 Player.cpp:14456-14469
--   CastedCreatureOrGO）；GO 命名空间里同样有 22798~22801（Wooden Chair/High Back Chair），
--   纯属撞号、与本题无关。所以"走到神殿自动完成"是设计而非 bug。
--
-- 真正的 bug 只有下面这条：中文名错译（184968/184969 都写成了「第一个预言」）
-- 幂等，可重复执行

INSERT INTO tbcmangos.locales_gameobject (`entry`, `name_loc4`) VALUES
  (184950, '第一个预言'),
  (184967, '第二个预言'),
  (184968, '第三个预言'),
  (184969, '第四个预言')
ON DUPLICATE KEY UPDATE `name_loc4` = VALUES(`name_loc4`);
