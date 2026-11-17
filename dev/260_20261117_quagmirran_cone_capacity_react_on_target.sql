-- Character database (tbccharacters). 夸格米拉 tracked_cone：锥容量 + 点名后临时跑位。
--
-- 只加列，不改任何现有行，默认 0/0 **保持旧行为**：
--   · `cone_max_targets`     TINYINT UNSIGNED NOT NULL DEFAULT 0
--       0 = 完整走旧的槽位分配（ComputeTrackedCone 旧分支，逐字不变）
--       1..5 = 新分配：任一**完整伤害锥窗口**内计划暴露人数 <= N（不是"每个坐标槽 <= N"）
--       越界（>5）会被 EncounterStrategy 判定为非法配置 ⇒ 保留上一快照，不静默夹取
--   · `cone_react_on_target` TINYINT UNSIGNED NOT NULL DEFAULT 0
--       0 = 现有反应路径；1 = 点名目标确定后的临时跑位状态机（Evade/SafeHold/Recover）
--       与容量独立：可以 2/0 或 0/1 单独验证，再合并 2/1
--
-- 旧 schema 兼容：新二进制启动时用 information_schema 只读探测这两列。
--   两列都没有 ⇒ 退回旧 SELECT 并显式映射 0/0（等价旧行为）；
--   只缺一列 ⇒ 视为迁移不完整，保留上一快照并打 [ENCOUNTER-STRATEGY] 错误，不会悄悄降级成空配置。
--
-- 幂等：用 information_schema + PREPARE 完成"缺才加"，同一文件可重复执行（第二次 0 变更）。
-- 启用某只 boss 需要另外 UPDATE 对应 profile/binding（本次不启用，默认 0/0）。

-- 1) 表不存在时先按旧结构建（与 dev/241 同构；已存在则不动）。
CREATE TABLE IF NOT EXISTS `ai_playerbot_strategy_profile` (
  `id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(96) NOT NULL,
  `executor` VARCHAR(32) NOT NULL,
  `channel_spell` INT UNSIGNED NOT NULL,
  `damage_spell` INT UNSIGNED NOT NULL,
  `radius_effect` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `cone_degrees` FLOAT NOT NULL DEFAULT 60,
  `separation_degrees` FLOAT NOT NULL DEFAULT 4,
  `radial_degrees` FLOAT NOT NULL DEFAULT 2,
  `search_step` FLOAT NOT NULL DEFAULT 0.75,
  `search_distance` FLOAT NOT NULL DEFAULT 45,
  `directions` SMALLINT UNSIGNED NOT NULL DEFAULT 48,
  `plan_ms` INT UNSIGNED NOT NULL DEFAULT 150,
  `poison_totem` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `poison_aura` INT UNSIGNED NOT NULL DEFAULT 0,
  `heroic_poison_aura` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2) 缺列才加（幂等）。
SET @sql = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_playerbot_strategy_profile'
                  AND COLUMN_NAME = 'cone_max_targets') = 0,
  'ALTER TABLE `ai_playerbot_strategy_profile` ADD COLUMN `cone_max_targets` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''0=legacy allocation; 1..5=max planned exposure in any full damage cone'' AFTER `heroic_poison_aura`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF((SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ai_playerbot_strategy_profile'
                  AND COLUMN_NAME = 'cone_react_on_target') = 0,
  'ALTER TABLE `ai_playerbot_strategy_profile` ADD COLUMN `cone_react_on_target` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''0=legacy reaction; 1=evade/safe-hold/recover after the channel target resolves'' AFTER `cone_max_targets`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3) 数据不动：不 UPDATE 任何行。默认值 0/0 已经由列定义保证；
--    这里刻意不写"重置为 0"-- 否则以后站长手工启用 2/1 之后重放本文件会把配置打回去。
-- 4) 验收查询：应看到 id=1 的 0/0 与两只夸格米拉绑定（值由当前库真实状态决定）。
SELECT `id`,`name`,`executor`,`cone_max_targets`,`cone_react_on_target` FROM `ai_playerbot_strategy_profile` WHERE `id` = 1;
SELECT `map`,`entry`,`profile_id`,`enabled` FROM `ai_playerbot_encounter_binding` WHERE `map` = 547 ORDER BY `entry`;
