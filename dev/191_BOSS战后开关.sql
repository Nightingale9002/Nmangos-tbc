-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：BOSS战后开关
-- 来源（旧编号）：207_BOSS战后开关.sql、207_BOSS战后开关.sql（数据）
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- [2026-10-19 站长口径] boss 战后开关（蒸汽地窟门禁面板 / 毒蛇神殿桥控制台）
--   挂在 boss 上（boss_entry），由 DungeonRoute.h → FindPendingBossSwitch() 使用：
--   boss 打死后驱动坦克走到开关旁 GameObject::Use()，不是通用"卡住就开锁"。
-- ============================================================================
USE `tbcmangos`;
CREATE TABLE IF NOT EXISTS `ai_playerbot_boss_switch` (
  `map` smallint unsigned NOT NULL,
  `boss_entry` int unsigned NOT NULL,
  `go_guid` int unsigned NOT NULL,
  `go_entry` int unsigned NOT NULL DEFAULT 0,
  `x` float NOT NULL DEFAULT 0, `y` float NOT NULL DEFAULT 0, `z` float NOT NULL DEFAULT 0,
  `kind` tinyint unsigned NOT NULL DEFAULT 0 COMMENT '0=boss 战后点开关',
  `note` varchar(96) NOT NULL DEFAULT '',
  PRIMARY KEY (`map`,`go_guid`), KEY `idx_boss` (`boss_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- boss 打死后需要点的开关（蒸汽地窟门禁面板 / 毒蛇神殿桥控制台），挂在 boss_entry 上
USE `tbcmangos`;
INSERT IGNORE INTO `ai_playerbot_boss_switch`
  (`map`,`boss_entry`,`go_guid`,`go_entry`,`x`,`y`,`z`,`kind`,`note`) VALUES
(545,17797,5450035,184125,98.8,-316.3,-6.7,0,'蒸汽地窟：水术师塞斯匹亚后开主厅门'),
(545,17796,5450036,184126,-332.4,-117.2,-6.7,0,'蒸汽地窟：机械师蒸汽触发器后开瓦洛克门'),
(548,21214,5480006,184568,47.8,-581.8,4.7,0,'毒蛇神殿：深水领主卡拉瑟雷斯后放瓦丝琪桥'),
(548,21216,5480030,185114,457.4,-555.3,-7.0,0,'毒蛇神殿：海德斯后（待站长确认控制台）'),
(548,21217,5480031,185115,373.1,-465.1,30.7,0,'毒蛇神殿：潜伏者后（待站长确认控制台）'),
(548,21215,5480032,185116,349.0,-684.1,-12.4,0,'毒蛇神殿：盲眼者后（待站长确认控制台）');
