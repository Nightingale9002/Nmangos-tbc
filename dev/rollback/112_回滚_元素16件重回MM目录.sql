-- dev/rollback/112 回滚：元素类 16 件重新回到 MM 目录（category 0 → 1）
-- 用途：`dev/112` 若需要撤销，用本文件把这 16 件改回 category = 1。
-- 幂等：UPDATE ... AND `category` = 0 ⇒ 重跑更新 0 行。

UPDATE `tbccharacters`.`ahbot_market_state`
SET `category` = 1
WHERE `auction_house` = 2
  AND `category` = 0
  AND `item` IN (7067, 7068, 7069, 7070, 7075, 7076, 7077, 7078, 7079, 7080, 7081, 7082, 7972, 10286, 12803, 12808);
