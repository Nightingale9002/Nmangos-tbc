-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：副本推进_路线与巡逻表结构
-- 来源（旧编号）：183_副本推进路线与巡逻表.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- =====================================================================
-- 卡布魔兽 副本拉怪：推进路线表 + 巡逻怪表 + 触发/召唤 boss 落点表
-- 目标库：世界库（tbcmangos）
--
-- 三张表配套使用（模块 DungeonRoute.cpp / DungeonPatrol.cpp / PullActions.cpp）：
--   ① ai_playerbot_dungeon_route  固定"入口 -> BOSS1 -> BOSS2 -> ..."的推进波次序；
--                                 本图每只怪一行；**同组共享同一个 ord**；坦克按组拉（不越波）。
--   ② ai_playerbot_patrol         巡逻怪及其路线点（只放类型B = 真巡逻怪）；
--                                 运行时按当前位置动态避让 / 动态判它连锁谁。
--   ③ ai_playerbot_boss_spawn     **本图所有 boss 的落点**（静态 boss 取"离入口最近的刷点"当
--                                 代表点；触发/召唤 boss 用脚本常量坐标，如帕萨雷恩 / 斯克瑞斯 / 尤尔）。
--                                 运行期 `GetBossPositions(map)` 与推进路线都读它。
--
-- 数据来源：**不在运行时现算**，一律离线生成：
--   生成器 `dev/tools/route_v2.py`（推进路线 + ord）/ `dev/tools/mob_group.py`（只做分组）
--         / `dev/tools/boss_point_gen.py`（boss 落点）；
--   汇总进编号文件（`dev/188_*.sql` 分组数据 / `dev/190_*.sql` boss 落点 / `dev/186_*.sql` 路线数据），
--   再由 apply_dev_sql.sh 入库。
--   未录入的副本 = 无路线/无巡逻数据（坦克回落原逻辑，"不越波"约束不生效）。
--
-- ⚠️ 这两张表是**派生数据**（可随时重算重灌），所以这里用 DROP + CREATE：
--    口径一变（例如新加 group_id / kind / patrol_type）不会因为"表已存在"而漏列。
--    重灌后数据由对应编号文件补回；DLL 变更只影响结构，不影响既有怪的其他表。
-- =====================================================================

DROP TABLE IF EXISTS `ai_playerbot_dungeon_route`;
CREATE TABLE `ai_playerbot_dungeon_route` (
    `map`      SMALLINT(5) UNSIGNED NOT NULL COMMENT '地图/副本 id',
    `guid`     INT(10) UNSIGNED    NOT NULL COMMENT 'creature spawn guid',
    `ord`      SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0 COMMENT '波次序：沿细化路径的弧长序，越小越靠前；同组共享同一个值；0 = 未算（只有分组）',
    `group_id` INT(10) UNSIGNED    NOT NULL DEFAULT 0 COMMENT '静态遭遇组 id（同组一起拉）；0 = 未分组',
    `kind`     TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = 静态怪；1 = 类型A巡逻怪（路线全在本组领地内，已并入本组）',
    `verified` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0
        COMMENT '1 = 该图已通过 L3 实测，允许运行时按 ord 驱动；0 = 未验证（运行时完全回落原逻辑）',
    PRIMARY KEY (`map`, `guid`),
    KEY `idx_map_ord` (`map`, `ord`),
    KEY `idx_map_grp` (`map`, `group_id`, `ord`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC
  COMMENT='副本推进路线：怪 -> 波次序 + 遭遇组（离线生成，勿手改）';

-- 每波拉怪锚点：一个 ord 一个锚点（pull/combat/party 三组坐标 + 评分）。
-- 原缺 CREATE（只有 dev/191 往里 INSERT，靠生成器手工建表）⇒ 2026-10-19 补在这里，
-- 让"整库重灌"不依赖任何手工步骤。
DROP TABLE IF EXISTS `ai_playerbot_wave_anchor`;
CREATE TABLE `ai_playerbot_wave_anchor` (
    `map`           SMALLINT(5) UNSIGNED NOT NULL COMMENT '地图/副本 id',
    `ord`           SMALLINT(5) UNSIGNED NOT NULL COMMENT '波次序（与 ai_playerbot_dungeon_route.ord 对应）',
    `group_id`      INT(10) UNSIGNED    NOT NULL DEFAULT 0 COMMENT '该波的遭遇组 id',
    `pull_x`        FLOAT NOT NULL DEFAULT 0 COMMENT '坦克拉怪位 世界X',
    `pull_y`        FLOAT NOT NULL DEFAULT 0,
    `pull_z`        FLOAT NOT NULL DEFAULT 0,
    `combat_x`      FLOAT NOT NULL DEFAULT 0 COMMENT '开打位（坦克站住的位置）',
    `combat_y`      FLOAT NOT NULL DEFAULT 0,
    `combat_z`      FLOAT NOT NULL DEFAULT 0,
    `party_x`       FLOAT NOT NULL DEFAULT 0 COMMENT '队伍待命位（其他人应停的位置）',
    `party_y`       FLOAT NOT NULL DEFAULT 0,
    `party_z`       FLOAT NOT NULL DEFAULT 0,
    `blocked_ratio` FLOAT NOT NULL DEFAULT 0 COMMENT '视线被挡比例（0~1，越大越差）',
    `dist_route`    FLOAT NOT NULL DEFAULT 0 COMMENT '锚点离推进路线的距离（码）',
    `score`         FLOAT NOT NULL DEFAULT 0 COMMENT '离线评分（越大越好）',
    `needs_corner`  TINYINT(3) UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = 需要贴墙角拉（避免引到背后的怪）',
    `verified`      TINYINT(1) UNSIGNED NOT NULL DEFAULT 0
        COMMENT '1 = 该图已通过 L3 实测，允许运行时按 ord 驱动；0 = 未验证',
    PRIMARY KEY (`map`, `ord`),
    KEY `idx_map_grp` (`map`, `group_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC
  COMMENT='每波拉怪锚点（离线生成，勿手改）';

DROP TABLE IF EXISTS `ai_playerbot_patrol`;
CREATE TABLE `ai_playerbot_patrol` (
    `map`         SMALLINT(5) UNSIGNED NOT NULL COMMENT '地图/副本 id',
    `guid`        INT(10) UNSIGNED    NOT NULL COMMENT 'creature spawn guid',
    `entry`       INT(10) UNSIGNED    NOT NULL COMMENT 'creature entry',
    `point`       SMALLINT(5) UNSIGNED NOT NULL COMMENT '路线点序号，从 0 起',
    `x`           FLOAT NOT NULL COMMENT '路线点 世界X',
    `y`           FLOAT NOT NULL COMMENT '路线点 世界Y',
    `z`           FLOAT NOT NULL COMMENT '路线点 高度',
    `detection`   FLOAT NOT NULL DEFAULT 18 COMMENT '该怪侦测距离（战斗点安全距离用）',
    `patrol_type` CHAR(1) NOT NULL DEFAULT 'B'
        COMMENT 'A = 单组巡逻（仅诊断，正常应并入 ①）；B = 跨组/无组巡逻，运行时动态避让，不占 ord',
    PRIMARY KEY (`map`, `guid`, `point`),
    KEY `idx_map_guid` (`map`, `guid`),
    KEY `idx_map_type` (`map`, `patrol_type`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC
  COMMENT='巡逻怪及其路线点（离线生成，勿手改）';

DROP TABLE IF EXISTS `ai_playerbot_boss_spawn`;
CREATE TABLE `ai_playerbot_boss_spawn` (
    `map`    SMALLINT(5) UNSIGNED NOT NULL COMMENT '地图/副本 id',
    `entry`  INT(10) UNSIGNED    NOT NULL COMMENT 'creature entry',
    `x`      FLOAT NOT NULL COMMENT '落点 世界X（静态 boss = 离入口最近的刷点；多刷点只留一行）',
    `y`      FLOAT NOT NULL COMMENT '落点 世界Y',
    `z`      FLOAT NOT NULL COMMENT '落点 高度',
    `ord`    SMALLINT(5) UNSIGNED NOT NULL DEFAULT 0
        COMMENT '该 boss 落在第几波之后（= P 的最大 ord + 1）；运行时用它判定"这条路是否走完"',
    `source` VARCHAR(64) NOT NULL DEFAULT ''
        COMMENT '来源：loot/script/rank3（可叠加，`#N` = 本图刷点数）/ 脚本常量名（触发召唤 boss）/ 手工',
    `verified` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0
        COMMENT '1 = 该图已通过 L3 实测，允许运行时按 ord 驱动；0 = 未验证',
    PRIMARY KEY (`map`, `entry`),
    KEY `idx_map_ord` (`map`, `ord`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC
  COMMENT='本图 boss 落点（静态 + 触发/召唤；离线生成，勿手改）';

-- 触发/召唤 boss 落点（坐标抄自 ScriptDevAI 脚本常量，非运行时现算）；**本文件只给这 5 行种子**，
-- 其余（含全部静态 boss）由 `dev/tools/boss_point_gen.py` 生成到 `dev/190_*.sql`：
--   543 瓦兹德 = boss_nazan_and_vazruden.cpp landingPosition（纳杉落地后召唤）；
--   543 纳杉   = 同文件 landingPhasePos（落地战斗点）；
--   552 斯克瑞斯 = arcatraz.h aSummonPosition[4]；
--   554 帕萨雷恩 = mechanar.h aBridgeEventLocs 最后一波刷点；
--   557 尤尔     = 557 里 22927 内静滞囚笼的刷点（脚本 UpdateEntry 成 22930）。
REPLACE INTO `ai_playerbot_boss_spawn` (`map`, `entry`, `x`, `y`, `z`, `ord`, `source`) VALUES
(543, 17537, -1410.5200,  1740.5850, 89.05998, 0, 'boss_nazan_and_vazruden.cpp:landingPosition'),
(543, 17536, -1429.1720,  1749.1290, 84.34760, 0, 'boss_nazan_and_vazruden.cpp:landingPhasePos'),
(552, 20912,   445.7630,  -191.6390, 44.64000, 0, 'arcatraz.h:aSummonPosition'),
(554, 19220,   139.5425,   149.3192, 25.65904, 0, 'mechanar.h:aBridgeEventLocs'),
(557, 22930,  -235.7885,   -13.0054, 17.13969, 0, 'mana_tombs:22927 stasis chamber');

-- =====================================================================
-- verified 列（2026-10-19 补）：运行时"按 ord 驱动"的总闸门
--   语义：**只有 verified=1 的图**才允许 DungeonRoute 接管坦克推进；
--         未验证图 / 列不存在时，AllowAttack 恒 true、ShouldDrive 恒 false ⇒ 零行为变化。
--   纪律：跑通一张才置 1。置 1 的动作**不写进本文件**（本文件是结构，不是放行单），
--         按 L3 实测结果手工执行，例如：
--             UPDATE `ai_playerbot_dungeon_route` SET `verified`=1 WHERE `map` IN (547,556,558);
--             UPDATE `ai_playerbot_wave_anchor`  SET `verified`=1 WHERE `map` IN (547,556,558);
--             UPDATE `ai_playerbot_boss_spawn`   SET `verified`=1 WHERE `map` IN (547,556,558);
--
-- 幂等补列：MySQL 没有 ADD COLUMN IF NOT EXISTS，用 information_schema 探测后再动态执行
--   （老库已经有这三张表、但没有 verified 列时，这一段负责补上；新建库由上面 CREATE 直接带列）
-- =====================================================================

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_playerbot_dungeon_route' AND COLUMN_NAME = 'verified');
SET @sql := IF(@has = 0,
    'ALTER TABLE `ai_playerbot_dungeon_route` ADD COLUMN `verified` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 COMMENT ''1 = 该图已通过 L3 实测''',
    'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_playerbot_wave_anchor' AND COLUMN_NAME = 'verified');
SET @sql := IF(@has = 0,
    'ALTER TABLE `ai_playerbot_wave_anchor` ADD COLUMN `verified` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 COMMENT ''1 = 该图已通过 L3 实测''',
    'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @has := (SELECT COUNT(*) FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_playerbot_boss_spawn' AND COLUMN_NAME = 'verified');
SET @sql := IF(@has = 0,
    'ALTER TABLE `ai_playerbot_boss_spawn` ADD COLUMN `verified` TINYINT(1) UNSIGNED NOT NULL DEFAULT 0 COMMENT ''1 = 该图已通过 L3 实测''',
    'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SELECT 'verified 列就绪' AS status,
       (SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND COLUMN_NAME = 'verified'
          AND TABLE_NAME IN ('ai_playerbot_dungeon_route','ai_playerbot_wave_anchor','ai_playerbot_boss_spawn')) AS tables_with_verified;
