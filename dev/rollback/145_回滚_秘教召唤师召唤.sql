-- 145 回滚：把暗影迷宫「秘教召唤师」(18634) 的两条召唤法术还原回 creature_spell_list，
--           并删掉 dev/145 新增的两条 EventAI 行。
-- 原始值取自参考库（tbcdb_ref / wotlkmangos 与本地一致）：
--   1863401(N): Position1 = 33506 目标2 初始 3000~17000 重复 12000~26000
--               Position2 = 33507 目标2 初始 4000~18000 重复 13000~27000
--   2064801(H): 同上（Position1 注释为 Execute，SpellId 仍为 33506）

DELETE FROM `tbcmangos`.`creature_ai_scripts` WHERE `id` IN (1863410, 1863411);

DELETE FROM `tbcmangos`.`creature_spell_list` WHERE `Id` IN (1863401, 2064801) AND `SpellId` IN (33506, 33507);
INSERT INTO `tbcmangos`.`creature_spell_list`
(`Id`, `Position`, `SpellId`, `Flags`, `CombatCondition`, `TargetId`, `ScriptId`, `Availability`, `Probability`,
 `InitialMin`, `InitialMax`, `RepeatMin`, `RepeatMax`, `Comments`)
VALUES
(1863401, 1, 33506, 0, -1, 2, 0, 100, 0, 3000, 17000, 12000, 26000, 'Cabal Summoner - Summon Cabal Deathsworn - self'),
(1863401, 2, 33507, 0, -1, 2, 0, 100, 0, 4000, 18000, 13000, 27000, 'Cabal Summoner - Summon Cabal Acolyte - self'),
(2064801, 1, 33506, 0, -1, 2, 0, 100, 0, 3000, 17000, 12000, 26000, 'Cabal Summoner - Execute - self'),
(2064801, 2, 33507, 0, -1, 2, 0, 100, 0, 4000, 18000, 13000, 27000, 'Cabal Summoner - Summon Cabal Acolyte - self');
