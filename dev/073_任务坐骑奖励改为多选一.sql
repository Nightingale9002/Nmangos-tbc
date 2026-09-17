USE tbcmangos;
-- 073_任务坐骑奖励改为多选一.sql（2026-09-17，第四版：战备 + 驰骋外域合并到一个文件）
--
-- 本文件一次覆盖**两条**自定义任务线的坐骑奖励，全部改成"按该族坐骑商人在售的坐骑多选一"：
--   ① 战备     90100-90109（需等级 30，奖励 **60% 档**坐骑 + 初级骑术 33388）
--   ② 驰骋外域 90200-90209（需等级 60，奖励 **100% 史诗档**坐骑 + 中级骑术 33391）
--
-- 口径（重要）：某个种族"有几种坐骑"以**该族坐骑商人实际在售**为准；而商人库存 =
--   直挂的 `npc_vendor` **加上**它引用的 `npc_vendor_template`（`creature_template.VendorTemplateId`，
--   核心在 `ObjectMgr.cpp:9703 LoadVendors("npc_vendor_template", true)` 合并加载）。
--   各档在售数量：人类 4+3 / 矮人 3+3 / 暗夜精灵 3+3 / 侏儒 4+3 / 德莱尼 3+3 / 兽人 3+3 /
--   亡灵 3+**2** / 牛头人 **2**+3 / 巨魔 3+3 / 血精灵 4+3（前一个是 60% 档，后一个是 100% 档）。
--   → 所以选项数是 2/3/4 不等，**该族原有那一匹一律保留在选项里**，不会少拿。
--
-- 做法：清 `RewItemId1/RewItemCount1`，写 `RewChoiceItemId1..N` + `RewChoiceItemCount1..N = 1`
--       （服务端每位任务最多支持 6 个可选奖励：`QUEST_REWARD_CHOICES_COUNT`，
--        `GossipDef.cpp:396/498` 下发给客户端，`Player.cpp:13174` 发放）。骑术奖励字段不动。
-- 幂等：直接覆盖这些字段，可重复执行。
-- ⚠️ 不要重复执行 `dev/002_紧急征召任务线_完整最终版_tbcmangos.sql`（它会把这两批改回旧值）。
-- 编号说明：本文件与 `dev/072`（古罗克翻译）都是**编号复用**——旧的 `dev/072`~`dev/074` 属"刷新时间整改"，
--           已并入 `dev/071` 并删除；云端 marker 现为 071，nightly 会按 072 → 073 顺序应用。
-- ⚠️ 本文件**取代** `dev/073_战备任务坐骑改为三选一.sql` 与 `dev/074_驰骋外域任务坐骑改为多选一.sql`
--   （两者已删除，勿再执行）。

-- =====================================================================================
-- 第 1 部分：战备 90100-90109（60% 档）—— 按在售数量 2/3/4 选一
-- =====================================================================================

-- 90100 人类（在售 4 种）→ 四选一：黑马 / 花斑马 / 栗色马 / 棕马
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 2411, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 2414, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 5655, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 5656, RewChoiceItemCount4 = 1
 WHERE entry = 90100;

-- 90101 矮人（3 种）→ 棕山羊 / 灰山羊 / 白山羊
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 5872, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 5864, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 5873, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,    RewChoiceItemCount4 = 0
 WHERE entry = 90101;

-- 90102 暗夜精灵（3 种）→ 斑点霜刃豹 / 条纹霜刃豹 / 条纹夜刃豹
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 8632, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 8631, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 8629, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,    RewChoiceItemCount4 = 0
 WHERE entry = 90102;

-- 90103 侏儒（在售 4 种）→ 四选一：蓝 / 绿 / 红 / 未涂装 机械陆行鸟
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 8595,  RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 13321, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 8563,  RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 13322, RewChoiceItemCount4 = 1
 WHERE entry = 90103;

-- 90104 德莱尼（3 种）→ 灰 / 棕 / 紫 雷象
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 29744, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 28481, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 29743, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90104;

-- 90105 兽人（3 种）→ 恐狼 / 棕狼 / 冬狼
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 5665, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 5668, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 1132, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,    RewChoiceItemCount4 = 0
 WHERE entry = 90105;

-- 90106 亡灵（3 种）→ 红 / 蓝 / 棕 骷髅马
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 13331, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 13332, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 13333, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90106;

-- 90107 牛头人（原版 60% 档只有 2 种）→ 两选一：灰科多 / 棕科多
--   ⚠️ TBC 客户端数据里 60% 档科多兽法术只有 `18989 灰色科多兽`(+60%) 与 `18990 棕色科多兽`(+60%)；
--      科多兽商人 Harb Clawhoof 也只卖这两匹（另卖 3 匹"大型"史诗科多）。
--      第三种"绿色科多兽"(15292) 用的是 `18991`（**+100%**、史诗、需等级 60），且**没有商人出售**
--      → 不能当 60% 档奖励；要造一个 60% 绿科多必须新做召唤法术，而法术在客户端 Spell.dbc 里 → 需客户端补丁。
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 15277, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 15290, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 0,     RewChoiceItemCount3 = 0,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90107;

-- 90108 巨魔（3 种）→ 翡翠 / 青绿 / 紫罗兰 迅猛龙
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 8588, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 8591, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 8592, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,    RewChoiceItemCount4 = 0
 WHERE entry = 90108;

-- 90109 血精灵（在售 4 种）→ 四选一：黑 / 蓝 / 红 / 紫 陆行鸟
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 29221, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 29220, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 28927, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 29222, RewChoiceItemCount4 = 1
 WHERE entry = 90109;

-- 1.1 战备任务改名：去掉"迅捷"（奖励是 60% 档，"迅捷XX"是 100% 史诗档的命名，名不副实）
UPDATE quest_template SET Title = '战备：战马'         WHERE entry = 90100 AND Title = '战备：迅捷战马';
UPDATE quest_template SET Title = '战备：山羊'         WHERE entry = 90101 AND Title = '战备：迅捷山羊';
UPDATE quest_template SET Title = '战备：霜刃豹'       WHERE entry = 90102 AND Title = '战备：迅捷霜刃豹';
UPDATE quest_template SET Title = '战备：机械陆行鸟'   WHERE entry = 90103 AND Title = '战备：迅捷机械陆行鸟';
UPDATE quest_template SET Title = '战备：雷象'         WHERE entry = 90104 AND Title = '战备：迅捷雷象';
UPDATE quest_template SET Title = '战备：战狼'         WHERE entry = 90105 AND Title = '战备：迅捷战狼';
UPDATE quest_template SET Title = '战备：骷髅马'       WHERE entry = 90106 AND Title = '战备：迅捷骷髅马';
UPDATE quest_template SET Title = '战备：科多兽'       WHERE entry = 90107 AND Title = '战备：迅捷科多兽';
UPDATE quest_template SET Title = '战备：迅猛龙'       WHERE entry = 90108 AND Title = '战备：迅捷迅猛龙';
UPDATE quest_template SET Title = '战备：陆行鸟'       WHERE entry = 90109 AND Title = '战备：迅捷陆行鸟';

-- =====================================================================================
-- 第 2 部分：驰骋外域 90200-90209（100% 史诗档）—— 按在售数量 2/3 选一
--   任务文本本身写的就是"领取你的**史诗**坐骑"，原来却各只给一匹固定坐骑。
-- =====================================================================================

-- 90200 人类 → 迅捷褐色马 / 迅捷棕马 / 迅捷白马
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18776, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18777, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18778, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90200;

-- 90201 矮人 → 迅捷白山羊 / 迅捷棕山羊 / 迅捷灰山羊
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18785, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18786, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18787, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90201;

-- 90202 暗夜精灵 → 迅捷霜刃豹 / 迅捷雾刃豹 / 迅捷雷刃豹
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18766, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18767, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18902, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90202;

-- 90203 侏儒 → 迅捷绿色 / 迅捷白色 / 迅捷黄色 机械陆行鸟
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18772, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18773, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18774, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90203;

-- 90204 德莱尼 → 重型蓝色 / 重型绿色 / 重型紫色 雷象
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 29745, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 29746, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 29747, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90204;

-- 90205 兽人 → 迅捷棕狼 / 迅捷森林狼 / 迅捷灰狼
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18796, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18797, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18798, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90205;

-- 90206 亡灵 → **两选一**：绿色骸骨军马 / 紫色骷髅战马
--   原版 TBC 的 100% 档骷髅马只有这两匹（商人 Zachariah Post 卖这两匹史诗 + 三匹 60% 档）。
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 13334, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18791, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 0,     RewChoiceItemCount3 = 0,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90206;

-- 90207 牛头人 → 大型白色 / 大型棕色 / 大型灰色 科多兽
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18793, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18794, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18795, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90207;

-- 90208 巨魔 → 迅捷蓝色 / 迅捷绿色 / 迅捷橙色 迅猛龙
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 18788, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 18789, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 18790, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90208;

-- 90209 血精灵 → 迅捷粉色 / 迅捷绿色 / 迅捷紫色 陆行鸟
--   ⚠️ 顺带修一处明显的写错：原本奖励 `28927 红色陆行鸟`，那是 **60% 档**（spell 34795 = +60%），
--      与本任务线"史诗坐骑 + 中级骑术 33391"的定位矛盾（任务文本也写"史诗坐骑"）。
UPDATE quest_template SET RewItemId1 = 0, RewItemCount1 = 0,
       RewChoiceItemId1 = 28936, RewChoiceItemCount1 = 1,
       RewChoiceItemId2 = 29223, RewChoiceItemCount2 = 1,
       RewChoiceItemId3 = 29224, RewChoiceItemCount3 = 1,
       RewChoiceItemId4 = 0,     RewChoiceItemCount4 = 0
 WHERE entry = 90209;

-- =====================================================================================
-- 第 3 部分：纠错（幂等无副作用）
-- =====================================================================================
-- 曾误以为 15292（绿色科多兽）是 60% 档而把它的 RequiredLevel 改成 30 —— 它是**史诗**物品（spell 18991 = +100%），
-- 需要等级 60，必须保持原值。若已被改过，这里改回 60（未改过则 0 行受影响）。
UPDATE item_template SET RequiredLevel = 60 WHERE entry = 15292 AND RequiredLevel = 30;

-- =====================================================================================
-- 校验
-- =====================================================================================
-- 战备：应为 人类4 / 矮人3 / 暗夜3 / 侏儒4 / 德莱尼3 / 兽人3 / 亡灵3 / 牛头人2 / 巨魔3 / 血精灵4
SELECT '战备' AS line, entry, Title,
       (RewChoiceItemId1 > 0) + (RewChoiceItemId2 > 0) + (RewChoiceItemId3 > 0) + (RewChoiceItemId4 > 0) AS choices,
       RewItemId1 AS fixed_item,
       CONCAT_WS(' / ', NULLIF(RewChoiceItemId1,0), NULLIF(RewChoiceItemId2,0),
                          NULLIF(RewChoiceItemId3,0), NULLIF(RewChoiceItemId4,0)) AS choice_items,
       RewSpell AS riding_spell
  FROM quest_template WHERE entry BETWEEN 90100 AND 90109 ORDER BY entry;

-- 驰骋外域：应为 人类3 / 矮人3 / 暗夜3 / 侏儒3 / 德莱尼3 / 兽人3 / 亡灵2 / 牛头人3 / 巨魔3 / 血精灵3
SELECT '驰骋外域' AS line, entry, Title,
       (RewChoiceItemId1 > 0) + (RewChoiceItemId2 > 0) + (RewChoiceItemId3 > 0) + (RewChoiceItemId4 > 0) AS choices,
       RewItemId1 AS fixed_item,
       CONCAT_WS(' / ', NULLIF(RewChoiceItemId1,0), NULLIF(RewChoiceItemId2,0),
                          NULLIF(RewChoiceItemId3,0), NULLIF(RewChoiceItemId4,0)) AS choice_items,
       RewSpell AS riding_spell
  FROM quest_template WHERE entry BETWEEN 90200 AND 90209 ORDER BY entry;

-- 每个选项都要是"该族能骑"的物品（AllowableRace 与 RequiredRaces 有交集）
SELECT q.entry AS quest, q.RequiredRaces AS qrace, i.entry AS item, i.name, i.ItemLevel,
       i.AllowableRace AS item_race,
       CASE WHEN (i.AllowableRace & q.RequiredRaces) = 0 THEN '✗ 该族不能骑' ELSE 'ok' END AS usable
  FROM quest_template q JOIN item_template i
    ON i.entry IN (q.RewChoiceItemId1, q.RewChoiceItemId2, q.RewChoiceItemId3, q.RewChoiceItemId4)
 WHERE q.entry BETWEEN 90100 AND 90209 AND i.entry > 0
 ORDER BY q.entry, i.entry;

-- 战备里不应再出现"迅捷"
SELECT COUNT(*) AS leftover_xunjie FROM quest_template
 WHERE entry BETWEEN 90100 AND 90109 AND Title LIKE '%迅捷%';
-- 科多兽等级（15277/15290 = 30，15292 必须回到 60）
SELECT entry, name, ItemLevel, RequiredLevel FROM item_template WHERE entry IN (15277, 15290, 15292);
