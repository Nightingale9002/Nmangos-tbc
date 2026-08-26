-- ============================================================
-- 任务物品每人一份 (ITEM_FLAG_MULTI_DROP = 0x800 = 2048)
-- 2026-08-26 复核：云端 class=12 仅 815 个带 MULTI_DROP，执行后全部 3865 个
-- 原理：loot 负 ChanceOrQuestChance(needs_quest) + MULTI_DROP(freeForAll)
--   -> 队伍里每个有任务的人都能拾取自己的一份（原版机制，LootMgr L511-512）
-- 注意：改 item_template 后需重启 mangosd 才生效（item proto 内存缓存）
-- ============================================================
UPDATE item_template SET Flags = Flags | 2048 WHERE class = 12;
-- 特殊物品单独补充（之前 003 里的）
UPDATE item_template SET Flags = Flags | 2048 WHERE entry IN (22520, 32385, 32386, 32405);
