-- 本地测试库对齐云端 AHBot 目录（只在本地执行；云端本来就是目标状态）
-- 生成时间：2026-09-24 01:0x
-- 依据：把本地 tbccharacters.ahbot_market_state(house 2) 与云端逐行对比后，**仅有**下面两处实质差异：
--   1) 7 件「源生」：本地是 category=3（封禁），云端是 category=1（MM 管理）  => 本地改回 1
--   2) 21840 灵纹布卷：本地是 category=3（封禁），云端**没有这一行**            => 本地删行（等同 category 0）
-- 另外 16 件经典元素材料已由 dev/112 改成 category=0（与云端 04:06 后的状态一致）。
--
-- ⚠️ 刻意**不**对齐的字段（这些是市场商人运行期自己改的，不是配置；对齐了也会立刻漂开）：
--   price / price_ref / target / qty / avg_cost / spent / earned / flow_bought / flow_sold / day_price / day_start / last_settle_time
--   （实测 price_ref 有 63 项、target 有 23 项与云端不同，全是运行期浮动/需求加成/闲置衰减造成的）
--
-- 幂等：UPDATE 带 category=3 条件；DELETE 带 item 条件 ⇒ 重跑 0 行变更。

UPDATE `tbccharacters`.`ahbot_market_state`
SET `category` = 1, `enabled` = 1
WHERE `auction_house` = 2 AND `category` = 3
  AND `item` IN (21884, 21885, 21886, 22451, 22452, 22456, 22457);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `item` = 21840;
