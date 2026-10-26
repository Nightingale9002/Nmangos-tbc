-- [卡视野点库 2026-10-26] 离线预筛的"贴墙 + 怪看不见"的点位，战斗时实时挑最近的用。
-- 生成：控制台 `.rndbot sim spots <mapId|all>`（需要 VMap/MMap 已加载，不需要开图）。
CREATE TABLE IF NOT EXISTS `ai_playerbot_cover_spot` (
  `map`         smallint unsigned NOT NULL,
  `x`           float NOT NULL,
  `y`           float NOT NULL,
  `z`           float NOT NULL,
  `wall_dist`   float NOT NULL DEFAULT 0 COMMENT '离墙距离（码），越小越贴墙',
  `block_rays`  tinyint unsigned NOT NULL DEFAULT 0 COMMENT '1.2 码半径内 16 条射线被挡住的条数（>=8 即 180 度）',
  `seen_max_ord` smallint unsigned NOT NULL DEFAULT 0 COMMENT '能看到这个点的最大波次；0=谁都看不见，9999=巡逻怪看得见',
  `seen_count`  smallint unsigned NOT NULL DEFAULT 0 COMMENT '能看到这个点的路线怪数量',
  PRIMARY KEY (`map`,`x`,`y`),
  KEY `idx_map_seen` (`map`,`seen_max_ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='离线预筛的卡视野点库（.rndbot sim spots 生成）';
