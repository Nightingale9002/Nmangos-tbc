-- =====================================================================================
-- 132_ahbot去掉曝光与库存上限_按target补满.sql
-- 日期：2026-09-26        适用库：tbccharacters（AHBot 的 operator 表）+ 只读 tbcmangos
-- 类型：静态 / 幂等（可重复执行）
-- -------------------------------------------------------------------------------------
-- 【背景】站长指示：「之前设置的曝光量和库存管理已经没用了，清理这部分代码，按照上一版
-- 定的方案做」。上一版方案 = 本地 KNOWN_ISSUES 里 bdcfaff3c（2026-09-25「修改ahbot」）
-- 记下的 AH 改造待办第 1 条原文：
--     「所有 cat1 商品一次固定挂 10 组、每周期补满（替换现有 target=1600 / capacity=4800
--       这类过大数值；target/capacity 是**单位数**，挂单按 ceil(units / GetMaxStackSize())
--       拆组）」
-- 该 commit 的三条待办里，①成对/共同定价（虚拟基准价 ahbot_virtual_price + 价格对
-- ahbot_price_pair + 复合锭配方 ahbot_price_recipe）与 ②价格发现参数化（MoveBpPerStack /
-- MaxHourlyMoveBp / MaxDailyMovePct 三级）已在后续提交落地；**只有 ③（清理曝光量与库存
-- 管理这套老机制）一直挂着没做**，而 2026-09-26 cat1/cat2「一本都不上架」正是它造成的。
--
-- 【旧口径的两个坑（2026-09-26 定位）】
--   ① 上架量 = target × QuoteExposurePct(25%) —— 只看"曝光切片"，不是把货架补满；
--   ② 切片值再经"整栈取整"（每档 tierUnits 向下取整到 maxStack 的整数倍）后归零：
--      target=200、maxStack=20 ⇒ exposure=50 ⇒ 整栈 2 组 40 单位 ⇒ tier0 拿 40% = 16 单位
--      ⇒ 16/20 取整 = 0 组 ⇒ 每一档都是 0 ⇒ 该商品一个单都不挂。
--   叠加结果：云端 cat1=0 组、cat2=0 组，而正常 loot 流程（category 0）的 98 件照常上架。
--
-- 【新口径（本站定案）】
--   代码侧（已改，见 src/game/AuctionHouseBot/AuctionHouseBot.cpp QuoteCatalog）：
--     每周期遍历**真实货架**统计"我们自己的挂单单位数"，不足 target 就补满到 target；
--     内存快照（tierStock/probeStock/GetBookedUnits）、曝光切片（QuoteExposurePct）、
--     分批轮转（ListBatch）、库存上限（CatalogCapacity）、需求加码、闲置衰减、玩家深度
--     调节、过渡商品倍率全部删除。target 只由 operator 行决定（行里为 0 时用 conf 的
--     CatalogTarget 兜底），机器人运行期不再自行缩放额度。
--     阶梯定价 / 探针单 / 吃掉检测 / 成对与虚拟价结算照旧（tierStock 只作为价格发现的
--     观察量）。
--   数据侧（本文件）：
--     - cat1（材料，可堆叠）：target = 10 组 = 10 × maxStack。**核对结果：库里本来就是
--       100（堆叠 10 × 20 件）与 200（堆叠 20 × 110 件），无需改动**，这里仍写成显式
--       UPDATE 以便在别的环境（云端/新建库）自愈；
--     - cat2（固定商人价的书架，不可堆叠 stackable=1）：旧口径 exposure = 4 × 25% = 1 件
--       ⇒ 新口径 target = 1 件，**与今天可见的挂单量完全一致**（每件配方 1 张单）。
--       若站长想让固定价书架一次摆 4 张，把下面 cat2 的 1 改成 4 即可（务必在 .ahbot
--       reload 之前改）。
--     - 删除已废弃列 capacity（代码已不再读写；qty 早在 2026-09-25 已删）。
--
-- 【生效方式】capacity 列删除只需 DB；target 由 AHBot 启动时载入 ⇒ 需重启，或站长在游
--             戏内/控制台执行 `.ahbot reload`（会重读 operator 行与定价定义表）。
-- 【验证】
--   SELECT category, COUNT(*) FROM tbccharacters.ahbot_market_state
--    WHERE auction_house=2 AND enabled=1 AND category IN (1,2) GROUP BY category;  -- 1->130, 2->292
--   SHOW COLUMNS FROM tbccharacters.ahbot_market_state LIKE 'capacity';            -- 空
--   重启后看日志：[MMQUOTE] house=7 book=422 quoted=... units=...（每周期一条）
--   再查 AH：cat1 材料应有矿石/锭/附魔材料等，且每件 ≈10 组（= maxStack × 10 单位）
-- 【回滚】dev/rollback/132_回滚_恢复库存上限列与挂单量.sql
-- =====================================================================================

-- ---------- 0) 备份（幂等：只建一次，保留改造前的 quantity 定义） ----------
CREATE TABLE IF NOT EXISTS `tbccharacters`.`ahbot_market_state_bak_20260926_cap` AS
SELECT item, auction_house, target, capacity FROM `tbccharacters`.`ahbot_market_state`;

-- ---------- 1) cat1：target = 10 组 = 10 × maxStack ----------
-- 堆叠 20（矿石/锭/石头/布/皮等 110 件）⇒ 200 单位 = 10 组
UPDATE `tbccharacters`.`ahbot_market_state`
   SET `target` = 200
 WHERE `auction_house` = 2 AND `category` = 1 AND `enabled` = 1
   AND `item` IN (765,785,2318,2319,2447,2449,2450,2452,2453,2589,2592,2770,2771,2772,2775,2776,2835,2836,2838,2840,2841,2842,3356,3357,3358,3575,3576,3577,3818,3819,3820,3821,3858,3859,3860,4234,4304,4306,4338,4625,6037,7911,7912,8153,8170,8831,8836,8838,8839,8845,8846,10620,10940,10978,11083,11084,11137,11138,11139,11176,11177,11178,12359,12365,13463,13464,13465,13466,13467,13468,14047,14343,14344,16204,20725,21877,21884,21885,21886,21887,22445,22448,22449,22450,22451,22452,22456,22457,22710,22785,22786,22787,22788,22789,22790,22791,22792,22793,22794,22797,23424,23425,23426,23427,23445,23446,23447,23448,23449,23573)
   AND `target` <> 200;

-- 堆叠 10（强效/次级精华等 20 件）⇒ 100 单位 = 10 组
UPDATE `tbccharacters`.`ahbot_market_state`
   SET `target` = 100
 WHERE `auction_house` = 2 AND `category` = 1 AND `enabled` = 1
   AND `item` IN (3857,10938,10939,10998,11082,11134,11135,11174,11175,16202,16203,22446,22447,22572,22573,22574,22575,22576,22577,22578)
   AND `target` <> 100;

-- ---------- 2) cat2：固定商人价书架，不可堆叠 ⇒ 1 件（= 旧口径 exposure 4×25% 的可见量） ----------
UPDATE `tbccharacters`.`ahbot_market_state`
   SET `target` = 1
 WHERE `auction_house` = 2 AND `category` = 2 AND `enabled` = 1
   AND `target` <> 1;

-- ---------- 3) 删除废弃列 capacity（幂等：列不存在时什么也不做） ----------
SET @has_capacity := (SELECT COUNT(*) FROM information_schema.COLUMNS
                       WHERE TABLE_SCHEMA = 'tbccharacters'
                         AND TABLE_NAME = 'ahbot_market_state'
                         AND COLUMN_NAME = 'capacity');
SET @stmt := IF(@has_capacity > 0,
                'ALTER TABLE `tbccharacters`.`ahbot_market_state` DROP COLUMN `capacity`',
                'DO 0');
PREPARE s FROM @stmt;
EXECUTE s;
DEALLOCATE PREPARE s;

-- ---------- 4) 核对 ----------
-- 期望：category 1 -> 130 行，category 2 -> 292 行；target 只有 200 / 100 / 1 三种值
SELECT category, target, COUNT(*) AS rows_cnt
  FROM `tbccharacters`.`ahbot_market_state`
 WHERE auction_house = 2 AND enabled = 1 AND category IN (1,2)
 GROUP BY category, target ORDER BY category, target;

-- 期望：空（capacity 已删除）
SELECT COLUMN_NAME FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'tbccharacters' AND TABLE_NAME = 'ahbot_market_state'
   AND COLUMN_NAME IN ('capacity','qty');
