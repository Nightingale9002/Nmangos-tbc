-- ============================================================================
-- 090_ahbot去掉材料钉价_交回价格发现.sql（2026-09-19）
--
-- 站长定案：ahbot_market_state 里 `price > 0` 的"操作员钉价"是错误做法，
--           材料价格应当依赖【价格发现】。
--
-- 背景（云端实测）：125 条 book 行里只有 2 行是钉死的，其余 123 行 price=0、已走发现：
--   22449 大块棱光碎片  price = 108000（10.80 金）
--   22450 虚空水晶      price = 250000（25.00 金）
--   而这两件恰好是紫装拆解的主要产物 → 钉死会让"开放紫装上架"的套利窗口无法被市场抹平。
--
-- 代码语义（AuctionHouseBot.cpp）：
--   * 273 行：启动时 `SELECT item, price_ref AS price ... WHERE price_ref > 0` 载入上次收盘价当锚；
--   * 750 行：`op.enabled && op.category == 1 && op.price > 0` → state.price = op.price 并 continue，
--             **跳过全部发现逻辑**（流量结算 / 中位价 / 漂移），且每轮把 op.price 写回 price_ref。
--   * 因此：真正"钉死"的是 `price` 列，不是 price_ref；price_ref 是 bot 自己持久化的报价，
--     对 price = 0 的行会被 clamp 进 [floor, ceil] 后交给发现（±10%/日限额、6h 结算）。
--   * 对 staticPrice 为 0 的物品（如碎片/水晶，无买卖店价），clamp 的 lo/hi 都是 0 →
--     持久化的锚价原样保留（302/304 行的 `if (lo && ...)` / `if (hi && ...)`），不会被打成 0。
--
-- 本文件做法：只把这两行的 `price` 清 0（**不删行**）。
--   为什么不能删行：删行后物品退出 book（category 0）→ 落到老路径，而 class 7 品质 3/4
--   在 Value 矩阵里取值 0（`GetItemValue()==0 -> continue`）→ bot 会彻底不上架这两种材料，
--   连 MM 阶梯都没了，等于把碎片/水晶的市场整个关掉。
--
-- 与 dev/084 的关系：084 只改 price_ref（锚价）。对 123 行有效；对本文件这两行，
--   084 现在也能**真正生效**了（因为 price 已清 0，不会再被覆盖回去）。
--   建议执行顺序：084（调锚价）→ 090（去钉价）。夜间 apply_dev_sql 按编号升序执行 ✓。
--
-- 幂等：price 已为 0 时重跑无副作用（WHERE price > 0 限定）。
--
-- 生效方式：book 目录在启动时载入 → 应用后需重启（随夜间重启）。
-- ============================================================================

USE tbccharacters;

UPDATE ahbot_market_state
   SET price = 0
 WHERE category = 1
   AND price > 0
   AND item IN (22449, 22450);

-- ---------------------------------------------------------------------------
-- 校验
-- ---------------------------------------------------------------------------
SELECT 'leftover pinned rows (expect 0)' AS check_name, COUNT(*) AS n
  FROM ahbot_market_state WHERE category = 1 AND price > 0;

SELECT item, category, enabled, price, price_ref, ROUND(price_ref / 10000, 2) AS price_ref_gold, target, capacity
  FROM ahbot_market_state WHERE item IN (22449, 22450) ORDER BY item;
