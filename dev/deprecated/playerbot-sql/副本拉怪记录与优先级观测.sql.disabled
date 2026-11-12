-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：副本拉怪记录与优先级观测
-- 来源（旧编号）：192_副本拉怪记录表.sql、193_优先级观测表.sql、194_副本拉怪记录_所有玩家.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================
-- 192_副本拉怪记录表.sql
-- [副本推进 2026-10-18 站长口径] 服务器要记录**每一轮副本的拉怪顺序**和**每一次拉怪的结果**。
--
-- 口径：
--   一轮副本 = 一个副本实例（`instance_id`；WoW 每次新建副本实例都会换号，出本再进通常还是同一个）
--   拉怪顺序 = `seq`（本轮第 1、2、3…次拉怪）
--   每次拉怪结果 = `result`：
--       pending  拉怪已开始、还没结束（进程异常退出会留这种）
--       cleared  这波打光了（或 boss 打死了）
--       skipped  卡住被跳过（DungeonRoute 的 90 秒卡住保护）
--       died     拉怪过程中（驱动坦克所在队伍）有人死了 ⇒ 记录死亡数，方便区分"打掉"和"打崩"
--       left     中途换图/出本/换实例
--   同时记 `mobs_total`（开拉时这波还活着几只）、`mobs_alive`（结束时还剩几只）、
--   `deaths`（本次拉怪期间队伍死亡人数 = 开拉时活人数 - 结束时活人数）。
--
-- 写入方：playerbot 模块 `dungeonroute::PullBegin()/PullEnd()`（见 playerbot/DungeonRoute.h）。
--   每次拉怪只写两条语句（开始 INSERT、结束 UPDATE），失败静默 —— 记录是可选增强，
--   表不存在时整个记录功能自动失效，不影响推进。
--
-- 全部幂等（IF NOT EXISTS），可重复执行。

CREATE TABLE IF NOT EXISTS `ai_playerbot_pull_log` (
  `id`            BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `map`           SMALLINT UNSIGNED NOT NULL COMMENT '地图/副本 id',
  `instance_id`   INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '副本实例 id（= 一轮副本）',
  `seq`           SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '本轮第几次拉怪，从 1 开始',
  `ord`           SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '波次（= dungeon_route.ord；0 = boss 阶段/不在路线表）',
  `target_guid`   INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '第一次拉的目标 spawn guid',
  `target_entry`  INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '目标 entry',
  `tank_guid`     INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '驱动坦克 bot guid',
  `started_at`    INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '开拉 unix 时间',
  `ended_at`      INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '结束 unix 时间（0 = 还没结束）',
  `duration_s`    SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '持续秒数',
  `result`        VARCHAR(16)      NOT NULL DEFAULT 'pending' COMMENT 'pending/cleared/skipped/died/left',
  `mobs_total`    SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '开拉时这波还活着几只',
  `mobs_alive`    SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '结束时还剩几只',
  `deaths`        TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '本次拉怪期间队伍死亡人数',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_run_seq` (`map`,`instance_id`,`seq`),
  KEY `idx_map_ord` (`map`,`ord`),
  KEY `idx_started` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC
  COMMENT='每轮副本的拉怪顺序与每次拉怪的结果（playerbot 引擎自动写入，勿手改）';

-- 常用观察视图（可选，纯读取；不给就用下面的 SQL 自己查）
-- 每轮副本的推进概况：
--   SELECT map, instance_id, MIN(started_at) AS run_start, COUNT(*) AS pulls,
--          SUM(result='cleared') AS cleared, SUM(result='skipped') AS skipped,
--          SUM(result='died') AS died, SUM(deaths) AS deaths
--   FROM ai_playerbot_pull_log GROUP BY map, instance_id ORDER BY run_start DESC;
-- 某一轮的拉怪顺序：
--   SELECT seq, ord, target_entry, started_at, duration_s, result, mobs_total, mobs_alive, deaths
--   FROM ai_playerbot_pull_log WHERE map=556 AND instance_id=<id> ORDER BY seq;

-- 193_优先级观测表.sql
-- [副本AI 2026-10-18 站长口径] 引擎**观测到的读条**要落库，并且每个变化都要有日志。
--
-- 站长口径原话：
--   ① "对于怪物所有读条的治疗都标记为优先级[最高]，对于读条的控制技能，包括击晕、魅惑、恐惧
--      等等标记为[优先击杀]，不包括缠绕"；
--   ② "ai_playerbot_priority_obs 表 + 观测持久化，每个变化加日志"。
--
-- 现行威胁等级口径 = **数字越大越优先**（见 dev/179_重点小怪优先级表.sql）：
--   5 = 任何情况必须立刻转火击杀（不因吃控制降级）
--   4 = 需要优先控制
--   3 = 优先击杀
--   2 = 没有对应驱散才优先击杀
--   1 = 只需要打断
-- ⇒ 观测分类按**新**口径换算：
--   读条治疗 → 表 priority 5（不打掉它，其它目标都打不死）
--   读条控制 → 表 priority 3（优先击杀；缠绕/定身、减速、缴械**不算**控制）
--
-- 这张表**只记观测**，不是人工名单：人工名单仍然是 `ai_playerbot_priority_target`（dev/179），
--   两者优先级：人工表 > 观测表 > 启发式；观测只补"人工表里没有这只怪"的 entry。
--
-- 写入方：playerbot 模块 `PossibleAttackTargetsValue::ObservePriorityCast()`（见
--   playerbot/strategy/values/PossibleAttackTargetsValue.cpp）；批量 upsert 在
--   `FlushPriorityObs()`（拉怪结束 PullEnd 时 + 每 120s 兜底一次）。
--   `count` 是**累计观测次数**（只增不减，`ON DUPLICATE KEY UPDATE count = GREATEST(...)`），
--   跨进程重启保留；同一 entry 同 kind 观察 >= 2 次才生效（一次可能是被打断的残条）。
--
-- 日志（/opt/mangos/logs/ 里的 server.log）：
--   [PRIO-OBS]    entry/name/kind/spell/count 达到生效门槛
--   [PRIO-CHANGE] entry/name/old->new/source=obs|table  —— **每个变化都记**
--   [PRIO-DB]     flush 行数 + 两张表各自行数
--
-- 数据库：**characters 库**（与 ai_playerbot_priority_target 同库；不是 world 库）。
-- 幂等（IF NOT EXISTS），可重复执行；表不存在时模块自动降级为"只记内存、不落库"。
-- 云端执行（静态、幂等、秒级）：
--   mysql --defaults-file=/root/.my_cm.cnf tbccharacters < dev/193_优先级观测表.sql
-- 本地执行：
--   mysql -uroot -pqwerty tbccharacters < dev/193_优先级观测表.sql

CREATE TABLE IF NOT EXISTS `ai_playerbot_priority_obs` (
  `entry`      INT UNSIGNED     NOT NULL                COMMENT 'creature_template.entry（怪的类型，不是 guid）',
  `kind`       ENUM('heal','control') NOT NULL          COMMENT 'heal=读条治疗；control=读条控制（击晕/魅惑/恐惧/沉默等，不含缠绕）',
  `count`      INT UNSIGNED     NOT NULL DEFAULT 0      COMMENT '累计观测到该 entry 读此类条的次数（只增）',
  `last_seen`  INT UNSIGNED     NOT NULL DEFAULT 0      COMMENT '最近一次观测到的 unix 时间',
  `last_map`   SMALLINT UNSIGNED NOT NULL DEFAULT 0     COMMENT '最近一次观测到的地图/副本 id',
  `last_spell` INT UNSIGNED     NOT NULL DEFAULT 0      COMMENT '最近一次观测到的 spell id',
  PRIMARY KEY (`entry`,`kind`),
  KEY `idx_kind_count` (`kind`,`count`),
  KEY `idx_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='playerbot 观测到的怪读条（治疗/控制），用于威胁等级自适应；人工名单见 ai_playerbot_priority_target';

-- 观测生效后的有效优先级（查询用；模块里同一口径，改这里只为方便人工查看）：
--   读条治疗 -> 5，读条控制 -> 3，count < 2 不生效
SELECT `entry`, `kind`, `count`,
       CASE WHEN `count` >= 2 THEN (CASE `kind` WHEN 'heal' THEN 5 ELSE 3 END) ELSE 0 END AS `effective_priority`,
       FROM_UNIXTIME(NULLIF(`last_seen`,0)) AS `last_seen_at`, `last_map`, `last_spell`
FROM `ai_playerbot_priority_obs`
ORDER BY `count` DESC, `last_seen` DESC;

-- 194_副本拉怪记录_所有玩家.sql
-- [2026-10-18 站长口径] 拉怪日志 = **所有玩家在副本的日志**（采集真玩家数据，所有图放行）。
--
-- 站长原话：
--   "拉怪日志是记录所有玩家在副本的日志，因为我们要采集真玩家数据，所有图都放行。"
--
-- 原实现（dev/192 + 模块 dungeonroute::PullBegin/PullEnd）只有 **bot 自动开怪** 才记录，
--   而且要求 `verified=1`；真人手动拉怪、随机本、团本、未放行的图全都不记 ⇒ 采不到真玩家数据。
--
-- 本版改动：
--   1. 记录逻辑移到**核心** `pullrec::Update()`（src/game/Combat/InstancePullRecorder.cpp）：
--        在 `Map::Update()` 里对所有副本实例图（5 人本 / 团本）逐 tick 观测，
--        每支队伍（或单人）"进入战斗 → 脱战"算一次拉怪，seq 递增。
--        **不再要求 verified=1、不再要求自动开怪开关** ⇒ 所有图都放行、真人被完整覆盖。
--   2. **单一写入方**：模块不再写这张表（只给记录器补 ord 提示），同一波不会记两遍。
--   3. 表加三列区分数据来源与队伍（便于离线按"真玩家 / 纯机器人"过滤）：
--        group_id  队伍 id（0 = 单人）
--        source    player = 队里有真人；bot = 纯机器人队
--        members   开拉时在本里的队伍人数
--   4. `tank_guid` 语义放宽为"**记录者/队长** guid"：
--        真人组 = 队长；单人 = 自己；bot 路线 = 驱动坦克。
--   5. 唯一键从 (map, instance_id, seq) 换成 (map, instance_id, tank_guid, seq)：
--        同一副本实例里可能同时有多支队伍，旧键会互相覆盖/冲突。
--
-- 数据库：**world 库**（`tbcmangos`，与 dev/192 同库；核心用 WorldDatabase）。
-- 幂等：列/索引都先查 information_schema 再决定是否 ALTER，可重复执行。
-- 云端执行（静态、幂等、秒级）：
--   mysql --defaults-file=/root/.my_cm.cnf tbcmangos < dev/192_副本拉怪记录表.sql   # 表不存在才需要
--   mysql --defaults-file=/root/.my_cm.cnf tbcmangos < dev/194_副本拉怪记录_所有玩家.sql
-- 本地执行（本地 world 库还没有这张表，先跑 192 再跑本文件）：
--   mysql -uroot -pqwerty tbcmangos < dev/192_副本拉怪记录表.sql
--   mysql -uroot -pqwerty tbcmangos < dev/194_副本拉怪记录_所有玩家.sql
--
-- 复核（表里有行之后）：
--   SELECT source, COUNT(*) FROM tbcmangos.ai_playerbot_pull_log GROUP BY source;
--   SELECT map, instance_id, tank_guid, seq, ord, result, duration_s, deaths
--   FROM tbcmangos.ai_playerbot_pull_log ORDER BY id DESC LIMIT 20;

-- ---------------------------------------------------------------------------
-- 1) 加列（缺才加）
-- ---------------------------------------------------------------------------
SET @has_group_id := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND column_name = 'group_id');
SET @sql := IF(@has_group_id = 0,
  'ALTER TABLE `ai_playerbot_pull_log` ADD COLUMN `group_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''队伍 id（0 = 单人）'' AFTER `tank_guid`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_source := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND column_name = 'source');
SET @sql := IF(@has_source = 0,
  'ALTER TABLE `ai_playerbot_pull_log` ADD COLUMN `source` ENUM(''player'',''bot'') NOT NULL DEFAULT ''player'' COMMENT ''player = 队里有真人；bot = 纯机器人队'' AFTER `group_id`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_members := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND column_name = 'members');
SET @sql := IF(@has_members = 0,
  'ALTER TABLE `ai_playerbot_pull_log` ADD COLUMN `members` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''开拉时在本里的队伍人数'' AFTER `source`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2) tank_guid 语义放宽（MODIFY 本身幂等）
ALTER TABLE `ai_playerbot_pull_log`
  MODIFY COLUMN `tank_guid` INT UNSIGNED NOT NULL DEFAULT 0
  COMMENT '记录者/队长 guid：真人组=队长；单人=自己；bot 路线=驱动坦克';

-- ---------------------------------------------------------------------------
-- 3) 唯一键：旧 (map,instance_id,seq) → 新 (map,instance_id,tank_guid,seq)
--    同一副本实例可能同时有多支队伍；旧键会互相覆盖。
-- ---------------------------------------------------------------------------
SET @has_old_key := (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND index_name = 'uk_run_seq');
SET @sql := IF(@has_old_key > 0,
  'ALTER TABLE `ai_playerbot_pull_log` DROP INDEX `uk_run_seq`',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_new_key := (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND index_name = 'uk_run_seq_leader');
SET @sql := IF(@has_new_key = 0,
  'ALTER TABLE `ai_playerbot_pull_log` ADD UNIQUE KEY `uk_run_seq_leader` (`map`,`instance_id`,`tank_guid`,`seq`)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 4) 分析常用：按开始时间倒序捞"最近的真玩家拉怪"
SET @has_started_idx := (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log' AND index_name = 'idx_started_at');
SET @sql := IF(@has_started_idx = 0,
  'ALTER TABLE `ai_playerbot_pull_log` ADD KEY `idx_started_at` (`started_at`)',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 复核：列 / 索引是否符合预期（可选）
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_COMMENT
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'ai_playerbot_pull_log'
ORDER BY ORDINAL_POSITION;
