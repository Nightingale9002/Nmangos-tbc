-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：观测_真人跳跃电梯
-- 来源（旧编号）：206_观测_真人跳跃电梯.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- [2026-10-19 站长口径] 真人跳跃 / 电梯标注观测（PlayerNavObs.h）
--   jump_obs：MSG_MOVE_JUMP 起点 -> MSG_MOVE_FALL_LAND 落点，含 mmap 方块 tile
--   lift_obs：竖移不动水平（电梯/升降台）的上下点与 tile
--   两张表都带 verified 列：默认 0，由人工标注为 1 后可作为路线跳点/升降台数据。
-- ============================================================================
USE `tbcmangos`;
CREATE TABLE IF NOT EXISTS `ai_playerbot_jump_obs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ts` int unsigned NOT NULL DEFAULT 0,
  `map` smallint unsigned NOT NULL DEFAULT 0,
  `instance_id` int unsigned NOT NULL DEFAULT 0,
  `is_bot` tinyint unsigned NOT NULL DEFAULT 0,
  `player_guid` int unsigned NOT NULL DEFAULT 0,
  `player_name` varchar(32) NOT NULL DEFAULT '',
  `src_x` float NOT NULL DEFAULT 0, `src_y` float NOT NULL DEFAULT 0, `src_z` float NOT NULL DEFAULT 0,
  `src_tile` int NOT NULL DEFAULT 0, `src_tile_x` tinyint NOT NULL DEFAULT 0, `src_tile_y` tinyint NOT NULL DEFAULT 0,
  `dst_x` float NOT NULL DEFAULT 0, `dst_y` float NOT NULL DEFAULT 0, `dst_z` float NOT NULL DEFAULT 0,
  `dst_tile` int NOT NULL DEFAULT 0, `dst_tile_x` tinyint NOT NULL DEFAULT 0, `dst_tile_y` tinyint NOT NULL DEFAULT 0,
  `dz` float NOT NULL DEFAULT 0, `dist2d` float NOT NULL DEFAULT 0,
  `duration_ms` int unsigned NOT NULL DEFAULT 0,
  `verified` tinyint unsigned NOT NULL DEFAULT 0,
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`), KEY `idx_map_verified` (`map`,`verified`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `ai_playerbot_lift_obs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `ts` int unsigned NOT NULL DEFAULT 0,
  `map` smallint unsigned NOT NULL DEFAULT 0,
  `instance_id` int unsigned NOT NULL DEFAULT 0,
  `is_bot` tinyint unsigned NOT NULL DEFAULT 0,
  `player_guid` int unsigned NOT NULL DEFAULT 0,
  `player_name` varchar(32) NOT NULL DEFAULT '',
  `src_x` float NOT NULL DEFAULT 0, `src_y` float NOT NULL DEFAULT 0, `src_z` float NOT NULL DEFAULT 0,
  `src_tile` int NOT NULL DEFAULT 0, `src_tile_x` tinyint NOT NULL DEFAULT 0, `src_tile_y` tinyint NOT NULL DEFAULT 0,
  `dst_x` float NOT NULL DEFAULT 0, `dst_y` float NOT NULL DEFAULT 0, `dst_z` float NOT NULL DEFAULT 0,
  `dst_tile` int NOT NULL DEFAULT 0, `dst_tile_x` tinyint NOT NULL DEFAULT 0, `dst_tile_y` tinyint NOT NULL DEFAULT 0,
  `d_z` float NOT NULL DEFAULT 0,
  `duration_ms` int unsigned NOT NULL DEFAULT 0,
  `verified` tinyint unsigned NOT NULL DEFAULT 0,
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`), KEY `idx_map_verified` (`map`,`verified`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================================
