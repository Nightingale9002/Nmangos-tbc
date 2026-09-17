USE tbcmangos;
-- 072_翻译修正_侵占者古罗克.sql（2026-09-17）
--
-- 问题（站长报告）：纳格兰任务链「元素王座」里，同一只怪在**任务文本**和**生物/物品名**里译名不一致 ——
--   生物/物品（正确）：locales_creature 18182「侵占者古罗克」、18181「古罗克的爪牙」、18208「古罗克事件控制者」、
--                     locales_item 24503「古罗克的徽记」
--   任务文本（错误）：9849 / 9853 里写成了「戈隆克」✗ → 玩家看到"杀死侵占者戈隆克，把戈隆克的头颅/徽记交回"，
--                     与任务物品名（古罗克）对不上。
--
-- 官方译名的依据：本条链的 NPC/物品名来自客户端 zhCN 数据（古罗克 Gurok the Usurper），故以「古罗克」为准。
--
-- 写法：用 REPLACE() 只对这两个任务条目做替换，**限定 entry**，不触碰其它任何行（即使以后别处出现"戈隆克"也不受影响）。
-- 幂等：重复执行无副作用（已替换过则不再匹配）。
-- 生效：locales 在服务端启动时载入 → 需重启 mangosd（随 nightly）。

UPDATE locales_quest
   SET Title_loc4            = REPLACE(Title_loc4,            '戈隆克', '古罗克'),
       Details_loc4          = REPLACE(Details_loc4,          '戈隆克', '古罗克'),
       Objectives_loc4       = REPLACE(Objectives_loc4,       '戈隆克', '古罗克'),
       OfferRewardText_loc4  = REPLACE(OfferRewardText_loc4,  '戈隆克', '古罗克'),
       RequestItemsText_loc4 = REPLACE(RequestItemsText_loc4, '戈隆克', '古罗克'),
       EndText_loc4          = REPLACE(EndText_loc4,          '戈隆克', '古罗克')
 WHERE entry IN (9849, 9853)
   AND (Title_loc4 LIKE '%戈隆克%' OR Details_loc4 LIKE '%戈隆克%' OR Objectives_loc4 LIKE '%戈隆克%'
        OR OfferRewardText_loc4 LIKE '%戈隆克%' OR RequestItemsText_loc4 LIKE '%戈隆克%' OR EndText_loc4 LIKE '%戈隆克%');

-- 校验（应返回 0 行）
SELECT entry, Title_loc4, Objectives_loc4
  FROM locales_quest
 WHERE entry IN (9849, 9853)
   AND (Title_loc4 LIKE '%戈隆克%' OR Objectives_loc4 LIKE '%戈隆克%'
        OR Details_loc4 LIKE '%戈隆克%' OR OfferRewardText_loc4 LIKE '%戈隆克%'
        OR RequestItemsText_loc4 LIKE '%戈隆克%');
