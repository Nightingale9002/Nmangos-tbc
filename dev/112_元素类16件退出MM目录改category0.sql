-- dev/112 元素类（class 7 / subclass 10）16 件退出 MM 目录：category 1 → 0
-- ===============================================================
-- 站长 2026-09-24 指示：元素类里除了「源生」「微粒」之外的那 16 件**不该**由市场商人目录
-- （category=1）定价挂牌，应该是 **category = 0（untouched，不管理）**。
--
-- 涉及 16 件（本库/云端都在 category=1）：
--   7067 元素之土     7068 元素火焰     7069 元素空气     7070 元素之水
--   7075 大地之核     7076 大地精华     7077 火焰之心     7078 火焰精华
--   7079 纯水之球     7080 水之精华     7081 风之气息     7082 空气精华
--   7972 亡灵腐液     10286 野性之心    12803 生命精华    12808 死灵精华
-- （保留在 category=1 的是：源生 7 件 + 微粒 7 件 = 14 件；源生之能 23571 仍是 category=3 封禁）
--
-- 语义（`src/game/AuctionHouseBot/AuctionHouseBot.cpp`）：
--   * category = 0 / 无行 ⇒ **不**属于 MM 书目：MM 不再为它定价、不再按曝光切片挂牌；
--   * 同时 `if (GetCatalogEntry(itemId).category != 0) continue;`（约 466 行）**只过滤 category≠0 的物品**，
--     所以改成 0 之后这些元素材料会**重新回到普通 loot 来源供给**（生物/采集/剥皮等，受 ahbot.conf
--     的 `Loot.*` 与 `Chance.Sell` 控制），与「MM 管理」路径互斥。
--
-- 幂等：UPDATE ... AND `category` = 1 ⇒ 重跑更新 0 行（已改过或本来就不是 1 的行不受影响）。
-- 生效：`ahbot_market_state` 由 AHBot 在启动时与 `.ahbot reload` 时读取 ⇒ 需重启或 .ahbot reload。
-- ===============================================================

UPDATE `tbccharacters`.`ahbot_market_state`
SET `category` = 0
WHERE `auction_house` = 2
  AND `category` = 1
  AND `item` IN (7067, 7068, 7069, 7070, 7075, 7076, 7077, 7078, 7079, 7080, 7081, 7082, 7972, 10286, 12803, 12808);
