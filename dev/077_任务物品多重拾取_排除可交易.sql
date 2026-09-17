USE tbcmangos;
-- 077_任务物品多重拾取_排除可交易.sql（2026-09-17）
--
-- 背景：`dev/035_任务物品每人一份_MULTI_DROP.sql` 给**所有** class=12（任务物品）加了
--       `ITEM_FLAG_MULTI_DROP`(0x800 = 2048) → 队伍里每个有任务的人都能拾取自己的一份。
--       但那一刀切**没有排除"可交易"的任务物品**（`bonding = 0`，无绑定，可以送人/卖店/邮寄），
--       于是这些物品变成了"每人一份"，等于凭空多刷 —— 典型例子：
--         · 荆棘谷的青山 第 1~27 页（SellPrice 375 铜，可交易）
--         · Rethban Ore / Okra / Hops / Captain Sander's Treasure Map 等采集类任务物品
--       本文件把 `bonding = 0`（可交易）的 class=12 物品的 MULTI_DROP 去掉，恢复"一次一份、队内自行交易"的原版行为。
--
-- 剔除范围（云端实测）：
--   class=12 共 3,865 个，全部带 MULTI_DROP；其中 `bonding = 0` **542 个**（全是可交易的）。
--   这 542 个里有 **11 个是上游原版就带 MULTI_DROP 的**（E'ko 系列 12430-12436、能量水晶 11184-11188），
--   那是暴雪的刻意设计（每个采集者各得一份、卖价 0 无法变现）→ **保留，不动原版早有的一切**。
--   → 本文件只删**我们 035 那刀一刀切多加的 531 个**（云端；本地 529 个，两库条目数略有差异属正常）。
--   换句话说：**排除列表 = 上游原版本来就带 MULTI_DROP 的全部可交易任务物品（实测恰好这 11 个）**，
--   所以这条 UPDATE 等价于"只回滚我们多加的，不碰原版原有的"。
--   其余 `bonding = 1`（拾取绑定，576 个）与 `bonding = 4`（任务物品，2747 个）**不可交易，保持每人一份**。
--
-- 幂等：带目标值判断，可重复执行。回滚：`UPDATE item_template SET Flags = Flags | 2048 WHERE ...`（同条件）。
-- 生效：改 item_template 后需**重启 mangosd**（item proto 内存缓存）。

-- 去掉"可交易任务物品"的 MULTI_DROP（保留上游 E'ko / 能量水晶这 11 个）
UPDATE item_template
   SET Flags = Flags & ~2048
 WHERE class = 12
   AND bonding = 0
   AND entry NOT IN (11184, 11185, 11186, 11188, 12430, 12431, 12432, 12433, 12434, 12435, 12436)
   AND (Flags & 2048) <> 0;

-- 校验一：可交易(class12,bonding=0)里，应该只剩上游那 11 个还带 MULTI_DROP
SELECT COUNT(*) AS tradeable_still_multidrop
  FROM item_template
 WHERE class = 12 AND bonding = 0 AND (Flags & 2048) <> 0;

-- 校验二：不可交易的两档应保持 100% 带 MULTI_DROP（拾取绑定 576 / 任务物品 2747）
SELECT bonding, COUNT(*) AS total, SUM((Flags & 2048) <> 0) AS with_multidrop
  FROM item_template WHERE class = 12 AND bonding IN (1, 4) GROUP BY bonding ORDER BY bonding;

-- 校验三：抽样看几个典型的"可交易任务物品"已恢复（应全部为 with_md = 0）
SELECT entry, name, bonding, (Flags & 2048) <> 0 AS with_md
  FROM item_template
 WHERE entry IN (2725, 2728, 2798, 732, 1274, 1357)
 ORDER BY entry;
