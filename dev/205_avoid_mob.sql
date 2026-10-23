-- [2026-10-23] "无敌 + 击飞"类怪按躲地板处理（不是拉怪）。
--   引擎已有 avoid specific creatures 策略：CloseToSpecificCreaturesTrigger → move away from specific creatures。
--   这里只提供数据：某张图里哪些 entry 要躲。
CREATE TABLE IF NOT EXISTS `ai_playerbot_avoid_mob` (
  `map` smallint unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `note` varchar(160) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `ai_playerbot_avoid_mob` (`map`,`entry`,`note`) VALUES
  (558, 18506, 'Raging Soul：无敌+击飞，被打飞掉桥会死；按躲地板处理，不拉')
ON DUPLICATE KEY UPDATE `note`=VALUES(`note`);
