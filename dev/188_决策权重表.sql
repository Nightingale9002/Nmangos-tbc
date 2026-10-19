-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：决策权重表
-- 来源（旧编号）：202_决策权重表.sql、203_决策权重表_移除标签泄漏项.sql、204_决策权重扩展.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- 202_决策权重表.sql
-- [2026-10-18 决策参数化] 把策略里写死的打分权重挪到数据（后续离线调参 / RL 的入口）。
--
-- 表在 **characters 库**（与 ai_playerbot_priority_target 等运行期数据同库）。
-- 代码默认值见 playerbot/DecisionWeights.h（表里没有的 key 用默认值，缺表也能跑）。
-- 改完 300 秒内生效（模块按 300s 重读，不用重启）。
--
-- 当前已接入的 key：
--   target.threat_tier        目标选择：威胁等级权重（默认 100）
--   target.distance           目标选择：距离权重（默认 -1 / 码）
--   target.casting            目标选择：正在读条加成（默认 30）
--   position.cover_distance   卡视野掩体点：距离权重（默认 -1，取最近）
--   log.decision              预留：决策打分日志开关（0/1，默认 0）
--
-- 幂等（IF NOT EXISTS + INSERT IGNORE），可重复执行。
-- 云端执行：mysql --defaults-file=/root/.my_cm.cnf tbccharacters < dev/202_决策权重表.sql
-- 本地执行：mysql -uroot -pqwerty tbccharacters < dev/202_决策权重表.sql

CREATE TABLE IF NOT EXISTS `ai_playerbot_decision_weight` (
  `key`    VARCHAR(64)  NOT NULL COMMENT '决策项.因子，例 target.threat_tier',
  `weight` FLOAT        NOT NULL DEFAULT 0 COMMENT '权重（线性加权求和；负值=惩罚）',
  `note`   VARCHAR(255) NOT NULL DEFAULT '' COMMENT '说明/调参记录',
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='playerbot 决策打分权重（离线调参/RL 入口）';

INSERT IGNORE INTO `ai_playerbot_decision_weight` (`key`,`weight`,`note`) VALUES
  ('target.threat_tier',       100,  '目标：威胁等级权重'),
  ('target.distance',          -1,   '目标：距离惩罚（每码）'),
  ('target.casting',           30,   '目标：正在读条加成'),
  ('position.cover_distance',  -1,   '卡视野掩体点：距离惩罚（每码）'),
  ('log.decision',             0,    '预留：决策打分日志开关');

-- 复核：SELECT `key`,`weight` FROM tbccharacters.ai_playerbot_decision_weight ORDER BY `key`;

-- 203_决策权重表_移除标签泄漏项.sql
-- [2026-10-18 站长口径] 骷髅标记是**人工指挥（动作/结果）**，不是特征（原因）：
--   - 代码侧：标记改为 override（先按标记选中），不再进入加权打分；
--   - 数据侧：删掉权重表里的 target.skull（避免以后又被当成可学习特征）。
-- 幂等（DELETE 重复执行无副作用）。
DELETE FROM `tbccharacters`.`ai_playerbot_decision_weight` WHERE `key` = 'target.skull';

-- 204_决策权重扩展.sql
-- [2026-10-18 决策参数化·第二批] 把剩余决策点也挪到权重表：
--   控制目标排序 / 治疗目标排序 / 进攻驱散排序 / 跑位模式选择。
-- 代码默认值见 playerbot/DecisionWeights.h；表里没有的 key 用默认值。
-- 幂等（INSERT IGNORE）。
-- 云端：mysql --defaults-file=/root/.my_cm.cnf tbccharacters < dev/204_决策权重扩展.sql
-- 本地：mysql -uroot -pqwerty tbccharacters < dev/204_决策权重扩展.sql

INSERT IGNORE INTO `ai_playerbot_decision_weight` (`key`,`weight`,`note`) VALUES
  -- 控制（CC）目标排序
  ('cc.needs_control',        100,  '优先级4（需要优先控制）加成'),
  ('cc.dps',                  1,    '普通输出能力权重（近战/远程取大）'),
  ('cc.priority_rank',        15,   '威胁等级加权'),
  ('cc.distance',             -1,   '距离惩罚（每码）'),
  -- 治疗目标排序
  ('heal.missing_health',     100,  '缺失血量权重（按最大血量百分比）'),
  ('heal.tank_bonus',         30,   '坦克加成'),
  ('heal.incoming_damage',    1,    '预计承伤加权（preheal 时算入缺失血量）'),
  ('heal.distance',           -0.5, '距离惩罚（每码）'),
  -- 进攻驱散排序
  ('dispel.buff_count',       50,   '目标身上魔法增益数量加权'),
  ('dispel.casting',          30,   '目标正在读条加成'),
  ('dispel.priority_rank',    20,   '威胁等级加权'),
  ('dispel.distance',         -1,   '距离惩罚（每码）'),
  -- 跑位模式选择（同一只怪同时命中多种模式时按分值挑一个）
  ('position.mode.los_all',       100, '卡视野（全队）'),
  ('position.mode.los_pull',      95,  '卡视野拉怪（坦克去卡点）'),
  ('position.mode.los_backline',  90,  '卡视野（远程/治疗）'),
  ('position.mode.los_break',     85,  '断读条卡视野'),
  ('position.mode.frontal',       70,  '避开正面'),
  ('position.mode.knockback',     60,  '击退沙包/回位'),
  ('position.mode.stack',         40,  '集合'),
  ('position.mode.spread',        30,  '分散'),
  ('position.mode.wall',          20,  '贴墙防击飞');



-- ============================================================================
