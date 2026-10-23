-- [2026-10-22] 540 破碎大厅特殊策略：按"附近同类怪数量"动态调整拉怪权重。
--   语义：附近该 entry 的活怪数量 < engage_count ⇒ 无视它继续推进；
--         >= engage_count ⇒ 正常清，且数量越多权重越高（等效距离 d/(1+weight_per_count*count)）。
--   站长 2026-10-22：engage_count 偏大 ⇒ Oozeling 8→4、Zealot 6→3；
--   之后靠 ai_playerbot_decision_weight 的 mob.count.engage_scale（300s 热加载）在线扫参。
CREATE TABLE IF NOT EXISTS `ai_playerbot_mob_count_weight` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `radius` float NOT NULL DEFAULT 25,
  `engage_count` smallint unsigned NOT NULL DEFAULT 4,
  `weight_per_count` float NOT NULL DEFAULT 0.15,
  `note` varchar(128) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `ai_playerbot_mob_count_weight` (`map`,`entry`,`radius`,`engage_count`,`weight_per_count`,`note`) VALUES
  (540, 17357, 25, 4, 0.15, 'Creeping Oozeling：数量少无视继续推进，攒多了才清'),
  (540, 17462, 25, 3, 0.20, 'Shattered Hand Zealot：同上')
ON DUPLICATE KEY UPDATE `radius`=VALUES(`radius`), `engage_count`=VALUES(`engage_count`),
  `weight_per_count`=VALUES(`weight_per_count`), `note`=VALUES(`note`);

INSERT INTO `ai_playerbot_decision_weight` (`key`,`weight`,`note`) VALUES
  ('mob.count.engage_scale', 1.0, '540 同类怪攒够才清的门槛倍率（engage_count × 本值，下限1）')
ON DUPLICATE KEY UPDATE `note`=VALUES(`note`);
