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


-- =====================================================================================
-- 追加（2026-10-04）：修「问句 ↔ 子菜单」错位 + 补 12302/12303 的 npc_text
-- -------------------------------------------------------------------------------------
-- 【症状】选 "Exarch, have we taken the Sun's Reach Harbor yet?"（广播文本 24227）得到铁砧那段回答。
-- 【根因】对照 AzerothCore 权威数据：本表这两行的**问句与条件是对的**，只有 `action_menu_id` 两跳被互换了
--        id=1（港口问句 24227 / 条件 10306 Phase3）→ 51001 → 正文 12301「铁砧」  ← 应为 51002
--        id=2（铁砧问句 24224 / 条件 10308 No Anvil）→ 51002 → 正文 12302「港口」 ← 应为 51001
--   本段只交换这两跳；问句、条件、选项顺序（上一轮 2026-09-29 调整的）都不动。
-- 【附带·兜底】npc_text 表里原本没有 12302（阳湾港口）/ 12303（炼金实验室）两行，且这两条在 locales_npc_text
--   各有 5 条重复行。
--   !! 更正（2026-10-05 当日）：本服 gossip 正文实际由 npc_text_broadcast_text -> broadcast_text 决定
--   （ObjectMgr.cpp:6191-6209：该 id 有 broadcast_text 时会把 npc_text 那行文本清空、改存 broadcastTextId
--   运行期解析），实测这四个 id 的英文与 zhCN 中文都在 => 原本就能正常显示，不存在"空白"。所以本段补的
--   npc_text / locales_npc_text 行属于无害兜底（值与 broadcast_text 英文逐字一致），顺带把重复 locale 行收敛成 1 条。
--   本次真凶只有一处：action_menu_id 两跳互换。
-- 【幂等】两跳用旧值守卫；npc_text / locales 用 DELETE + INSERT。
-- 【生效】gossip 与 npc_text 启动时载入；本机可先试 .reload npc_text，否则重启 mangosd；云端随夜间流程。
-- 【验证】
--   SELECT id, option_broadcast_text, action_menu_id, condition_id FROM tbcmangos.gossip_menu_option WHERE menu_id=9046 ORDER BY id;
--     期望 1 -> (24227, 51002, 10306)    2 -> (24224, 51001, 10308)
--   SELECT ID, LEFT(text0_0,26) FROM tbcmangos.npc_text WHERE ID IN (12302,12303);
--   SELECT entry, COUNT(*) FROM tbcmangos.locales_npc_text WHERE entry IN (12302,12303) GROUP BY entry;   -- 期望各 1 行
-- =====================================================================================

-- ① id=1（港口问句）：指向 51002（正文 12302 港口）。守卫：仍是旧值 51001 时才改
UPDATE `tbcmangos`.`gossip_menu_option`
   SET `action_menu_id` = 51002
 WHERE `menu_id` = 9046 AND `id` = 1 AND `action_menu_id` = 51001;

-- ② id=2（铁砧问句）：指向 51001（正文 12301 铁砧）。守卫：仍是旧值 51002 时才改
UPDATE `tbcmangos`.`gossip_menu_option`
   SET `action_menu_id` = 51001
 WHERE `menu_id` = 9046 AND `id` = 2 AND `action_menu_id` = 51002;

-- ③ npc_text 12302（阳湾港口）＋ 简体中文 locale（先删后插，避免无主键表产生重复行）
DELETE FROM `tbcmangos`.`npc_text` WHERE `ID` = 12302;
INSERT INTO `tbcmangos`.`npc_text` (`ID`, `text0_0`) VALUES
 (12302, 'No, unfortunately we have not yet taken the harbor. However, reports indicate that we are $3238w percent of the way towards doing so.$B$B$N, if you want to help out, look for Magister Ilastar and Vindicator Kaalan at the Sun''s Reach Armory on the Isle of Quel''Danas.');
DELETE FROM `tbcmangos`.`locales_npc_text` WHERE `entry` = 12302;
INSERT INTO `tbcmangos`.`locales_npc_text` (`entry`, `Text0_0_loc4`) VALUES
 (12302, '不，很不幸地我们还没拿下港口。然而，报告显示我们已经完成了$3238w％的目标。$B$B$N，如果你想要帮忙，可以去找奎尔丹纳斯岛上日境军械库的博学者伊拉斯塔和复仇者卡蓝。');

-- ④ npc_text 12303（炼金实验室）＋ 简体中文 locale
DELETE FROM `tbcmangos`.`npc_text` WHERE `ID` = 12303;
INSERT INTO `tbcmangos`.`npc_text` (`ID`, `text0_0`) VALUES
 (12303, 'The alchemy lab is not quite yet ready, $N. Mar''nah says that she is $3223w percent done with its assembly, however.$B$BIf you would like to help her with that, you will find her inside the inn at the Sun''s Reach Harbor.');
DELETE FROM `tbcmangos`.`locales_npc_text` WHERE `entry` = 12303;
INSERT INTO `tbcmangos`.`locales_npc_text` (`entry`, `Text0_0_loc4`) VALUES
 (12303, '链金实验室还没准备好，$N。玛纳说她才准备了$3223w％，然而。$B$B如果你愿意协助她的话，你可以在日境港的旅店中找到她。');

-- ---------- 核对（追加段）----------
SELECT `id`, `option_broadcast_text`, `action_menu_id`, `condition_id`
  FROM `tbcmangos`.`gossip_menu_option` WHERE `menu_id` = 9046 ORDER BY `id`;
SELECT `ID`, LEFT(`text0_0`, 30) AS en_head FROM `tbcmangos`.`npc_text` WHERE `ID` IN (12302, 12303);
SELECT `entry`, COUNT(*) AS locale_rows FROM `tbcmangos`.`locales_npc_text` WHERE `entry` IN (12302, 12303) GROUP BY `entry`;