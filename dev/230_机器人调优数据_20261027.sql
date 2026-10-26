-- =============================================================================
-- 机器人（playerbots）调优数据快照 — 2026-10-27
--
-- 本文件 = 下列表的**最终状态**（结构 + 数据），数据直接从本地 world 库导出：
--   %s
--
-- 合并来源（原文件已删除）：184/187/188/189/191/192/193/194/195/201/204-222/227/229。
-- 保留的独立数据集：183/185（路线/巡逻）、223/224（拉怪代价/顺序）、228（卡视野点结构）、
--   180/181（台词）、186/199（观测与拉怪日志结构）、190（升降台观测结构）、203（easy_waves）。
--
-- 用法：**最后执行**。可重复执行（CREATE IF NOT EXISTS + REPLACE INTO）。
-- 注意：REPLACE 是“先删后插”，对 (map, ...) 主键行等价于覆盖；运行时表（pull_log/priority_obs）不在本文件内。
-- =============================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
-- (snapshot) DROP removed: `ai_playerbot_avoid_mob`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_avoid_mob` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_avoid_spell`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_avoid_spell` (
  `map` smallint unsigned NOT NULL,
  `spell_id` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '25',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_ability`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_ability` (
  `map` smallint unsigned NOT NULL COMMENT '地图/副本 id',
  `boss_entry` int unsigned NOT NULL COMMENT 'BOSS 本体 entry（召唤物的行也填它所属的 boss）',
  `owner_entry` int unsigned NOT NULL DEFAULT '0' COMMENT '实际施法单位 entry：boss 本体=boss_entry；召唤物/图腾=它自己的 entry',
  `spell_id` int unsigned NOT NULL COMMENT 'spell_template.Id（未匹配到 = 0，靠 note 保留攻略名字）',
  `category` varchar(24) NOT NULL DEFAULT 'other' COMMENT 'heal/control/interrupt/dispel/aoe/move/summon/buff/damage/other',
  `interruptible` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '是否可打断（0/1）',
  `dispellable` varchar(16) NOT NULL DEFAULT '' COMMENT '可驱散类型：magic/disease/curse/poison（空=不可驱散/未知）',
  `avoid_sectors` varchar(32) NOT NULL DEFAULT '' COMMENT '禁站扇区：front/right/back/left（60° 一档，逗号分隔）',
  `facing_mode` varchar(24) NOT NULL DEFAULT 'away_group' COMMENT '朝向模式：away_group/fixed/open/wall',
  `facing_deg` smallint NOT NULL DEFAULT '0' COMMENT 'fixed 模式下的目标朝向（度）',
  `generic_handling` varchar(32) NOT NULL DEFAULT '' COMMENT '交给哪条通用链路（空 = 通用处理不了）',
  `needs_special` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = 需要单独策略',
  `source` enum('guide','db','observed') NOT NULL DEFAULT 'guide' COMMENT '数据来源',
  `note` varchar(255) NOT NULL DEFAULT '' COMMENT '攻略原文/补充说明',
  PRIMARY KEY (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`),
  KEY `idx_needs_special` (`needs_special`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='副本 BOSS/召唤物技能与效果，决定"通用处理 or 单独策略"';
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_arena`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_arena` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `kind` enum('hold','spread','bounds') NOT NULL,
  `role` enum('tank','dps','heal','all') NOT NULL,
  `idx` tinyint unsigned NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `tol` float NOT NULL DEFAULT '3',
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`boss_entry`,`kind`,`role`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_position`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_position` (
  `entry` int unsigned NOT NULL COMMENT 'BOSS 的 creature entry',
  `map` int unsigned NOT NULL DEFAULT '0' COMMENT '地图 id（0 = 不限地图）',
  `bot_role` varchar(16) NOT NULL COMMENT 'tank / healer / melee / ranged',
  `x` float NOT NULL DEFAULT '0' COMMENT '站位 世界X',
  `y` float NOT NULL DEFAULT '0' COMMENT '站位 世界Y',
  `z` float NOT NULL DEFAULT '0' COMMENT '站位 高度',
  `radius` float NOT NULL DEFAULT '8' COMMENT '战场半径/到点容差（码），超出就回来',
  PRIMARY KEY (`entry`,`bot_role`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC COMMENT='每个 BOSS 的角色站位（playerbot，`.bot bosspos` 维护）';
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_require`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_require` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `req_entry` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '40',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`boss_entry`,`req_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_spawn`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_spawn` (
  `map` smallint unsigned NOT NULL COMMENT '地图/副本 id',
  `entry` int unsigned NOT NULL COMMENT 'creature entry',
  `x` float NOT NULL COMMENT '落点 世界X（静态 boss = 离入口最近的刷点；多刷点只留一行）',
  `y` float NOT NULL COMMENT '落点 世界Y',
  `z` float NOT NULL COMMENT '落点 高度',
  `ord` smallint unsigned NOT NULL DEFAULT '0' COMMENT '该 boss 落在第几波之后（= P 的最大 ord + 1）；运行时用它判定"这条路是否走完"',
  `source` varchar(64) NOT NULL DEFAULT '' COMMENT '来源：loot/script/rank3（可叠加，`#N` = 本图刷点数）/ 脚本常量名（触发召唤 boss）/ 手工',
  `verified` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = 该图已通过 L3 实测，允许运行时按 ord 驱动；0 = 未验证',
  PRIMARY KEY (`map`,`entry`),
  KEY `idx_map_ord` (`map`,`ord`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC COMMENT='本图 boss 落点（静态 + 触发/召唤；离线生成，勿手改）';
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_switch`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_switch` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `go_guid` int unsigned NOT NULL,
  `go_entry` int unsigned NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `kind` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=boss 战后点开关',
  `note` varchar(96) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`go_guid`),
  KEY `idx_boss` (`boss_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_boss_strategy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_strategy` (
  `entry` int unsigned NOT NULL,
  `note` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_cc_creature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_cc_creature` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `has_fear` tinyint unsigned NOT NULL DEFAULT '0',
  `has_spell` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_custom_strategy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_custom_strategy` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `idx` bigint DEFAULT NULL,
  `owner` bigint DEFAULT NULL,
  `action_line` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1957 DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_decision_weight`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_decision_weight` (
  `key` varchar(64) NOT NULL COMMENT '决策项.因子，例 target.threat_tier',
  `weight` float NOT NULL DEFAULT '0' COMMENT '权重（线性加权求和；负值=惩罚）',
  `note` varchar(255) NOT NULL DEFAULT '' COMMENT '说明/调参记录',
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='playerbot 决策打分权重（离线调参/RL 入口）';
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_dungeon_stage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_dungeon_stage` (
  `map` smallint unsigned NOT NULL,
  `stage_ord` smallint unsigned NOT NULL,
  `kind` varchar(16) NOT NULL,
  `target_entry` int unsigned NOT NULL DEFAULT '0',
  `anchor_x` float NOT NULL DEFAULT '0',
  `anchor_y` float NOT NULL DEFAULT '0',
  `radius` float NOT NULL DEFAULT '0',
  `count_limit` int unsigned NOT NULL DEFAULT '0',
  `keep_out` float NOT NULL DEFAULT '0',
  `note` varchar(160) NOT NULL DEFAULT '',
  `wait_ms` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`map`,`stage_ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_mob_count_weight`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_mob_count_weight` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '25',
  `engage_count` smallint unsigned NOT NULL DEFAULT '8',
  `weight_per_count` float NOT NULL DEFAULT '0.15',
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_priority_target`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_priority_target` (
  `entry` int unsigned NOT NULL,
  `priority` tinyint unsigned NOT NULL,
  `source` varchar(16) NOT NULL,
  `reason` varchar(255) NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_pull_first`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_pull_first` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `max_dist` float NOT NULL DEFAULT '30',
  `max_adds` int unsigned NOT NULL DEFAULT '2',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_pull_wait`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_pull_wait` (
  `map` smallint unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '40',
  `max_assist` int unsigned NOT NULL DEFAULT '1',
  `wait_enemy_fight` tinyint unsigned NOT NULL DEFAULT '1',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_pullback`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_pullback` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `dist` float NOT NULL DEFAULT '40',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_route_link`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_route_link` (
  `map` smallint unsigned NOT NULL,
  `src_x` float NOT NULL,
  `src_y` float NOT NULL,
  `src_z` float NOT NULL,
  `dst_x` float NOT NULL,
  `dst_y` float NOT NULL,
  `dst_z` float NOT NULL,
  `kind` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=跳点 1=升降台/传送点',
  `note` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`src_x`,`src_y`,`src_z`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_skip_entry`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_skip_entry` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_unreachable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_unreachable` (
  `map` smallint unsigned NOT NULL,
  `guid` int unsigned NOT NULL,
  `reason` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_weightscale_caps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_weightscale_caps` (
  `id` int NOT NULL,
  `field` varchar(18) NOT NULL,
  `cap` int unsigned NOT NULL,
  `capped` int unsigned NOT NULL,
  `alt_field` varchar(18) NOT NULL DEFAULT '',
  `alt_cap` int unsigned NOT NULL DEFAULT '0',
  `cap2` int unsigned NOT NULL DEFAULT '0',
  `capped2` int unsigned NOT NULL DEFAULT '0',
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_weightscale_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_weightscale_data` (
  `id` int NOT NULL,
  `field` varchar(18) NOT NULL,
  `val` smallint unsigned NOT NULL,
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;
/*!40101 SET character_set_client = @saved_cs_client */;
-- (snapshot) DROP removed: `ai_playerbot_weightscales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE IF NOT EXISTS `ai_playerbot_weightscales` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=COMPACT;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;



-- ===== 数据 =====


/*!50503 SET NAMES utf8mb4 */;
DROP TABLE IF EXISTS `ai_playerbot_avoid_mob`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_avoid_mob` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_avoid_mob` (`map`, `entry`, `note`) VALUES (558,18506,'Raging Soul：无敌+击飞，被打飞掉桥会死；按躲地板处理，不拉');
DROP TABLE IF EXISTS `ai_playerbot_avoid_spell`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_avoid_spell` (
  `map` smallint unsigned NOT NULL,
  `spell_id` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '25',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_avoid_spell` (`map`, `spell_id`, `radius`, `note`) VALUES (542,33775,25,'Keli\'dan Fire Nova (normal): run out of 20yd'),(542,37371,25,'Keli\'dan Fire Nova (heroic): run out of 20yd');
DROP TABLE IF EXISTS `ai_playerbot_boss_ability`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_ability` (
  `map` smallint unsigned NOT NULL COMMENT '地图/副本 id',
  `boss_entry` int unsigned NOT NULL COMMENT 'BOSS 本体 entry（召唤物的行也填它所属的 boss）',
  `owner_entry` int unsigned NOT NULL DEFAULT '0' COMMENT '实际施法单位 entry：boss 本体=boss_entry；召唤物/图腾=它自己的 entry',
  `spell_id` int unsigned NOT NULL COMMENT 'spell_template.Id（未匹配到 = 0，靠 note 保留攻略名字）',
  `category` varchar(24) NOT NULL DEFAULT 'other' COMMENT 'heal/control/interrupt/dispel/aoe/move/summon/buff/damage/other',
  `interruptible` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '是否可打断（0/1）',
  `dispellable` varchar(16) NOT NULL DEFAULT '' COMMENT '可驱散类型：magic/disease/curse/poison（空=不可驱散/未知）',
  `avoid_sectors` varchar(32) NOT NULL DEFAULT '' COMMENT '禁站扇区：front/right/back/left（60° 一档，逗号分隔）',
  `facing_mode` varchar(24) NOT NULL DEFAULT 'away_group' COMMENT '朝向模式：away_group/fixed/open/wall',
  `facing_deg` smallint NOT NULL DEFAULT '0' COMMENT 'fixed 模式下的目标朝向（度）',
  `generic_handling` varchar(32) NOT NULL DEFAULT '' COMMENT '交给哪条通用链路（空 = 通用处理不了）',
  `needs_special` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = 需要单独策略',
  `source` enum('guide','db','observed') NOT NULL DEFAULT 'guide' COMMENT '数据来源',
  `note` varchar(255) NOT NULL DEFAULT '' COMMENT '攻略原文/补充说明',
  PRIMARY KEY (`map`,`boss_entry`,`owner_entry`,`spell_id`,`category`),
  KEY `idx_needs_special` (`needs_special`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='副本 BOSS/召唤物技能与效果，决定"通用处理 or 单独策略"';

REPLACE INTO `ai_playerbot_boss_ability` (`map`, `boss_entry`, `owner_entry`, `spell_id`, `category`, `interruptible`, `dispellable`, `avoid_sectors`, `facing_mode`, `facing_deg`, `generic_handling`, `needs_special`, `source`, `note`) VALUES (540,16808,16808,0,'knockback',0,'','front','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 破碎大厅/酋长卡加斯·刃拳'),(540,16808,16808,0,'spread',0,'','front','away_group',0,'跑位:分散',0,'guide','攻略: 破碎大厅/酋长卡加斯·刃拳'),(540,16809,16809,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 破碎大厅/战争使者沃姆罗格'),(540,20923,20923,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 破碎大厅/血卫士伯鲁恩'),(542,17381,17381,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 鲜血熔炉/制造者'),(542,17381,17381,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 鲜血熔炉/制造者'),(543,17306,17306,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 地狱火城墙/巡视者加戈玛'),(543,17306,17306,0,'knockback',0,'','front','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 地狱火城墙/巡视者加戈玛'),(543,17308,17308,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 地狱火城墙/无疤者奥摩尔'),(545,17796,17796,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 蒸汽地窟/机械师斯蒂里格'),(546,17770,17770,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 幽暗沼泽/霍加尔芬'),(546,17770,17770,0,'stack',0,'','','away_group',0,'跑位:集合',0,'guide','攻略: 幽暗沼泽/霍加尔芬'),(546,17826,17826,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 幽暗沼泽/沼地领主穆塞雷克'),(546,17826,17826,0,'wall',0,'','','away_group',0,'跑位:贴墙防击飞',0,'guide','攻略: 幽暗沼泽/沼地领主穆塞雷克'),(546,17882,17882,0,'frontal',0,'','back,front','away_group',0,'跑位:避开正面',0,'guide','攻略: 幽暗沼泽/黑色阔步者'),(546,17882,17882,0,'spread',0,'','back,front','away_group',0,'跑位:分散',0,'guide','攻略: 幽暗沼泽/黑色阔步者'),(546,18105,18105,0,'knockback',0,'','back','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 幽暗沼泽/加兹安'),(546,18105,18105,0,'wall',0,'','back','away_group',0,'跑位:贴墙防击飞',0,'guide','攻略: 幽暗沼泽/加兹安'),(547,17942,17942,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 奴隶围栏/夸格米拉'),(547,17942,17942,0,'knockback',0,'','front','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 奴隶围栏/夸格米拉'),(547,17942,17942,0,'spread',0,'','front','away_group',0,'跑位:分散',0,'guide','攻略: 奴隶围栏/夸格米拉'),(552,20870,20870,0,'knockback',0,'','front','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),(552,20870,20870,0,'los',0,'','front','away_group',0,'los_all',0,'guide','攻略正文提到卡视野: 卡视角/视角/柱子 |  来自扭曲虚空的大部分生物都需要主人不断地给予指示，但少数杰出的虚空幽灵却不用主人下达这种命令。瑟雷凯斯屹立在禁魔监狱的入口处，时刻准备消灭那些胆敢挑战他的不速之客。   整体战术：和法力一王一样，所有伤害包括近战攻击都是暗影伤害；但因为对团队伤害高，总体压力比法力一王要大得多。这里通常有两种打法：  刚正面：圣骑牧师 (如果有) 上好暗抗、喝暗抗药水'),(552,20870,20870,0,'spread',0,'','front','away_group',0,'跑位:分散',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),(552,20870,20870,0,'wall',0,'','front','away_group',0,'跑位:贴墙防击飞',0,'guide','攻略: 禁魔监狱/自由的瑟雷凯斯'),(552,20886,20886,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 禁魔监狱/天怒预言者苏克拉底'),(552,20912,20912,0,'spread',0,'','front','away_group',0,'跑位:分散',0,'guide','攻略: 禁魔监狱/预言者斯克瑞斯'),(553,17977,17977,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 生态船/迁跃扭木'),(553,17977,17977,0,'stack',0,'','','away_group',0,'跑位:集合',0,'guide','攻略: 生态船/迁跃扭木'),(553,17980,17980,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 生态船/拉伊'),(554,19219,19219,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 能源舰/机械领主卡帕西图斯'),(554,19220,19220,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 能源舰/计算者帕萨雷恩'),(554,19221,19221,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 能源舰/灵术师塞比瑟蕾'),(555,18667,18667,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),(555,18667,18667,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),(555,18667,18667,0,'wall',0,'','','away_group',0,'跑位:贴墙防击飞',0,'guide','攻略: 暗影迷宫/煽动者布莱卡特'),(555,18708,18708,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 暗影迷宫/摩摩尔'),(555,18708,18708,0,'stack',0,'','','away_group',0,'跑位:集合',0,'guide','攻略: 暗影迷宫/摩摩尔'),(556,18473,0,38197,'los_break',0,'','','away_group',0,'',1,'guide','魔爆术（普通）：读条时卡柱子断视线'),(556,18473,0,38245,'los_break',0,'magic','','away_group',0,'',1,'guide','变形术（普通）：读条时卡柱子断视线'),(556,18473,0,40425,'los_break',0,'','','away_group',0,'',1,'guide','魔爆术（英雄）：读条时卡柱子断视线'),(556,18473,0,43309,'los_break',0,'magic','','away_group',0,'',1,'guide','变形术（英雄）：读条时卡柱子断视线'),(556,18473,18473,0,'los',0,'','','away_group',0,'los_all',0,'guide','攻略正文提到卡视野: 柱子 |  利爪之王艾吉斯是一群勇敢鸦人极富魅力的精神领袖，他们离开了位于泰罗卡森林的家园，前去寻找某位“预示之神”。他在睡梦中见到了这位神灵，领悟了深藏在奥金顿破碎殿堂中的启示。梦中的景象使艾吉斯陷入了疯狂，他现在自称是泰罗克转世，一位鸦人神话中的神圣英雄。   整体战术：所有人靠近一根柱子，每次闪现后出现魔爆术的表情提示立刻躲到柱子后面，躲避 [魔爆术]。 秒驱 [变形术'),(557,18341,18341,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 法力陵墓/潘德莫努斯'),(557,18343,18343,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 法力陵墓/塔瓦洛克'),(557,18344,18344,0,'frontal',0,'','front','away_group',0,'跑位:避开正面',0,'guide','攻略: 法力陵墓/节点亲王沙法尔'),(557,22930,22930,0,'knockback',0,'','','away_group',0,'跑位:沙包/回位',0,'guide','攻略: 法力陵墓/尤尔'),(558,18371,18371,0,'spread',0,'','','away_group',0,'跑位:分散',0,'guide','攻略: 奥金尼地穴/死亡观察者希尔拉克');
DROP TABLE IF EXISTS `ai_playerbot_boss_arena`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_arena` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `kind` enum('hold','spread','bounds') NOT NULL,
  `role` enum('tank','dps','heal','all') NOT NULL,
  `idx` tinyint unsigned NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `tol` float NOT NULL DEFAULT '3',
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`boss_entry`,`kind`,`role`,`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3;

REPLACE INTO `ai_playerbot_boss_arena` (`map`, `boss_entry`, `kind`, `role`, `idx`, `x`, `y`, `z`, `tol`, `note`) VALUES (540,16808,'hold','tank',0,243.7,-84.09,6.17,3,'Kargath red circle: tank holds boss here'),(540,16808,'bounds','all',0,231.48,-84.18,6.22,20,'Kargath arena center/radius');
DROP TABLE IF EXISTS `ai_playerbot_boss_position`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_position` (
  `entry` int unsigned NOT NULL COMMENT 'BOSS 的 creature entry',
  `map` int unsigned NOT NULL DEFAULT '0' COMMENT '地图 id（0 = 不限地图）',
  `bot_role` varchar(16) NOT NULL COMMENT 'tank / healer / melee / ranged',
  `x` float NOT NULL DEFAULT '0' COMMENT '站位 世界X',
  `y` float NOT NULL DEFAULT '0' COMMENT '站位 世界Y',
  `z` float NOT NULL DEFAULT '0' COMMENT '站位 高度',
  `radius` float NOT NULL DEFAULT '8' COMMENT '战场半径/到点容差（码），超出就回来',
  PRIMARY KEY (`entry`,`bot_role`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC COMMENT='每个 BOSS 的角色站位（playerbot，`.bot bosspos` 维护）';

REPLACE INTO `ai_playerbot_boss_position` (`entry`, `map`, `bot_role`, `x`, `y`, `z`, `radius`) VALUES (16808,540,'tank',248.386,-84.1944,4.93864,8),(16808,540,'ranged',223.496,-83.673,4.9401,12),(16808,540,'melee',245.327,-83.805,4.9401,5),(16808,540,'healer',223.496,-83.673,4.9401,12);
DROP TABLE IF EXISTS `ai_playerbot_boss_require`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_require` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `req_entry` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '40',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`boss_entry`,`req_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_boss_require` (`map`, `boss_entry`, `req_entry`, `radius`, `note`) VALUES (555,18731,18794,40,'Hellmaw banished: clear Cabal Ritualists around him first');
DROP TABLE IF EXISTS `ai_playerbot_boss_spawn`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_spawn` (
  `map` smallint unsigned NOT NULL COMMENT '地图/副本 id',
  `entry` int unsigned NOT NULL COMMENT 'creature entry',
  `x` float NOT NULL COMMENT '落点 世界X（静态 boss = 离入口最近的刷点；多刷点只留一行）',
  `y` float NOT NULL COMMENT '落点 世界Y',
  `z` float NOT NULL COMMENT '落点 高度',
  `ord` smallint unsigned NOT NULL DEFAULT '0' COMMENT '该 boss 落在第几波之后（= P 的最大 ord + 1）；运行时用它判定"这条路是否走完"',
  `source` varchar(64) NOT NULL DEFAULT '' COMMENT '来源：loot/script/rank3（可叠加，`#N` = 本图刷点数）/ 脚本常量名（触发召唤 boss）/ 手工',
  `verified` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = 该图已通过 L3 实测，允许运行时按 ord 驱动；0 = 未验证',
  PRIMARY KEY (`map`,`entry`),
  KEY `idx_map_ord` (`map`,`ord`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 ROW_FORMAT=DYNAMIC COMMENT='本图 boss 落点（静态 + 触发/召唤；离线生成，勿手改）';

REPLACE INTO `ai_playerbot_boss_spawn` (`map`, `entry`, `x`, `y`, `z`, `ord`, `source`, `verified`) VALUES (543,17308,-1122.34,1718.41,89.431,2,'loot+script',0),(552,20870,275.788,-123.343,-10.123,0,'loot',0),(554,19219,210.416,15.641,-2.192,0,'loot+script',0),(557,18341,-67.325,-120.09,-1.283,1,'loot+script',0),(30,11946,-1370.88,-220.208,98.51,0,'rank3',0),(30,11947,-545.23,-165.35,57.014,0,'rank3',0),(30,11948,722.43,-10.998,50.705,0,'rank3',0),(33,4275,-76.754,2152.41,155.792,0,'script',0),(36,646,-22.847,-797.283,20.374,0,'script',0),(70,2748,104.338,272.31,-51.696,0,'script',0),(90,7800,-531.324,670.159,-325.185,0,'script',0),(109,5708,-467.617,-2.193,-148.802,0,'loot',0),(109,5719,-646.48,122.121,-90.829,0,'loot',0),(109,5722,-649.679,131.596,-90.829,0,'loot',0),(189,3975,1965.09,-431.607,6.261,0,'script',0),(189,3976,1153.87,1398.39,32.611,0,'script',0),(189,3977,1202.13,1399.07,29.093,0,'script',0),(189,6487,148.32,-428.692,18.486,0,'loot+script',0),(209,7271,1912.17,1016.11,11.599,0,'script',0),(229,9568,-22.633,-486.186,90.753,0,'script',0),(229,9816,144.59,-258.05,96.5,0,'script+rank3',0),(229,10363,36.451,-285.994,111.036,0,'rank3',0),(229,10430,87.38,-554.12,111.1,0,'rank3',0),(230,8929,1384.64,-831.486,-87.589,0,'script',0),(230,9018,310.558,-146.251,-70.303,0,'script',0),(230,9019,1380.18,-831.645,-87.59,0,'script',0),(230,9033,652.39,21.374,-59.976,0,'script',0),(230,9039,1281.14,-282.151,-78.136,0,'script',0),(230,9156,1009.75,-239.017,-61.304,0,'script',0),(230,9499,888.472,-177.929,-42.962,0,'script',0),(230,23872,891.839,-129.183,-49.66,0,'script',0),(249,10184,-4.869,-217.171,-86.71,0,'loot+script+rank3',0),(269,15608,-2025.3,7119.58,22.747,0,'rank3',0),(289,10502,265.956,0.903,75.333,0,'loot',0),(289,10503,268.223,73.633,95.924,0,'script',0),(289,10504,178.724,-91.023,70.857,0,'loot',0),(289,10505,86.663,-1.96,85.312,0,'loot',0),(289,10507,103.305,-1.678,75.218,0,'loot',0),(289,10508,-25.108,141.284,83.908,0,'loot',0),(289,10901,274.877,1.334,85.312,0,'loot',0),(289,11261,182.246,-95.437,85.312,0,'loot',0),(309,11380,-11515.8,-1275.48,79.662,0,'loot+rank3',0),(309,11382,-12167.8,-1927.25,153.73,0,'loot+script+rank3',0),(309,14507,-12029.8,-1707.93,39.413,0,'loot+script+rank3',0),(309,14509,-11700.8,-1998.94,62.416,0,'loot+script+rank3',0),(309,14510,-12326.5,-1577.11,133.588,0,'loot+script+rank3',0),(309,14517,-12291.9,-1380.08,144.902,0,'loot+script+rank3',0),(309,14834,-11787.4,-1649.34,54.102,0,'loot+script+rank3',0),(329,10436,3855.34,-3715.75,148.175,0,'script',0),(329,10438,4035.81,-3647.78,135.738,0,'script',0),(329,10812,3415.84,-3044.54,136.814,0,'script',0),(329,10997,3573.57,-2937.31,125.085,0,'script',0),(349,12201,27.898,83.193,-124.483,0,'loot',0),(349,13282,1130.4,-191.342,-80.001,0,'script',0),(409,11982,1144.63,-1020.48,-185.663,0,'loot+script+rank3',0),(409,11988,793.248,-998.265,-206.762,0,'loot+script+rank3',0),(409,12056,747.547,-981.676,-178.401,0,'loot+script+rank3',0),(409,12057,679.838,-497.988,-213.733,0,'loot+script+rank3',0),(409,12098,601.087,-1179.11,-195.882,0,'loot+script+rank3',0),(409,12118,1000.2,-955.407,-179.583,0,'loot+script+rank3',0),(409,12259,898.074,-545.87,-203.405,0,'loot+script+rank3',0),(409,12264,583.49,-799.755,-205.356,0,'loot+script+rank3',0),(429,14323,550.38,533.725,-25.319,0,'loot',0),(429,14326,410.711,-3.15,-24.558,0,'loot',0),(469,10162,-7588.27,-1261.92,482.03,0,'script+rank3',0),(469,11981,-7407.94,-1031.04,477.35,0,'loot+script+rank3',0),(469,11983,-7433.38,-923.829,465.354,0,'loot+script+rank3',0),(469,12017,-7573.89,-1035.25,449.248,0,'loot+script+rank3',0),(469,12435,-7571.7,-1088.25,413.465,0,'loot+script+rank3',0),(469,13020,-7483.79,-1015.99,408.652,0,'loot+script+rank3',0),(469,14020,-7515.34,-1029.62,476.73,0,'loot+script+rank3',0),(469,14601,-7358.19,-994.32,477.35,0,'loot+script+rank3',0),(509,15339,-9493.6,2030.27,105.48,0,'loot+script+rank3',0),(509,15340,-8845.52,2260.14,21.47,0,'loot+script+rank3',0),(509,15341,-9129.73,1602.5,26.544,0,'loot+rank3',0),(509,15348,-8824.54,1629.52,20.446,0,'loot+script+rank3',0),(509,15369,-9719.61,1514.75,27.552,0,'loot+script+rank3',0),(509,15370,-9235.98,1234.07,-63.658,0,'loot+script+rank3',0),(531,15263,-8346.05,2080.98,125.732,0,'loot+script+rank3',0),(531,15275,-9023.67,1176.24,-104.226,0,'loot+script+rank3',0),(531,15276,-8868.31,1205.97,-104.231,0,'loot+script+rank3',0),(531,15299,-8000.18,928.603,-51.901,0,'loot+script+rank3',0),(531,15378,-8652.15,2020.91,108.661,0,'rank3',0),(531,15379,-8660.59,2022.34,108.661,0,'rank3',0),(531,15380,-8663.46,2029.89,108.661,0,'rank3',0),(531,15509,-8532.09,1696.53,-90.26,0,'loot+script+rank3',0),(531,15510,-8085.39,1196.72,-91.97,0,'loot+script+rank3',0),(531,15511,-8566.88,2177.17,-3.979,0,'loot+script+rank3',0),(531,15516,-8281.88,1688.65,-25.941,0,'loot+script+rank3',0),(531,15543,-8587.96,2174.21,-4.148,0,'loot+script+rank3',0),(531,15544,-8544.09,2165,-3.477,0,'loot+script+rank3',0),(531,15589,-8578.79,1986.18,100.304,0,'script+rank3',0),(531,15727,-8578.65,1985.85,100.304,0,'loot+script+rank3',0),(531,15963,-8953.3,1233.64,-99.718,0,'rank3',0),(532,15687,-10982.7,-1877.93,81.812,0,'loot+script+rank3',0),(532,15688,-11240.6,-1704.27,179.32,0,'loot+script+rank3',0),(532,15689,-11089.4,-1615.26,279.362,0,'loot+script+rank3',0),(532,15690,-10926.3,-2011.54,275.686,0,'loot+script+rank3',0),(532,15691,-11194.2,-1875.34,153.544,0,'loot+script+rank3',0),(532,16151,-11126.3,-1929.11,49.329,0,'script+rank3',0),(532,16457,-10945.9,-2103.79,92.794,0,'loot+script+rank3',0),(532,16524,-11164.5,-1909.56,232.009,0,'loot+script+rank3',0),(532,16816,-11099.8,-1852.39,221.07,0,'rank3',0),(532,17225,-11003.7,-1760.19,140.253,0,'loot+script+rank3',0),(533,15928,3508.02,-2931.33,303.015,0,'loot+script+rank3',0),(533,15929,3449.03,-2934.74,312.18,0,'script+rank3',0),(533,15930,3508.85,-2994.08,312.18,0,'script+rank3',0),(533,15931,3253.28,-3310.71,292.678,0,'script+rank3',0),(533,15932,3283.09,-3156.96,297.788,0,'script+rank3',0),(533,15936,2795.29,-3708.85,276.563,0,'script+rank3',0),(533,15952,3503.04,-3919.22,297.6,0,'loot+script+rank3',0),(533,15953,3353.25,-3620.1,261.08,0,'script+rank3',0),(533,15954,2677.99,-3485.05,261.29,0,'script+rank3',0),(533,15956,3316.47,-3476.23,287.26,0,'script+rank3',0),(533,15990,3746.41,-5113.35,142.031,0,'loot+script+rank3',0),(533,16011,2909.43,-3999.46,274.28,0,'loot+script+rank3',0),(533,16028,3308.46,-3232.08,294.24,0,'script+rank3',0),(533,16060,2642.2,-3388.39,285.6,0,'script+rank3',0),(533,16061,2755.56,-3098.04,267.86,0,'script+rank3',0),(533,16062,2524.32,-2951.28,245.633,0,'script+rank3',0),(533,16063,2528.79,-2948.58,245.633,0,'script+rank3',0),(533,16064,2520.5,-2955.38,245.635,0,'script+rank3',0),(533,16065,2517.62,-2959.38,245.636,0,'script+rank3',0),(534,17772,5084.07,-1789.03,1322.65,0,'rank3',0),(534,17852,5450.54,-2723.97,1485.59,0,'rank3',0),(534,17948,5184.97,-3383.56,1638.26,0,'rank3',0),(540,16807,178.928,289.487,-8.187,1,'loot+script',0),(540,16808,231.25,-83.645,5.023,4,'loot+script',0),(540,16809,375.12,57.578,-7.216,3,'loot+script',0),(540,20923,512.687,315.652,2.041,2,'loot',0),(542,17377,326.503,-86.003,-24.577,3,'loot+script',0),(542,17380,455.336,-1.829,9.63,2,'loot+script',0),(542,17381,328.127,128.866,9.619,1,'loot',0),(543,17307,-1363.89,1728.03,105.865,3,'script',0),(543,17306,-1164.29,1516.02,68.51,1,'loot+script',0),(544,17256,10.478,23.991,0.714,0,'rank3#5',0),(544,17257,-18.701,2.241,-0.321,0,'loot+script+rank3',0),(544,18829,36.449,2.03,45.139,0,'rank3#12',0),(545,17796,-330.083,-121.505,-7.985,2,'loot+script',0),(545,17797,88.397,-316.111,-7.787,1,'loot+script',0),(545,17798,-95.419,-552.031,8.27,3,'loot+script',0),(546,17770,-121.344,-388.626,36.866,1,'loot+script',0),(546,17826,288.582,-121.831,29.703,3,'loot+script',0),(546,17882,141.659,32.42,26.831,4,'loot+script',0),(546,18105,278.241,-446.206,40.64,2,'loot',0),(547,17941,49.476,-380.219,3.036,1,'loot',0),(547,17942,-281.096,-667.139,9.402,3,'loot',0),(547,17991,18.321,-448.448,3.056,2,'loot',0),(548,21212,29.99,-922.409,42.985,0,'loot+script+rank3',0),(548,21213,370.829,-723.939,-14.005,0,'loot+script+rank3',0),(548,21214,456.869,-539.741,-7.464,0,'loot+script+rank3',0),(548,21215,376.543,-438.631,29.608,0,'loot+script+rank3',0),(548,21216,-239.843,-366.494,-0.745,0,'loot+script+rank3',0),(548,21964,462.676,-546.957,-7.463,0,'script',0),(548,21965,462.519,-533.391,-7.465,0,'script',0),(548,21966,465.738,-540.036,-7.464,0,'script',0),(550,18805,432.74,-373.645,18.014,0,'loot+script+rank3',0),(550,19514,370.328,-32.595,44.086,0,'loot+script+rank3',0),(550,19516,424.235,403.475,14.977,0,'loot+script+rank3',0),(550,19622,795.408,-1.605,48.812,0,'loot+script+rank3',0),(550,20060,785.782,-20.399,48.812,0,'script+rank3',0),(550,20062,792.408,-13.242,48.812,0,'script+rank3',0),(550,20063,792.725,12.775,48.812,0,'script+rank3',0),(550,20064,785.807,19.486,48.812,0,'script+rank3',0),(552,20885,137.234,128.506,22.524,0,'loot+script',0),(552,20886,136.2,168.31,22.524,0,'loot+script',0),(552,20912,445.763,-191.639,44.64,26,'arcatraz.h:aSummonPosition',0),(553,17975,116.326,455.57,-4.941,2,'loot+script',0),(553,17976,125.729,321.185,-3.636,1,'loot',0),(553,17977,63.841,391.882,-27.894,5,'loot+script',0),(553,17978,4.949,596.578,-15.078,3,'loot+script',0),(553,17980,-204.125,391.249,-11.194,4,'loot+script',0),(554,19220,139.542,149.319,25.659,4,'mechanar.h:aBridgeEventLocs',0),(554,19221,326.517,13.196,27.92,0,'loot+script',0),(555,18667,-328.209,-39.05,12.689,2,'loot+script',0),(555,18708,-157.895,-497.322,15.865,4,'loot+script',0),(555,18731,-156.675,4.983,8.156,1,'loot+script',0),(555,18732,-253.548,-263.646,17.17,3,'loot+script',0),(556,18472,-144.827,173.557,1.769,1,'loot+script',0),(556,18473,44.723,286.96,25.152,2,'loot+script',0),(557,18343,-321.717,-222.183,-0.778,2,'loot',0),(557,18344,-184.366,9.333,16.817,4,'loot+script',0),(557,22930,-235.788,-13.005,17.14,3,'mana_tombs:22927 stasis chamber',0),(558,18371,-26.245,-162.785,26.094,1,'loot+script',0),(558,18373,66.766,-388.345,26.673,2,'loot+script',0),(564,22841,449.595,401.194,118.621,0,'loot+script+rank3',0),(564,22856,497.772,184.166,94.605,0,'script+rank3',0),(564,22871,606.641,402.173,187.173,0,'loot+script+rank3',0),(564,22887,434.943,739.254,15.07,0,'loot+script+rank3',0),(564,22898,702.141,650.715,75.049,0,'loot+script+rank3',0),(564,22917,705.732,304.988,353.925,0,'loot+script+rank3',0),(564,22947,945.313,149.078,197.158,0,'loot+script+rank3',0),(564,22948,744.302,277.077,63.839,0,'loot+script+rank3',0),(564,22949,700.739,302.722,277.526,0,'loot+script+rank3',0),(564,22950,700.792,307.192,277.526,0,'loot+script+rank3',0),(564,22951,697.409,299.377,277.526,0,'loot+script+rank3',0),(564,22952,697.495,310.651,277.527,0,'loot+script+rank3',0),(564,23426,737.455,305.054,277.526,0,'rank3',0),(564,23499,723.065,305.023,277.526,0,'rank3',0),(565,18831,143.049,192.726,-11.215,0,'loot+script+rank3',0),(565,18832,149.823,178.019,-10.593,0,'script+rank3',0),(565,18834,146.521,185.358,-10.838,0,'script+rank3',0),(565,18835,145.96,207.296,-8.671,0,'script+rank3',0),(565,18836,144.731,199.921,-9.977,0,'script+rank3',0),(565,19044,237.403,357.981,-3.408,0,'loot+script+rank3',0),(568,23574,376.353,1407.34,75.531,0,'script+rank3',0),(568,23576,16.962,1414.6,11.927,0,'script+rank3',0),(568,23577,370.257,1135.74,6.549,0,'script+rank3',0),(568,23578,-18.642,1150.46,18.795,0,'script+rank3',0),(568,23863,119.981,674.245,51.824,0,'loot+script+rank3',0),(568,23877,149.657,705.75,45.195,0,'rank3',0),(568,23878,134.6,724.341,45.195,0,'rank3',0),(568,23879,91.133,705.753,45.195,0,'rank3',0),(568,23880,105.526,724.926,45.195,0,'rank3',0),(568,24239,117.363,923.569,33.973,0,'loot+script+rank3',0),(580,24850,1704.21,924.758,53.161,0,'script+rank3',0),(580,24882,1463.83,611.512,21.57,0,'loot+script+rank3',0),(580,24892,1699.91,929.021,-74.284,0,'loot+script+rank3',0),(580,25165,1814.27,626.452,33.487,0,'loot+script+rank3',0),(580,25166,1818.21,625.044,33.487,0,'loot+script+rank3',0),(580,25741,1816.4,625.894,69.689,0,'script+rank3',0),(580,26046,1698.09,627.29,58.177,0,'rank3',0),(580,26246,1721.73,648.482,27.757,0,'rank3',0),(580,26247,1720.02,643.233,28.134,0,'rank3',0),(585,24560,126.901,19.155,-19.922,0,'loot+script',0),(585,24664,148.549,186.981,-16.644,0,'loot+script',0),(585,24723,242.075,0.301,1.84,0,'loot+script',0),(585,24744,231.367,-214.346,-6.323,0,'loot+script',0),(585,25960,-24.611,-482.024,-22.129,0,'rank3',0),(585,26579,-25.236,-599.946,-31.02,0,'rank3',0);
DROP TABLE IF EXISTS `ai_playerbot_boss_switch`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_switch` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `go_guid` int unsigned NOT NULL,
  `go_entry` int unsigned NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `kind` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=boss 战后点开关',
  `note` varchar(96) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`go_guid`),
  KEY `idx_boss` (`boss_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_boss_switch` (`map`, `boss_entry`, `go_guid`, `go_entry`, `x`, `y`, `z`, `kind`, `note`) VALUES (545,17797,5450035,184125,98.8,-316.3,-6.7,0,'蒸汽地窟：水术师塞斯匹亚后开主厅门'),(545,17796,5450036,184126,-332.4,-117.2,-6.7,0,'蒸汽地窟：机械师蒸汽触发器后开瓦洛克门'),(548,21214,5480006,184568,47.8,-581.8,4.7,0,'毒蛇神殿：深水领主卡拉瑟雷斯后放瓦丝琪桥'),(548,21216,5480030,185114,457.4,-555.3,-7,0,'毒蛇神殿：海德斯后（待站长确认控制台）'),(548,21217,5480031,185115,373.1,-465.1,30.7,0,'毒蛇神殿：潜伏者后（待站长确认控制台）'),(548,21215,5480032,185116,349,-684.1,-12.4,0,'毒蛇神殿：盲眼者后（待站长确认控制台）');
DROP TABLE IF EXISTS `ai_playerbot_boss_strategy`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_boss_strategy` (
  `entry` int unsigned NOT NULL,
  `note` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

REPLACE INTO `ai_playerbot_boss_strategy` (`entry`, `note`) VALUES (16807,'破碎大厅 - 高阶术士奈瑟库斯 Grand Warlock Nethekurse'),(16808,'破碎大厅 - 酋长卡加斯·刃拳 Warchief Kargath Bladefist'),(16809,'破碎大厅 - 战争使者沃姆罗格 Warbringer O\'mrogg'),(17306,'地狱火城墙 - 巡视者加戈玛 Watchkeeper Gargolmar'),(17308,'地狱火城墙 - 无疤者奥摩尔 Omor the Unscarred'),(17377,'鲜血熔炉 - 击碎者克里丹 Keli\'dan the Breaker'),(17380,'鲜血熔炉 - 布洛戈克 Broggok'),(17381,'鲜血熔炉 - 制造者 The Maker'),(17461,'破碎大厅：破碎之手血卫（带小弟/斩杀）'),(17536,'地狱火城墙 - 纳杉 Nazan（瓦兹德的坐骑，二阶段同场）'),(17537,'地狱火城墙 - 传令官瓦兹德 Vazruden'),(17770,'幽暗沼泽 - 霍加尔芬 Hungarfen'),(17796,'蒸汽地窟 - 机械师斯蒂里格 Mekgineer Steamrigger'),(17797,'蒸汽地窟 - 水术师瑟丝比娅 Hydromancer Thespia'),(17798,'蒸汽地窟 - 督军卡利瑟里斯 Warlord Kalithresh'),(17826,'幽暗沼泽 - 沼地领主穆塞雷克 Swamplord Musel\'ek'),(17848,'旧希尔斯布莱德 - 德拉克中尉 Lieutenant Drake'),(17862,'旧希尔斯布莱德 - 斯卡洛克上尉 Captain Skarloc'),(17879,'黑色沼泽 - 时空领主德亚 Chrono Lord Deja'),(17880,'黑色沼泽 - 坦普卢斯 Temporus'),(17881,'黑色沼泽 - 埃欧努斯 Aeonus'),(17882,'幽暗沼泽 - 黑色阔步者 The Black Stalker'),(17941,'奴隶围栏 - 背叛者门努 Mennu the Betrayer'),(17942,'奴隶围栏 - 夸格米拉 Quagmirran'),(17975,'生态船 - 高级植物学家弗雷温 High Botanist Freywinn'),(17976,'生态船 - 指挥官萨拉妮丝 Commander Sarannis'),(17977,'生态船 - 迁跃扭木 Warp Splinter'),(17978,'生态船 - 看管者索恩格林 Thorngrin the Tender'),(17980,'生态船 - 拉伊 Laj'),(17991,'奴隶围栏 - 巨钳鲁克玛尔 Rokmar the Crackler'),(18096,'旧希尔斯布莱德 - 时空猎手 Epoch Hunter'),(18105,'幽暗沼泽 - 加兹安 Ghaz\'an'),(18170,'时光之穴：无限杀戮者（致死打击/暗影箭）'),(18171,'时光之穴：无限玷污者（驱散/解除诅咒）'),(18172,'时光之穴：无限破坏者（驱散魔法）'),(18341,'法力陵墓 - 潘德莫努斯 Pandemonius（只有通用行为）'),(18343,'法力陵墓 - 塔瓦洛克 Tavarok'),(18344,'法力陵墓 - 节点亲王沙法尔 Nexus-Prince Shaffar'),(18371,'奥金尼地穴 - 死亡观察者希尔拉克 Shirrak the Dead Watcher'),(18373,'奥金尼地穴 - 大主教玛拉达尔 Exarch Maladaar'),(18472,'赛泰克大厅 - 黑暗编织者塞斯 Darkweaver Syth'),(18473,'赛泰克大厅 - 利爪之王艾吉斯 Talon King Ikiss'),(18667,'暗影迷宫 - 煽动者布莱卡特 Blackheart the Inciter'),(18731,'暗影迷宫 - 赫尔默大使 Ambassador Hellmaw（只有通用行为）'),(18732,'暗影迷宫 - 沃匹尔大师 Grandmaster Vorpil'),(19218,'能源舰 - 看守者盖罗基尔 Gatewatcher Gyro-Kill'),(19219,'能源舰 - 机械领主卡帕西图斯 Mechano-Lord Capacitus'),(19220,'能源舰 - 计算者帕萨雷恩 Pathaleon the Calculator'),(19221,'能源舰 - 灵术师塞比瑟蕾 Nethermancer Sepethrea'),(19710,'能源舰 - 看守者埃隆汉 Gatewatcher Iron-Hand'),(20870,'禁魔监狱 - 自由的瑟雷凯斯 Zereketh the Unbound'),(20885,'禁魔监狱 - 末日预言者达尔莉安 Dalliah the Doomsayer'),(20886,'禁魔监狱 - 天怒预言者苏克拉底 Wrath-Scryer Soccothrates'),(20912,'禁魔监狱 - 预言者斯克瑞斯 Harbinger Skyriss'),(20923,'破碎大厅 - 血卫士伯鲁恩 Blood Guard Porung'),(21466,'禁魔监狱 - 预言者斯克瑞斯的幻象 1（36931 召唤；本尊 20912 的转火目标）'),(21467,'禁魔监狱 - 预言者斯克瑞斯的幻象 2（36932 召唤）'),(22930,'法力陵墓 - 尤尔 Yor');
DROP TABLE IF EXISTS `ai_playerbot_cc_creature`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_cc_creature` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `has_fear` tinyint unsigned NOT NULL DEFAULT '0',
  `has_spell` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_cc_creature` (`map`, `entry`, `has_fear`, `has_spell`) VALUES (269,2914,0,0),(269,15608,0,0),(269,17952,0,0),(269,18625,0,0),(269,18982,0,0),(269,18983,0,0),(269,20201,0,0),(269,21862,0,0),(540,2110,0,0),(540,2914,0,0),(540,4075,0,0),(540,9699,0,0),(540,15384,0,0),(540,16507,0,1),(540,16523,0,1),(540,16593,0,1),(540,16594,0,1),(540,16699,0,1),(540,16700,0,0),(540,16704,0,1),(540,16807,1,1),(540,16808,0,0),(540,16809,1,1),(540,17083,0,0),(540,17302,0,0),(540,17356,0,1),(540,17357,0,1),(540,17420,0,1),(540,17427,0,1),(540,17461,0,0),(540,17462,0,1),(540,17464,0,1),(540,17465,0,1),(540,17552,0,0),(540,17578,0,0),(540,17611,0,0),(540,17669,0,1),(540,17670,0,1),(540,17671,0,0),(540,17687,0,0),(540,17693,0,0),(540,17695,0,0),(540,20709,0,0),(540,20923,0,0),(542,17256,1,1),(542,17370,0,1),(542,17371,0,1),(542,17377,0,0),(542,17380,0,1),(542,17381,0,1),(542,17395,0,1),(542,17397,0,1),(542,17398,0,1),(542,17400,0,1),(542,17414,0,1),(542,17416,0,0),(542,17429,0,1),(542,17477,0,1),(542,17491,0,1),(542,17624,0,1),(542,17626,0,1),(542,17653,0,0),(542,18894,0,1),(542,19016,0,1),(542,21174,0,0),(543,17259,0,1),(543,17264,0,1),(543,17269,0,1),(543,17270,0,1),(543,17271,0,1),(543,17280,0,1),(543,17281,0,1),(543,17306,0,0),(543,17307,0,0),(543,17308,0,0),(543,17309,0,1),(543,17455,0,1),(543,17478,1,1),(543,17517,0,1),(543,22515,0,0),(545,1420,0,0),(545,2914,0,0),(545,6827,0,0),(545,13321,0,0),(545,17378,0,0),(545,17721,0,1),(545,17722,0,1),(545,17796,0,1),(545,17797,0,1),(545,17798,0,1),(545,17799,0,0),(545,17800,0,1),(545,17801,1,1),(545,17802,0,1),(545,17803,0,1),(545,17805,0,1),(545,17917,0,1),(545,17951,0,0),(545,17954,0,0),(545,20926,0,0),(545,21338,0,0),(545,21694,0,1),(545,21695,0,1),(545,21696,0,1),(546,1420,0,0),(546,3300,0,0),(546,15384,0,0),(546,16030,0,0),(546,17723,0,1),(546,17724,0,1),(546,17725,0,0),(546,17726,0,1),(546,17727,0,1),(546,17728,0,1),(546,17729,0,1),(546,17730,0,1),(546,17731,1,1),(546,17732,0,1),(546,17734,0,1),(546,17735,0,1),(546,17770,0,0),(546,17826,0,0),(546,17827,0,1),(546,17871,0,1),(546,17882,0,0),(546,17885,0,0),(546,17992,0,0),(546,18105,0,1),(546,18409,0,0),(546,19632,0,1),(546,20465,0,0),(547,2110,0,0),(547,3300,0,0),(547,13321,0,0),(547,17816,0,1),(547,17817,0,1),(547,17890,0,0),(547,17893,0,0),(547,17938,0,1),(547,17940,0,1),(547,17941,0,1),(547,17942,0,1),(547,17957,1,1),(547,17958,0,1),(547,17959,0,1),(547,17960,0,1),(547,17961,0,1),(547,17962,0,1),(547,17963,0,1),(547,17964,0,1),(547,17991,0,1),(547,18206,0,0),(547,21126,0,1),(547,21127,0,1),(547,21128,1,1),(547,22421,0,0),(547,25697,0,0),(547,25710,0,0),(547,25745,0,0),(547,25746,0,0),(547,25754,0,0),(547,25952,0,0),(547,25961,0,0),(547,25971,0,0),(547,25972,0,0),(547,25973,0,0),(547,26120,0,0),(547,26121,0,0),(547,26190,0,0),(552,15384,0,0),(552,20857,0,0),(552,20859,0,1),(552,20864,0,1),(552,20865,0,1),(552,20866,0,1),(552,20869,0,0),(552,20870,0,1),(552,20873,0,1),(552,20875,0,0),(552,20879,0,1),(552,20880,0,1),(552,20881,0,1),(552,20882,0,0),(552,20883,0,1),(552,20885,0,1),(552,20886,0,1),(552,20896,0,1),(552,20897,0,1),(552,20898,0,1),(552,20900,0,1),(552,20901,0,1),(552,20902,0,1),(552,20904,0,0),(552,20978,0,0),(552,21186,0,0),(552,21436,0,0),(552,21437,0,0),(552,21438,0,0),(552,21439,0,0),(552,21440,0,0),(552,21702,0,1),(552,21962,0,0),(553,17975,0,1),(553,17976,0,1),(553,17977,0,1),(553,17978,0,1),(553,17980,0,1),(553,17993,0,1),(553,17994,0,1),(553,18155,0,1),(553,18404,0,1),(553,18405,0,1),(553,18419,0,1),(553,18420,0,1),(553,18421,0,1),(553,18422,0,1),(553,18587,0,0),(553,19486,0,1),(553,19505,0,1),(553,19507,0,1),(553,19508,0,1),(553,19509,0,1),(553,19511,0,1),(553,19512,0,1),(553,19513,1,1),(553,19555,0,0),(553,19557,0,1),(553,19598,0,1),(553,19608,0,1),(553,19633,0,1),(553,19843,0,0),(553,19865,0,0),(555,14881,0,0),(555,18631,0,1),(555,18632,0,1),(555,18633,0,1),(555,18634,0,1),(555,18635,0,1),(555,18636,0,0),(555,18637,0,1),(555,18638,0,1),(555,18639,0,1),(555,18640,0,1),(555,18641,0,1),(555,18642,0,1),(555,18667,0,1),(555,18708,0,1),(555,18731,1,1),(555,18732,0,1),(555,18793,0,0),(555,18794,0,0),(555,18796,1,1),(555,18797,0,0),(555,18848,0,1),(555,18891,0,0),(555,21159,0,0),(556,2914,0,0),(556,3300,0,0),(556,4075,0,0),(556,4076,0,0),(556,14881,0,0),(556,18318,0,1),(556,18319,0,1),(556,18320,0,1),(556,18321,0,1),(556,18322,0,1),(556,18323,0,1),(556,18325,1,1),(556,18326,0,1),(556,18327,0,1),(556,18472,0,1),(556,18473,0,0),(556,18956,0,0),(556,19428,0,1),(556,19429,0,1),(556,21891,0,1),(556,21904,0,1),(556,21931,0,0),(557,3300,0,0),(557,4075,0,0),(557,4076,0,0),(557,14881,0,0),(557,18309,0,1),(557,18311,0,1),(557,18312,0,1),(557,18313,0,1),(557,18314,0,1),(557,18315,0,1),(557,18317,0,1),(557,18331,0,1),(557,18341,0,1),(557,18343,0,1),(557,18344,0,0),(557,18431,0,0),(557,19306,0,1),(557,19307,1,1),(557,22927,0,0),(558,14881,0,0),(558,18371,0,1),(558,18373,1,1),(558,18497,0,1),(558,18506,0,0),(558,18700,0,1),(558,18702,0,1),(558,18726,0,0),(558,18766,0,0),(558,18778,0,0),(558,19416,0,0);
DROP TABLE IF EXISTS `ai_playerbot_custom_strategy`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_custom_strategy` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `idx` bigint DEFAULT NULL,
  `owner` bigint DEFAULT NULL,
  `action_line` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1957 DEFAULT CHARSET=utf8mb3;

REPLACE INTO `ai_playerbot_custom_strategy` (`id`, `name`, `idx`, `owner`, `action_line`) VALUES (1,'say',1,0,'critical health>emote::helpme!99,say::critical health!98'),(2,'say',2,0,'low health>emote::healme!99,say::low health!98'),(3,'say',3,0,'low mana>emote::oom!99,say::low mana!98'),(4,'say',4,0,'tank aoe>charge!99,say::taunt!98'),(5,'say',5,0,'medium aoe>say::aoe!99'),(6,'say',6,0,'can loot>say::loot!99'),(1863,'boss_common',1,0,'feared>every_man_for_himself!96,will of the forsaken!95'),(1864,'boss_common',2,0,'target of fear cast>tremor totem!90,fear ward!89'),(1865,'boss_common',3,0,'val::and::{trigger::enemy too close for melee,not::is tank}>move out of enemy contact!80'),(1866,'boss_16807',1,0,'val::and::{is tank,trigger::target critical health}>move out of enemy contact!80'),(1867,'boss_16807',2,0,'val::and::{is dps,trigger::target critical health,trigger::low health}>healing potion!70,try emergency!60'),(1868,'boss_16808',1,0,'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20'),(1869,'boss_16808',2,0,'val::or::{trigger::has aura::spellid::25821,trigger::has aura::spellid::23601}>use trinket!95'),(1870,'boss_16809',1,0,'val::and::{not::is tank,trigger::has aggro}>stoneshield potion!80,healing potion!75,try emergency!60'),(1871,'boss_17306',1,0,'has aura::spellid::30641>healing potion!70,stoneshield potion!60,try emergency!50'),(1872,'boss_17306',2,0,'has aura::spellid::36814>healing potion!70,stoneshield potion!60,try emergency!50'),(1873,'boss_17308',1,0,'has aura::spellid::30695>flee!90'),(1874,'boss_17308',2,0,'has aura::spellid::37566>flee!90'),(1875,'boss_17308_dps',1,0,'has nearest adds>attack least hp target!20'),(1876,'boss_17377',1,0,'has aura::spellid::30937>dispel magic!55,cleanse magic!50'),(1877,'boss_17377',2,0,'has aura::spellid::30938>dispel magic!55,cleanse magic!50'),(1878,'boss_17380_dps',1,0,'not behind target>set behind!20'),(1879,'boss_17381',1,0,'has aura::spellid::30923>every_man_for_himself!96,will of the forsaken!95,use trinket!90'),(1880,'boss_17461',1,0,'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20'),(1881,'boss_17536_dps',1,0,'not behind target>set behind!20'),(1882,'boss_17537_dps',1,0,'not behind target>set behind!20'),(1883,'boss_17796_melee',1,0,'not behind target>set behind!20'),(1884,'boss_17797',1,0,'has aura::spellid::31718>use trinket!95,try emergency!50'),(1885,'boss_17797',2,0,'has aura::spellid::31481>healing potion!60'),(1886,'boss_17797',3,0,'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20'),(1887,'boss_17798',1,0,'has aura::spellid::39061>healing potion!60'),(1888,'boss_17826',1,0,'val::and::{trigger::enemy too close for melee,is ranged}>flee!50'),(1889,'boss_17848',1,0,'val::and::{is tank,trigger::has aura::spellid::31911,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),(1890,'boss_17848',2,0,'has aura::spellid::33792>use trinket!95'),(1891,'boss_17862',1,0,'has aura::spellid::13005>use trinket!95,cleanse magic!50,dispel magic!50'),(1892,'boss_17862',2,0,'has aura::spellid::15654>dispel magic!55,cleanse magic!50'),(1893,'boss_17862_dps',1,0,'has nearest adds>attack least hp target!20'),(1894,'boss_17879',1,0,'has aura::spellid::31467>dispel magic!60,cleanse magic!59'),(1895,'boss_17879',2,0,'val::and::{trigger::enemy too close for melee,not::is tank}>move out of enemy contact!80'),(1896,'boss_17880',1,0,'val::and::{is tank,trigger::has aura::spellid::31464::greater or equal::4}>stoneshield potion!80,healing potion!70,try emergency!60'),(1897,'boss_17881',1,0,'has aura::spellid::31422>use trinket!95'),(1898,'boss_17881',2,0,'dispel enrage>tranquilizing shot!40'),(1899,'boss_17881_melee',1,0,'not behind target>set behind!20'),(1900,'boss_17882_tank',1,0,'enemy too close for melee>move out of enemy contact!80'),(1901,'boss_17941_dps',1,0,'has nearest adds>attack least hp target!20'),(1902,'boss_17975_dps',1,0,'has nearest adds>attack least hp target!20'),(1903,'boss_17977',1,0,'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20'),(1904,'boss_17978',1,0,'has aura::spellid::34661>use trinket!95'),(1905,'boss_17980',1,0,'has aura::spellid::34697>flee!85'),(1906,'boss_17980',2,0,'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20'),(1907,'boss_17991_healer',1,0,'low health>try emergency!80,healing potion!70'),(1908,'boss_18096_dps',1,0,'not behind target>set behind!20'),(1909,'boss_18105_dps_melee',1,0,'not behind target>set behind!20'),(1910,'boss_18170',1,0,'val::and::{is tank,trigger::has aura::spellid::16856,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),(1911,'boss_18170',2,0,'val::and::{is tank,trigger::has aura::spellid::15708,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),(1912,'boss_18170',3,0,'has aura::spellid::21068>dispel magic!55,cleanse magic!50'),(1913,'boss_18170_dps',1,0,'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20'),(1914,'boss_18171',1,0,'has aura::spellid::21068>dispel magic!55,cleanse magic!50'),(1915,'boss_18171',2,0,'has aura::spellid::31977>remove curse!55'),(1916,'boss_18172',1,0,'has aura::spellid::21068>dispel magic!55,cleanse magic!50'),(1917,'boss_18343_dps',1,0,'not behind target>set behind!20'),(1918,'boss_18344',1,0,'val::and::{trigger::has attackers,is dps}>attack least hp target!70'),(1919,'boss_18344',2,0,'val::and::{trigger::target critical health,is dps}>attack!75'),(1920,'boss_18344',3,0,'has aura::spellid::32365>dispel magic!55,cleanse magic!50'),(1921,'boss_18371_dps_melee',1,0,'has aura::spellid::36383::greater or equal::4>flee!68'),(1922,'boss_18373',1,0,'val::and::{trigger::has nearest adds,is dps}>attack least hp target!62'),(1923,'boss_18373',2,0,'val::and::{trigger::target critical health,is dps}>attack!65'),(1924,'boss_18472',1,0,'val::or::{trigger::has aura::spellid::15039,trigger::has aura::spellid::12548,trigger::has aura::spellid::33534,trigger::has aura::spellid::33620}>dispel magic!55,cleanse magic!50'),(1925,'boss_18472',2,0,'val::or::{trigger::has aura::spellid::15616,trigger::has aura::spellid::21401,trigger::has aura::spellid::38135,trigger::has aura::spellid::38136}>dispel magic!55,cleanse magic!50'),(1926,'boss_18472',3,0,'val::or::{trigger::has aura::spellid::33526::greater or equal::3,trigger::has aura::spellid::33527::greater or equal::3,trigger::has aura::spellid::33528::greater or equal::3,trigger::has aura::spellid::33529::greater or equal::3}>dispel magic!60,cleanse magic!55'),(1927,'boss_18472',4,0,'val::or::{trigger::has aura::spellid::38141::greater or equal::3,trigger::has aura::spellid::38138::greater or equal::3,trigger::has aura::spellid::38142::greater or equal::3,trigger::has aura::spellid::38143::greater or equal::3}>dispel magic!60,cleanse magic!55'),(1928,'boss_18472',5,0,'val::and::{trigger::has nearest adds,is dps}>attack least hp target!80'),(1929,'boss_18473',1,0,'has aura::spellid::35032>dispel magic!55,cleanse magic!50'),(1930,'boss_18473',2,0,'val::or::{trigger::has aura::spellid::38245,trigger::has aura::spellid::43309}>dispel magic!55,cleanse magic!50'),(1931,'boss_18667',1,0,'enemy too close for melee>move out of enemy contact!90'),(1932,'boss_18667',2,0,'val::and::{trigger::enemy too close for melee,is ranged}>flee!60'),(1935,'boss_19218',1,0,'val::or::{trigger::has aura::spellid::35318,trigger::has aura::spellid::39192}>healing potion!60'),(1936,'boss_19218',2,0,'has aura::spellid::35311>cure poison!85,anti-venom!80'),(1937,'boss_19219',1,0,'val::and::{is tank,trigger::has aura::spellid::35161}>healing potion!70'),(1938,'boss_19220_dps',1,0,'has nearest adds>attack least hp target!20'),(1939,'boss_19221',1,0,'raging flames too close>move away from raging flames!90'),(1940,'boss_19221',2,0,'has aura::spellid::35250>use trinket!95'),(1941,'boss_19710',1,0,'has aura::spellid::35326>use trinket!95'),(1942,'boss_19710',2,0,'has aura::spellid::35311>cure poison!85,anti-venom!80'),(1943,'boss_20870',1,0,'val::or::{trigger::has aura::spellid::36123,trigger::has aura::spellid::39367}>flee!85'),(1944,'boss_20870',2,0,'val::and::{trigger::low health,is dps}>try emergency!80'),(1945,'boss_20885',1,0,'has aura::spellid::39016>healing potion!60'),(1946,'boss_20886',1,0,'val::or::{trigger::has aura::spellid::35759,trigger::has aura::spellid::39006}>healing potion!60,try emergency!50'),(1947,'boss_20912',1,0,'val::or::{trigger::has aura::spellid::36924,trigger::has aura::spellid::39017}>use trinket!95,try emergency!50'),(1948,'boss_20912_dps',1,0,'has nearest adds>attack least hp target!20'),(1949,'boss_20923',1,0,'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20'),(1950,'boss_21466',1,0,'val::or::{trigger::has aura::spellid::36929,trigger::has aura::spellid::39021}>healing potion!55,try emergency!50'),(1951,'boss_21467',1,0,'val::or::{trigger::has aura::spellid::36929,trigger::has aura::spellid::39021}>healing potion!55,try emergency!50'),(1952,'boss_22930',2,0,'val::and::{trigger::enemy ten yards,is ranged}>flee!45'),(1953,'boss_22930_dps',1,0,'not behind target>set behind!20'),(1954,'boss_18473',3,0,'enemy casting::spellid::40425>flee!90'),(1955,'boss_18732',1,0,'val::and::{trigger::has nearest adds,is dps}>attack nearest add'),(1956,'boss_18732',2,0,'val::and::{trigger::has nearest adds,is tank}>flee!20');
DROP TABLE IF EXISTS `ai_playerbot_decision_weight`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_decision_weight` (
  `key` varchar(64) NOT NULL COMMENT '决策项.因子，例 target.threat_tier',
  `weight` float NOT NULL DEFAULT '0' COMMENT '权重（线性加权求和；负值=惩罚）',
  `note` varchar(255) NOT NULL DEFAULT '' COMMENT '说明/调参记录',
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='playerbot 决策打分权重（离线调参/RL 入口）';

REPLACE INTO `ai_playerbot_decision_weight` (`key`, `weight`, `note`) VALUES ('aoe.cc_guard.penalty',0,'AoE 破控守卫：有被控目标时 AoE 权重'),('aoe.cc_guard.radius',12,'AoE 破控守卫半径'),('cc.distance',-1,'距离惩罚（每码）'),('cc.dps',1,'普通输出能力权重（近战/远程取大）'),('cc.needs_control',100,'优先级4（需要优先控制）加成'),('cc.priority_rank',15,'威胁等级加权'),('dispel.buff_count',50,'目标身上魔法增益数量加权'),('dispel.casting',30,'目标正在读条加成'),('dispel.distance',-1,'距离惩罚（每码）'),('dispel.priority_rank',20,'威胁等级加权'),('dps.overaggro_penalty',0.3,'DPS 被怪打时输出惩罚'),('heal.distance',-0.5,'距离惩罚（每码）'),('heal.incoming_damage',1,'预计承伤加权（preheal 时算入缺失血量）'),('heal.missing_health',100,'缺失血量权重（按最大血量百分比）'),('heal.tank_bonus',50,'[R6 2026-10-23] 鍧﹀厠娌荤枟鍔犳垚 30鈫?0'),('log.decision',0,'预留：决策打分日志开关'),('mob.count.engage_scale',1,'540 同类怪攒够才清的门槛倍率（engage_count × 本值，下限1）'),('position.cover_distance',-1,'卡视野掩体点：距离惩罚（每码）'),('position.mode.frontal',70,'避开正面'),('position.mode.knockback',60,'击退沙包/回位'),('position.mode.los_all',100,'卡视野（全队）'),('position.mode.los_backline',90,'卡视野（远程/治疗）'),('position.mode.los_break',85,'断读条卡视野'),('position.mode.los_pull',95,'卡视野拉怪（坦克去卡点）'),('position.mode.spread',30,'分散'),('position.mode.stack',40,'集合'),('position.mode.wall',20,'贴墙防击飞'),('pull.action.incombat_penalty',0.05,'cheat/寻路阶段：坦克战斗中有攻击者时压低 pull 动作'),('pull.encounter_boost',1.6,'路上遭遇 pull：pull 动作权重乘数'),('pull.encounter.range',30,'路上遭遇 pull：触发半径（码）'),('pull.safe.strict',0,'cheat 验证寻路：宽松拉怪，只拦巡逻怪'),('sim.assist.max_dist',60,'坦克救场最大距离'),('tank.threat.mult',2.5,'坦克被多目标打时威胁动作权重'),('target.casting',30,'目标：正在读条加成'),('target.distance',-1,'目标：距离惩罚（每码）'),('target.reselect.waiting_penalty',0.2,'等坦克仇恨期间 select new target 的权重乘数'),('target.threat_tier',100,'目标：威胁等级权重'),('wait.attack.boost',4,'非坦等仇恨：wait 动作权重'),('wait.attack.dps_penalty',0.5,'[R6 2026-10-23] 绛変粐鎭ㄦ湡闂?DPS 鎯╃綒鏀惧锛?.2鈫?.5锛夛細鍧﹀厠缁忓父鑴遍澏锛孌PS 琚帇寰楀お姝诲鑷存墦寰楁參');
DROP TABLE IF EXISTS `ai_playerbot_dungeon_stage`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_dungeon_stage` (
  `map` smallint unsigned NOT NULL,
  `stage_ord` smallint unsigned NOT NULL,
  `kind` varchar(16) NOT NULL,
  `target_entry` int unsigned NOT NULL DEFAULT '0',
  `anchor_x` float NOT NULL DEFAULT '0',
  `anchor_y` float NOT NULL DEFAULT '0',
  `radius` float NOT NULL DEFAULT '0',
  `count_limit` int unsigned NOT NULL DEFAULT '0',
  `keep_out` float NOT NULL DEFAULT '0',
  `note` varchar(160) NOT NULL DEFAULT '',
  `wait_ms` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`map`,`stage_ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_dungeon_stage` (`map`, `stage_ord`, `kind`, `target_entry`, `anchor_x`, `anchor_y`, `radius`, `count_limit`, `keep_out`, `note`, `wait_ms`) VALUES (269,1,'talk_npc',20201,0,0,0,1,0,'进门跟 Sa\'at 对话领时空道标(24289)',0),(269,2,'kill_entry',18983,-2025,7120,160,0,45,'提前清 Blackfang Tarantula',0),(269,3,'kill_entry',2914,-2025,7120,160,0,45,'提前清 Snake',0),(269,4,'kill_entry',17952,-2025,7120,160,0,45,'提前清 Darkwater Crocolisk',0),(269,5,'kill_entry',18982,-2025,7120,160,0,45,'提前清 Sable Jaguar',0),(269,6,'walk_to',0,-2025,7120,8,0,0,'走到麦迪文旁边触发事件',0),(269,7,'event_guard',0,-2025,7120,60,0,0,'守时空门：清门旁的怪、拦追麦迪文的怪、放道标',0),(540,1,'boss',16807,179,289,0,0,0,'1 号 Grand Warlock Nethekurse',0),(540,2,'gauntlet',17461,513,316,30,8,0,'天堂之路：无限刷怪中往前走引 Blood Guard(普通)/Porung(英雄)；附近活怪 >=8 先清',0),(540,3,'kill_entry',17461,0,0,0,0,0,'杀掉 Blood Guard（普通难度的\"Porung 位\"）',0),(540,4,'kill_entry',20923,0,0,0,0,0,'英雄难度才是 Porung；普通难度没刷则直接跳过',0),(540,5,'boss',16809,0,0,0,0,0,'3 号 Warbringer O\'mrogg',0),(540,6,'boss',16808,0,0,0,0,0,'4 号 Warchief Kargath Bladefist',0),(542,1,'interact_go',181982,0,0,0,0,0,'拉开关 GO_PRISON_CELL_DOOR_LEVER',0),(542,2,'waves_clear',0,328,129,45,4,0,'清 4 波小怪（事件刷出来的）',0),(542,3,'boss',17381,0,0,0,0,0,'1 号 The Maker',0),(542,4,'kill_entry',17653,0,0,0,0,0,'杀 5 只 Shadowmoon Channeler（Broggok 开门条件）',0),(542,5,'boss',17380,0,0,0,0,0,'2 号 Broggok',0),(542,6,'boss',17377,0,0,0,0,0,'3 号 Keli\'dan the Breaker',0),(543,1,'boss',17306,-1164.29,1516.02,0,0,0,'auto: boss order',0),(543,2,'boss',17308,-1122.34,1718.41,0,0,0,'auto: boss order',0),(543,3,'boss',17307,-1363.89,1728.03,0,0,0,'auto: boss order',0),(545,1,'boss',17797,0,0,0,0,0,'1 号 Hydromancer Thespia',0),(545,2,'interact_go',184125,0,0,0,0,0,'开关：Main Chambers Access Panel（Thespia 房）',0),(545,3,'boss',17796,0,0,0,0,0,'2 号 Mekgineer Steamrigger',0),(545,4,'interact_go',184126,0,0,0,0,0,'开关：Main Chambers Access Panel（Steamrigger 房）',0),(545,5,'boss',17798,0,0,0,0,0,'3 号 Warlord Kalithresh',0),(546,1,'boss',17770,0,0,0,0,0,'1 号 Hungarfen',0),(546,2,'boss',18105,0,0,0,0,0,'2 号 Ghaz\'an',0),(546,3,'boss',17826,0,0,0,0,0,'3 号 Swamplord Musel\'ek（过 link 后）',0),(546,4,'boss',17882,0,0,0,0,0,'4 号 The Black Stalker',0),(547,1,'boss',17941,0,0,0,0,0,'1 打 Mennu the Betrayer',0),(547,2,'link',0,-182.76,-348.31,0,0,0,'2 走到 platform→water 连接点，跳进水里',0),(547,3,'boss',17991,0,0,0,0,0,'3 打 Rokmar the Crackler',0),(547,4,'link',0,-179.33,-412.18,0,0,0,'4 走第二个 platform→water 连接点，跳进水里',0),(547,5,'boss',17942,0,0,0,0,0,'5 打 Quagmirran',0),(552,1,'kill_entry',20859,0,0,0,0,0,'先杀 Arcatraz Warder（看守员），停止无限出怪',0),(552,2,'wait',0,73.457,1.1833,0,0,0,'清完开头 4 个 Arcatraz Warder 后原地干等 25s：让会自己消失的 Protean 走干净再推进（以前用 skip_entry 按 entry 跳过，把同 entry 的正常怪也跳了）',25000),(553,1,'boss',17976,125.729,321.185,0,0,0,'auto: boss order',0),(553,2,'boss',17975,116.326,455.57,0,0,0,'auto: boss order',0),(553,3,'boss',17978,4.949,596.578,0,0,0,'auto: boss order',0),(553,4,'boss',17980,-204.125,391.249,0,0,0,'auto: boss order',0),(553,5,'boss',17977,63.841,391.882,0,0,0,'auto: boss order',0),(555,1,'kill_entry',18794,-157,5,45,0,0,'1 号房：清 Hellmaw 周围 Cabal Ritualist',0),(555,2,'boss',18731,0,0,0,0,0,'1 号 boss Hellmaw',0),(555,3,'room_clear',0,-328,-39,70,0,0,'2 号房：清 Blackheart 房间小怪',0),(555,4,'boss',18667,0,0,0,0,0,'2 号 boss Blackheart',0),(555,5,'boss',18732,0,0,0,0,0,'3 号 boss Vorpil',0),(555,6,'boss',18708,0,0,0,0,0,'4 号 boss Murmur',0),(556,1,'boss',18472,-144.827,173.557,0,0,0,'auto: boss order',0),(556,2,'boss',18473,44.723,286.96,0,0,0,'auto: boss order',0),(557,1,'boss',18341,-67.325,-120.09,0,0,0,'auto: boss order',0),(557,2,'boss',18343,-321.717,-222.183,0,0,0,'auto: boss order',0),(557,3,'boss',22930,-235.788,-13.005,0,0,0,'auto: boss order',0),(557,4,'boss',18344,-184.366,9.333,0,0,0,'auto: boss order',0),(558,1,'boss',18371,-26.245,-162.785,0,0,0,'auto: boss order',0),(558,2,'boss',18373,66.766,-388.345,0,0,0,'auto: boss order',0);
DROP TABLE IF EXISTS `ai_playerbot_mob_count_weight`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_mob_count_weight` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '25',
  `engage_count` smallint unsigned NOT NULL DEFAULT '8',
  `weight_per_count` float NOT NULL DEFAULT '0.15',
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_mob_count_weight` (`map`, `entry`, `radius`, `engage_count`, `weight_per_count`, `note`) VALUES (540,17357,25,4,0.15,'Creeping Oozeling：数量少无视继续推进，攒多了才清'),(540,17462,25,3,0.2,'Shattered Hand Zealot：同上');
DROP TABLE IF EXISTS `ai_playerbot_priority_target`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_priority_target` (
  `entry` int unsigned NOT NULL,
  `priority` tinyint unsigned NOT NULL,
  `source` varchar(16) NOT NULL,
  `reason` varchar(255) NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_priority_target` (`entry`, `priority`, `source`, `reason`) VALUES (7136,2,'guide','地狱火哨兵：治疗 [读条，只打断，击杀优先级 1]；暗言术：痛 [魔法] 伤害 dot、恢复 [魔法] 均可驱散。伤害 dot 取最高 ⇒ 2。｜静态证据: Heal, Shadow Word: Pain, Renew'),(16507,3,'guide','会 [冲锋] 随机目标，而且会抓潜行。 ｜静态证据: Charge'),(16594,1,'guide','[心灵震爆] 造成中等伤害，可打断；给自己和周围的怪施放 [真言术盾]、[抵抗暗影] 提高暗抗，对小怪施放 [治疗祷言] 造成 5000 左右群疗；注意进攻驱散和打断。 ｜静态证据: Prayer of Healing'),(16699,3,'guide','[上勾拳]、[顺劈斩]、[激怒] 提高攻速与伤害。 ｜静态证据: Uppercut'),(16700,5,'manual','Legionnaire 召唤援军+高伤：第一优先击杀，且从 CC 顺序排除'),(16704,2,'guide','会对法系玩家施放抽蓝的 [蝰蛇钉刺]。 ｜静态证据: Incendiary Shot'),(16874,3,'guide','频繁 [灼烧] 目标造成中等火焰伤害并范围性 [火焰之雨]；注意打断，或干脆离开 [火焰之雨] 范围。'),(17269,3,'guide','频繁 [灼烧] 目标造成中等火焰伤害并范围性 [火焰之雨]；注意打断，或干脆离开 [火焰之雨] 范围。 ｜静态证据: Rain of Fire'),(17280,3,'guide','[血肉撕咬] 会产生流血 dot，且 [狂怒嚎叫] 会提升自身伤害。 ｜静态证据: Carnivorous Bite, Furious Howl'),(17309,2,'guide','地狱火哨兵：治疗 [读条，只打断，击杀优先级 1]；暗言术：痛 [魔法] 伤害 dot、恢复 [魔法] 均可驱散。伤害 dot 取最高 ⇒ 2。｜静态证据: Heal, Shadow Word: Pain, Renew'),(17370,5,'guide','对当前目标 [盾牌猛击] 瞬发 2 秒击晕并驱散一个增益，中等伤害。瞬发控制 ⇒ 5（站长 2026-10-19 手动改档）。｜静态证据: Shield Slam(CTI=1, 2s)'),(17371,3,'guide','频繁的 [腐蚀术] 和高额伤害的 [暗影箭]，还会以 [邪魔之能] 强化自己的宠物恶魔，尤其尾王前的两波，最好等 [邪魔之能] 消散了再开，免得控场成功前先被打死。 ｜静态证据: Corruption'),(17395,5,'manual','Shadowmoon Summoner: priority 5 (542)'),(17397,3,'guide','会对坦克施放 [痛击]，这是二段三连击，可能对坦克造成瞬间大量伤害。由于本身就是双持速攻怪，瞬间七连击秒坦的事屡见不鲜，尽量风筝不要扛。'),(17398,5,'guide','[震荡猛击] 瞬发昏迷 5 秒、[践踏] 范围击退。瞬发硬控 ⇒ 5。｜静态证据: Concussion Blow(CTI=1), Stomp'),(17414,3,'guide','影月技师：[自走炸弹]（白色地雷）靠近 8 码引爆，15 码内高额火焰伤害；[投掷炸弹] 中等火焰 AOE；对法系 [沉默]。｜静态证据: Silence, Throw Dynamite'),(17427,3,'guide','在往血卫士伯鲁恩的天堂路上持续投放 [烈焰箭]，在地上生成一摊火焰。'),(17429,3,'guide','会对自身施放 [狂乱]，使攻速提高 60%；[冲锋] 随机目标、[失控] 清空仇恨转移目标。 ｜静态证据: Charge, Enrage'),(17464,3,'guide','伤害很高但可被缓速，[致死打击]。'),(17465,3,'guide','免疫所有控场，对目标 [破甲攻击]、对周围小怪 [战斗怒吼] 增伤。'),(17478,3,'guide','固定组合，前者对随机目标 [恐惧]（读条可打断）、[暗影箭] 使玩家逃跑，后者免疫控场。读条控制 ⇒ 3。｜静态证据: Fear(CTI=4)'),(17491,5,'guide','以潜行状态存在，[肾击] 瞬发昏迷 5 秒，脆皮被一套秒杀。瞬发硬控 ⇒ 5。｜静态证据: Kidney Shot(CTI=1), Poison'),(17540,3,'guide','无疤者奥摩尔召唤的军犬：[法力燃烧] 抽蓝(15785)、[吸取生命] 35748 不可驱散伤害；攻略要求优先击杀 ⇒ 3。｜静态证据: Mana Burn, Drain Life(EventAI)'),(17670,3,'guide','这两种怪是固定组合，驯犬者免疫控场，会 [多重射击]，并周期性驱散周围小怪的减益效果；军犬则会 [狂怒嚎叫] 增伤，[血肉撕咬] 造成高额物理伤害，清这波怪时注意注意维持控场缓速的减益效果。 ｜静态证据: Volley'),(17671,3,'guide','免疫控场但可缓速。'),(17693,3,'guide','会 [冲锋] 随机目标，而且会抓潜行。'),(17694,3,'guide','会 [恐惧]（读条可打断），还有大范围 [火焰之雨] 务必打断或躲开。读条控制 ⇒ 3。｜静态证据: Fear(CTI=16), Rain of Fire'),(17695,3,'guide','以潜行状态存在，会 [闷棍]、[背刺] 偷袭。'),(17721,3,'guide','[投网] 定身玩家后，对他所在位置投掷炸弹 [轰炸]。'),(17722,3,'guide','[冰霜新星] 可驱散；寒冰箭、[暴风雪] 可打断。 ｜静态证据: Blizzard'),(17723,3,'guide','门神，[击退] 附带高额物理伤害、[蘑菇凋零] 缓速目标，是疾病可驱散、[生长] 每 20 秒提高 15% 伤害，能叠加 10 次。幽暗沼泽领主的伤害尤其高，可以用 [击退] 风筝一下。 ｜静态证据: Fungal Decay, Trample'),(17725,3,'guide','本身伤害就高，还自带狂暴 [野性成长]，提高 50% 物理伤害，但可缓速。'),(17729,2,'guide','[蝰蛇钉刺] 抽蓝，即时驱散。'),(17730,1,'guide','[圣光术]、[治疗祷言] 造成巨额治疗，务必打断。[恢复] 可进攻驱散。 ｜静态证据: Holy Light, Prayer of Healing'),(17731,3,'guide','对非当前目标 [惊骇]（读条可打断/驱散），恐惧跑得飞快小心引怪。读条控制 ⇒ 3。｜静态证据: Psychic Horror(CTI=16)'),(17732,2,'guide','不停地 [毒液喷吐]，是中毒可驱散或打断。 ｜静态证据: Poison Spit'),(17771,3,'guide','分成三种法系，读条都会造成中等魔法伤害，其中火法型威胁最大。'),(17801,3,'guide','[闪电箭] 可打断；[奥术闪耀] 可驱散魔法 dot；[恐惧] 20 码 4 秒群恐为读条可打断。读条控制 ⇒ 3。｜静态证据: Fear(CTI=4), Arcane Flare'),(17803,3,'guide','[冰霜震击] 会造成单体高额冰霜伤害并缓速 8 秒，[音素爆破] 对近战范围小额 AOE 且沉默 10 秒，两者都是魔法、皆可驱散；[治疗术] 注意打断。 ｜静态证据: Heal, Sonic Burst'),(17815,3,'guide','虽然是黄名怪，但会主动攻击萨尔，而且不给声望。'),(17816,3,'guide','小的会 [穿刺] 目标，使受到的物理伤害提高 15%，可叠加；大的会 [力量衰减] 使力量降低 25%。 ｜静态证据: Piercing Jab'),(17819,3,'guide','对目标 [致死打击]。'),(17820,3,'guide','[多重射击] AOE 和对当前目标 [驱散射击] 使其困惑 4 秒。'),(17833,5,'guide','敦霍尔德看守：队长战 \'优先击杀敦霍尔德看守\'；[治疗] 读条、[心灵尖啸] 瞬发群恐 4 秒、[暗言术：痛] 可驱散。瞬发群恐+留场回血 ⇒ 5。｜静态证据: Psychic Scream(CTI=1), Heal, Shadow Word: Pain'),(17860,3,'guide','随机施放 [暗言术痛] 可驱散、[驱散魔法]、[心灵尖啸] 群恐（读条可打断）。静态表仅见近战技能，与攻略描述不符 ⇒ 3。★待复核｜静态证据: Sinister Strike, Backstab'),(17871,2,'guide','对玩家施放 [疼痒孢子] 疾病伤害 dot 可驱散；[蘑菇再生] 读条治疗可打断/偷取；[过敏] 打喷嚏断法击退。dot+治疗取最高 ⇒ 2。｜静态证据: Itchy Spores, Fungal Regrowth'),(17893,3,'guide','位于尾王房右手边的友方 NPC，完成营救事件后对话给予 [拜特的印记] 增益效果，提高 110 自然抗性与 5% 所有属性。'),(17938,2,'guide','施放 [献祭]，可驱散；丢掷 [烈性炸药]，使 30 码内玩家受到火焰伤害。 ｜静态证据: Immolate'),(17940,3,'guide','[火焰之雨] 造成中等火焰伤害，可以打断或干脆躲开。 ｜静态证据: Rain of Fire'),(17957,5,'guide','[破甲攻击]、[顺劈斩]；[破胆怒吼] 瞬发群恐 6 秒并转头打最高威胁。瞬发群恐+仇恨重置 ⇒ 5。｜静态证据: Frightening Shout(CTI=1)'),(17958,3,'guide','门神怪，免疫控场但可缓速，对坦克造成高额伤害，一般会风筝走一个。[盾牌猛击] 会使目标昏迷 2 秒，[法术反射] 有 50% 机率反弹受到的法术。 ｜静态证据: Shield Slam'),(17960,5,'guide','[智力衰减] 智力 -25%、[支配] 瞬发心控一名玩家 10 秒（不可驱散）。瞬发控制 ⇒ 5。★待确认｜静态证据: Domination(CTI=1), Decayed Intellect'),(17961,3,'guide','[闪电箭] 可打断；群体定身 8 秒的 [纠缠根须] 和指定一个区域施放的 [落雷之云] 两者连招会死人，务必及时驱散定身。 ｜静态证据: Entangling Roots'),(17962,3,'guide','[残废术] 降低攻速与移速，可以打断或驱散。低血量时会 [激怒] 提高攻速。'),(17964,3,'guide','当盘牙纳迦进入战斗，会驱使附近的黄名荒土怪也一起参战；荒土工人会对目标叠加流血 dot [撕裂]，荒土奴隶会施放 [寒冰箭] 和 [冰霜新星]，不过一但盘牙监工死亡，他们就会脱战离开。 ｜静态证据: Rend'),(17993,3,'guide','[水晶打击] 是近战攻击但是造成奥术伤害，所以对坦也不低；[法术反射] 可以在 8 秒内反射 4 次法术。'),(17994,3,'guide','标记一名玩家 [猎鹰的召唤] 使血鹰无视仇恨锁定攻击，[冲锋] 击倒后 [猛扑] 击晕、[摔拌] 缓速；本体无读条控制。⇒ 3。★瞬发锁仇型待确认｜静态证据: Call of the Falcon, Wing Clip'),(18058,2,'guide','地狱火哨兵：治疗 [读条，只打断，击杀优先级 1]；暗言术：痛 [魔法] 伤害 dot、恢复 [魔法] 均可驱散。伤害 dot 取最高 ⇒ 2。｜静态证据: Heal, Shadow Word: Pain, Renew'),(18092,3,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。'),(18093,5,'guide','[震荡猛击] 重击目标昏迷 5 秒（瞬发）；[清洁术] 驱散小怪减益；[快速治疗] 读条可打断。瞬发控制 ⇒ 5。★与 23179/23180 同型待确认'),(18094,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。'),(18311,3,'guide','[灵魂打击] 附带致死效果，对远处玩家 [冲锋] 击倒昏迷 2 秒，低血量时还会 [激怒] 提高伤害与攻速。 ｜静态证据: Charge'),(18312,2,'guide','施放造成中等伤害的 [献祭] DOT，且虚灵巫师相似，会召唤 [虚灵怨魂]。 ｜静态证据: Immolate, Summon Ethereal Wraith'),(18313,3,'guide','[减速]、[奥术飞弹]、召唤会 [魔爆术] 的虚数魔。'),(18314,5,'guide','[凿击] 瞬发昏迷 4 秒，昏迷期间无视被凿目标转打其他人。瞬发控制+仇恨转移 ⇒ 5。｜静态证据: Gouge(CTI=1), Phantom Strike'),(18315,3,'guide','会使用 [变羊术]（读条可打断/可驱散）。读条控制 ⇒ 3。｜静态证据: Polymorph(CTI=16)'),(18317,3,'guide','会对小怪施放治疗量极高的 [治疗术]（读条可打断）；另有瞬发群体治疗 [神圣新星]。瞬发治疗 ⇒ 3。★口径边界待确认（小瞬发 HoT 不算）｜静态证据: Heal(CTI=22), Holy Nova(CTI=1)'),(18318,3,'guide','[法术反射] 持续 6 秒。'),(18321,5,'guide','[击晕] 瞬发眩晕当前仇恨目标并转移仇恨。瞬发控制+仇恨转移 ⇒ 5。｜静态证据: Talon of Justice(CTI=1)'),(18322,3,'guide','门神怪，对坦伤害极高，只吃昏迷控场。场上同时存在二只时，一只死亡另一只 [激怒]。'),(18323,3,'guide','对坦伤害偏高，免疫缴械和昏迷以外的控场，并会 [雷霆一击] 近战范围缓速，是魔法可驱散。'),(18325,3,'guide','死后生成一个 [幽灵]，移动速度缓慢，但近身后造成高额伤害，免疫攻击，几秒后自动消失；被盯上绕道走。 ｜静态证据: Fear'),(18328,3,'guide','对目标与其正面 [奥术闪电]（读条可打断，弹射+群体沉默），坦克使怪背对队友。读条控制 ⇒ 3。｜静态证据: Arcane Lightning(CTI=16)'),(18331,3,'guide','会施放造成中等伤害的 [暗言术痛] DOT，并对 30 有码内的蓝职业施放 [法力燃烧]，点一次最高能烧掉一万点法力值。除此之外，虚灵暗法师还自带一个 [吸血光环]，会在造成近战攻击的同时治疗自身。后二者法术的存在导致他们必需被优先击杀，而且最好全程晕缓控制，让他放不出法术也无法攻击坦克。 ｜静态证据: Shadow Word: Pain'),(18404,3,'guide','[奥术飓风] 是一个 30 码范围的奥术版旋风斩。'),(18405,3,'guide','[奥术冲击] 对目标造成中等伤害并击退；[奥术箭雨] 和 [魔爆术] 两者皆为范围 AOE 且可打断。'),(18419,3,'guide','[管理员之怒] 造成高额伤害，但可打断，被反制后会改用瞬发的 [自然震击] 但伤害就低得多；[昏迷迫近] 会使移速降低 70%，是中毒可驱散，持续时间结束后会使该玩家沉睡 5 秒。'),(18422,1,'guide','植物学家会对魔花施放 [自然之怒]，使它的攻速伤害翻倍；还会施放 [枯木逢春]、[愈合] 治疗小怪，可打断或驱散。 ｜静态证据: Regrowth'),(18431,3,'guide','虚灵航标：沙法尔战 \'全程优先击杀 [虚灵航标]\'（否则变成学徒）；[奥术箭]、自毁召唤 [虚灵学徒]。｜静态证据: 沙法尔战攻略（优先击杀指令）'),(18497,3,'guide','免疫控场，并以 [飓风打击] 造成中等物理伤害并击退附近的玩家。'),(18498,3,'guide','[防护光环] 提供周围小怪极高护甲、并会使用有法术反制效果的 [盾击]。'),(18500,1,'guide','[特效治疗] 治疗小怪，可打断。 ｜静态证据: Major Heal'),(18501,2,'guide','对怪施放 [灵魂复仇]，提高攻速与移速，还会 [蝰蛇钉刺] 抽蓝。 ｜静态证据: Serpent Sting, Spirit Vengeance'),(18503,3,'guide','免疫控场，出现后立即引导 5 秒施法，对一名玩家施放 [占据] 心控他，持续一分钟、或将被心控的玩家的血量削减到 50% 以下方能脱控。'),(18506,3,'guide','桥上的隐形怪，现形后 5 秒会 [暴怒] 自爆击退 8 码内玩家，小心别被弹下桥。'),(18521,3,'guide','周期性地清空威胁值列表、转移仇恨目标，另外因为掉落附魔靴子敏捷配方而成为单刷热门。'),(18524,3,'guide','周期性地 [发怒] 提高攻速。'),(18633,1,'guide','[治疗术]，可打断。 ｜静态证据: Heal'),(18636,5,'guide','击败一王后刷新，潜行游荡，[偷袭]、[凿击] 瞬发偷袭。按同型（凿击=瞬发硬控）从严 ⇒ 5。★无静态数据待确认'),(18637,3,'guide','[精神鞭笞]（引导）与 [暗言术痛] 伤害相当高，后者魔法可驱散。高伤害+dot 取最高 ⇒ 3。★待确认｜静态证据: Mind Flay(引导), Shadow Word: Pain'),(18638,3,'guide','当血量降至 20% 时会施放 [野兽之形] 变身为怪兽，可进攻驱散。'),(18639,3,'guide','会 [洗脑] 心控玩家，可打断。'),(18640,2,'guide','自带 [魔甲术] 吸收暗影伤害，可進攻驱散；对玩家施放 [暗影箭]、[腐蚀之种]，后者应当尽早驱散或爆炸前远离队友。 ｜静态证据: Seed of Corruption'),(18702,2,'guide','奥金尼通灵师：[腐蚀之种] 不驱散会爆炸（可驱散 dot）、[暗影愈合]（可打断）、[吸取灵魂]。｜静态证据: Seed of Corruption, Shadow Mend'),(18794,3,'manual','Cabal Ritualist: must clear before Hellmaw (555)'),(18796,5,'guide','门神免疫控场；[上勾拳]、[致死打击]；[破胆怒吼] 瞬发群恐 6 秒并转头打最高威胁。瞬发群恐+仇恨重置 ⇒ 5。｜静态证据: Frightening Shout(CTI=1), Uppercut'),(18830,3,'guide','无视仇恨目标，[凝视] 特定玩家追击他并提高攻速。'),(18848,3,'guide','会对当前目标施放 [缴械] 和造成额外伤害的 [恶意印记]、对近战范围 [暗影新星] AOE。'),(18894,3,'guide','可控场缓速但无法被奴役，对坦高额物理伤害，务必一次只拉一只；而且还会 [冲锋] 和 [上勾拳]，一套连招巨额伤害，脆皮职业直接升天。另外要注意这种怪的攻击范围很大，似乎有 15 码。 ｜静态证据: Uppercut'),(18934,3,'guide','只在萨尔逃离段刷新。会 [霜甲术]、[冰锥术]、[火球术] 和 [变羊术]（读条可打断，变羊可驱散）。读条控制 ⇒ 3。★无静态数据（脚本）'),(19166,5,'guide','[击倒] 当前目标昏迷 2 秒（瞬发，脚本/EventAI）；半血呼救引怪。瞬发硬控 ⇒ 5（站长 2026-10-19 手动改档）。｜静态证据: 无（脚本流程）'),(19167,3,'guide','本身伤害就高，还会 [旋风斩]、对当前目标 [恒星之击] 重击造成高额伤害并附带致死效果。'),(19168,3,'guide','[灼烧]、[灼热日光] 造成火焰伤害，并会使其目标 [熔化护甲]；对自身施加 [火焰之盾] 持续地 5 码范围 AOE，可进攻驱散或偷取，法师偷取它们能增加不少伤害。'),(19218,3,'guide','看守者盖罗基尔（能源舰看门人）：[锯齿利刃] 4500 物理+8 秒 DOT、[暗影能量] 攻速+115% 可打断、[流动机蒸汽] 中毒可驱散。高伤害 ⇒ 3。'),(19306,3,'guide','会 [法力燃烧] 抽取 30 码内玩家的蓝，死亡时会 [魔爆术] 10 码爆炸，近战远离。'),(19307,5,'guide','[心灵尖啸] 瞬发群恐 4 秒、[死亡缠绕] 瞬发恐惧；[无力诅咒] 诅咒、[暗影之拥] 魔法可驱散。瞬发群恐 ⇒ 5。｜静态证据: Psychic Scream(CTI=1), Death Coil(CTI=1)'),(19428,3,'guide','正面群体攻击，坦克使其保持背对人群。'),(19429,3,'guide','[冲锋] 第二仇恨并击倒，造成中等伤害。 ｜静态证据: Carnivorous Bite, Sonic Charge'),(19486,3,'guide','不停在脚下丢掷 [毒性之瓶]，近战要持续移动；[火息药水] 会正面喷火造成高額火焰傷害。 ｜静态证据: Vial of Poison'),(19507,3,'guide','[死亡凋零] 对一名玩家所在地点指定 8 码范围的高额伤害 AOE，要尽速离开。与收割员、草药学家的小怪组合能组成一套秒杀。 ｜静态证据: Summon Lasher Beast'),(19508,3,'guide','[纠缠根须] 缓速，魔法可驱散。 ｜静态证据: Entangling Roots'),(19509,3,'guide','[变形术] 读条 16 把玩家变花（可打断/驱散）、[枯萎之触] 可驱散。读条控制 ⇒ 3。｜静态证据: Polymorph(CTI=16), Wilting Touch'),(19511,5,'guide','[肾击] 瞬发昏迷 5 秒，[致命药膏] 中毒可驱散。瞬发硬控 ⇒ 5。｜静态证据: Kidney Shot(CTI=1), Deadly Poison'),(19512,2,'guide','[顺劈斩]、[白鬼死亡] 使耐力降低 35%，诅咒可驱散。'),(19632,3,'guide','周期性地 [钉刺狂暴] 提高 75% 攻速。'),(19633,1,'guide','[神圣愤怒] 使小怪提高 295 法伤，可进攻驱散或偷取；[心灵震爆]、[强效治疗术] 均可打断，务必打断后者。 ｜静态证据: Greater Heal'),(19710,3,'guide','看守者埃隆汉（能源舰看门人）：[锤击] 昏迷 6 秒、[风钻] 15 码每秒 2500×8 秒、[暗影能量] 可打断、[流动机蒸汽] 中毒可驱散。高伤害 ⇒ 3。'),(19735,3,'guide','物理伤害偏高但走路较慢，同样会 [击倒]，并会以 [充能之拳] 强化自身，使每次近战攻击都附加造成中等奥术伤害的近战范围 AOE，务必打断，如果没打断就风筝起来吧。'),(19843,3,'guide','以潜行状态存在，会 [背刺]。'),(20059,3,'guide','[奥术新星] 对 10 码内玩家造成中等奥术伤害，并治疗小怪。[驱散魔法] 能主动驱散小怪身上的 debuff。并且召唤会 [奥术箭雨] 的 [奥术仆从]，其死亡时会 [魔爆术]，人宠都是单技能伤害不高、但叠加起来就可观了。'),(20988,3,'guide','[超级缩小射线] 降低攻强、[死亡射线] 随机点名一名玩家造成高额伤害。'),(20990,3,'guide','[神圣震击]、对一名玩家丢掷 [麻醉剂] 昏迷 6 秒，魔法可驱散。[绷带] 治疗小怪。'),(21126,3,'guide','会使用 [治疗术]（读条可打断）；另有瞬发群体治疗 [神圣新星]。瞬发治疗 ⇒ 3。★口径边界待确认（小瞬发 HoT 不算）｜静态证据: Heal(CTI=22), Holy Nova(CTI=1)'),(21127,3,'guide','双持速攻，对当前目标 [影袭]、[致命药膏]。 ｜静态证据: Deadly Poison'),(21128,3,'guide','施放 [惊骇]（读条可打断）一名玩家使其逃跑 3 秒。读条控制 ⇒ 3。｜静态证据: Psychic Horror(CTI=16)'),(21395,6,'manual','priority6(原豁免表 map=554)：Protean Spawn：不断分裂，等坦克仇恨会被淹'),(21609,6,'manual','priority6(原豁免表 map=554)：Protean Spawn (1)：同上'),(21695,3,'guide','一般不打这群水元素，大的会 [冰霜新星]、[水柱喷射] 正面 AOE 带击退，小的频繁 [水箭]，造成中等伤害。'),(22081,3,'guide','会 [恐惧]（读条），还有大范围 [火焰之雨] 务必打断或躲开。读条控制 ⇒ 3。★无静态数据（脚本）'),(23175,3,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。'),(23176,3,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。'),(23177,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。'),(23178,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。'),(23179,5,'guide','[震荡猛击] 重击目标昏迷 5 秒（瞬发）；[清洁术] 驱散小怪减益；[快速治疗] 读条可打断。瞬发控制 ⇒ 5。★待确认'),(23180,5,'guide','[震荡猛击] 重击目标昏迷 5 秒（瞬发）；[清洁术] 驱散小怪减益；[快速治疗] 读条可打断。瞬发控制 ⇒ 5。★待确认');
DROP TABLE IF EXISTS `ai_playerbot_pull_first`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_pull_first` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `max_dist` float NOT NULL DEFAULT '30',
  `max_adds` int unsigned NOT NULL DEFAULT '2',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_pull_first` (`map`, `entry`, `max_dist`, `max_adds`, `note`) VALUES (540,16700,30,2,'Legionnaire: pull it alone before other mobs, wait if >2 adds within 15yd');
DROP TABLE IF EXISTS `ai_playerbot_pull_wait`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_pull_wait` (
  `map` smallint unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT '40',
  `max_assist` int unsigned NOT NULL DEFAULT '1',
  `wait_enemy_fight` tinyint unsigned NOT NULL DEFAULT '1',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_pull_wait` (`map`, `radius`, `max_assist`, `wait_enemy_fight`, `note`) VALUES (552,40,0,1,'stricter: only pull when no assist will join (552)');
DROP TABLE IF EXISTS `ai_playerbot_pullback`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_pullback` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `dist` float NOT NULL DEFAULT '40',
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_pullback` (`map`, `entry`, `dist`, `note`) VALUES (552,20859,30,'Arcatraz Warder: pull back 30yd (knockback/hamstring) before engaging'),(552,20865,25,'Protean Horror: pull back 25yd (Toothy Bite ~1000)'),(552,20901,40,'Sargeron Archer: pull back 40yd before engaging (avoid adds)');
DROP TABLE IF EXISTS `ai_playerbot_route_link`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_route_link` (
  `map` smallint unsigned NOT NULL,
  `src_x` float NOT NULL,
  `src_y` float NOT NULL,
  `src_z` float NOT NULL,
  `dst_x` float NOT NULL,
  `dst_y` float NOT NULL,
  `dst_z` float NOT NULL,
  `kind` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=跳点 1=升降台/传送点',
  `note` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`src_x`,`src_y`,`src_z`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_route_link` (`map`, `src_x`, `src_y`, `src_z`, `dst_x`, `dst_y`, `dst_z`, `kind`, `note`) VALUES (0,-6904.81,-1206.78,178.42,-6904.81,-1206.78,239.9,1,'lift entry=149045 guid=6945 dz=61'),(0,-6900.42,-1339.33,212.05,-6900.42,-1339.33,239.65,1,'lift entry=149046 guid=6946 dz=28'),(0,-5164.47,648.44,350.02,-5164.47,648.44,362.1,1,'lift entry=80022 guid=9411 dz=12'),(0,-5164.24,650.35,249.43,-5164.24,650.35,349.52,1,'lift entry=80023 guid=9450 dz=100'),(0,-5067.02,438.45,410.93,-5067.46,438.98,423.76,1,'lift entry=152614 guid=9290 dz=13'),(0,1533.88,240.83,-40.48,1533.88,240.83,-32.35,1,'lift entry=20657 guid=44909 dz=8'),(0,1544.24,240.77,-40.78,1544.24,240.77,55.72,1,'lift entry=20655 guid=44901 dz=97'),(0,1553.3,240.66,55.4,1553.3,240.66,60.05,1,'lift entry=20656 guid=44890 dz=5'),(0,1595.21,178.69,-40.52,1595.21,178.69,-32.39,1,'lift entry=20654 guid=44954 dz=8'),(0,1595.26,188.64,-40.78,1595.26,188.64,55.72,1,'lift entry=20652 guid=44962 dz=97'),(0,1595.38,197.71,55.4,1595.38,197.71,60.05,1,'lift entry=20653 guid=44891 dz=5'),(0,1596.04,282.74,55.4,1596.04,282.74,60.05,1,'lift entry=20650 guid=44976 dz=5'),(0,1596.15,291.8,-40.78,1596.15,291.8,55.72,1,'lift entry=20649 guid=44892 dz=97'),(0,1596.21,302.4,-40.66,1596.21,302.4,-32.53,1,'lift entry=20651 guid=44893 dz=8'),(1,-11342.6,-4760.16,6.49,-11341.9,-4760.26,19.32,1,'lift entry=152614 guid=93886 dz=13'),(1,-5399.19,-2504.62,-40.28,-5399.19,-2504.62,89.02,1,'lift entry=11898 guid=16875 dz=129'),(1,-5382.5,-2489.42,-40.53,-5382.5,-2489.42,89.03,1,'lift entry=11899 guid=16877 dz=130'),(1,-4670.77,-1849.61,-44.14,-4670.77,-1849.61,85.41,1,'lift entry=11899 guid=16876 dz=130'),(1,-4665.43,-1827.67,-43.89,-4665.43,-1827.67,85.41,1,'lift entry=11898 guid=16874 dz=129'),(1,-1308.38,185.29,68.59,-1308.38,185.29,130.08,1,'lift entry=4171 guid=18435 dz=61'),(1,-1286.24,189.72,68.84,-1286.24,189.72,130.08,1,'lift entry=4170 guid=18298 dz=61'),(1,-1037.27,-49.24,69.27,-1037.27,-49.24,140.49,1,'lift entry=47297 guid=20640 dz=71'),(1,-1028.04,-28.36,69.02,-1028.04,-28.36,140.5,1,'lift entry=47296 guid=20639 dz=71'),(1,2264.14,-5566.1,21.11,2263.7,-5565.56,33.94,1,'lift entry=152614 guid=48263 dz=13'),(47,1729.23,1350.39,-44.14,1729.23,1350.39,85.41,1,'lift entry=11899 guid=4700002 dz=130'),(47,1734.57,1372.32,-43.89,1734.57,1372.32,85.41,1,'lift entry=11898 guid=4700001 dz=129'),(90,-806.89,323.96,-316.2,-806.89,323.96,-271.66,1,'lift entry=85556 guid=900012 dz=45'),(209,2600.81,1228.72,-40.28,2600.81,1228.72,89.02,1,'lift entry=11898 guid=2090002 dz=129'),(209,2617.51,1243.92,-40.53,2617.51,1243.92,89.03,1,'lift entry=11899 guid=2090003 dz=130'),(369,-45.4,3577.49,-114.98,-45.4,4975.79,7.18,1,'lift entry=176082 guid=18804 dz=122'),(369,-45.4,3616.62,-114.98,-45.4,2512.15,6.99,1,'lift entry=176083 guid=18805 dz=122'),(369,-45.39,3538.22,-114.98,-45.39,4956.25,7.18,1,'lift entry=176084 guid=18806 dz=122'),(369,4.5,-1116.2,-114.95,4.5,-11.35,7.01,1,'lift entry=176085 guid=18807 dz=122'),(369,4.53,-1076.63,-114.95,4.53,-2473.86,7.2,1,'lift entry=176081 guid=18803 dz=122'),(369,4.58,-1037.08,-114.95,4.58,-2454.07,7.2,1,'lift entry=176080 guid=18802 dz=122'),(469,-6904.81,-1206.78,178.42,-6904.81,-1206.78,239.9,1,'lift entry=149045 guid=4690001 dz=61'),(469,-6900.42,-1339.33,212.05,-6900.42,-1339.33,239.65,1,'lift entry=149046 guid=4690002 dz=28'),(530,-3297.07,1898.14,106.55,-3297.07,1898.14,168.03,1,'lift entry=149045 guid=16760 dz=61'),(530,-3207.32,1995.78,140.18,-3207.32,1995.78,167.78,1,'lift entry=149046 guid=16761 dz=28'),(530,-2021.46,5482.74,3,-2021.46,5482.74,53.73,1,'lift entry=183203 guid=24075 dz=51'),(530,-2000.07,5678.34,66.15,-2000.07,5678.34,116.88,1,'lift entry=183202 guid=24074 dz=51'),(530,-1810.27,5590.54,2.91,-1810.27,5590.54,129.97,1,'lift entry=183169 guid=24055 dz=127'),(530,285.75,5918.21,26.14,268.49,5919.77,149.39,1,'lift entry=183177 guid=20505 dz=123'),(530,1916.5,5515.03,267.58,1916.06,5515.57,280.41,1,'lift entry=152614 guid=16871 dz=13'),(530,4208.69,3111.24,183.82,4208.69,3111.24,335.3,1,'lift entry=184330 guid=25138 dz=151'),(540,123.07,251.51,-14.58,120.53,245.55,-45.05,2,'tile3131 poly763->759 client jump drop'),(546,245.78,-481.24,81.45,248.18,-481.78,51.35,2,'tile3132 poly4853 platform -> water 4873'),(546,336.97,-474.98,51.45,350.24,-479.79,24.2,2,'tile3132 poly6199->6379 drop jump'),(547,-230.1,-661.3,36.4,-230.1,-661.3,34.7,0,'reach-gap Quagmirran 1.8yd step (2026-10-22 寻路)'),(547,-182.76,-348.31,57.93,-174.07,-351.73,18.67,2,'tile3232 poly1417 platform->water1425'),(547,-179.33,-412.18,59.62,-170.84,-406.4,18.85,2,'tile3232 poly1378 platform->water1384'),(548,-59.13,-98.8,-52.93,-59.13,-98.8,7.21,1,'lift entry=183490 guid=5480002 dz=60'),(548,50,-0.01,-72.06,50,-0.01,820.35,1,'lift entry=183407 guid=5480001 dz=892'),(553,-209.7,394.5,-14.1,-209.6,394.4,-12.5,0,'reach-gap Laj 1.6yd step (2026-10-22)'),(554,0,0,0,0,0,25.44,1,'lift entry=183788 guid=5540001 dz=25');
DROP TABLE IF EXISTS `ai_playerbot_skip_entry`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_skip_entry` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_skip_entry` (`map`, `entry`, `note`) VALUES (552,20864,'Arcatraz Protean Nightmare: temporary protean add (despawns) - do not attack, wait'),(552,20865,'Arcatraz Protean Horror: temporary protean add (despawns) - do not attack, wait'),(552,21186,'Arcane Warder Target: script dummy, not attackable'),(552,21395,'Arcatraz Protean Spawn: protean summon (despawns) - do not attack, wait');
DROP TABLE IF EXISTS `ai_playerbot_unreachable`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_unreachable` (
  `map` smallint unsigned NOT NULL,
  `guid` int unsigned NOT NULL,
  `reason` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

REPLACE INTO `ai_playerbot_unreachable` (`map`, `guid`, `reason`) VALUES (540,5400052,'no_poly'),(540,5400053,'no_poly'),(540,5400054,'no_poly'),(540,5400205,'not_in_region'),(540,5400206,'not_in_region'),(540,5400208,'not_in_region'),(542,5420001,'not_in_region'),(542,5420002,'not_in_region'),(542,5420003,'not_in_region'),(542,5420004,'not_in_region'),(542,5420005,'not_in_region'),(542,5420099,'not_in_region'),(542,5420100,'not_in_region'),(542,5420102,'not_in_region'),(542,5420104,'not_in_region'),(542,5420105,'not_in_region'),(542,5420106,'not_in_region'),(542,5420107,'not_in_region'),(542,5420108,'not_in_region'),(542,5420111,'not_in_region'),(542,5420112,'not_in_region'),(542,5420113,'not_in_region'),(542,5420114,'not_in_region'),(542,5420117,'not_in_region'),(542,5420118,'not_in_region'),(542,5420120,'not_in_region'),(542,5420122,'not_in_region'),(542,5420123,'not_in_region'),(542,5420125,'not_in_region'),(542,5420127,'not_in_region'),(542,5420128,'not_in_region'),(542,5420129,'not_in_region'),(542,5420130,'not_in_region'),(542,5420131,'not_in_region'),(542,5420133,'not_in_region'),(542,5420136,'not_in_region'),(542,5420138,'not_in_region'),(542,5420139,'not_in_region'),(542,5420140,'not_in_region'),(542,5420142,'not_in_region'),(542,5420143,'not_in_region'),(542,5420145,'not_in_region'),(542,5420147,'not_in_region'),(542,5420148,'not_in_region'),(542,5420149,'not_in_region'),(542,5420150,'not_in_region'),(542,5420151,'not_in_region'),(542,5420152,'not_in_region'),(542,5420153,'not_in_region'),(542,5420154,'not_in_region'),(542,5420155,'not_in_region'),(542,5420156,'not_in_region'),(542,5420157,'not_in_region'),(542,5420159,'not_in_region'),(542,5420160,'not_in_region'),(542,5420161,'not_in_region'),(542,5420163,'not_in_region'),(542,5420164,'not_in_region'),(542,5420165,'not_in_region'),(542,5420212,'not_in_region'),(543,5430085,'not_in_region'),(543,5430090,'no_poly'),(545,5450135,'no_poly'),(546,5460117,'no_poly'),(546,5460121,'no_poly'),(546,5460122,'no_poly'),(546,5460123,'no_poly'),(546,5460124,'no_poly'),(546,5460125,'no_poly'),(546,5460126,'no_poly'),(546,5460127,'no_poly'),(546,5460128,'no_poly'),(546,5460129,'not_in_region'),(546,5460141,'not_in_region'),(546,5460142,'no_poly'),(546,5460143,'no_poly'),(546,5460144,'no_poly'),(546,5460145,'no_poly'),(546,5460146,'no_poly'),(546,5460147,'no_poly'),(546,5460148,'no_poly'),(546,5460149,'no_poly'),(546,5460150,'not_in_region'),(546,5460156,'not_in_region'),(546,5460157,'no_poly'),(546,5460158,'not_in_region'),(546,5460159,'not_in_region'),(546,5460160,'no_poly'),(546,5460161,'no_poly'),(546,5460162,'not_in_region'),(546,5460163,'not_in_region'),(546,5460164,'no_poly'),(546,5460165,'not_in_region'),(546,5460166,'not_in_region'),(546,5460167,'not_in_region'),(546,5460168,'not_in_region'),(546,5460169,'not_in_region'),(546,5460170,'no_poly'),(546,5460171,'no_poly'),(546,5460172,'no_poly'),(546,5460173,'no_poly'),(546,5460174,'not_in_region'),(546,5460175,'no_poly'),(546,5460176,'no_poly'),(546,5460177,'no_poly'),(546,5460178,'not_in_region'),(546,5460179,'no_poly'),(546,5460180,'no_poly'),(546,5460182,'not_in_region'),(546,5460183,'not_in_region'),(546,5460184,'not_in_region'),(547,5470023,'no_poly'),(547,5470148,'not_in_region'),(547,5470149,'not_in_region'),(547,5470151,'not_in_region'),(547,5470153,'not_in_region'),(547,5470154,'not_in_region'),(547,5470159,'not_in_region'),(547,5470160,'no_poly'),(547,5470161,'not_in_region'),(547,5470162,'not_in_region'),(547,5470163,'not_in_region'),(547,5470165,'not_in_region'),(547,5470167,'not_in_region'),(547,5470168,'not_in_region'),(547,5470169,'not_in_region'),(547,5470170,'not_in_region'),(547,5470171,'not_in_region'),(547,5470173,'not_in_region'),(547,5470174,'not_in_region'),(547,5470176,'not_in_region'),(547,5470180,'not_in_region'),(547,5470181,'not_in_region'),(547,5470184,'not_in_region'),(547,5470186,'not_in_region'),(547,5470187,'not_in_region'),(547,5470188,'not_in_region'),(547,5470189,'not_in_region'),(547,5470223,'no_poly'),(552,5520140,'no_poly'),(552,5520141,'no_poly'),(552,5520142,'no_poly'),(552,5520143,'no_poly'),(552,5520144,'no_poly'),(553,5530140,'no_poly'),(553,5530141,'not_in_region'),(553,5530142,'not_in_region'),(553,5530143,'not_in_region'),(555,5550141,'no_poly'),(555,5550142,'no_poly'),(555,5550143,'no_poly'),(555,5550144,'no_poly'),(555,5550145,'no_poly'),(555,5550146,'no_poly'),(555,5550228,'not_in_region'),(555,5550244,'no_poly'),(555,5550245,'not_in_region'),(555,5550246,'not_in_region'),(556,5560130,'not_in_region'),(556,5560135,'no_poly'),(556,5560136,'no_poly'),(556,5560138,'no_poly'),(556,5560140,'no_poly'),(556,5560142,'no_poly'),(556,5560143,'no_poly'),(558,5580060,'no_poly'),(558,5580061,'no_poly'),(558,5580068,'no_poly'),(558,5580069,'no_poly'),(558,5580143,'no_poly'),(558,5580144,'no_poly'),(558,5580145,'no_poly'),(558,5580146,'no_poly'),(558,5580147,'no_poly'),(558,5580148,'no_poly'),(558,5580161,'no_poly'),(558,5580162,'no_poly'),(558,5580163,'no_poly'),(558,5580164,'no_poly');
DROP TABLE IF EXISTS `ai_playerbot_weightscale_caps`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_weightscale_caps` (
  `id` int NOT NULL,
  `field` varchar(18) NOT NULL,
  `cap` int unsigned NOT NULL,
  `capped` int unsigned NOT NULL,
  `alt_field` varchar(18) NOT NULL DEFAULT '',
  `alt_cap` int unsigned NOT NULL DEFAULT '0',
  `cap2` int unsigned NOT NULL DEFAULT '0',
  `capped2` int unsigned NOT NULL DEFAULT '0',
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

REPLACE INTO `ai_playerbot_weightscale_caps` (`id`, `field`, `cap`, `capped`, `alt_field`, `alt_cap`, `cap2`, `capped2`) VALUES (1,'hitrtng',142,6,'',0,0,0),(1,'exprtng',103,5,'',0,0,0),(2,'hitrtng',142,6,'',0,0,0),(2,'exprtng',103,5,'',0,0,0),(3,'hitrtng',142,6,'',0,0,0),(3,'exprtng',103,5,'',0,221,0),(3,'armor',35880,0,'',0,0,0),(30,'resirtng',102,8,'defrtng',156,0,0),(30,'defrtng',156,8,'resirtng',102,0,0),(30,'armor',35880,0,'',0,0,0),(30,'hitrtng',127,6,'',0,0,0),(30,'exprtng',60,6,'',0,0,0),(5,'defrtng',332,10,'',0,0,0),(5,'spellhitrtng',63,15,'',0,0,0),(5,'avoid4',10240,0,'',0,0,0),(5,'dodgertng',0,15,'',0,0,0),(5,'parryrtng',0,15,'',0,0,0),(5,'blockrtng',0,20,'',0,0,0),(5,'block',2400,10,'',0,0,0),(7,'hitrtng',142,8,'',0,0,0),(8,'hitrtng',142,8,'',0,0,0),(9,'hitrtng',142,8,'',0,0,0),(10,'hitrtng',142,6,'',0,0,0),(10,'exprtng',103,6,'',0,0,0),(11,'hitrtng',142,6,'',0,0,0),(11,'exprtng',103,6,'',0,0,0),(12,'hitrtng',142,6,'',0,0,0),(12,'exprtng',103,6,'',0,0,0),(15,'spellhitrtng',164,0,'',0,0,0),(20,'spellhitrtng',51,0,'',0,0,0),(23,'spellhitrtng',76,0,'',0,0,0),(24,'spellhitrtng',164,0,'',0,0,0),(25,'spellhitrtng',164,0,'',0,0,0),(26,'spellhitrtng',164,0,'',0,0,0),(27,'spellhitrtng',164,0,'',0,0,0),(28,'spellhitrtng',164,0,'',0,0,0),(29,'spellhitrtng',152,0,'',0,0,0),(21,'hitrtng',142,5,'',0,0,0),(21,'exprtng',103,4,'',0,0,0),(32,'defrtng',156,2,'resirtng',103,0,0),(32,'armor',35880,0,'',0,0,0);
DROP TABLE IF EXISTS `ai_playerbot_weightscale_data`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_weightscale_data` (
  `id` int NOT NULL,
  `field` varchar(18) NOT NULL,
  `val` smallint unsigned NOT NULL,
  KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

REPLACE INTO `ai_playerbot_weightscale_data` (`id`, `field`, `val`) VALUES (6,'mledps',100),(6,'hitrtng',45),(6,'str',50),(6,'exprtng',75),(6,'critstrkrtng',36),(6,'atkpwr',21),(6,'agi',35),(6,'hastertng',34),(6,'armorpenrtng',5),(6,'splpwr',20),(16,'mledps',360),(16,'armorpenrtng',100),(16,'str',99),(16,'hitrtng',91),(16,'exprtng',90),(16,'critstrkrtng',57),(16,'hastertng',55),(16,'atkpwr',36),(16,'armor',1),(17,'mledps',337),(17,'hitrtng',100),(17,'str',97),(17,'exprtng',81),(17,'armorpenrtng',61),(17,'critstrkrtng',45),(17,'atkpwr',35),(17,'hastertng',28),(17,'armor',1),(18,'mledps',419),(18,'parryrtng',100),(18,'hitrtng',97),(18,'str',96),(18,'defrtng',85),(18,'exprtng',69),(18,'dodgertng',61),(18,'agi',61),(18,'sta',61),(18,'critstrkrtng',49),(18,'atkpwr',41),(18,'armorpenrtng',31),(18,'armor',5),(19,'mledps',209),(19,'str',100),(19,'hitrtng',66),(19,'exprtng',51),(19,'hastertng',48),(19,'critstrkrtng',45),(19,'atkpwr',34),(19,'armorpenrtng',32),(19,'armor',1),(21,'hitrtng',58),(21,'exprtng',100),(21,'agi',50),(21,'int',3),(21,'critstrkrtng',51),(21,'hastertng',67),(21,'str',78),(21,'atkpwr',35),(21,'splpwr',16),(21,'armorpenrtng',10),(6,'manargn',50),(6,'spellcritstrkrtng',8),(6,'spellhitrtng',20),(6,'spi',1),(6,'int',13),(21,'spellcritstrkrtng',7),(21,'spellhitrtng',30),(21,'spi',2),(1,'str',204),(1,'exprtng',160),(1,'hitrtng',150),(1,'hastertng',118),(1,'agi',110),(1,'atkpwr',102),(1,'critstrkrtng',100),(1,'armorpenrtng',27),(1,'mledps',100),(2,'str',204),(2,'exprtng',160),(2,'hitrtng',150),(2,'hastertng',125),(2,'agi',110),(2,'atkpwr',102),(2,'critstrkrtng',100),(2,'armorpenrtng',27),(2,'mledps',100),(4,'int',440),(4,'splheal',100),(4,'splpwr',100),(4,'manargn',60),(4,'spellcritstrkrtng',60),(4,'spellhastertng',50),(4,'spi',40),(7,'hitrtng',260),(7,'agi',210),(7,'critstrkrtng',170),(7,'hastertng',150),(7,'atkpwr',100),(7,'int',20),(8,'hitrtng',260),(8,'agi',210),(8,'critstrkrtng',170),(8,'hastertng',150),(8,'atkpwr',100),(8,'int',20),(9,'hitrtng',260),(9,'agi',210),(9,'critstrkrtng',170),(9,'hastertng',150),(9,'atkpwr',100),(9,'int',20),(10,'hitrtng',250),(10,'exprtng',230),(10,'agi',221),(10,'hastertng',200),(10,'critstrkrtng',176),(10,'armorpenrtng',120),(10,'atkpwr',100),(10,'str',50),(10,'mledps',100),(11,'hitrtng',250),(11,'exprtng',230),(11,'agi',221),(11,'hastertng',200),(11,'critstrkrtng',176),(11,'armorpenrtng',120),(11,'atkpwr',100),(11,'str',50),(11,'mledps',100),(12,'hitrtng',250),(12,'exprtng',230),(12,'agi',221),(12,'hastertng',200),(12,'critstrkrtng',176),(12,'armorpenrtng',120),(12,'atkpwr',100),(12,'str',50),(12,'mledps',100),(13,'spellhastertng',150),(13,'splheal',100),(13,'spi',60),(13,'int',60),(13,'spellcritstrkrtng',40),(13,'manargn',15),(14,'spellhastertng',150),(14,'splheal',100),(14,'spi',60),(14,'int',60),(14,'spellcritstrkrtng',40),(14,'manargn',15),(15,'spellhitrtng',140),(15,'splpwr',100),(15,'spellcritstrkrtng',80),(15,'spellhastertng',80),(15,'int',26),(15,'spi',20),(15,'manargn',10),(20,'splpwr',100),(20,'spellcritstrkrtng',80),(20,'spellhitrtng',70),(20,'spellhastertng',60),(20,'int',20),(20,'manargn',20),(22,'manargn',200),(22,'spellhastertng',150),(22,'splheal',100),(22,'int',50),(22,'spellcritstrkrtng',30),(23,'int',100),(23,'splpwr',100),(23,'spellhitrtng',70),(23,'spellcritstrkrtng',60),(23,'spellhastertng',50),(23,'manargn',40),(23,'spi',30),(24,'splpwr',100),(24,'spellhitrtng',120),(24,'spellcritstrkrtng',70),(24,'spellhastertng',60),(24,'manargn',25),(24,'int',20),(24,'spi',15),(25,'splpwr',100),(25,'spellhitrtng',120),(25,'spellcritstrkrtng',70),(25,'spellhastertng',60),(25,'manargn',25),(25,'int',20),(25,'spi',15),(26,'spellhastertng',126),(26,'spellhitrtng',120),(26,'splpwr',110),(26,'spellcritstrkrtng',86),(26,'int',26),(26,'spi',10),(26,'manargn',6),(27,'spellhastertng',126),(27,'spellhitrtng',120),(27,'splpwr',110),(27,'spellcritstrkrtng',86),(27,'int',26),(27,'spi',10),(27,'manargn',6),(28,'spellhastertng',126),(28,'spellhitrtng',120),(28,'splpwr',110),(28,'spellcritstrkrtng',86),(28,'int',26),(28,'spi',10),(28,'manargn',6),(29,'spellhitrtng',140),(29,'spellcritstrkrtng',100),(29,'splpwr',90),(29,'spellhastertng',60),(29,'int',20),(29,'spi',15),(29,'manargn',10),(3,'sta',110),(3,'defrtng',68),(3,'blockrtng',63),(3,'agi',63),(3,'dodgertng',53),(3,'parryrtng',42),(3,'armor',95),(3,'hitrtng',52),(3,'exprtng',46),(3,'str',40),(3,'block',58),(3,'critstrkrtng',34),(3,'atkpwr',30),(3,'mledps',100),(5,'sta',110),(5,'blockrtng',63),(5,'dodgertng',53),(5,'defrtng',50),(5,'parryrtng',42),(5,'armor',70),(5,'splpwr',90),(5,'spellhitrtng',50),(5,'block',44),(5,'exprtng',38),(5,'hitrtng',32),(5,'agi',30),(5,'str',30),(5,'int',15),(5,'manargn',15),(5,'spellcritstrkrtng',15),(31,'splheal',110),(31,'spi',90),(31,'spellhastertng',80),(31,'manargn',60),(31,'int',30),(31,'spellcritstrkrtng',10),(30,'armor',150),(30,'sta',150),(30,'resirtng',120),(30,'agi',100),(30,'exprtng',100),(30,'defrtng',90),(30,'hitrtng',90),(30,'dodgertng',70),(30,'str',60),(30,'critstrkrtng',40),(30,'feratkpwr',40),(30,'atkpwr',30),(30,'hastertng',20),(32,'str',200),(32,'agi',180),(32,'exprtng',150),(32,'hitrtng',150),(32,'critstrkrtng',120),(32,'hastertng',90),(32,'atkpwr',60),(32,'feratkpwr',60),(32,'armorpenrtng',40),(32,'sta',30),(32,'armor',20);
DROP TABLE IF EXISTS `ai_playerbot_weightscales`;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_playerbot_weightscales` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb3 ROW_FORMAT=COMPACT;

REPLACE INTO `ai_playerbot_weightscales` (`id`, `name`, `class`) VALUES (1,'arms',1),(2,'fury',1),(3,'prot',1),(4,'holy',2),(5,'prot',2),(6,'retrib',2),(7,'beast',3),(8,'marks',3),(9,'surv',3),(10,'assas',4),(11,'combat',4),(12,'subtle',4),(13,'disc',5),(14,'holy',5),(15,'shadow',5),(16,'blooddps',6),(17,'frostdps',6),(18,'frosttank',6),(19,'unholydps',6),(20,'elem',7),(21,'enhance',7),(22,'resto',7),(23,'arcane',8),(24,'fire',8),(25,'frost',8),(26,'afflic',9),(27,'demo',9),(28,'destro',9),(29,'balance',11),(30,'feraltank',11),(31,'resto',11),(32,'feraldps',11);



