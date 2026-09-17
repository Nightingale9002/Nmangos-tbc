-- ============================================================================
-- 081_超稀有掉落提升.sql（2026-09-18）
--
-- 背景与目标（站长定案）：
--   把"万分之一级（1/10 万~1/200 万）"的**世界掉落组**抬到"有稳定机会见到"的量级，
--   重点两类内容：
--     ① 603xx 系列 = 世界掉落**紫装（Epic 装备）**组（60345 那组是 TBC 紫装 21 件，绑 670 只怪）
--     ② 505xx / 361xx / 57xx 系列 = 世界掉落**配方 / 图样 / 设计图**组
--   实际期望：让"某个具体物品"从 1/420 万 → 1/5,000~1/20,000（仍然稀有，但打得到）。
--
-- 为什么不用 Rate.Drop.Item.Referenced（重要）：
--   它是【全局均匀乘数】，只作用于引用行的外层几率，无法区分"万分之一级"和"普通 1.94%"：
--     ×10 → 普通引用行 1.94% → 19.4%（材料/绿装/普通引用掉落全线泛滥，且 >10% 的行直接变必掉）
--            而 0.0005% → 0.005%（依然等于没有）
--   两头都不讨好。所以本文件只做【按稀有度分档、定向改组】的数据修改，Referenced 保持 1。
--
-- 分档规则（只抬"外层组出现率"，不动组内容 → 组内物品相对比例不变）：
--   A) 紫装组（603xx 全域 + 41301 + 30012），当前 <=0.1%：
--        <=0.001%  → 0.15%（含 60345 的 0.0005%）
--        <=0.01%   → 0.25%（603xx 绝大多数）
--        (0.01,0.1]→ 0.5%
--   B) 配方/图纸组，当前 <0.5%：
--        <=0.05%   → 0.6%
--        其它(<0.5)→ 1.2%
--
-- 幂等性（dev SQL 会被重复应用）：
--   改写后的取值全部落在 WHERE 阈值【之上】（A 组结果 0.15/0.25/0.5 > 0.1；B 组结果 0.6/1.2 > 0.5），
--   因此重跑本文件不会再命中任何行 → 不会叠加放大。已本地连续执行两次验证。
--
-- 影响面（云端实测）：
--   A 组 ~2,266 行 —— 正好覆盖全库所有 <=0.01% 的引用行（说明"万分之一级"被完整覆盖）
--   B 组 ~2,800 行 —— 主要是 50501 珠宝设计图 1,517 行 + 50500 666 行 + 50502 894 行
--
-- 明确【不动】的部分：
--   * 全部 >0.5% 的普通引用行（26,346 行）—— 材料/绿装/普通引用掉落都在这里，动了就是全服泛滥 + AH 爆量；
--   * 34002 / 34003 / 34024 等技能书/圣契组（外层本来就是 100% 必掉）；
--   * 直接掉落的超稀有物品行（item<>0 且 <=0.01%，约 2,980 行）—— 其中大半是宝石（Citrine/Jade 等），
--     它们本就有其它常见掉落渠道，抬了收益小、副作用是宝石价崩。若日后要动，另开一份文件单独评估。
--
-- 生效方式：掉落表在 mangosd 启动时载入 → 应用后需重启（nightly 会重启）。无需额外操作。
-- ============================================================================

USE tbcmangos;

-- ---------------------------------------------------------------------------
-- A) 紫装组（603xx 全域 + 41301 + 30012）：<=0.1% 的引用行分档抬到 0.15 / 0.25 / 0.5%
-- ---------------------------------------------------------------------------
UPDATE creature_loot_template
   SET ChanceOrQuestChance = CASE
         WHEN ChanceOrQuestChance <= 0.001 THEN 0.15
         WHEN ChanceOrQuestChance <= 0.01  THEN 0.25
         ELSE 0.5
       END
 WHERE mincountOrRef < 0
   AND ChanceOrQuestChance > 0
   AND ChanceOrQuestChance <= 0.1
   AND (-mincountOrRef BETWEEN 60300 AND 60399 OR -mincountOrRef IN (41301, 30012));

-- ---------------------------------------------------------------------------
-- B) 配方 / 图样 / 设计图组：当前 <0.5% 的引用行 → 0.6%（<=0.05%）或 1.2%
-- ---------------------------------------------------------------------------
UPDATE creature_loot_template
   SET ChanceOrQuestChance = CASE WHEN ChanceOrQuestChance <= 0.05 THEN 0.6 ELSE 1.2 END
 WHERE mincountOrRef < 0
   AND ChanceOrQuestChance > 0
   AND ChanceOrQuestChance < 0.5
   AND -mincountOrRef IN (50501, 50500, 50502, 50503, 50526, 50536, 50545, 50548, 50549,
                          50551, 50557, 50563, 36100, 50498, 50499);

-- ---------------------------------------------------------------------------
-- 校验（三条都应为 0 或符合预期）
-- ---------------------------------------------------------------------------
-- 1) A 组不应再有 <=0.1%
SELECT 'A: leftover epic rows <=0.1%' AS check_name, COUNT(*) AS should_be_zero
  FROM creature_loot_template
 WHERE mincountOrRef < 0 AND ChanceOrQuestChance > 0 AND ChanceOrQuestChance <= 0.1
   AND (-mincountOrRef BETWEEN 60300 AND 60399 OR -mincountOrRef IN (41301, 30012));

-- 2) B 组不应再有 <0.5%
SELECT 'B: leftover recipe rows <0.5%' AS check_name, COUNT(*) AS should_be_zero
  FROM creature_loot_template
 WHERE mincountOrRef < 0 AND ChanceOrQuestChance > 0 AND ChanceOrQuestChance < 0.5
   AND -mincountOrRef IN (50501, 50500, 50502, 50503, 50526, 50536, 50545, 50548, 50549,
                          50551, 50557, 50563, 36100, 50498, 50499);

-- 3) 改后效果抽样（每组：多少行、几率区间）
SELECT -mincountOrRef AS ref_group, COUNT(*) AS rows_after,
       ROUND(MIN(ChanceOrQuestChance),3) AS min_pct, ROUND(MAX(ChanceOrQuestChance),3) AS max_pct
  FROM creature_loot_template
 WHERE mincountOrRef < 0 AND -mincountOrRef IN (60345, 60300, 60327, 41301, 30012,
                                                50501, 50500, 50502, 50551, 36100)
 GROUP BY ref_group ORDER BY ref_group;
