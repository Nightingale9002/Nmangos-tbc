-- ============================================================================
-- 095_精华强弱效套利修复_强效价重定为次级3倍.sql（2026-09-19）
--
-- 站长诉求：强效<X>精华 与 次级<X>精华 之间存在套利空间，因为 1 强效 = 3 次级。
--           要求修改 ahbot 价格表，把两者的价格关系拉回 3:1。
--
-- 背景（套利是怎么来的）：
--   游戏自身的 BuyPrice 已经严格定义了这个汇率 —— 每一对都恰好是 3 倍：
--     次级魔法精华  800 / 强效魔法精华  2400
--     次级星界精华 3000 / 强效星界精华  9000
--     次级秘法精华10000 / 强效秘法精华 30000
--     次级虚空精华20000 / 强效虚空精华 60000
--     次级永恒精华40000 / 强效永恒精华120000
--     次级位面精华40000 / 强效位面精华120000
--   但 ahbot 的 price_ref（价格发现出来的报价）把【强效】压得远低于 3 倍【次级】
--   （云端 tbccharacters.ahbot_market_state 实测，2026-09-19）：
--     对    次级ref   3×次级   强效ref   强效/次级
--     魔法      299      897       478      1.60
--     星界      743     2229       675      0.91   ← 强效比 1 个次级还便宜
--     秘法     2437     7311      5007      2.05
--     虚空     6236    18708      7061      1.10
--     永恒     9511    28533      9855      1.01
--     位面    17659    52977     26575      1.50
--   → 1 强效 = 3 次级，于是只要「强效价 < 3 × 次级价」就能
--     「买强效 → 拆成 3 个次级 → 卖给 bot」白拿差价：
--     星界那一对几乎是无风险 3 倍收益，永恒/虚空也接近 3 倍。
--
-- 做法（沿用站长对材料的定案：走【价格发现】，不钉价）：
--   只把【强效】一侧的 price_ref 重定为「当前次级 price_ref × 3」。
--   * 不动次级 —— 它是这一对的锚，且 dev/084 已按分解期望定过。
--   * 不写 `price` 列钉价 —— dev/090 已定案：材料价应交给价格发现，
--     `price > 0` 的钉死是错误做法（会让市场无法把它抹平）。
--   * 3× 与游戏自身 BuyPrice 的 3:1 一致；且 staticPrice = BuyPrice × 物品价值%，
--     同一对品质/分类相同 → staticPrice 天然也是 3:1，所以不会被启动时的
--     [PriceFloor=5%, PriceCeil=300%] clamp 打歪。
--   * 3 × 次级全部是整数，无需取整。
--
-- 数值来源：云端 ahbot_market_state 实测（2026-09-19 20:5x）
--     次级 10938=299 10998=743 11134=2437 11174=6236 16202=9511 22447=17659
--   → 强效目标值 897 / 2229 / 7311 / 18708 / 28533 / 52977
--   ⚠️ 按 P0 写【写死值】：云端库只跑静态、幂等、秒级的写操作，不做计算/判断。
--
-- 幂等：按 item 绝对赋值，重复执行结果一致；WHERE 带 auction_house = 2（book 行）。
-- 回滚：UPDATE ahbot_market_state m
--         JOIN ahbot_market_state_bak_20260919_essence b
--           ON b.item = m.item AND b.auction_house = m.auction_house
--         SET m.price_ref = b.price_ref;
-- 生效方式：price_ref 由 AuctionHouseBot 在 mangosd 启动时载入
--           → 应用后需重启 mangosd 才生效（随夜间重启）。
-- ============================================================================

USE tbccharacters;

-- 备份改前值（首次执行时创建；已存在则不动）
CREATE TABLE IF NOT EXISTS ahbot_market_state_bak_20260919_essence AS
SELECT item, auction_house, price_ref FROM ahbot_market_state
 WHERE item IN (10939,11082,11135,11175,16203,22446);

-- 强效魔法精华 / 强效星界精华 / 强效秘法精华 / 强效虚空精华 / 强效永恒精华 / 强效位面精华
UPDATE ahbot_market_state SET price_ref =   897 WHERE auction_house = 2 AND item = 10939;
UPDATE ahbot_market_state SET price_ref =  2229 WHERE auction_house = 2 AND item = 11082;
UPDATE ahbot_market_state SET price_ref =  7311 WHERE auction_house = 2 AND item = 11135;
UPDATE ahbot_market_state SET price_ref = 18708 WHERE auction_house = 2 AND item = 11175;
UPDATE ahbot_market_state SET price_ref = 28533 WHERE auction_house = 2 AND item = 16203;
UPDATE ahbot_market_state SET price_ref = 52977 WHERE auction_house = 2 AND item = 22446;

-- ---------------------------------------------------------------------------
-- 校验 1：强弱配对必须恰好 3:1（每对一行，ratio 必须 = 3.00）
-- ---------------------------------------------------------------------------
SELECT g.item AS greater_id, g.price_ref AS greater_ref,
       l.item AS lesser_id,  l.price_ref AS lesser_ref,
       ROUND(g.price_ref / l.price_ref, 2) AS ratio,
       ROUND(g.price_ref / 10000, 2) AS greater_gold
  FROM ahbot_market_state g
  JOIN ahbot_market_state l
    ON l.item = CASE g.item
                  WHEN 10939 THEN 10938 WHEN 11082 THEN 10998
                  WHEN 11135 THEN 11134 WHEN 11175 THEN 11174
                  WHEN 16203 THEN 16202 WHEN 22446 THEN 22447
                END
 WHERE g.auction_house = 2 AND l.auction_house = 2
 ORDER BY l.item;

-- ---------------------------------------------------------------------------
-- 校验 2：不应再有「强效价 < 3 × 次级价」的配对（期望返回 0 行）
-- ---------------------------------------------------------------------------
SELECT g.item AS greater_id, l.item AS lesser_id,
       g.price_ref AS greater_ref, l.price_ref * 3 AS need_ref
  FROM ahbot_market_state g
  JOIN ahbot_market_state l
    ON l.item = CASE g.item
                  WHEN 10939 THEN 10938 WHEN 11082 THEN 10998
                  WHEN 11135 THEN 11134 WHEN 11175 THEN 11174
                  WHEN 16203 THEN 16202 WHEN 22446 THEN 22447
                END
 WHERE g.auction_house = 2 AND l.auction_house = 2
   AND g.price_ref < l.price_ref * 3;
