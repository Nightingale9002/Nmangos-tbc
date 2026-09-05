-- [ahbot] 2026-09-05: 元素/布料/皮革/金属矿石/草药/附魔 可掉落材料 按品质设定上架组数
-- 白(quality1)=20组 绿(2)=10组 蓝(3)/紫(4)=5组
-- target = 组数 x 堆叠 x 4 (QuoteExposurePct=25% 下曝光=组数x堆叠), capacity=3x, qty=target
-- 幂等：可重复执行
USE tbccharacters;
UPDATE ahbot_market_state s
JOIN tbcmangos.item_template it ON it.entry = s.item
SET s.target = CASE it.Quality
        WHEN 2 THEN it.stackable * 40
        WHEN 3 THEN it.stackable * 20
        WHEN 4 THEN it.stackable * 20
        ELSE it.stackable * 80 END,
    s.capacity = s.target * 3,
    s.qty = s.target
WHERE s.enabled = 1 AND s.category = 1 AND s.auction_house = 2
  AND it.class = 7 AND it.stackable > 1
  AND it.subclass IN (10, 5, 6, 7, 9, 12)
  AND s.item IN (
      SELECT item FROM (
          SELECT item FROM tbcmangos.creature_loot_template
          UNION SELECT item FROM tbcmangos.gameobject_loot_template
          UNION SELECT item FROM tbcmangos.fishing_loot_template
          UNION SELECT item FROM tbcmangos.skinning_loot_template
          UNION SELECT item FROM tbcmangos.disenchant_loot_template
          UNION SELECT item FROM tbcmangos.item_loot_template
      ) lt
  );