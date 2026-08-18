-- ============================================================
-- 任务物品 maxcount 补齐（最终版）
-- 目标：限制任务物品持有量不超过任务所需数量，防止拾取超量
-- 范围：flags&2048(任务物品) AND maxcount=0(未限制)
--      AND 被 ReqItemId 引用(确需收集交给任务的需求物品)
-- 排除：46个未引用任务物品(货币/交易品等) + 4个环形山水晶(11184/11185/11186/11188)
-- 经核对：198个被引用任务物品中无货币/高价值交易品误伤
-- ============================================================

-- [1] 预览：将修改的物品及新maxcount（执行前查）
SELECT it.entry AS item, it.name,
       it.maxcount AS old_maxcount,
       MAX(req.cnt) AS new_maxcount
FROM tbcmangos.item_template it
JOIN (
    SELECT ReqItemId1 AS item, ReqItemCount1 AS cnt FROM tbcmangos.quest_template WHERE ReqItemId1 != 0
    UNION ALL SELECT ReqItemId2, ReqItemCount2 FROM tbcmangos.quest_template WHERE ReqItemId2 != 0
    UNION ALL SELECT ReqItemId3, ReqItemCount3 FROM tbcmangos.quest_template WHERE ReqItemId3 != 0
    UNION ALL SELECT ReqItemId4, ReqItemCount4 FROM tbcmangos.quest_template WHERE ReqItemId4 != 0
) req ON req.item = it.entry
WHERE it.flags & 2048 AND it.maxcount = 0
  AND it.entry NOT IN (11184,11185,11186,11188)
GROUP BY it.entry
ORDER BY new_maxcount DESC, it.entry;

-- [2] 实际更新（幂等：只更新 maxcount=0 的）
UPDATE tbcmangos.item_template it
JOIN (
    SELECT item, MAX(cnt) AS maxcnt FROM (
        SELECT ReqItemId1 AS item, ReqItemCount1 AS cnt FROM tbcmangos.quest_template WHERE ReqItemId1 != 0
        UNION ALL SELECT ReqItemId2, ReqItemCount2 FROM tbcmangos.quest_template WHERE ReqItemId2 != 0
        UNION ALL SELECT ReqItemId3, ReqItemCount3 FROM tbcmangos.quest_template WHERE ReqItemId3 != 0
        UNION ALL SELECT ReqItemId4, ReqItemCount4 FROM tbcmangos.quest_template WHERE ReqItemId4 != 0
    ) t GROUP BY item
) req ON req.item = it.entry
SET it.maxcount = req.maxcnt
WHERE it.flags & 2048
  AND it.maxcount = 0
  AND it.entry NOT IN (11184,11185,11186,11188);

-- [3] 验证：应无剩余被ReqItem引用且未限量的任务物品
SELECT CONCAT('剩余未限制的被ReqItem引用任务物品: ',
  (SELECT COUNT(DISTINCT it.entry)
   FROM tbcmangos.item_template it
   WHERE it.flags&2048 AND it.maxcount=0
     AND it.entry NOT IN (11184,11185,11186,11188)
     AND EXISTS (SELECT 1 FROM tbcmangos.quest_template qt 
                 WHERE qt.ReqItemId1=it.entry OR qt.ReqItemId2=it.entry OR qt.ReqItemId3=it.entry OR qt.ReqItemId4=it.entry))) AS remaining;
