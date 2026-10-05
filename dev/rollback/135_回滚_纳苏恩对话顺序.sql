-- =====================================================================================
-- 135_回滚_纳苏恩对话顺序.sql
-- 对应：dev/135_纳苏恩对话顺序_修正.sql
-- 日期：2026-09-29        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 把 menu 9046 的 id=1/2 换回去（幂等守卫：只有 id=1 已是"修好"的条件 10306 时才换回）。
-- =====================================================================================

SET @need_swap := (SELECT COUNT(*) FROM `tbcmangos`.`gossip_menu_option`
                    WHERE `menu_id` = 9046 AND `id` = 1 AND `condition_id` = 10306);

SET @r1 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 99 WHERE `menu_id` = 9046 AND `id` = 1', 'DO 0');
PREPARE r1 FROM @r1; EXECUTE r1; DEALLOCATE PREPARE r1;

SET @r2 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 1 WHERE `menu_id` = 9046 AND `id` = 2', 'DO 0');
PREPARE r2 FROM @r2; EXECUTE r2; DEALLOCATE PREPARE r2;

SET @r3 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 2 WHERE `menu_id` = 9046 AND `id` = 99', 'DO 0');
PREPARE r3 FROM @r3; EXECUTE r3; DEALLOCATE PREPARE r3;

-- 核对：期望 1→10308、2→10306（回到原状）
SELECT `id`, `condition_id` FROM `tbcmangos`.`gossip_menu_option` WHERE `menu_id` = 9046 ORDER BY `id`;


-- =====================================================================================
-- 追加回滚（2026-10-04 那一段）：撤销「action_menu_id 两跳交换」+ 删掉补进去的 12302/12303
-- 反向守卫：只有仍是"修好后"的值才改回去。
-- 注意：npc_text 12302/12303 与 locales_npc_text 对应行**本来就是缺的**（12302/12303 主表无行、
--       locale 各有 5 条重复行），所以这里直接删除即为"回到原状"，不会丢原有数据。
-- =====================================================================================

UPDATE `tbcmangos`.`gossip_menu_option` SET `action_menu_id` = 51001
 WHERE `menu_id` = 9046 AND `id` = 1 AND `action_menu_id` = 51002;

UPDATE `tbcmangos`.`gossip_menu_option` SET `action_menu_id` = 51002
 WHERE `menu_id` = 9046 AND `id` = 2 AND `action_menu_id` = 51001;

DELETE FROM `tbcmangos`.`npc_text` WHERE `ID` IN (12302, 12303);
DELETE FROM `tbcmangos`.`locales_npc_text` WHERE `entry` IN (12302, 12303);

SELECT `id`, `option_broadcast_text`, `action_menu_id`, `condition_id`
  FROM `tbcmangos`.`gossip_menu_option` WHERE `menu_id` = 9046 ORDER BY `id`;
SELECT COUNT(*) AS npc_text_12302_12303 FROM `tbcmangos`.`npc_text` WHERE `ID` IN (12302, 12303);