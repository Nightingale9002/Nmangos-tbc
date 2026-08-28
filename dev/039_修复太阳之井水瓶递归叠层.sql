-- 修复太阳之井水瓶递归叠层（45059 Vessel of the Naaru 触发 45062 Holy Energy 时，
-- 45062 为 dmg-none 正面法术 → 再次满足 45059 的 DEAL_HELPFUL_SPELL proc → 递归叠 20 层）
-- 方案：给 45062/45064 加 SPELL_ATTR_EX3_SUPPRESS_CASTER_PROCS (0x10000) → 施放 procAttacker=0，
--       不触发任何 proc（Spell.cpp PrepareMasksForProcSystem），递归/释放叠层消除。
--   45062 Holy Energy：45059 proc 触发它时不递归（解决一次叠 20 层）
--   45064 释放治疗：使用物品释放时不触发 45059（解决释放后残留 2 层，应全部消耗）
--   45059 proc cooldown 100ms：一次治疗在"命中+施放结束"两阶段触发两次 → 同帧第二次被挡，
--       只叠 1 层（GCD 1.5s 不影响下次施放正常 +1）
UPDATE spell_template SET AttributesEx3 = AttributesEx3 | 65536 WHERE id IN (45062, 45064);
UPDATE spell_proc_event SET Cooldown = 100 WHERE entry = 45059;


