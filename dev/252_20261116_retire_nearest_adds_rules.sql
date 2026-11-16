-- Character database (tbccharacters).
-- 方案 A：退役「最近有 add 就改目标」这类旧规则，真正的 encounter add 改用
-- `ai_playerbot_encounter_add_range` + `ThreatTier()`=5 表达（dev/249、dev/250 是沃匹尔的首样例）。
--
-- 为什么不是改半径：
--   旧写法 `has nearest adds>attack least hp target!20` 的语义是「身边 8 码内有除当前目标外的
--   敌对单位 ⇒ 立刻改打 possible attack targets（SightDistance，现场 60 码）里威胁分最高的那个」。
--   触发半径与选择半径不一致；`NearestAddsValue::AcceptUnit()` 只排除 current target，
--   所以 boss 本人也会被算成 add；动作是每次检查窗口都重新下发 Attack()（含清移动）。
--   结果就是每个 tick 都有另一个"裁判"在抢 victim —— 2026-11-15 沃匹尔 r4 日志已闭环证明
--   （dev/245 注释、dev/KNOWN_ISSUES「[PlayerBots]」章）。
--
-- 本文件做两件事：
--   ① 给「确有可击杀 add」的 boss 补 ai_playerbot_encounter_add_range（add 靠近自己的 boss ⇒ tier 5）；
--   ② 删掉这些 boss 的旧规则；同时删掉「根本没有 add 可打」的 boss 的旧规则。
--
-- 半径口径：30 码沿用 dev/249（沃匹尔 travelers）。脚本召唤的 add 都落在 boss 身边，30 足够；
--   Kargath 的卫兵由传送门召唤（`wss` 脚本 warchiefsPortal），传送门与 boss 的实际距离未实测，
--   30 是保守值 —— 若实测超出，add 会落回 tier 0（不抢，队伍照常打 boss），不会像旧规则那样乱跑。
--
-- 幂等：重复执行零变更（INSERT ... ON DUPLICATE KEY UPDATE + 精确 DELETE）。

CREATE TABLE IF NOT EXISTS `ai_playerbot_encounter_add_range` (
 `map` SMALLINT UNSIGNED NOT NULL,
 `add_entry` INT UNSIGNED NOT NULL,
 `boss_entry` INT UNSIGNED NOT NULL,
 `radius` FLOAT NOT NULL,
 `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
 PRIMARY KEY (`map`,`add_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

START TRANSACTION;

-- ============ ① 有真实 add 的 boss：补 encounter add 半径 ============
-- 16808 酋长卡加斯·刃拳（破碎大厅 540）：30737/30785/30786 召唤的三种卫兵
-- 17308 无疤者奥摩尔（地狱火城墙 543）：30707 召唤的恶魔犬
-- 17797 水术师瑟丝比娅（蒸汽地窟 545）：31476 召唤的水元素
-- 17975 高级植物学家弗雷温（生态船 553）：34759/34761/34762/34763 种下的幼苗 + 34557 的 Frayer Protector
-- 17977 迁跃扭木（生态船 553）：34741 吸血的 Sapling
-- 18373 大主教玛拉达尔（奥金尼地穴 558）：32360 偷走的灵魂
-- 18472 黑暗编织者赛斯（塞泰克大厅 556）：33537-33540 的四种元素
-- 19220 计算者帕萨雷恩（能源舰 554）：35284 召唤的虚空怨灵
-- 17941 门努（奴隶围栏 547）：图腾走 `Totem::Create()` 的 `entry*100+0` 兜底
--   （`spell_template` 没写 SpellList，但 `creature_template_spells` 有 18176→31983、18177→31986），
--   所以地缚/石肤两个图腾是**真有效果且可击杀**的，属于该集火的 add；半径 20（刷在 boss 脚下）。
--   18179 堕落新星：出生 `ACTION_T_SET_DEATH_PREVENTION` ⇒ 打不掉，只能靠坦克拖出 15 码；
--   20208 治疗图腾：dev/253 给它补回了 34978 光环（每 2 秒 34977 治疗 2313–2688、10 码），
--   现在它真的会回血 ⇒ 必须纳入集火，否则治疗量白送；20208 只有 5 点血，一下就没。
--   18178 是残留数据（无召唤法术/无 spells 行/无刷点），不配。
DELETE FROM `ai_playerbot_encounter_add_range` WHERE
     (`map`=540 AND `add_entry` IN (17621,17622,17623))
  OR (`map`=543 AND `add_entry` IN (17540))
  OR (`map`=545 AND `add_entry` IN (17917))
  OR (`map`=547 AND `add_entry` IN (18176,18177,20208))
  OR (`map`=553 AND `add_entry` IN (19953,19958,19962,19964,19969,19949))
  OR (`map`=558 AND `add_entry` IN (18441))
  OR (`map`=556 AND `add_entry` IN (19203,19204,19205,19206))
  OR (`map`=554 AND `add_entry` IN (21062));

INSERT INTO `ai_playerbot_encounter_add_range` (`map`,`add_entry`,`boss_entry`,`radius`,`enabled`) VALUES
 (540,17621,16808,30,1),   -- Heathen Guard
 (540,17622,16808,30,1),   -- Sharpshooter Guard
 (540,17623,16808,30,1),   -- Reaver Guard
 (543,17540,17308,30,1),   -- Fiendish Hound
 (545,17917,17797,30,1),   -- Coilfang Water Elemental
 (547,18176,17941,20,1),   -- Tainted Earthgrab Totem（出生定身，可击杀）
 (547,18177,17941,20,1),   -- Tainted Stoneskin Totem（可击杀）
 (547,20208,17941,20,1),   -- Mennu's Healing Ward（dev/253 补回 34978 后真的会回血，5 点血）
 (553,19953,17975,30,1),   -- Frayer Protector
 (553,19958,17975,30,1),   -- White Seedling
 (553,19962,17975,30,1),   -- Blue Seedling
 (553,19964,17975,30,1),   -- Red Seedling
 (553,19969,17975,30,1),   -- Green Seedling
 (553,19949,17977,30,1),   -- Sapling
 (558,18441,18373,30,1),   -- Stolen Soul
 (556,19203,18472,30,1),   -- Syth Fire Elemental
 (556,19204,18472,30,1),   -- Syth Frost Elemental
 (556,19205,18472,30,1),   -- Syth Arcane Elemental
 (556,19206,18472,30,1),   -- Syth Shadow Elemental
 (554,21062,19220,30,1)    -- Nether Wraith
ON DUPLICATE KEY UPDATE
 `boss_entry`=VALUES(`boss_entry`), `radius`=VALUES(`radius`), `enabled`=1;

-- ============ ② 退役旧规则（name + action_line 精确匹配）============
-- 17461/20923 是破碎大厅的 gauntlet 精英（EventAI 只有喊话/打断），本身没有 add；
-- 18170 Infinite Slayer 是小怪模板，不是 boss。
-- 17941 门努：图腾已改用 encounter_add_range 表达（18176/18177），旧的「身边有怪就换目标」没有存在意义。
-- boss_18732 的 `attack nearest add` 是 dev/245 未在 characters 库生效的同一条冲突规则，这里一并退役。
DELETE FROM `ai_playerbot_custom_strategy` WHERE `owner`=0 AND (
     (`name`='boss_16808'     AND `action_line`='val::and::{is dps,trigger::has nearest adds}>attack least hp target!20')
  OR (`name`='boss_17308_dps' AND `action_line`='has nearest adds>attack least hp target!20')
  OR (`name`='boss_17461'     AND `action_line`='val::and::{is dps,trigger::has nearest adds}>attack least hp target!20')
  OR (`name`='boss_17797'     AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack least hp target!20')
  OR (`name`='boss_17941_dps' AND `action_line`='has nearest adds>attack least hp target!20')
  OR (`name`='boss_17975_dps' AND `action_line`='has nearest adds>attack least hp target!20')
  OR (`name`='boss_17977'     AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack least hp target!20')
  OR (`name`='boss_18170_dps' AND `action_line`='val::and::{is dps,trigger::has nearest adds}>attack least hp target!20')
  OR (`name`='boss_18373'     AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack least hp target!62')
  OR (`name`='boss_18472'     AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack least hp target!80')
  OR (`name`='boss_18732'     AND `action_line`='val::and::{trigger::has nearest adds,is dps}>attack nearest add')
  OR (`name`='boss_19220_dps' AND `action_line`='has nearest adds>attack least hp target!20')
  OR (`name`='boss_20923'     AND `action_line`='val::and::{is dps,trigger::has nearest adds}>attack least hp target!20')
);

COMMIT;

-- ============ ③ 验收（期望值）============
-- 期望 rows=22（沃匹尔 dev/249 的 555×2 + 本文件 20 行）
SELECT COUNT(*) AS encounter_add_rows FROM `ai_playerbot_encounter_add_range`;
-- 期望剩 3 行：boss_17862_dps / boss_17980 / boss_20912_dps（本轮无 add 证据，保留待逐场核查）
SELECT `name`,`idx`,`action_line` FROM `ai_playerbot_custom_strategy`
 WHERE `action_line` LIKE '%nearest adds%' ORDER BY `name`,`idx`;
