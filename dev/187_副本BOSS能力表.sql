-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：副本BOSS能力表
-- 来源（旧编号）：195_副本BOSS能力表.sql、197_BOSS能力表_主键加category.sql、199_BOSS能力表_禁站扇区.sql、201_BOSS能力表_朝向规则.sql、196_boss_ability_los_seed.sql、198_boss_ability_position_seed.sql、200_boss_avoid_sectors_seed.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- 195_副本BOSS能力表.sql
-- [2026-10-18 站长口径] BOSS 技能/效果能力表：**能按通用策略处理的就通用，不能的才单独做策略**。
--
-- 站长原话："对于boss我们是能按照通用策略处理的就处理，不能处理的我们再做单独的策略"；
--          "召唤物/图腾不是按召唤物做优先级，而是按召唤物的技能或者效果"。
--
-- 设计要点：
--   1. 一行 = 一个单位（boss 本体，或它的召唤物/图腾）的一个**可施放技能**。
--      `owner_entry` 是"实际施法单位"的 entry：boss 本体 = boss_entry；召唤物/图腾 = 召唤物自己。
--      召唤物**不因为"是召唤物"进优先级**，而是和普通单位一样按技能效果分类（见 category）。
--   2. `category` 是效果分类（与 combatlog/观测层同一口径）：
--        heal        读条治疗            → 通用：观测层自动 priority 5
--        control     读条控制（击晕/魅惑/恐惧/沉默…，不含缠绕）→ 通用：观测层 priority 3
--        interrupt   可打断的高威胁读条   → 通用：1s 内打断 + 预留资源
--        dispel      魔法/疾病/诅咒/毒   → 通用：驱散
--        aoe         地面/锥形范围伤害    → 通用：躲地板技
--        move        击退/冲锋/位移       → 通用：躲/位移
--        summon      召唤/图腾/分身       → 只记来源；优先级看召唤物自身技能
--        buff        给友方/boss 的增益光环 → 通用：优先打掉（效果决定）
--        damage      普通伤害
--        other       以上都不是
--   3. `generic_handling` 写明"交给哪条通用链路"（空 = 通用处理不了，看 needs_special）。
--   4. `needs_special = 1` ⇒ 这条技能必须先写单独策略（换坦/停手/特殊站位/阶段机制等）。
--   5. `source` 记录数据来源：guide（攻略人工条目）/ db（creature_spell_list 展开）/ observed
--      （combatlog 实测到它读过这个条）；三种可并存，靠 `note` 区分。
--
-- 数据库：world 库（tbcmangos）。幂等（IF NOT EXISTS），可重复执行。

CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_ability` (
  `map`            SMALLINT UNSIGNED NOT NULL COMMENT '地图/副本 id',
  `boss_entry`     INT UNSIGNED NOT NULL COMMENT 'BOSS 本体 entry（召唤物的行也填它所属的 boss）',
  `owner_entry`    INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '实际施法单位 entry：boss 本体=boss_entry；召唤物/图腾=它自己的 entry',
  `spell_id`       INT UNSIGNED NOT NULL COMMENT 'spell_template.Id（未匹配到 = 0，靠 note 保留攻略名字）',
  `category`       VARCHAR(24) NOT NULL DEFAULT 'other' COMMENT 'heal/control/interrupt/dispel/aoe/move/summon/buff/damage/other',
  `interruptible`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '是否可打断（0/1）',
  `dispellable`    VARCHAR(16) NOT NULL DEFAULT '' COMMENT '可驱散类型：magic/disease/curse/poison（空=不可驱散/未知）',
  `avoid_sectors`  VARCHAR(32) NOT NULL DEFAULT '' COMMENT '禁站扇区：front/right/back/left（60° 一档，逗号分隔）',
  `facing_mode`    VARCHAR(24) NOT NULL DEFAULT 'away_group' COMMENT '朝向模式：away_group/fixed/open/wall',
  `facing_deg`     SMALLINT NOT NULL DEFAULT 0 COMMENT 'fixed 模式下的目标朝向（度）',
  `generic_handling` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '交给哪条通用链路（空 = 通用处理不了）',
  `needs_special`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = 需要单独策略',
  `source`         ENUM('guide','db','observed') NOT NULL DEFAULT 'guide' COMMENT '数据来源',
  `note`           VARCHAR(255) NOT NULL DEFAULT '' COMMENT '攻略原文/补充说明',
  PRIMARY KEY (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`),
  KEY `idx_needs_special` (`needs_special`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='副本 BOSS/召唤物技能与效果，决定"通用处理 or 单独策略"';

-- 复核：
--   SELECT map, boss_entry, owner_entry, spell_id, category, generic_handling, needs_special
--   FROM tbcmangos.ai_playerbot_boss_ability ORDER BY map, boss_entry, owner_entry;
--   不能通用处理的清单：
--   SELECT map, boss_entry, spell_id, category, note FROM tbcmangos.ai_playerbot_boss_ability
--   WHERE needs_special = 1;

-- 197_BOSS能力表_主键加category.sql
-- 原因：同一 boss 可以同时有 los/frontal/knockback/... 多个类别，而"攻略级"条目的 spell_id=0，
--       旧主键 (map,boss_entry,owner_entry,spell_id) 会互相覆盖 ⇒ 主键加上 category。
-- [2026-10-20 口径修订] 这里原来用 information_schema + PREPARE 守卫（属于逻辑查询，见 README §〇）；
--   **结构变更一律静态**：新库由上面的 CREATE TABLE 直接建成 5 列主键，老库按下面这条**手工**执行一次：
--   ALTER TABLE `ai_playerbot_boss_ability` DROP PRIMARY KEY,
--     ADD PRIMARY KEY (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`);
--   云端/本地 2026-10-20 已核对：PRIMARY KEY 就是这 5 列 ✓，不需要再跑。

-- 199_BOSS能力表_禁站扇区.sql
-- [2026-10-18 站长口径] 跑位避让按**扇区**算：以 BOSS 朝向为 0°，60° 一档分 6 个扇区；
--   正面锥形禁 front、龙类甩尾禁 back（有的前后都禁）。
--   avoid_sectors: 逗号分隔，取值 front/right/back/left（front=正前±30°，back=正后±30°，
--   right/left=对应侧 60°）。空 = 无扇区限制。
-- [2026-10-20] `avoid_sectors` 已并入 CREATE TABLE；老库手工执行（云端/本地均已存在 ✓）：
--   ALTER TABLE `ai_playerbot_boss_ability` ADD COLUMN `avoid_sectors` VARCHAR(32) NOT NULL DEFAULT ''
--     COMMENT '禁站扇区：front/right/back/left（60° 一档，逗号分隔）' AFTER `dispellable`;

-- 201_BOSS能力表_朝向规则.sql
-- [2026-10-18 站长口径] 调整怪物朝向不止"背朝团队"，还包括特定方向：
--   facing_mode:
--     away_group  默认：坦克站到"队伍质心的反方向" ⇒ BOSS 背对队伍（现有行为）
--     fixed       固定世界朝向：facing_deg（0-359，0=正北/游戏坐标 +Y，顺时针？按游戏坐标角度）
--     open        面向最空旷的方向（用服务端 vmap/地形采样，避免把怪顶到墙/悬崖）
--     wall        面向最近的墙（需要把 BOSS 顶到墙边时用；坦克站到它与墙之间）
--   facing_deg: 仅 fixed 用。
-- [2026-10-20 定案·已修] 这两列**从未在云端生效**：守卫式 ALTER 写法（information_schema + PREPARE）
--   在 apply_dev_sql.sh 里没跑成，而 marker 已推进 ⇒ 挂在 `ai_playerbot_boss_ability` 上的
--   `PartyPositionCoordinator::RefreshBossFacing()`（`SELECT DISTINCT … facing_mode …`）每 5 分钟报
--   `Unknown column 'facing_mode' in 'field list'`，BOSS 朝向数据完全没生效。
--   ⇒ 已按规范改成**静态 DDL**（2026-10-20 云端手工执行 ✓，44 行数据未动 ✓），新库由 CREATE TABLE 建好；
--   老库手工执行：
--   ALTER TABLE `ai_playerbot_boss_ability`
--     ADD COLUMN `facing_mode` VARCHAR(24) NOT NULL DEFAULT 'away_group'
--       COMMENT '朝向模式：away_group/fixed/open/wall' AFTER `avoid_sectors`,
--     ADD COLUMN `facing_deg`  SMALLINT     NOT NULL DEFAULT 0
--       COMMENT 'fixed 模式下的目标朝向（度）' AFTER `facing_mode`;

-- 196_BOSS能力表_LOS种子.sql（dev/analyzers 从攻略正文提取；幂等 INSERT IGNORE）
-- 让 PartyPositionCoordinator 的 LOS 触发集合有数据（category='los'）
INSERT IGNORE INTO ai_playerbot_boss_ability (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`interruptible`,`dispellable`,`generic_handling`,`needs_special`,`source`,`note`) VALUES
(556,18473,18473,0,'los',0,'','los_all',0,'guide','攻略正文提到卡视野: 柱子 |  利爪之王艾吉斯是一群勇敢鸦人极富魅力的精神领袖，他们离开了位于泰罗卡森林的家园，前去寻找某位“预示之神”。他在睡梦中见到了这位神灵，领悟了深藏在奥金顿破碎殿堂中的启示。梦中的景象使艾吉斯陷入了疯狂，他现在自称是泰罗克转世，一位鸦人神话中的神圣英雄。   整体战术：所有人靠近一根柱子，每次闪现后出现魔爆术的表情提示立刻躲到柱子后面，躲避 [魔爆术]。 秒驱 [变形术'),
(552,20870,20870,0,'los',0,'','los_all',0,'guide','攻略正文提到卡视野: 卡视角/视角/柱子 |  来自扭曲虚空的大部分生物都需要主人不断地给予指示，但少数杰出的虚空幽灵却不用主人下达这种命令。瑟雷凯斯屹立在禁魔监狱的入口处，时刻准备消灭那些胆敢挑战他的不速之客。   整体战术：和法力一王一样，所有伤害包括近战攻击都是暗影伤害；但因为对团队伤害高，总体压力比法力一王要大得多。这里通常有两种打法：  刚正面：圣骑牧师 (如果有) 上好暗抗、喝暗抗药水');

-- 198_BOSS能力表_跑位种子.sql（dev/analyzers/seed_boss_position.py 生成；幂等 INSERT IGNORE）
-- 让 PartyPositionCoordinator 的五种跑位模式有触发数据：los/frontal/knockback/stack/spread
INSERT IGNORE INTO `ai_playerbot_boss_ability` (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`,`interruptible`,`dispellable`,`generic_handling`,`needs_special`,`source`,`note`) VALUES
(540,16808,16808,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 破碎大厅/酋长卡加斯·刃拳'),
(540,16808,16808,0,'spread',0,'','跑位:分散',0,'guide','攻略: 破碎大厅/酋长卡加斯·刃拳'),
(540,16809,16809,0,'spread',0,'','跑位:分散',0,'guide','攻略: 破碎大厅/战争使者沃姆罗格'),
(540,20923,20923,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 破碎大厅/血卫士伯鲁恩'),
(542,17381,17381,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 鲜血熔炉/制造者'),
(542,17381,17381,0,'spread',0,'','跑位:分散',0,'guide','攻略: 鲜血熔炉/制造者'),
(543,17306,17306,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 地狱火城墙/巡视者加戈玛'),
(543,17306,17306,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 地狱火城墙/巡视者加戈玛'),
(543,17308,17308,0,'spread',0,'','跑位:分散',0,'guide','攻略: 地狱火城墙/无疤者奥摩尔'),
(545,17796,17796,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 蒸汽地窟/机械师斯蒂里格'),
(546,17770,17770,0,'spread',0,'','跑位:分散',0,'guide','攻略: 幽暗沼泽/霍加尔芬'),
(546,17770,17770,0,'stack',0,'','跑位:集合',0,'guide','攻略: 幽暗沼泽/霍加尔芬'),
(546,17826,17826,0,'spread',0,'','跑位:分散',0,'guide','攻略: 幽暗沼泽/沼地领主穆塞雷克'),
(546,17826,17826,0,'wall',0,'','跑位:贴墙防击飞',0,'guide','攻略: 幽暗沼泽/沼地领主穆塞雷克'),
(546,17882,17882,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 幽暗沼泽/黑色阔步者'),
(546,17882,17882,0,'spread',0,'','跑位:分散',0,'guide','攻略: 幽暗沼泽/黑色阔步者'),
(546,18105,18105,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 幽暗沼泽/加兹安'),
(546,18105,18105,0,'wall',0,'','跑位:贴墙防击飞',0,'guide','攻略: 幽暗沼泽/加兹安'),
(547,17942,17942,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 奴隶围栏/夸格米拉'),
(547,17942,17942,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 奴隶围栏/夸格米拉'),
(547,17942,17942,0,'spread',0,'','跑位:分散',0,'guide','攻略: 奴隶围栏/夸格米拉'),
(552,20870,20870,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),
(552,20870,20870,0,'los',0,'','跑位:卡视野',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),
(552,20870,20870,0,'spread',0,'','跑位:分散',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),
(552,20870,20870,0,'wall',0,'','跑位:贴墙防击飞',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),
(552,20886,20886,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 禁魔监狱/天怒预言者苏克拉底'),
(552,20912,20912,0,'spread',0,'','跑位:分散',0,'guide','攻略: 禁魔监狱/预言者斯克瑞斯'),
(553,17977,17977,0,'spread',0,'','跑位:分散',0,'guide','攻略: 生态船/迁跃扭木'),
(553,17977,17977,0,'stack',0,'','跑位:集合',0,'guide','攻略: 生态船/迁跃扭木'),
(553,17980,17980,0,'spread',0,'','跑位:分散',0,'guide','攻略: 生态船/拉伊'),
(554,19219,19219,0,'spread',0,'','跑位:分散',0,'guide','攻略: 能源舰/机械领主卡帕西图斯'),
(554,19220,19220,0,'spread',0,'','跑位:分散',0,'guide','攻略: 能源舰/计算者帕萨雷恩'),
(554,19221,19221,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 能源舰/灵术师塞比瑟蕾'),
(555,18667,18667,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),
(555,18667,18667,0,'spread',0,'','跑位:分散',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),
(555,18667,18667,0,'wall',0,'','跑位:贴墙防击飞',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),
(555,18708,18708,0,'spread',0,'','跑位:分散',0,'guide','攻略: 暗影迷宫/摩摩尔'),
(555,18708,18708,0,'stack',0,'','跑位:集合',0,'guide','攻略: 暗影迷宫/摩摩尔'),
(556,18473,18473,0,'los',0,'','跑位:卡视野',0,'guide','攻略: 塞泰克大厅/利爪之王艾吉斯'),
(557,18341,18341,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 法力陵墓/潘德莫努斯'),
(557,18343,18343,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 法力陵墓/塔瓦洛克'),
(557,18344,18344,0,'frontal',0,'','跑位:避开正面',0,'guide','攻略: 法力陵墓/节点亲王沙法尔'),
(557,22930,22930,0,'knockback',0,'','跑位:沙包/回位',0,'guide','攻略: 法力陵墓/尤尔'),
(558,18371,18371,0,'spread',0,'','跑位:分散',0,'guide','攻略: 奥金尼地穴/死亡观察者希尔拉克');

-- 200_BOSS能力表_禁站扇区种子.sql（dev/analyzers/seed_boss_avoid.py 生成；幂等 UPDATE）
-- 正面锥形 -> front；龙类甩尾/尾击 -> back；两者都有 -> 'front,back'
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `category`='frontal' AND `avoid_sectors`='';
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=16807;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=16808;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=17306;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=17307;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=17796;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='back' WHERE `boss_entry`=17798;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=17881;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='back,front' WHERE `boss_entry`=17882;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=17942;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=18096;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='back' WHERE `boss_entry`=18105;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=18343;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=18344;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=18472;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=18731;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=20870;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=20912;
UPDATE `ai_playerbot_boss_ability` SET `avoid_sectors`='front' WHERE `boss_entry`=20923;
