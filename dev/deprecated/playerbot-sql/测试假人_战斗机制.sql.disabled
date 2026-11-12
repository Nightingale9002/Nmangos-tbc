-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：测试假人_战斗机制
-- 来源（旧编号）：189_测试假人_战斗机制.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- ============================================================================
-- 189: 训练假人 190013 的"战斗机制"技能（单目标 / 五目标场景用）
-- 站长 2026-10-17 指定：
--   地面技      = 27810 暗影裂隙（瞬发，召唤裂隙）
--   可打断读条  = 635   圣光术（有读条，InterruptFlags=15）
--   点名 / DoT  = 589   暗影痛（瞬发 + 每 3 秒周期伤害，魔法）
--   点名高伤    = 31249 寒冰箭（瞬发，直接伤害）
-- 另加三类可驱散 DoT（都要测驱散）：
--   诅咒 = 980   Curse of Agony（瞬发，每 2 秒）
--   疾病 = 16432 Plague Mist（瞬发，每 2 秒）
--   毒   = 32139 Acidic Splash（瞬发，周期伤害）
-- 说明：DoT 本身也算"点名"，所以不单独再做；四类驱散 + 地面 + 打断 + 点名已全覆盖。
-- ⚠️ 仅本地测试库；不要上云。幂等：先删后插。
-- ============================================================================

DELETE FROM creature_template_spells WHERE entry = 190013;

-- ----------------------------------------------------------------------------
-- [2026-10-19] 之前只有 creature_template_spells，**没有 creature_template 行** ⇒
--   `SummonCreature(190013)` 找不到模板、召唤失败，测试场景里一个怪都没有，
--   于是 bot_events.csv 里从来没有战斗数据（KPI/奖励函数无从谈起）。
--   这里以游戏内现成的 70 级测试假人 15134（Outlands Test Dummy Warrior 70）为蓝本复制，
--   只覆盖 Entry / Name / 血量；另外 190014、190015 是"普通假人"（无技能），供五目标场景用。
--   幂等：先删后插（临时表只在本次连接里存在）。
-- ----------------------------------------------------------------------------
DELETE FROM creature_template WHERE Entry IN (190013, 190014, 190015);

DROP TEMPORARY TABLE IF EXISTS tmp_dummy_base;
CREATE TEMPORARY TABLE tmp_dummy_base AS
    SELECT * FROM creature_template WHERE Entry = 15134 LIMIT 1;

UPDATE tmp_dummy_base
   SET Entry = 190013, Name = '训练假人(技能)',
       MinLevelHealth = 1000000, MaxLevelHealth = 1000000;
INSERT INTO creature_template SELECT * FROM tmp_dummy_base;

UPDATE tmp_dummy_base
   SET Entry = 190014, Name = '训练假人(普通)';
INSERT INTO creature_template SELECT * FROM tmp_dummy_base;

UPDATE tmp_dummy_base
   SET Entry = 190015, Name = '训练假人(普通2)';
INSERT INTO creature_template SELECT * FROM tmp_dummy_base;

DROP TEMPORARY TABLE tmp_dummy_base;

INSERT INTO creature_template_spells
    (entry, setId, spell1, spell2, spell3, spell4, spell5, spell6, spell7,
     spell8, spell9, spell10)
VALUES
    (190013, 0,
      27810,   -- 地面：暗影裂隙
      635,     -- 可打断：圣光术
      589,     -- 魔法 DoT：暗影痛（点名）
      32139,   -- 毒 DoT：Acidic Splash
      16432,   -- 疾病 DoT：Plague Mist
      980,     -- 诅咒 DoT：Curse of Agony
      31249,   -- 点名高伤：寒冰箭
      0, 0, 0);

UPDATE creature_template SET MinLevelHealth = 1000000, MaxLevelHealth = 1000000 WHERE entry = 190013;

SELECT entry, spell1, spell2, spell3, spell4, spell5, spell6, spell7 FROM creature_template_spells WHERE entry = 190013;
