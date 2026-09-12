-- ============================================================
-- 063_翻译错译修复_已确认17条.sql
-- 修复经人工核实的中文译名错误（creature / gameobject）
-- ============================================================
-- 来源：三层校验流水线（内部一致性 / 数字规则 / qwen3:4b 英中对应检验）
--       每条均已对照数据库核实，非模型单方面判断。
--
-- 注意：本文件只改 zhCN (name_loc4)，不动 zhTW (name_loc5)。
--       locales_* 是启动时加载，需重启才生效（或 .reload locales_creature / locales_gameobject）。
--
-- 制定：2026-09-12
-- ============================================================


-- ============================================================
-- A 类：机械可确定，无需翻译判断（8 条）
-- ============================================================

-- A1. Fire Nova Totem III (6111) 被写成 "II"
--     同系列证据：Fire Nova Totem II(6110)=火焰新星图腾 II、IV(7844)=IV、V(7845)=V
--     其他图腾系列(灼热/石爪/石肤/治疗之泉)的 III 全部正确译作 III
--     ⚠️ 参考源 wowdb_zh 此处也是错的，不可照抄
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '火焰新星图腾 III' WHERE `entry` = 6111;

-- A2/A3. Cokeplay 兑换商 02/03 编号写反了
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '赎回供应商03' WHERE `entry` = 22248;
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '赎回供应商02' WHERE `entry` = 22249;

-- A4. Ogre 被译成 "巨魔"(Troll)，应为 "食人魔"
--     注：这是开发者用名(Bunny/Small)，实际不怎么显示，但错误明确
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '食人魔建筑兔子小型' WHERE `entry` = 21456;

-- A5. Lieutenant Fangore (703) 军衔错译
--     同系列证据：Lieutenant Farren Orinelle=法尔林·奥里涅尔中尉、
--                 Lieutenant Valorcall=瓦罗卡尔中尉、Lieutenant Doren=多伦上尉
--                 —— 全库 14 个 Lieutenant 中只有他是"将军"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '范高雷中尉' WHERE `entry` = 703;

-- A6/A7. Aura Trap 颜色错译：Blue 和 Yellow 都被写成 "Purple"
--       且 Aura Trap 被译成 "光环 Trap"，中英混杂
UPDATE `tbcmangos`.`locales_gameobject` SET `name_loc4` = '光环陷阱蓝色高大' WHERE `entry` = 185578;
UPDATE `tbcmangos`.`locales_gameobject` SET `name_loc4` = '光环陷阱黄色高大' WHERE `entry` = 185579;

-- A8. 编号错译 02 -> 01
UPDATE `tbcmangos`.`locales_gameobject` SET `name_loc4` = '虚拟大闸门门 02' WHERE `entry` = 161516;


-- ============================================================
-- B 类：参考源给出合理译法，建议采用（7 条）
-- ============================================================

-- B1. Vi'el (16015)：线上是一个物品名"恶性角斗士的小木槌"，与 NPC 名无关
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '维尔' WHERE `entry` = 16015;

-- B2. Morganth (397)：线上是"大魔导师杜内"，整个人名被换成了别人
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '莫甘斯' WHERE `entry` = 397;

-- B3. Dalaran Mage (1914)：线上写成"安伯米尔魔导师"，地名错（达拉然 vs 安伯米尔）
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '达拉然法师' WHERE `entry` = 1914;

-- B4. Stone Fury (2258)：线上是专有名词"玛格拉克"，但英文是描述性名字"石之狂怒"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '狂怒的石元素' WHERE `entry` = 2258;

-- B5. Large Loch Crocolisk (2476)：线上是专有名词"格什哈尔迪"
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '大型洛克鳄' WHERE `entry` = 2476;

-- B6. Disciple of Naralex (3678)：线上是"穆约"，丢失了 Naralex
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '纳拉雷克斯的信徒' WHERE `entry` = 3678;

-- B7. Caylais Moonfeather (3841)：名错（姓对）—— 线上"特尔迪娜·月羽"，英文是 Caylais
UPDATE `tbcmangos`.`locales_creature` SET `name_loc4` = '凯莱斯·月羽' WHERE `entry` = 3841;


-- ============================================================
-- C 类：线上与参考源同时错误，但属前台不显示的装饰性物件（2 条）
-- ============================================================
-- 说明：House / Bench 这类装饰性 gameobject 的名字不在客户端显示，
--       改动无可见影响；此处按英文原名修正为中英对应。
--       （原值"生锈的箱子陷阱"/"旅店桌子"明显是错配到了别的物件）

-- C1. House 2 (19023)：原名 "House 2"，原值"生锈的箱子陷阱"
UPDATE `tbcmangos`.`locales_gameobject` SET `name_loc4` = '房屋2' WHERE `entry` = 19023;

-- C2. OrcBench01 (180326)：原名 "OrcBench"，原值"旅店桌子"
UPDATE `tbcmangos`.`locales_gameobject` SET `name_loc4` = '兽人长椅01' WHERE `entry` = 180326;


-- ============================================================
-- 验证
-- ============================================================
-- SELECT ct.Entry, ct.Name, lc.name_loc4 FROM tbcmangos.creature_template ct
--   JOIN tbcmangos.locales_creature lc ON lc.entry=ct.Entry
--   WHERE ct.Entry IN (6111,22248,22249,21456,703,16015,397,1914,2258,2476,3678,3841);
-- SELECT gt.entry, gt.name, lg.name_loc4 FROM tbcmangos.gameobject_template gt
--   JOIN tbcmangos.locales_gameobject lg ON lg.entry=gt.entry
--   WHERE gt.entry IN (185578,185579,161516);

-- ============================================================
-- 回滚（原始值）
-- ============================================================
-- UPDATE tbcmangos.locales_creature SET name_loc4='火焰新星图腾 II' WHERE entry=6111;
-- UPDATE tbcmangos.locales_creature SET name_loc4='赎回供应商02'   WHERE entry=22248;
-- UPDATE tbcmangos.locales_creature SET name_loc4='赎回供应商03'   WHERE entry=22249;
-- UPDATE tbcmangos.locales_creature SET name_loc4='巨魔建筑兔子小型' WHERE entry=21456;
-- UPDATE tbcmangos.locales_creature SET name_loc4='范高雷将军'     WHERE entry=703;
-- UPDATE tbcmangos.locales_gameobject SET name_loc4='光环 Trap Purple Tall' WHERE entry IN (185578,185579);
-- UPDATE tbcmangos.locales_gameobject SET name_loc4='虚拟大闸门门 01' WHERE entry=161516;
-- UPDATE tbcmangos.locales_creature SET name_loc4='恶性角斗士的小木槌' WHERE entry=16015;
-- UPDATE tbcmangos.locales_creature SET name_loc4='大魔导师杜内'   WHERE entry=397;
-- UPDATE tbcmangos.locales_creature SET name_loc4='安伯米尔魔导师' WHERE entry=1914;
-- UPDATE tbcmangos.locales_creature SET name_loc4='玛格拉克'       WHERE entry=2258;
-- UPDATE tbcmangos.locales_creature SET name_loc4='格什哈尔迪'     WHERE entry=2476;
-- UPDATE tbcmangos.locales_creature SET name_loc4='穆约'           WHERE entry=3678;
-- UPDATE tbcmangos.locales_creature SET name_loc4='特尔迪娜·月羽' WHERE entry=3841;
