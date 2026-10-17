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