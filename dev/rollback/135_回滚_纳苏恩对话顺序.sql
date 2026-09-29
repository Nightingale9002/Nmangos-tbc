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
