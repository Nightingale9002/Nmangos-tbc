-- =====================================================================
-- dev/143 两处小修正：任务 11010/11102 互斥（职业门），NPC 23253 Kronk 坐姿
-- =====================================================================
-- 一、任务 11010 与 11102「Bombing Run」可以同时接（站长实测）
--   查证：两条任务**不是重复条目**，文本不同 ——
--     11010：\"You have a flying mount... so what!\"  RequiredClasses = 0（任意职业）
--     11102：\"You can fly around as a crow...\"      RequiredClasses = 1024（德鲁伊）
--   所以官服的口径是：德鲁伊只该看到 11102，其它职业只该看到 11010。
--   我们的数据里 11010 没有排除德鲁伊 ⇒ 德鲁伊能同时接到两条（都给自 NPC 23120）。
--   参考库 tbcdb_ref 也一样，属上游数据缺口，不是本服漂移。
--   修法：给 11010 挂一个\"玩家不是德鲁伊\"的条件（conditions 表 type=14 RACE_CLASS，
--   race_mask=0 表示任意种族，class_mask=1024 德鲁伊，flags=1 = CONDITION_FLAG_REVERSE_RESULT 取反），
--   再让 quest_template.RequiredCondition 指向它。核心侧支撑见 Player.cpp:13780 SatisfyQuestCondition
--   与 Conditions.h:47 CONDITION_RACE_CLASS / :87 CONDITION_FLAG_REVERSE_RESULT。
--
-- 二、NPC 23253（Kronk）官服是坐着的，本服站着
--   guid 91790（map 530，2313.5 / 7278.1 / 368.7）在 creature_addon 里**根本没有行**
--   ⇒ 用默认站姿。补一行 stand_state=1（坐下），sheath_state=1 与同表的其它坐姿 NPC 保持一致。
--   回滚：dev/rollback/143_回滚_任务11010互斥_Kronk坐姿.sql
-- =====================================================================

INSERT INTO `conditions` (`condition_entry`, `type`, `value1`, `value2`, `value3`, `value4`, `flags`, `comments`)
VALUES (5800002, 14, 0, 1024, 0, 0, 1, 'PLAYER: not a druid - gate for quest 11010 Bombing Run (druids get 11102)');

UPDATE `quest_template` SET `RequiredCondition` = 5800002 WHERE `entry` = 11010;

INSERT INTO `creature_addon` (`guid`, `mount`, `stand_state`, `sheath_state`, `emote`, `moveflags`)
VALUES (91790, 0, 1, 1, 0, 0);
