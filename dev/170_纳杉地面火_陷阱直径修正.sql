-- =====================================================================================
-- 170_纳杉地面火_陷阱直径修正（Liquid Fire 打不到人）.sql
-- 日期：2026-10-09        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】站长实测：地狱火城墙（Hellfire Ramparts，map 543）纳杉(Nazan) 落地后的**地面火没有伤害**。
-- 【链路（逐段实测/代码级）】
--   火球的 `Effect2 = 77 (SCRIPT_EFFECT)` → C++ 脚本 `spell_vazruden_liquid_fire_script`
--   （绑定见 `spell_scripts`：30926 / 33793 / 33794 / 36921，四库一致 ✓）
--   → 脚本里 `target->CastSpell(nullptr, 普通 23971 / 英雄 30928)`（本文件不涉及）
--   → 23971/30928「Summon Liquid Fire」`Effect1 = 76 (SUMMON_OBJECT_WILD)`、
--     `EffectMiscValue1` = 召唤 **GO 180125（普通）/ 182533（英雄）「Liquid Fire」**（type 6 = TRAP）
--   → 陷阱字段映射（`GameObject.h:122-139`）：
--       data0 = lockId、**data1 = level**、**data2 = diameter(触发直径)**、**data3 = spellId**、data4 = charges、data5 = cooldown
--     ⇒ 本库/上游：`180125 = (0, 60, 0, 23972, 0, 0)`、`182533 = (0, 70, 0, 32492, 0, 0)`
--     ⇒ **`data2 = 0` ⇒ 触发半径 = 0/2 = 0**
--   → `GameObject::Update` 的陷阱分支（`GameObject.cpp:448-467`）：半径 0 时
--     **`valid = false`（只有战场陷阱 `cooldown==3` 才例外）⇒ 陷阱永远不触发 ⇒ 火完全没有伤害** ✓ 与现象吻合。
-- 【对照】AzerothCore `gameobject_template`：`180125 data2 = 6`、`182533 data2 = 6`
--   ⇒ 直径 6（半径 3 码）；而 mangos 系四库（本库 / tbcmangos_orig / tbcdb_ref / wotlkmangos / classicmangos_ref）
--   全都是 0 ⇒ **mangos 数据缺口，不是我们改坏的** ✓
-- 【修复】把两行陷阱的 `data2` 由 0 改成 **6**（与 AC 一致），其余字段一字不动。
-- 【生效】gameobject_template 启动时载入 ⇒ 需重启（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/170_回滚_纳杉地面火陷阱直径.sql
-- =====================================================================================

UPDATE `tbcmangos`.`gameobject_template`
   SET `data2` = 6
 WHERE `entry` = 180125 AND `type` = 6 AND `data2` = 0 AND `data3` = 23972;

UPDATE `tbcmangos`.`gameobject_template`
   SET `data2` = 6
 WHERE `entry` = 182533 AND `type` = 6 AND `data2` = 0 AND `data3` = 32492;

-- ---------- 核对 ----------
-- 期望：180125 data2 = 6、182533 data2 = 6（其余字段不变）
SELECT `entry`, `name`, `type`, `data0`, `data1`, `data2`, `data3`, `data4`, `data5`
  FROM `tbcmangos`.`gameobject_template`
 WHERE `entry` IN (180125, 182533) ORDER BY `entry`;
