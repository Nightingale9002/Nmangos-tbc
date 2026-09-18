-- ============================================================================
-- 087_掉落比例提升_能量枯竭+暗月卡牌+全紫装.sql（2026-09-19）
--
-- 合并三件事（原 087/088/089 三份文件，站长要求写到同一个 SQL）：
--   A. 能量枯竭系列（Depleted Items）小怪外层掉率
--   B. 暗月卡牌（Darkmoon cards）
--   C. 全部「全紫装」参考组
--
-- 站长定案：
--   * 判据是「AHBot 供得上还是供不上」，不是单看掉率高低；
--   * 装备总体不动（AHBot 有货），但【紫装】例外 —— 含站长点名的 60346；
--   * 不改 ahbot 规则（ahbot.conf / 货架表都不动），只调掉落。
--
-- 判据实测（云端生产库 / 角色库）：
--   bot 挂牌按品质：q1 44,744 条（498 种）、q2 80,847 条（3,468 种）、
--                   q3 10,099 条（393 种）、q4 1,818 条但只有 **2 种物品**
--   → 蓝绿稀有装备 AHBot 供得上（不动）；紫装 AHBot 基本供不上 → 用掉落补（C 组）。
--   卡牌属结构性上不了架（B 组），见下。
--
-- 改动方式：**一律写死目标值**（不写「每次都乘一下」的运算），目标 = 原值 × 5。
--   ×5 的口径来自 081 A 组最后一级：(0.01%, 0.1%] → 0.5%，即 ×5。
--
-- 幂等：每条 UPDATE 的 WHERE 只匹配【原值】，目标值都不在匹配集合里 → 重跑 0 行，不叠加。
--   （旧写法 `SET chance = chance*5 WHERE chance <= 1` 有幂等陷阱：0.1→0.5 仍在 <=1 内，
--     第二次执行会再乘一次，本地实测 0.1 连跑两次变 2.5 —— 故改为写死。）
--
-- 【重要·踩坑记录】ChanceOrQuestChance 是 FLOAT：0.1 存为 0.100000001490116，
--   与字面量 0.1（DOUBLE）比较判为「大于」→ 写 `= 0.1` / `<= 0.1` 会静默漏行。
--   081 的 A 组就吃了这个亏（60345 名单内的 22 行 0.1 一行没抬）。本文件统一 ROUND(x,4) 后比较。
--
-- 生效方式：掉落表在 mangosd 启动时载入 → 应用后需重启（随夜间重启）。
-- ============================================================================

USE tbcmangos;

-- ===========================================================================
-- A. 能量枯竭系列（参考组 41301 = Blade's Edge Mountains - Depleted Items）
--    21 只小怪外层 0.25% → 1.25%（单件 0.025% → 0.125%，1/4000 → 1/800）
--    12 只精英的 20% 不动，事件 boss 沙图尔 23230 组内 8% 不动
--    背景：081 名单里点了 41301，但阈值 <=0.1% 与 0.25/20 不匹配 → 一行没命中
-- ===========================================================================
UPDATE creature_loot_template
   SET ChanceOrQuestChance = 1.25
 WHERE mincountOrRef = -41301
   AND ROUND(ChanceOrQuestChance, 4) = 0.25;

-- ===========================================================================
-- B. 暗月卡牌（参考组 49001 / 49002 / 49003 / 49004）
--    外层 0.05 → 0.25、0.1 → 0.5（单张卡 1/12,000~1/16,000 → 1/2,400~1/3,200）
--    为什么不能指望 AHBot：ahbot.conf 的 Value.Rare 第 13 个值（class 12 = 任务物品）为 0，
--    对应 AuctionHouseBot.cpp:441 `GetItemValue(proto) == 0 -> continue` → 卡牌永远不上架；
--    （class 12 仅 Normal 品质开启；能量枯竭系列 class 15 品质 3 同理）
--    即便打开该值，bot 货源是「模拟打怪掉落」，1/12,000 级命中在每周期几百次掷骰里也不会出现。
--    TBC 四张大乙在组 49000（挂在 1~2% 的精英/boss 上），经典四大乙是直接掉落（2~15%），均不动。
-- ===========================================================================
UPDATE creature_loot_template
   SET ChanceOrQuestChance = CASE ROUND(ChanceOrQuestChance, 4)
                               WHEN 0.05 THEN 0.25
                               WHEN 0.1  THEN 0.5
                               ELSE ChanceOrQuestChance
                             END
 WHERE mincountOrRef < 0
   AND -mincountOrRef IN (49001, 49002, 49003, 49004)
   AND ROUND(ChanceOrQuestChance, 4) IN (0.05, 0.1);

-- ===========================================================================
-- C. 全部「全紫装」参考组（组内物品品质全为 4）中外层几率 <= 1% 的行
--    实测（云端）：53 个组 / 2,386 行（603xx 47 组 2,304 行，含 60346；36xxx 6 组 82 行）
--    原值分布：0.1×22、0.15×259、0.212×1、0.25×1,983、0.45×1、0.5×1、
--              0.532×1、0.779×1、0.788×1、0.8×39、1×77
--    写死的映射：0.1→0.5、0.15→0.75、0.212→1.06、0.25→1.25、0.45→2.25、
--                0.532→2.66、0.779→3.895、0.788→3.94、0.8→4、1→5
--    注意 0.5 只出现在目标列、不在原值列：原本就恰好 0.5% 的行（云端 1 行）保持不动。
--    明确不动：30012（经典蓝装）、600xx–602xx / 61xxx 世界掉落蓝绿（AHBot 有货）、
--              6044x 背包（bot 每种 28~161 条）、506xx 卷轴（商店货）
-- ===========================================================================
UPDATE creature_loot_template
   SET ChanceOrQuestChance = CASE ROUND(ChanceOrQuestChance, 4)
                               WHEN 0.1   THEN 0.5
                               WHEN 0.15  THEN 0.75
                               WHEN 0.212 THEN 1.06
                               WHEN 0.25  THEN 1.25
                               WHEN 0.45  THEN 2.25
                               WHEN 0.532 THEN 2.66
                               WHEN 0.779 THEN 3.895
                               WHEN 0.788 THEN 3.94
                               WHEN 0.8   THEN 4
                               WHEN 1     THEN 5
                               ELSE ChanceOrQuestChance
                             END
 WHERE mincountOrRef < 0
   AND ROUND(ChanceOrQuestChance, 4) IN (0.1, 0.15, 0.212, 0.25, 0.45, 0.532, 0.779, 0.788, 0.8, 1)
   AND -mincountOrRef IN (
         SELECT ref_id FROM (
           SELECT r.entry AS ref_id
             FROM reference_loot_template r
             JOIN item_template i ON i.entry = r.item
            GROUP BY r.entry
           HAVING MIN(i.Quality) = 4
         ) epic_refs
       );

-- ===========================================================================
-- 校验
-- ===========================================================================
SELECT 'A: 41301 rows at 1.25 (expect 21)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template
 WHERE mincountOrRef = -41301 AND ROUND(ChanceOrQuestChance, 4) = 1.25;

SELECT 'A: 41301 rows at 20 untouched (expect 12)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template
 WHERE mincountOrRef = -41301 AND ROUND(ChanceOrQuestChance, 4) = 20;

SELECT 'B: cards at 0.25 (expect 30)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template
 WHERE mincountOrRef < 0 AND -mincountOrRef IN (49001,49002,49003,49004) AND ROUND(ChanceOrQuestChance,4) = 0.25;

SELECT 'B: cards at 0.5 (expect 1869)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template
 WHERE mincountOrRef < 0 AND -mincountOrRef IN (49001,49002,49003,49004) AND ROUND(ChanceOrQuestChance,4) = 0.5;

SELECT 'C: leftover source rows in epic groups (expect 0)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template c
 WHERE c.mincountOrRef < 0
   AND ROUND(c.ChanceOrQuestChance, 4) IN (0.1, 0.15, 0.212, 0.25, 0.45, 0.532, 0.779, 0.788, 0.8, 1)
   AND -c.mincountOrRef IN (SELECT r.entry FROM reference_loot_template r
                              JOIN item_template i ON i.entry = r.item
                             GROUP BY r.entry HAVING MIN(i.Quality) = 4);

SELECT 'C: epic rows at 1.25 (expect 1983)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template c
 WHERE c.mincountOrRef < 0 AND ROUND(c.ChanceOrQuestChance, 4) = 1.25
   AND -c.mincountOrRef IN (SELECT r.entry FROM reference_loot_template r
                              JOIN item_template i ON i.entry = r.item
                             GROUP BY r.entry HAVING MIN(i.Quality) = 4);

SELECT 'C: 60346 rows raised (expect 40: 1@2.25 / 39@4)' AS check_name, COUNT(*) AS n
  FROM creature_loot_template WHERE mincountOrRef = -60346 AND ROUND(ChanceOrQuestChance, 4) IN (2.25, 4);
