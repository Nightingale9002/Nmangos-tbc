-- ============================================================================
-- 096_虚空水晶价按新紫装价重定.sql（2026-09-19）
--
-- 背景：站长先把 AHBot 紫装价值从 25% 提到 50%（ahbot.conf：
--   `AuctionHouseBot.Value.Epic = 0,0,50,0,50,...` 武器 class2 + 护甲 class4 都 50），
--   使紫装（虚空水晶的分解来源）挂单价全线翻倍；随后要求按新紫装价重算虚空水晶。
--
-- ── 虚空水晶的产出关系（已核实）──
--   `disenchant_loot_template`：DE id **66/67**（ilvl 95+ 紫装）→ **22450 × 1~2 个，100%**
--   均值 **1.5 个/件**（DE id 65 出的是 20725 连结水晶，与本项无关）。
--   装备（非 book 物品）挂单价 = 静态价 ±5%（`ValueWithVariance`，`Value.Variance=5`），
--   即 **不会乱飘**，所以下限是可计算的。
--
-- ── 锚点选定（关键）──
--   候选来源里最便宜的几件其实**供不上**，不能当锚：
--     · 34029 Tiny Voodoo Mask 静态 1.80 金 —— 参考组 36152，仅 **1 只怪**引用
--     · 34837 The 2 Ring        静态 2.26 金 —— 参考组 10000、**0 只怪**引用；
--       且其商人 NPC 26300「Accessories Vendor」**无刷点**（幽灵商人）
--     · 21863 / 32655 / 34622 / 35693~35703（2.40~5.17 金）**完全没有掉落来源**
--   真正被稳定供给的是 **参考组 60345（670 只怪引用）**，组内最便宜的是
--   31339 Lola's Eve（护甲，24.10 × 50% = **12.05 金**）与 31335 Pants（13.48 金）。
--
-- ── 计算 ──
--   P_min = 12.05 × 0.95（±5% 浮动的最低挂单）= **11.45 金**
--   沿用 dev/084 的 relax=1.5（允许最多 50% 分解利润）：1.5V ≤ 1.5 × P_min → **V ≤ P_min**
--   → 取 **V = 11.45 金**（114500 铜，正是 relax=1.5 的边界）
--   验算：分解期望 1.5 × 11.45 = **17.18 金** ÷ 最低挂单 11.45 = **1.50 倍（+50%）** ✓
--   （改前：V=14.29 → 期望 21.43 金 ÷ 6.09 = 3.52 倍 = +252%）
--
-- 幂等：绝对赋值。回滚：
--   UPDATE ahbot_market_state m JOIN ahbot_market_state_bak_20260919_crystal b
--     ON b.item = m.item AND b.auction_house = m.auction_house SET m.price_ref = b.price_ref;
-- 生效：`price_ref` 由 AuctionHouseBot 在 mangosd 启动时载入 → 随夜间重启生效。
-- ============================================================================

USE tbccharacters;

CREATE TABLE IF NOT EXISTS ahbot_market_state_bak_20260919_crystal AS
SELECT item, auction_house, price_ref FROM ahbot_market_state
 WHERE item = 22450;

UPDATE ahbot_market_state SET price_ref = 114500 WHERE auction_house = 2 AND item = 22450;

-- 校验
SELECT item, price_ref, ROUND(price_ref/10000,2) AS gold FROM ahbot_market_state WHERE item = 22450;

SELECT ROUND(price_ref/10000 * 1.5, 2) AS disenchant_EV_gold,
       ROUND(price_ref/10000 * 1.5 / 11.45, 2) AS ratio_vs_cheapest_source
  FROM ahbot_market_state WHERE item = 22450;
