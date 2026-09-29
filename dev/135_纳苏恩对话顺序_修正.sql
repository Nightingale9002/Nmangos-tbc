-- =====================================================================================
-- 135_纳苏恩对话顺序_修正.sql
-- 日期：2026-09-29        适用库：tbcmangos（world 库）
-- 类型：静态 / 幂等（可重复执行）
-- -------------------------------------------------------------------------------------
-- 【症状】站长：*"主教纳苏恩的多个对话的顺序可能有偏移"*（Exarch Nasuun，NPC **24932**，
--   奎尔丹纳斯岛 Shattered Sun 阶段任务中枢，`GossipMenuId = 9046`）。
--
-- 【实测（云端库）】客户端按 `gossip_menu_option.id` 顺序显示选项，菜单 9046 当前为：
--   id=0  广播文本 24222 → 子菜单 51000 → 条件 10302（type=12 游戏事件 302 = Phase 2 Only）
--   id=1  广播文本 24224 → 子菜单 51002 → 条件 10308（事件 308 = Phase 3 **No Anvil**）  ← 应为 306
--   id=2  广播文本 24227 → 子菜单 51001 → 条件 10306（事件 306 = Phase 3 Only）          ← 应为 308
--   id=3  广播文本 24229 → 子菜单 51003 → 条件 10313（事件 313 = Phase 4 No Alchemy Lab）
--   id=7  广播文本 24231 → 子菜单 9307（条件 0，与本问题无关）
--   奎岛阶段推进顺序是 **302 → 306 → 308 → 313**，而中间两条被互换了（子菜单 51001/51002
--   也跟着换）⇒ 玩家看到的对话顺序与阶段顺序不一致 ✓ 与站长观察一致。
--
-- 【本文件做什么】仅交换这两条的 `id`（1 ↔ 2）：
--   id=1 ⇄ 条件 10306（事件 306，子菜单 51001）
--   id=2 ⇄ 条件 10308（事件 308，子菜单 51002）
--   幂等守卫：只有当 id=1 仍挂着"错误"的条件 10308 时才执行；已修好的库重跑不会来回翻。
--
-- 【生效方式】gossip 在启动时载入 ⇒ 重启 mangosd（或用 `.reload gossip_menu_option` /
--   `.reload gossip_menu`，视版本命令而定）。
-- 【验证】
--   SELECT id, option_broadcast_text, action_menu_id, condition_id
--     FROM tbcmangos.gossip_menu_option WHERE menu_id = 9046 ORDER BY id;   -- 期望 1→10306、2→10308
-- 【回滚】dev/rollback/135_回滚_纳苏恩对话顺序.sql
-- =====================================================================================

-- 幂等守卫：id=1 当前是否还是条件 10308（未修状态）
SET @need_swap := (SELECT COUNT(*) FROM `tbcmangos`.`gossip_menu_option`
                    WHERE `menu_id` = 9046 AND `id` = 1 AND `condition_id` = 10308);

-- 借道临时 id=99 交换，避免主键 (menu_id, id) 冲突
SET @s1 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 99 WHERE `menu_id` = 9046 AND `id` = 1', 'DO 0');
PREPARE s1 FROM @s1; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @s2 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 1 WHERE `menu_id` = 9046 AND `id` = 2', 'DO 0');
PREPARE s2 FROM @s2; EXECUTE s2; DEALLOCATE PREPARE s2;

SET @s3 := IF(@need_swap > 0, 'UPDATE `tbcmangos`.`gossip_menu_option` SET `id` = 2 WHERE `menu_id` = 9046 AND `id` = 99', 'DO 0');
PREPARE s3 FROM @s3; EXECUTE s3; DEALLOCATE PREPARE s3;

-- ---------- 核对 ----------
-- 期望：0→302、1→306、2→308、3→313（按 id 升序即阶段顺序）
SELECT `id`, `option_broadcast_text`, `action_menu_id`, `condition_id`
  FROM `tbcmangos`.`gossip_menu_option` WHERE `menu_id` = 9046 ORDER BY `id`;
