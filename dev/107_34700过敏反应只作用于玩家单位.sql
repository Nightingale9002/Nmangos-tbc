-- =============================================================
-- dev/107 34700「过敏反应」只对玩家控制单位生效（配套代码改动）
-- 来源：cmangos/mangos-tbc 上游提交 46d9a78d7
-- 配套：src/game/AI/ScriptDevAI/scripts/outland/tempest_keep/botanica/boss_laj.cpp
--       新增 SpellScript `spell_allergic_reaction`（OnCheckTarget 里要求 target->IsPlayerControlled()）
-- 背景：Laj（17980，植物园）给自己叠 34697 后，34697 触发 34700 传染；
--       原来 34700 也能传到非玩家控制单位（Laj 自己的召唤物等），官服只对玩家侧生效。
-- 生效：spell_scripts 在 mangosd 启动时载入 ⇒ 需重启；且**必须与上面的代码一起上线**，
--       否则启动日志会报 "script name 'spell_allergic_reaction' not found"（不致命，但该行会被跳过）。
-- 回滚：dev/rollback/107_回滚_34700过敏反应.sql
-- =============================================================

DELETE FROM `spell_scripts` WHERE `Id` = 34700;
INSERT INTO `spell_scripts` (`Id`, `ScriptName`) VALUES (34700, 'spell_allergic_reaction');
