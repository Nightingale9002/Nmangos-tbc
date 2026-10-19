-- ============================================================================
-- 卡布魔兽 bot 相关 SQL（2026-10-19 按主题重新编号；原 177–207 编号废弃）
-- 主题：BOSS战策略表
-- 来源（旧编号）：179_BOSS战策略表.sql
-- 静态/幂等 SQL；部署时由站长手工或 apply_dev_sql.sh 按编号顺序执行。
-- ============================================================================

-- 2026-10-19 检查（新策略/新标注口径）：
--   ① 规则行已用 dev/tools/boss_rule_check.py 对当前引擎 creators[] 全量校验：0 错误；
--   ② 补登记 4 个“有 boss_<entry> 专属集但没进 ai_playerbot_boss_strategy”的 BOSS
--      （不登记的话专属集永远不会挂上，等于白写）；
--   ③ 补 SET NAMES utf8mb4（否则中文 note 在 mysql CLI 下会乱码）。
SET NAMES utf8mb4;
USE `tbccharacters`;


-- ============================================================================
-- dev/179_BOSS战策略表.sql —— 副本 BOSS 战策略（机器人自定义策略数据）
-- ============================================================================
-- 这是什么：把 BOSS 攻略（机制 / 站位跑位 / 目标优先级 / 停手·大招·驱散·打断）翻译成
--           PlayerBots「自定义策略」的规则行，让 bot 打某个 BOSS 时自动套上对应规则。
--           只有数据，不改战斗代码。
-- 两块数据：
--   ① 通用集 + 各 BOSS 专属集 → 角色库 tbccharacters.ai_playerbot_custom_strategy
--        name        = boss_common*（通用集，所有登记过的 BOSS 都会挂）
--                      或 boss_<BOSS 的 creature entry>（该 BOSS 专属；引擎里键名 = custom::<name>）
--        owner       = 0（全服共享：bot 查不到自己的行会自动回落 owner=0）
--        idx         = 同一集内的规则序号
--        action_line = `<触发器> > <动作>[!权重], 动作2, ...`
--   ② BOSS 登记表 → tbccharacters.ai_playerbot_boss_strategy(entry, note)
--        打这些 entry 的怪时钩子才会挂"通用集"（有 boss_<entry> 专属行的 BOSS 自动算登记过，
--        本表用来收录"只有通用行为、没有专属规则"的 BOSS，或显式列出要覆盖的 BOSS）。
-- 角色精细分工（2026-10-16，两套并存）：
--   · 整个集只给某角色 ⇒ 集名后缀：boss_<entry>_dps / _tank / _healer / _melee / _ranged
--     （多个=与，如 boss_18371_dps_melee；后缀有未知名 ⇒ 该集不挂）
--   · 集里只有某几条限角色、或角色要和别的条件复合 ⇒ 规则内写
--       val::and::{trigger::<触发器名>,is dps}
--     （新值 is tank/is healer/is dps/is melee/is ranged 与 trigger 桥见
--      playerbot/strategy/values/BossRuleValues.h）
-- 谁挂上去：BossStrategyHook.h → bossstrategy::Update()（由 PlayerbotAI.cpp → UpdateAIInternal() 末尾调用；
--           每约 5 秒看一次"队伍正在打的 BOSS"，命中就 +custom::boss_common* +custom::boss_<entry>*，
--           脱战 / 换目标 / 死亡就摘掉；开关 AiPlayerbot.BossStrategies，默认 1；日志 [BOSSSTRAT]）。
-- 本文件是「生成物」：源 = _agent_tmp/bossrules_*.tsv + _agent_tmp/boss_enroll.tsv + 本段注释
--   （_agent_tmp/boss_sql_header.sql）。改规则 = 改 TSV → 重新生成，不要手改生成段落。
-- 生成 / 校验命令（Windows PowerShell）——最省事的是第一条，它会自动扫全部 bossrules_*.tsv：
--   cd _agent_tmp
--   python boss_apply_and_check.py          # 生成 179 + 校验 + 应用本地库 + 复跑验幂等
--   # 或手动指定：
--   python ..\Nmangos-tbc\dev\tools\boss_rule_check.py -i bossrules_common.tsv bossrules_A.tsv bossrules_B.tsv `
--     bossrules_C.tsv bossrules_D.tsv bossrules_E.tsv bossrules_F.tsv bossrules_G.tsv bossrules_H.tsv `
--     --enroll boss_enroll.tsv --header boss_sql_header.sql --out ..\Nmangos-tbc\dev\179_BOSS战策略表.sql
--   （校验器会查：策略名格式、触发器/动作名是否存在及类型、`val::` 复合表达式、权重是否数字、entry 是否存在；
--     词表见 dev/tools/export_context_words.py，规则写法与"做不到的机制"见
--     dev/功能更新手册_卡布魔兽.md 的「副本/BOSS 战策略」一章）
-- ⚠️ 库名（2026-10-16 站长指出，已修）：这两张表在**角色库**里，
--     模块 `CustomStrategy.cpp → CharacterDatabase.PQuery(…)` 读的就是 characters 库。
--     而 `/root/apply_dev_sql.sh` 是用**世界库当默认库**跑的：
--         mysql -u root … tbcmangos < dev/179_BOSS战策略表.sql
--     它自己的注释里也写明约定："dev 里的 SQL 幂等，且**自带库名限定**（无需选默认库）"。
--     ⇒ 本文件所有表名都写全 `tbccharacters.` 限定（即使默认库是世界库也写对地方），
--       并在下面补一句 `USE tbccharacters;` 让手工执行的人一眼看到目标库。
-- 幂等    ：只有 IF NOT EXISTS 建表 + 按 (owner=0, name) DELETE 再 INSERT + 登记表整表重写，
--           可重复执行；不写 JOIN / 子查询 / 聚合，全部静态字面量（云端只跑静态幂等写）。
-- ============================================================================

USE `tbccharacters`;

-- 表在角色库：tbccharacters.ai_playerbot_custom_strategy（模块读的就是这张）
CREATE TABLE IF NOT EXISTS `tbccharacters`.`ai_playerbot_custom_strategy` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `idx` bigint(20),
  `owner` bigint(20),
  `action_line` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- BOSS 登记表（钩子据此决定"这场 BOSS 战要不要挂通用集"）
CREATE TABLE IF NOT EXISTS `tbccharacters`.`ai_playerbot_boss_strategy` (
  `entry` int(10) unsigned NOT NULL,
  `note` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 下面每个集一段：先删掉该 name 的旧行（owner=0），再写新行。
-- 「做不到」的机制（没有对应触发器）写在注释里，供后续加触发器时接手。

-- ===== BOSS 登记表（打这些 BOSS 时自动挂通用集 boss_common*）=====
DELETE FROM `tbccharacters`.`ai_playerbot_boss_strategy`;
INSERT INTO `tbccharacters`.`ai_playerbot_boss_strategy` (`entry`, `note`) VALUES
(17306, '地狱火城墙 - 巡视者加戈玛 Watchkeeper Gargolmar'),
(17308, '地狱火城墙 - 无疤者奥摩尔 Omor the Unscarred'),
(17536, '地狱火城墙 - 纳杉 Nazan（瓦兹德的坐骑，二阶段同场）'),
(17537, '地狱火城墙 - 传令官瓦兹德 Vazruden'),
(17381, '鲜血熔炉 - 制造者 The Maker'),
(17380, '鲜血熔炉 - 布洛戈克 Broggok'),
(17377, '鲜血熔炉 - 击碎者克里丹 Keli''dan the Breaker'),
(18371, '奥金尼地穴 - 死亡观察者希尔拉克 Shirrak the Dead Watcher'),
(18373, '奥金尼地穴 - 大主教玛拉达尔 Exarch Maladaar'),
(18731, '暗影迷宫 - 赫尔默大使 Ambassador Hellmaw（只有通用行为）'),
(18667, '暗影迷宫 - 煽动者布莱卡特 Blackheart the Inciter'),
(18732, '暗影迷宫 - 沃匹尔大师 Grandmaster Vorpil'),
(18341, '法力陵墓 - 潘德莫努斯 Pandemonius（只有通用行为）'),
(16807, '破碎大厅 - 高阶术士奈瑟库斯 Grand Warlock Nethekurse'),
(20923, '破碎大厅 - 血卫士伯鲁恩 Blood Guard Porung'),
(16809, '破碎大厅 - 战争使者沃姆罗格 Warbringer O''mrogg'),
(16808, '破碎大厅 - 酋长卡加斯·刃拳 Warchief Kargath Bladefist'),
(18472, '赛泰克大厅 - 黑暗编织者塞斯 Darkweaver Syth'),
(18473, '赛泰克大厅 - 利爪之王艾吉斯 Talon King Ikiss'),
(18343, '法力陵墓 - 塔瓦洛克 Tavarok'),
(22930, '法力陵墓 - 尤尔 Yor'),
(18344, '法力陵墓 - 节点亲王沙法尔 Nexus-Prince Shaffar'),
(17941, '奴隶围栏 - 背叛者门努 Mennu the Betrayer'),
(17991, '奴隶围栏 - 巨钳鲁克玛尔 Rokmar the Crackler'),
(17942, '奴隶围栏 - 夸格米拉 Quagmirran'),
(17770, '幽暗沼泽 - 霍加尔芬 Hungarfen'),
(18105, '幽暗沼泽 - 加兹安 Ghaz''an'),
(17826, '幽暗沼泽 - 沼地领主穆塞雷克 Swamplord Musel''ek'),
(17882, '幽暗沼泽 - 黑色阔步者 The Black Stalker'),
(17797, '蒸汽地窟 - 水术师瑟丝比娅 Hydromancer Thespia'),
(17796, '蒸汽地窟 - 机械师斯蒂里格 Mekgineer Steamrigger'),
(17798, '蒸汽地窟 - 督军卡利瑟里斯 Warlord Kalithresh'),
(17976, '生态船 - 指挥官萨拉妮丝 Commander Sarannis'),
(17975, '生态船 - 高级植物学家弗雷温 High Botanist Freywinn'),
(17978, '生态船 - 看管者索恩格林 Thorngrin the Tender'),
(17980, '生态船 - 拉伊 Laj'),
(17977, '生态船 - 迁跃扭木 Warp Splinter'),
(20870, '禁魔监狱 - 自由的瑟雷凯斯 Zereketh the Unbound'),
(20885, '禁魔监狱 - 末日预言者达尔莉安 Dalliah the Doomsayer'),
(20886, '禁魔监狱 - 天怒预言者苏克拉底 Wrath-Scryer Soccothrates'),
(20912, '禁魔监狱 - 预言者斯克瑞斯 Harbinger Skyriss'),
(19218, '能源舰 - 看守者盖罗基尔 Gatewatcher Gyro-Kill'),
(19710, '能源舰 - 看守者埃隆汉 Gatewatcher Iron-Hand'),
(19219, '能源舰 - 机械领主卡帕西图斯 Mechano-Lord Capacitus'),
(19221, '能源舰 - 灵术师塞比瑟蕾 Nethermancer Sepethrea'),
(19220, '能源舰 - 计算者帕萨雷恩 Pathaleon the Calculator'),
(17879, '黑色沼泽 - 时空领主德亚 Chrono Lord Deja'),
(17880, '黑色沼泽 - 坦普卢斯 Temporus'),
(17881, '黑色沼泽 - 埃欧努斯 Aeonus'),
(17848, '旧希尔斯布莱德 - 德拉克中尉 Lieutenant Drake'),
(17862, '旧希尔斯布莱德 - 斯卡洛克上尉 Captain Skarloc'),
(18096, '旧希尔斯布莱德 - 时空猎手 Epoch Hunter'),
(21466, '禁魔监狱 - 预言者斯克瑞斯的幻象 1（36931 召唤；本尊 20912 的转火目标）'),
(21467, '禁魔监狱 - 预言者斯克瑞斯的幻象 2（36932 召唤）');

-- ===== 清理：owner=0 的 boss* 集（含改过名/已废弃的旧集）=====
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` LIKE 'boss%';

-- ===== boss_common =====
-- 低血保命、中毒解毒、被恐惧解控等通用行为一律归 boss_common，本文件不重复
-- boss_17537 TODO 归 boss_common: 低沉咆哮 —— 脚本只在英雄模式注册（boss_vazruden_heraldAI 构造里 `if (!m_inRegularMode) AddCombatAction(NAZAN_BELLOWING_ROAR, true)`），spell 39427（spell_template: Aura1=7 MOD_FEAR、RadiusIndex 覆盖 35 码、Mechanic=5）；普通模式不会施放。"被恐惧/预判恐惧就用解控"属于通用集，本组不重复
-- boss_17536 TODO 归 boss_common: 低沉咆哮 39427（仅英雄模式，Aura1=7 MOD_FEAR）⇒ 解控/预判走通用集
-- 只写本 BOSS 特有的；通用行为（低血保命 / 中毒解毒 / 被恐惧预判）归 boss_common，本文件不重复。
-- 挂载链：PlayerbotAI.cpp → UpdateBossStrategy()（打"已登记"的 BOSS 时把 boss_common* 通用集 + 该 BOSS 的 boss_<entry> 一起 +custom::，BOT_STATE_COMBAT）；
-- [毒液箭] 30917 → 通用"中毒解毒"（boss_common）
-- boss_17380 说明: [毒液箭] 30917（Dispel=DISPEL_POISON、可叠5层、光环=SPELL_AURA_PERIODIC_DAMAGE）属于通用"中毒解毒"，归 boss_common
-- 通用规则（低血保命、中毒解毒、被恐惧解控…）不在这里写 —— 归 boss_common（站长 2026-10-16 口径）
-- boss_18731 TODO 做不到: 恐惧(33547) 的解控 / 原因: 站长口径归 boss_common（被恐惧预判/解控是通用规则）；且该恐惧是瞬发，通用触发器 target of fear cast 抓的是"敌人正在读条"（GenericTriggers.cpp → TargetOfCastedAuraTypeTrigger::IsActive() 查 attacker->GetCurrentSpell()），基本抓不到 → 建议 boss_common 用 feared 触发器；战士/亡灵/人类的解控默认策略已有（warrior/WarriorStrategy.cpp → target of fear cast > berserker rage!40；generic/RacialsStrategy.cpp → will of the forsaken!71）
-- boss_18731 TODO 做不到: "非近战保持一定距离" / 原因: 属远程默认行为（generic/RangedCombatStrategy.cpp → enemy too close for spell > flee）；写进共享规则会连近战一起触发（RangeTriggers.h → EnemyTooCloseForSpellTrigger::IsActive() 用 ai->GetRange("spell")，近战 bot 也满足）→ 近战会跑去施法距离站桩。建议归 boss_common 或交给默认策略
-- 口径: 只写"该 BOSS 特有"的规则；低血保命 / 中毒解毒 / 被恐惧解控等通用行为一律归 boss_common，本文件不重复。
-- boss_16807   （spell_template 无 aura），玩家侧没有"我中了"的信号 ⇒ 只能靠通用集 boss_common 规则3（非坦克别站在 BOSS 模型里）间接缓解。
-- boss_16807 归 boss_common: 凋零缠绕 30500 的 4 秒恐惧（aura7=SPELL_AURA_MOD_FEAR）
-- boss_16809 归 boss_common: 恐惧 30584（aura7=MOD_FEAR，40 码全员 3 秒）
-- boss_16808 归 boss_common: 无（本 BOSS 对玩家没有 boss_common 已覆盖的可查 debuff，除了规则2 的两条控制）。
-- boss_17461 归 boss_common: 无（本 BOSS 不给玩家挂任何可查 debuff）。
-- boss_20923 归 boss_common: 无。
-- 口径: 只写"该 BOSS 特有"的规则；通用行为（低血保命 / 中毒解毒 / 被恐惧解控）归 boss_common，本文件不重复。
-- 注: 通用行为（低血保命、中毒解毒、被恐惧解控、被围/贴模型）已由 boss_common 与内置
-- 口径: 只写"该 BOSS 特有"的规则；低血保命/中毒解毒/预判恐惧等通用行为归 boss_common，本文件不重复。
-- boss_17797 TODO 归 boss_common: "治疗把所有人血线保持 50% 以上" —— 属治疗档位配置
-- boss_17975 TODO 归 boss_common: 白色树苗 34752 的冰封昏迷（Aura=MOD_STUN、Mechanic=12、
-- boss_17977 TODO 归 boss_common: 治疗保持全满应对奥术箭雨高额伤害 —— 属治疗档位配置/人工。
-- 口径: 只写"该 BOSS 特有"的规则；低血保命 / 中毒解毒 / 预判恐惧等通用行为归 boss_common，本文件不重复。
-- 恐惧: 39415 是 Aura1=7 MOD_FEAR（CastingTimeIndex=16 有读条）⇒ 通用集 boss_common 已经覆盖
-- （`not behind target` + `set behind` 是绕到**当前目标**背后，规则 3 的"别站模型里"已由 boss_common 处理）。
-- 归 boss_common 或引擎内置策略（见各节"归 boss_common"/"引擎已覆盖"注释），本文件不重复。
-- boss_19218 归 boss_common / 引擎已覆盖: 流动机蒸汽 35311（Dispel=4 中毒）
-- boss_19710 归 boss_common / 引擎已覆盖: 流动机蒸汽 35311（中毒）—— 同 boss_19218 的说明（引擎 potions 策略）
-- boss_19221 归 boss_common / 引擎已覆盖: 龙息术的"驱散"本身 ——
-- boss_19220 归 boss_common / 引擎已覆盖: "进攻驱散或偷取 [法力分流]"（攻略原文）
-- 口径: 只写"该 BOSS 特有"的规则；低血保命 / 中毒解毒 / 恐惧自解 / 非坦克退出 BOSS 模型等通用行为归 boss_common，本文件不重复。
-- boss_17879 语义注意: ① 这条的意图与 boss_common 规则3（`val::and::{inside target,not::is tank}`）**相同**，
-- boss_17879   但 boss_common 那条用了裸 `inside target` ⇒ 有限定词为空、空指针解引用的崩服风险（见文件头 §6）。
-- boss_17879   站长修好 boss_common 后这条对德亚之外没影响（同动作重复触发无害，可留可删）。
-- boss_17879 归 boss_common: 时间流逝的"驱散"如果站长认为不该在本集重复，删规则1 后由 boss_common/职业策略接管。
-- boss_17880 归 boss_common: 无（本 BOSS 给玩家的可查 debuff 只有坦克头上的 31464，已由规则1 处理）。
-- boss_17881 归 boss_common: [时间停止] 之外的昏迷/减速通用处理（恐惧自解、定身除根等）走 boss_common 与各职业策略，本组不重复。
-- 口径: 只写"该 BOSS 特有"的规则；通用行为（被恐惧解控 / 低血保命 / 中毒解毒）归 boss_common，本文件不重复。
-- boss_17848 归 boss_common: 破胆怒吼 33789（aura7 MOD_FEAR）—— "被恐惧就自解"在 bossrules_common.tsv 规则1
-- boss_17862 归 boss_common: 看守的心灵尖啸 22884（aura7 MOD_FEAR，8 码 AoE）—— 被恐惧自解在 bossrules_common.tsv 规则1。
-- 通用集 boss_common —— 所有"登记过的 BOSS"战斗里都会自动挂上（钩子同时挂它 + 该 BOSS 专属集）
-- @boss 通用集 boss_common
-- boss_common 机制: 被恐惧期间自解（瞬发恐惧也能救）
-- boss_common 机制: **有读条**的恐惧提前插战栗图腾 / 上防恐结界（瞬发恐惧抓不到，只有这条能用）
-- boss_common 机制: 非坦克被顶进 BOSS 模型里就退出来（避免站正面/模型内吃顺劈；MoveOutOfEnemyContactAction::isUseful 只在 inside target 时为真）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_common';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_common', 1, 0, 'feared>every_man_for_himself!96,will of the forsaken!95'),
('boss_common', 2, 0, 'target of fear cast>tremor totem!90,fear ward!89'),
('boss_common', 3, 0, 'val::and::{trigger::enemy too close for melee,not::is tank}>move out of enemy contact!80');

-- ===== boss_16807  Grand Warlock Nethekurse (rank=1) =====
-- boss_16807 脚本: .../shattered_halls/boss_nethekurse.cpp → boss_grand_warlock_nethekurseAI
-- boss_16807        （CombatAI；entry 16807 HP 107700；英雄同名 entry 20568 HP 149420）
-- boss_16807 技能栏 creature_spell_list 1680701（Position / spell / TargetId / 初始 / 重复）:
-- boss_16807   [0] 30495 Shadow Cleave 暗影顺劈        TargetId=1(当前目标)     5s   / 6-8.5s
-- boss_16807   [1] 30496 Lesser Shadow Fissure 次级暗影裂隙 TargetId=100(随机玩家) 8s   / 7.5-15s → 召唤 NPC 17471
-- boss_16807   [2] 30500 Death Coil 凋零缠绕            TargetId=100(随机玩家)  20s  / 15-20s
-- boss_16807         （spell_template: 系=暗影、光环=SPELL_AURA_MOD_FEAR(aura7)、时长索引35、CastingTimeIndex=1 瞬发）
-- boss_16807   [3] 30502 Dark Spin 黑暗之脊             TargetId=0(自己)        CombatCondition=872
-- boss_16807 黑暗之脊的真实触发线（实测 DB，**不是**攻略说的 25%）:
-- boss_16807   creature_spell_list.CombatCondition=872 → 表 combat_condition 872 → SelfConditionID=728
-- boss_16807   → 表 unit_condition 728 = Variable_0=HEALTH_PERCENT(12) / Op_0=LESS_THAN(3) / Value_0=20
-- boss_16807   ⇒ **自身血量 < 20% 时才上黑暗之脊**（脚本里没有 30502 的代码，全在数据里）
-- boss_16807 引擎有现成的 20% 代理: triggers/HealthTriggers.h → TargetCriticalHealthTrigger : TargetLowHealthTrigger(ai, 20)
-- boss_16807   （GetTargetName()="current target"；HealthTriggers.cpp → HealthInRangeTrigger::IsActive() 读 "health" 值、硬编码 20）
-- boss_16807   ⇒ 规则里 `target critical health` ≈ "奈瑟库斯已进黑暗之脊阶段"（Boss<20% 起全程为真，正好等于该阶段）
-- boss_16807 机制↔规则: 黑暗之脊 30502 是**挂在 BOSS 自己身上**的 aura（aura23=PERIODIC_TRIGGER_SPELL ×2 + aura38=STATE_IMMUNITY，
-- boss_16807   触发 30505 暗影箭 1062 / 30508 物理 274）⇒ `has aura` 查不到（HasAuraTrigger::GetTargetName() 恒为 "self target"），
-- boss_16807   只能用血量当阶段代理。
-- boss_16807 机制: 黑暗之脊阶段**坦克**退到模型外（近似攻略"坦克该阶段可后退到 5 码外"；元素顺序见文件头"空格风险"）
-- boss_16807 规则1 证据: RangeTriggers.h → EnemyTooCloseForMeleeTrigger（= values "inside target"，values/DistanceValue.h → InsideTargetValue
-- boss_16807   只看"是否站在目标 bounding radius 内"）+ actions/MovementActions.cpp → MoveOutOfEnemyContactAction::isUseful()（只有 inside target 才为真）
-- boss_16807   / Execute()（MoveTo(target, AiPlayerbot.ContactDistance 默认 0.5)）；BossRuleValues.h → IsTankValue + TriggerAsValue
-- boss_16807   + values/OperatorValues.cpp → BoolAndValue::Calculate()
-- boss_16807 语义注意: 这条只能把坦克从"模型内部"挪到"模型边缘"，**不等于**攻略的 5 码（没有"保持 5 码"的触发器/动作）；权重数值待定
-- boss_16807 机制: 黑暗之脊阶段 **DPS** 自保（只在自己已经掉血时才用，避免满血白喝药）
-- boss_16807 规则2 证据: triggers/HealthTriggers.h → LowHealthTrigger（自己血量 ∈ [AiPlayerbot.CriticalHealth 默认25, LowHealth 默认45)）；
-- boss_16807   BossRuleValues.h → IsDpsValue（= IsTank 与 IsHeal 都为假）；actions/UseItemAction.h → UseHealingPotionAction
-- boss_16807   （战斗中就可用、**没有血量门槛**，所以血量条件必须写在触发器里）；actions/ImbueAction.h →
-- boss_16807   TryEmergencyAction::Execute()（无 attacker 时先绷带，否则按 uPriorizedHealingItemIds 找治疗消耗品）
-- boss_16807 语义注意: 故意**不**嵌套 or::{…}（多一层 {} 会让 getMultiQualifiers 的括号配平更脆）；血量 <25% 那一档
-- boss_16807   引擎自己的 strategy/generic/UsePotionsStrategy.cpp 已经接了（critical health → healthstone → healing potion → 绷带），不重复。
-- boss_16807 数值待定: 权重；是否再收紧成 melee
-- boss_16807 TODO 做不到: 次级暗影裂隙 30496（攻略[致命]：脚下裂隙，每秒 3800 暗影）
-- boss_16807   原因: 30496 只**召唤 NPC 17471 Lesser Shadow Fissure**（EffectImplicitTargetA1=53 目标脚下、半径索引16），
-- boss_16807   伤害由 NPC 自己周期施放 —— src/game/AI/ScriptDevAI/scripts/world/npcs_special.cpp → npc_aoe_damage_triggerAI
-- boss_16807   （NPC_LESSER_SHADOW_FISSURE=17471）每 2.5s 给自己上 SPELL_CONSUMPTION_NPC_17471=30497
-- boss_16807   （aura23=PERIODIC_TRIGGER_SPELL → 触发 30498 Consumption 999 暗影）⇒ **玩家身上没有任何 aura**；
-- boss_16807   唯一沾边的触发器 `has area debuff` 只认 DynamicObject（values/AoeValues.cpp → HasAreaDebuffValue 遍历
-- boss_16807   "nearest dynamic objects no los"），17471 是 Creature ⇒ 机器人感知不到脚下裂隙 ⇒ "第一时间躲" 做不到（人工 / 后续加触发器）。
-- boss_16807 TODO 做不到: 暗影顺劈 30495 的"坦克使奈瑟库斯背对人群"
-- boss_16807   原因: 没有控制 BOSS 朝向/位置的动作（坦克站位与转向由核心仇恨逻辑决定）；30495 是 TargetId=1 + 链到最近盟友
-- boss_16807   （spell_template 无 aura），玩家侧没有"我中了"的信号 ⇒ 只能靠通用集 boss_common 规则3（非坦克别站在 BOSS 模型里）间接缓解。
-- boss_16807 TODO 做不到: 黑暗之脊 30502 本体的精确检测（"BOSS 身上有 aura"）
-- boss_16807   原因: HasAuraTrigger 只查自己（A 组已记同一限制）⇒ 这里退而用 `target critical health` 当阶段代理（好处是 20% 与 DB 条件完全一致）。
-- boss_16807 TODO 做不到: 黑暗之脊阶段"治疗加大治疗"
-- boss_16807   原因: 规则行只能触发**动作**，没有"提高治疗频率/优先级/预读"的动作（治疗强度由职业策略与 HealStrategy 决定）⇒ 需要新动作或引擎侧改动。
-- boss_16807 归 boss_common: 凋零缠绕 30500 的 4 秒恐惧（aura7=SPELL_AURA_MOD_FEAR）
-- boss_16807   —— "被恐惧就自解" 已在 bossrules_common.tsv 规则1（feared > every_man_for_himself / will of the forsaken），本组不重复；
-- boss_16807   30500 是**瞬发**（CastingTimeIndex=1）⇒ `target of fear cast`（查 attacker 正在读条）抓不到，只有 feared 能用。
-- boss_16807   若站长要给 bot 配 PvP 徽章，可另加 `has aura::spellid::30500 > use trinket!90`（注意"顺手记②"）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_16807';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_16807', 1, 0, 'val::and::{is tank,trigger::target critical health}>move out of enemy contact!80'),
('boss_16807', 2, 0, 'val::and::{is dps,trigger::target critical health,trigger::low health}>healing potion!70,try emergency!60');

-- ===== boss_16808  Warchief Kargath Bladefist (rank=1) =====
-- boss_16808 脚本: .../shattered_halls/boss_warchief_kargath_bladefist.cpp → boss_warchief_kargath_bladefistAI
-- boss_16808        （CombatAI；entry 16808 HP 167895、SpellList=0；英雄同名 entry 20597 HP 206640）
-- boss_16808   技能 id: SPELL_BLADE_DANCE=30739 / BLADE_DANCE_CHARGE=30751 / BLADE_DANCE_TARGETING=30738
-- boss_16808       （45s 起、之后每 30s 一轮；TARGET_NUM=8）
-- boss_16808       SPELL_CHARGE_H=25821（**仅英雄**：脚本 `if (!m_isRegularMode) ResetCombatAction(WARCHIEF_KARGATH_CHARGE, 500)`；
-- boss_16808        spell_template aura12=MOD_STUN，时长索引39）
-- boss_16808       SPELL_DOUBLE_ATTACK=19818（Reset() 里 CAST_AURA_NOT_PRESENT 给自己上的 proc aura，aura42=PROC_TRIGGER_SPELL）
-- boss_16808   召唤: 30737 Summon Heathen / 30785 Summon Reaver / 30786 Summon Sharpshooter（SpawnAssistant() 每 20s 从传送门轮一个）
-- boss_16808       → NPC 17621 Heathen Guard / 17623 Reaver Guard / 17622 Sharpshooter Guard；creature_spell_list 实测技能:
-- boss_16808         17621: 30474 Bloodthirst 嗜血；EventAI HP30% → 30485 Enrage
-- boss_16808         17623: 15496 Cleave 顺劈斩 + 30471 Uppercut 上钩拳；EventAI HP30% → 30485 Enrage
-- boss_16808         17622: 23601 Scatter Shot 驱散射击(aura5=MOD_CONFUSE) + 30481 Incendiary Shot 火焰射击(aura3 周期伤害) + 15620 Shoot
-- boss_16808       30485 Enrage = aura13(MOD_DAMAGE_DONE) + aura138(MOD_MELEE_HASTE 30%)，**Dispel=0 ⇒ 不可驱散**
-- boss_16808 机制: 卫兵从传送门刷出来（每 20s 一个），DPS 要优先点掉（攻略: 酋长的卫兵）
-- boss_16808 规则1 证据: TriggerContext.h:84 → triggers/GenericTriggers.h → HasNearestAddsTrigger::IsActive()（读 values "nearest adds"）
-- boss_16808   + values/NearestAdsValue.h（= PossibleTargetsValue(range=AiPlayerbot.FleeDistance 源码默认 8.0, ignoreLos=true)，排除当前目标）；
-- boss_16808   actions/ChooseTargetActions.h → AttackLeastHpTargetAction → values/LeastHpTargetValue.cpp → FindLeastHpTargetStrategy
-- boss_16808   （只在 "attackers"=已交战敌人里挑血最少的，跳过被标记 CC 的）
-- boss_16808 近似点: ① 判定半径 = FleeDistance(8 码) ⇒ 卫兵跑到身边才触发（远程 bot 常触发不到）；
-- boss_16808   ② 是"打血最少的已交战敌人"而不是按 entry 锁 17622；③ 卫兵 1762x 只有 8451 血、卡加斯 167895 血 ⇒ 实战基本会选卫兵。数值待定
-- boss_16808 机制: 控制技（英雄冲锋昏迷 2 秒 / 神射手卫士驱散射击迷惑 4 秒）用徽章解
-- boss_16808 规则2 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（正则 spellid::(\d+) → ai->GetAura(spell_id, GetTarget())，目标恒为自己）；
-- boss_16808   spell_template: 25821 光环=aura12(SPELL_AURA_MOD_STUN)、23601 光环=aura5(SPELL_AURA_MOD_CONFUSE)；
-- boss_16808   动作: actions/UseTrinketAction.cpp → Execute()（遍历 values "trinkets on use"，只看饰品可不可以用，**被控时仍会执行**——见"顺手记①"）
-- boss_16808 语义注意: 徽章常被泛用策略提前用掉（"顺手记②"）；这条只是把时机钉在"真的被控住"。数值待定
-- boss_16808 TODO 做不到: 刃舞 30738/30739/30751（攻略[重要]: 随机向多名玩家冲锋，对目标及附近 2700 物理）
-- boss_16808   原因: 这三个 spell 的 spell_template **没有任何 aura**（EffectApplyAuraName 全空、Mechanic=0），
-- boss_16808   脚本 HandleBladeDance() 只是 CastSpell(target, SPELL_BLADE_DANCE_CHARGE, TRIGGERED_IGNORE_HIT_CALCULATION)
-- boss_16808   ⇒ 玩家身上查不到"我正在被刃舞点" ⇒ "全程分散站位 / 近战保持最远距离输出" 没有规则行入口。只能人工或加新触发器。
-- boss_16808 TODO 做不到: 冲锋 25821 昏迷期间的额外应对（脚本 SelectAttackingTarget(ATTACKING_TARGET_RANDOM) 随机挑人）
-- boss_16808   原因: 昏迷 2 秒里 MovementAction 系动作全部 isUseful()=false（被控只挡移动，见"顺手记①"），
-- boss_16808   非位移动作只剩消耗品/饰品 ⇒ 除规则2 的徽章外无更多可写。
-- boss_16808 备注: 攻略里的"横扫攻击（下 5 次近战额外打一名玩家）"在**本 core 脚本/技能栏里没有**（SpellList=0，脚本只注册
-- boss_16808   19818 DOUBLE_ATTACK 这个自 proc aura）；Sweeping Strikes 系列 id（12328/12723/18765/26654/35429）与卡加斯无关
-- boss_16808   （12292 是 Death Wish）⇒ 脚本与攻略不一致，无可写规则。
-- boss_16808 备注: 卫兵的"激怒" 30485 **不可驱散**（spell_template Dispel=0）⇒ `dispel enrage` 对它不成立
-- boss_16808   （triggers/GenericTriggers.h → DispelEnrageOnTargetTrigger : DispelOnTargetTrigger(...,DISPEL_ENRAGE)；
-- boss_16808    GenericTriggers.cpp → DispelOnTargetTrigger::IsActive() 用 (1 << spellInfo->Dispel) & GetDispellMask(DISPEL_ENRAGE) 判定）
-- boss_16808   ⇒ 本组不写，避免死规则。
-- boss_16808 归 boss_common: 无（本 BOSS 对玩家没有 boss_common 已覆盖的可查 debuff，除了规则2 的两条控制）。
-- boss_17461 规则1 证据: 同 boss_16808 规则1（HasNearestAddsTrigger + AttackLeastHpTargetAction + NearestAdsValue(FleeDistance=8.0)）；
-- boss_20923 规则1 证据: 同 boss_16808 规则1；弓手 17427=20283 血 / 首领 20923=103320 血 ⇒ 实战会选弓手/狂热者。数值待定
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_16808';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_16808', 1, 0, 'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20'),
('boss_16808', 2, 0, 'val::or::{trigger::has aura::spellid::25821,trigger::has aura::spellid::23601}>use trinket!95');

-- ===== boss_16809  Warbringer O'mrogg (rank=1) =====
-- boss_16809 脚本: .../shattered_halls/boss_warbringer_omrogg.cpp → boss_warbringer_omroggAI
-- boss_16809        （CombatAI；entry 16809 HP 153135；英雄同名 entry 20596 HP 206732）
-- boss_16809 技能栏 creature_spell_list 1680901:
-- boss_16809   [0] 30598 Burning Maul 燃烧之槌（自己；aura42=PROC_TRIGGER_SPELL + aura23=PERIODIC_TRIGGER_SPELL，时长索引85）
-- boss_16809       触发链: 30598 → 30599(每次近战附加 832 火焰) / 30620 → **30600 Blast Wave 冲击波**
-- boss_16809       （脚本 BurningMaulTrigger::OnEffectExecute() 里 DoCastSpellIfCan(nullptr, SPELL_BLAST_WAVE=30600)；
-- boss_16809        30600: 火焰、Mechanic=MECHANIC_KNOCKOUT(14)、aura33=MOD_DECREASE_SPEED -50）
-- boss_16809   [1] 30618 Beatdown 击倒（自己；脚本 spell_beatdown → Beatdown::OnEffectExecute():
-- boss_16809       caster->getThreatManager().modifyAllThreatPercent(-100) + AttackStart(target)）
-- boss_16809   [2] 30584 Fear 恐惧（自己范围；aura7=MOD_FEAR，时长索引27，驱散=DISPEL_MAGIC）
-- boss_16809   [3] 30633 Thunderclap 雷霆一击（自己范围；aura33=MOD_DECREASE_SPEED -35 + aura138=MOD_MELEE_HASTE -35，时长索引1）
-- boss_16809   脚本 OnSpellCast() 在 30598/36056 时发 EMOTE_ENRAGE 16402 —— 就是攻略说的"他变红"
-- boss_16809 机制: 击倒 30618 清空全部仇恨并把目标转到被击倒的人 ⇒ **非坦克突然成为 BOSS 的当前目标 = 被击倒**，立刻自保
-- boss_16809 规则1 证据: TriggerContext.h:97 creators["has aggro"] → triggers/GenericTriggers.h → HasAggroTrigger::IsActive()
-- boss_16809   （= AI_VALUE2(bool,"has aggro","current target")，即"自己就是当前目标的 victim"）；`not::is tank` 的写法同 bossrules_common.tsv 规则3；
-- boss_16809   动作: actions/UseItemAction.h → UseStoneshieldPotionAction（isUseful 要求等级≥46、非竞技场；物品 13455）、UseHealingPotionAction；
-- boss_16809   actions/ImbueAction.h → TryEmergencyAction::Execute()
-- boss_16809 语义注意: 本规则只在"该 BOSS 的策略被挂上"时生效；对非坦克而言 has aggro = 坦克掉线/被清仇恨，属真应急。
-- boss_16809 数值待定: 权重；是否加 use trinket（见"顺手记②"）
-- boss_16809 备注: 攻略说"免疫嘲讽"，但本 core **没有** MECHANIC_TAUNT 位（Globals/SharedDefines.h 的 Mechanics 枚举里不存在），
-- boss_16809   16809 的 MechanicImmuneMask=653213695 解码后只有 charm/恐惧/定身/昏迷/打断/免疫盾等，没有"嘲讽"语义
-- boss_16809   ⇒ **我没找到 DB 层面的嘲讽免疫证据**（拿不准，留给站长核对）。坦克策略自带 `lose aggro > taunt`
-- boss_16809   （warrior/ProtectionWarriorStrategy.cpp 等），若真免疫，嘲讽会失败但不会有害 ⇒ 本组不写 taunt 规则。
-- boss_16809 TODO 做不到: 冲击波 30600（攻略: 变红就是即将冲击波 / 8 码 3147 火焰 + 减速 6 秒）
-- boss_16809   原因: 预警来自"燃烧之槌" 30598/36056 —— 它是**挂在 BOSS 自己身上**的 proc aura，`has aura` 查不到（只查自己）；
-- boss_16809   30600 对玩家只留 aura33 减速且瞬时，等有 aura 时伤害已经落地 ⇒ "视血量远离" 做不到。
-- boss_16809   能做的只有 `fire protection potion`（UseItemAction.h → UseFireProtectionPotionAction，物品 13457、等级≥48），
-- boss_16809   但**没有可用触发器**；若站长想开局吃，可另写 `combat start > fire protection potion!…`（本组没写，等站长定）。
-- boss_16809 TODO 做不到: 雷霆一击 30633 的减速/降攻速（aura33+aura138，魔法、约 10 秒）
-- boss_16809   原因: 玩家身上能查（`has aura::spellid::30633`），但现有动作都不是"解掉它"：
-- boss_16809     ① `free action potion` —— UseItemAction.h → UseFreeActionPotionAction::isUseful() 要求 `target->IsPlayer()`，
-- boss_16809        PvE 里当前目标是 BOSS（Creature）⇒ **永远为假**，写上去就是死规则（本组不写）；
-- boss_16809     ② `ra`（actions/RemoveAuraAction.cpp → ai->RemoveAura(spell)）需要"要移除的 buff 名"参数，规则行给不出 ⇒ 不可用；
-- boss_16809     ③ 自解魔法依赖牧师/圣骑的通用驱散（triggers/CureTriggers.h → NeedCureTrigger::GetTargetName()="self target"），与规则行无关。
-- boss_16809 TODO 做不到: 非近战"在斜坡散开站" / 坦克把 BOSS 拉开
-- boss_16809   原因: 站位与朝向没有规则行入口（没有"分散队形/指定点位"的动作），只能靠自由移动与阵型系统，留人工。
-- boss_16809 归 boss_common: 恐惧 30584（aura7=MOD_FEAR，40 码全员 3 秒）
-- boss_16809   —— 已被 bossrules_common.tsv 规则1（feared > every_man_for_himself / will of the forsaken）覆盖，本组不重复。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_16809';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_16809', 1, 0, 'val::and::{not::is tank,trigger::has aggro}>stoneshield potion!80,healing potion!75,try emergency!60');

-- ===== boss_17306  Watchkeeper Gargolmar (rank=1) =====
-- boss_17306 脚本: src/game/AI/ScriptDevAI/scripts/outland/hellfire_citadel/hellfire_ramparts/boss_watchkeeper_gargolmar.cpp → boss_watchkeeper_gargolmarAI::ExecuteAction()（HP 33381）
-- boss_17306 技能: SPELL_MORTAL_WOUND=30641(普通) / SPELL_MORTAL_WOUND_H=36814(英雄)；SPELL_SURGE=34645；SPELL_RETALIATION=22857；SPELL_OVERPOWER=32154
-- boss_17306 机制↔规则: 重伤 30641/36814 是挂在自己身上的可查 debuff（spell_template: Effect2=APPLY_AURA + Aura2=118 MOD_HEALING_PCT、每层 -6%、StackAmount=10、DurationIndex 18/9）⇒ 中了就往自己身上补（治疗药水/护甲药水/应急消耗品）
-- boss_17306 规则1/2 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（解析 spellid:: 限定词）+ HasAuraTrigger::GetTargetName() 返回 "self target"（只查自己）；strategy/NamedObjectContext.h → NamedObjectContext<T>::Create()（在第一个 "::" 处切出限定词）；动作 actions/UseItemAction.h → UseHealingPotionAction / UseStoneshieldPotionAction、actions/ImbueAction.cpp → TryEmergencyAction::Execute()（绷带或优先治疗消耗品）。权重数值待定
-- boss_17306 备注（有规则可写但我没写）: 40% 血以下 Boss 会喊治疗 —— Hellfire Watcher 17309（HP 10147）收到 AI 事件后对 Gargolmar 施放 30643 Heal（creature_ai_scripts 1730902: EVENT_T_RECEIVE_AI_EVENT(5,17306) → ACTION_T_CAST(30643)），它自带 Renew 8362 / Heal 12039 / SW:P 14032。可以写 `has nearest adds > attack least hp target!20` 让近战转火点杀它，但：① 攻略没提这条机制；② `nearest adds` 的判定半径是 AiPlayerbot.FleeDistance（源码默认 8.0 码，x64_Debug/aiplayerbot.conf 里该项是注释掉的 ⇒ 只有 8 码内有别的敌对单位才触发，远程基本触发不到）；③ 动作是"打血最少的已交战敌人"而不是按 entry 锁 Watcher ⇒ 按"宁少勿错"没写进规则，留给站长决定
-- boss_17306 TODO 做不到: 涌动 Surge 34645 —— 脚本用 SelectAttackingTarget(ATTACKING_TARGET_FARTHEST_AWAY) 挑"离得最远的玩家"（spell_template: Effect1=96 冲锋 + Effect2=98 击退，不施加任何 Aura）⇒ 没有"我是不是最远/我被点名"的触发器，也没有"指定某个 bot 当沙包"的规则入口（攻略要求的"一名远程站最远处当沙包"只能人工站位或后续加触发器）
-- boss_17306 TODO 做不到: 反击风暴 Retaliation 22857（脚本 <20% 血 DoCastSpellIfCan(nullptr, SPELL_RETALIATION)，是 Boss 自身的 aura）—— `has aura` 只查自己（HasAuraTrigger::GetTargetName() = "self target"），引擎没有"目标/BOSS 身上有 aura"的触发器 ⇒ 没法让近战停手或切远程
-- boss_17306 TODO 做不到: 压制 Overpower 32154 —— 脚本对当前目标（坦克）直接施放，前置条件是坦克躲闪（核心判定），无 aura、机器人没有可干预点
-- boss_17306 备注: 攻略写"反击风暴生命值降至 30% 时施放"，脚本实测阈值是 <20%（boss_watchkeeper_gargolmarAI::ExecuteAction() → GARGOLMAR_ACTION_RETALIATION）
-- boss_17308 规则1/2 证据: 触发器同 boss_17306（HasAuraTrigger 只查自己）；动作 actions/MovementActions.cpp → FleeAction::Execute() → MovementAction::Flee()。近似点: Flee 以"当前目标"（=Boss）为基点 —— 无真人主人的 bot 走 MoveChase(目标, flee 距离) 保持最大距离；带真人主人时会先 MoveNear 到"治疗/远程队友"⇒ 只是近似"离开人群/脱离 15 码"，不是严格"远离队友"。权重 90=应急档，数值待定
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17306';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17306', 1, 0, 'has aura::spellid::30641>healing potion!70,stoneshield potion!60,try emergency!50'),
('boss_17306', 2, 0, 'has aura::spellid::36814>healing potion!70,stoneshield potion!60,try emergency!50');

-- ===== boss_17308  Omor the Unscarred (rank=1) =====
-- boss_17308 脚本: src/game/AI/ScriptDevAI/scripts/outland/hellfire_citadel/hellfire_ramparts/boss_omor_the_unscarred.cpp → boss_omor_the_unscarredAI::ExecuteAction()（HP 59836）
-- boss_17308 技能: SPELL_TREACHEROUS_AURA=30695(普通) / SPELL_BANE_OF_TREACHERY_H=37566(英雄)；SPELL_ORBITAL_STRIKE=30637；SPELL_SHADOW_WHIP=30638；SPELL_DEMONIC_SHIELD=31901；SPELL_SHADOW_BOLT=30686/39297；SPELL_SUMMON_FIENDISH_HOUND=30707
-- boss_17308 机制↔规则: 反叛 30695/37566 是"挂在自己身上的可查 debuff"（spell_template: Effect1=APPLY_AURA + Aura1=23 PERIODIC_DAMAGE、Amplitude=1000ms、DurationIndex 8）⇒ 中了就往远离 Boss/人群的方向跑（攻略: 15 码内每跳约 4600 暗影）
-- boss_17308 规则1/2 证据: 触发器同 boss_17306（HasAuraTrigger 只查自己）；动作 actions/MovementActions.cpp → FleeAction::Execute() → MovementAction::Flee()。近似点: Flee 以"当前目标"（=Boss）为基点 —— 无真人主人的 bot 走 MoveChase(目标, flee 距离) 保持最大距离；带真人主人时会先 MoveNear 到"治疗/远程队友"⇒ 只是近似"离开人群/脱离 15 码"，不是严格"远离队友"。权重 90=应急档，数值待定
-- boss_17308 机制↔规则: 优先击杀残忍的军犬 —— Fiendish Hound 17540 HP 只有 2191（Boss 59836），boss_omor_the_unscarredAI::JustSummoned() 立刻让军犬 AttackStart 一个随机玩家 ⇒ 触发"附近还有别的敌对单位"时改为打"血最少的已交战敌人"=军犬
-- boss_17308_dps 机制: 军犬(17540) 只让 **DPS** 转火（角色后缀 `_dps`；坦克/治疗不挂这个集）
-- boss_17308 规则3 证据: triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()（读 values/NearestAdsValue.h = PossibleTargetsValue(fleeDistance, 忽略 LOS)，并排除"当前目标"）；动作 actions/ChooseTargetActions.h → AttackLeastHpTargetAction → values/LeastHpTargetValue.cpp → FindLeastHpTargetStrategy（只遍历 values/TargetValue.cpp → TargetValue::FindTarget() 的 "attackers"=正在打我们的敌人/附近队友，不会去开没交战的怪，也跳过被标记 CC 的目标）。近似点: ① 判定半径是 AiPlayerbot.FleeDistance（源码默认 8.0 码）⇒ 只有身边 8 码内有别的敌对单位才触发，远程 bot 常常触发不到；② 它是"打血最少的已交战敌人"而不是按 entry 锁 17540。若站长要 100% 覆盖，可改用 `has attackers > attack least hp target!20`（代价: 全场时刻重选血最少目标，治疗也会去平A）；权重数值待定
-- boss_17308 TODO 做不到: 按 entry 锁定军犬的严格触发器 —— values/PossibleAttackTargetsValue.cpp → PossibleAddsValue::Calculate() 要求该怪"没人打、无 threat、无 UNIT_FIELD_TARGET"，而 JustSummoned() 立刻 AttackStart ⇒ `possible adds` 永远为假；唯一能按 entry 找怪的 `specific creature too close` 只读预置的 "avoid creature list"（triggers/DungeonTriggers.cpp → CloseToSpecificCreaturesTrigger::IsActive()），规则行改不了它 ⇒ 只能用规则3那条近似规则
-- boss_17308 TODO 做不到: 军犬的烧蓝/吸血 —— 技能栏 creature_spell_list 1754001 是 Mana Burn 15785（目标类型 105 = on mana user），EventAI 1754003 是 30% 血 Drain Life 35748；两者都是瞬发、不挂 debuff，没有"正在被军犬烧蓝"的触发器，也没有"按 entry 指定控场目标"的触发器 ⇒ 攻略的"多用晕恐等控场"只能靠职业策略/人工
-- boss_17308 TODO 做不到: 轨道打击 Orbital Strike 30637 —— spell_template: Effect1=2 伤害 + Effect2=98 击退，不施加任何 Aura ⇒ 没有可查的自 debuff；`falling`/`falling far` 只是移动标志触发器（triggers/GenericTriggers.cpp → IsFallingTrigger::IsActive()，本 core=TBC 定义的是 MANGOSBOT_ONE（PlayerBots/CMakeLists.txt: TBC ⇒ -DMANGOSBOT_ONE），走 `#ifndef MANGOSBOT_TWO` 分支 = MOVEFLAG_JUMPING，检测的是"在跳"而不是"被扔上天"）⇒ 识别不了
-- boss_17308 TODO 做不到: 恶魔护盾 Demonic Shield 31901（<20% 血起每 15s 重施，是 Boss 自身的 aura；spell_template: Aura1=87 MOD_DAMAGE_PERCENT_TAKEN、BasePoints=-76 ⇒ 约 75% 减伤，攻略另说会周期反射法术）—— 同样没有"目标身上有 aura"的触发器 ⇒ 没法让法系停手躲反射、让近战减少输出
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17308';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17308', 1, 0, 'has aura::spellid::30695>flee!90'),
('boss_17308', 2, 0, 'has aura::spellid::37566>flee!90');

-- ===== boss_17308_dps  Omor the Unscarred (rank=1) =====
-- boss_17308_dps 机制: 军犬(17540) 只让 **DPS** 转火（角色后缀 `_dps`；坦克/治疗不挂这个集）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17308_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17308_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_17377  Keli'dan the Breaker (rank=1) =====
-- boss_17377 机制: [暗影印记] 30937（Dispel=DISPEL_MAGIC，持续2分钟，受到暗影伤害提高32=暗影系）
-- boss_17377 规则1: 自己中了暗影印记 → 牧师/圣骑士给自己驱散
-- boss_17377 机制: [腐蚀术] 30938（Dispel=DISPEL_MAGIC，光环=SPELL_AURA_PERIODIC_DAMAGE，DurationIndex=106 约15秒 dot）
-- boss_17377 规则2: 自己中了腐蚀术 → 牧师/圣骑士给自己驱散
-- boss_17377 触发器证据: TriggerContext.h → creators["has aura"]=HasAuraTrigger；GenericTriggers.cpp → HasAuraTrigger::IsActive() → ai->HasAura(spellid, self target) ⇒ 只判自己身上有没有这个 debuff
-- boss_17377 动作证据: PriestAiObjectContext.cpp → creators["dispel magic"]=CastDispelMagicAction（PriestActions.h → CURE_ACTION，GenericSpellActions.h → CastCureSpellAction::GetTargetName()="self target"）；
-- boss_17377 说明: 职业策略本身已有自身驱散（PriestStrategy.cpp → "dispel magic"、PaladinStrategy.cpp → "cleanse cure magic"→"cleanse magic"），
-- boss_17377 数值待定: 55/50（≈ ACTION_DISPEL=50，不会被治疗/保命动作压住）
-- boss_17377 TODO 做不到: [燃烧新星] 30940 "把人拉过去后立刻远离" / 原因: spell_template 里 30940 的两个效果都作用在 BOSS 自己身上
-- boss_17377 TODO 做不到: [暗影箭雨] 17228（目标=22 TARGET_LOCATION_CASTER_SRC + 半径索引10） / 原因: 纯伤害效果、不留光环，没有可触发条件；"散开"也没有对应动作
-- boss_17377 说明: 一阶段必须先杀 5 个影月导魔者（boss_kelidan_the_breaker.cpp → MAX_ADDS=5、DoSetupAdds() 期间给 BOSS 挂 UNIT_FLAG_UNINTERACTIBLE|UNIT_FLAG_IMMUNE_TO_NPC），
-- boss_17377 说明: 攻略提到的[暗影之怒]在本地数据里查无（boss_kelidan_the_breaker.cpp 无此技能、creature_template.SpellList=0、creature_ai_scripts 无 17377 记录）⇒ 不写规则
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17377';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17377', 1, 0, 'has aura::spellid::30937>dispel magic!55,cleanse magic!50'),
('boss_17377', 2, 0, 'has aura::spellid::30938>dispel magic!55,cleanse magic!50');

-- ===== boss_17380_dps  Broggok (rank=1) =====
-- boss_17380_dps 机制: 软泥喷射(30913)正面锥只让 **DPS** 绕背（角色后缀 `_dps`）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17380_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17380_dps', 1, 0, 'not behind target>set behind!20');

-- ===== boss_17381  The Maker (rank=1) =====
-- boss_17381 机制: [支配] 30923 控制一名玩家10秒，使其攻击盟友（spell_template: 光环=SPELL_AURA_MOD_CHARM + MOD_DAMAGE_PERCENT_DONE + MOD_MELEE_HASTE）
-- boss_17381 规则1: 自己被支配时，优先用种族解控/徽章把自己解出来（被心控的坦克/治疗=灭团点；通用集只含"被恐惧预判"，不含 charm）
-- boss_17381 触发器证据: TriggerContext.h → creators["has aura"]=HasAuraTrigger；GenericTriggers.h → HasAuraTrigger::GetTargetName() 返回 "self target"；
-- boss_17381 动作证据: ActionContext.h → creators["every_man_for_himself"]=CastEveryManforHimselfAction（人类种族解控，GenericSpellActions.h → SPELL_ACTION）；
-- boss_17381 数值待定: 96/95/90 仅用于压过通用 CombatStrategy.cpp → "often"→"use trinket"(50)
-- boss_17381 拿不准: 被心控时引擎是否仍执行动作 —— Engine.cpp → DoNextAction() 只对 stunned 做过滤（isUsefulWhenStunned），charm 不过滤；
-- boss_17381 TODO 做不到: [爆炸之杯] 30925 "8码分散站位" / 原因: spell_template 显示 30925 只有 Effect1=SCHOOL_DAMAGE(2)、Effect2=KNOCK_BACK(98)，DurationIndex=0、Dispel=0
-- boss_17381 TODO 做不到: 心控坦克/治疗时"爆发速杀" / 原因: 通用触发器没有"BOSS 血量档/阶段/正在施法"，也没有"队友被心控"（`charmed` 只查自己）
-- boss_17381 说明: 被心控的队友不会被机器人当目标打（PossibleAttackTargetsValue.cpp → IsImmuneToDamage() 把 charmed 队友判为免疫、EnemyPlayerValue.cpp 也排除），
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17381';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17381', 1, 0, 'has aura::spellid::30923>every_man_for_himself!96,will of the forsaken!95,use trinket!90');

-- ===== boss_17461  Shattered Hand Blood Guard (rank=1) =====
-- boss_17461 为什么写它: 副本脚本 instance_shattered_halls::DoInitialGets() →
-- boss_17461   `GetSingleCreatureFromStorage(instance->IsRegularDifficulty() ? NPC_BLOOD_GUARD : NPC_PORUNG)`
-- boss_17461   ⇒ 普通难度=17461，英雄难度=20923；creature 表里 17461(guid 5400276, spawnMask=1) 与 20923(guid 5400279, spawnMask=2)
-- boss_17461   **同一个坐标** (512.69, 315.65, 2.04)
-- boss_17461 技能: **没有任何战斗技能**（creature_ai_scripts 1746101-1746105 只有 spawn 隐身侦测 18950 / aggro 写实例数据+喊话 / death / evade）
-- boss_17461 通道小怪: 碎手弓箭手 17427 两只（creature 表坐标 (514.50,319.66) 与 (514.80,312.04)，**就站在首领旁边约 5 码**）
-- boss_17461   技能栏 1742701: 16100 Shoot + 30990 Multi-Shot；副本脚本 instance_shattered_halls::DoBeginArcherAttack() 每 15s
-- boss_17461   让弓箭手放 30952 Shoot Flame Arrow → 落地生成 GO 181915 Blaze → GO 每 2s 放 30979 Flames（火焰，半径索引15）
-- boss_17461 机制: 开怪后先点掉身边的弓箭手/狂热者（攻略: 触发首领战后优先击杀身边的弓箭手小怪）
-- boss_17461 规则1 证据: 同 boss_16808 规则1（HasNearestAddsTrigger + AttackLeastHpTargetAction + NearestAdsValue(FleeDistance=8.0)）；
-- boss_17461   弓手 17427 只有 20283 血（首领 17461 是 28006）且与首领同点 ⇒ 近战一旦交战，8 码判定通常能覆盖到。数值待定
-- boss_17461 TODO 做不到: 弓箭手火箭落地的火（GO 181915 Blaze → 30979 Flames）
-- boss_17461   原因: 伤害来自**游戏物件**（instance 脚本 Update() 里给 Blaze 定时 CastSpell(SPELL_FLAMES)），
-- boss_17461   而 `has area debuff` 只认 DynamicObject（values/AoeValues.cpp → HasAreaDebuffValue）⇒ 机器人感知不到脚下火，做不到"躲开"。
-- boss_17461 备注: 攻略"顺劈斩/恐惧"与 DB 不一致 —— 17461 的 EventAI 里**没有**顺劈斩（15496 Cleave 只在英雄版 20923 的脚本里），
-- boss_17461   "恐惧"在 20923 的 creature_ai_scripts（2092301-2092306）里也**不存在** ⇒ 本 BOSS 无这两条规则可写。
-- boss_17461 归 boss_common: 无（本 BOSS 不给玩家挂任何可查 debuff）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17461';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17461', 1, 0, 'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20');

-- ===== boss_17536_dps  Nazan (rank=1) =====
-- boss_17536_dps 机制: 纳杉火锥术正面规避只让 **DPS** 绕背（角色后缀 `_dps`）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17536_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17536_dps', 1, 0, 'not behind target>set behind!20');

-- ===== boss_17537_dps  Vazruden (rank=1) =====
-- boss_17537_dps 机制: 火锥术正面规避只让 **DPS** 绕背（角色后缀 `_dps`）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17537_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17537_dps', 1, 0, 'not behind target>set behind!20');

-- ===== boss_17796_melee  Mekgineer Steamrigger (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 ⇒ 集名后缀（boss_17796_melee / boss_17975_dps）；
-- boss_17796_melee 规则1 证据: triggers/GenericTriggers.cpp → IsNotBehindTargetTrigger::IsActive()
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17796_melee';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17796_melee', 1, 0, 'not behind target>set behind!20');

-- ===== boss_17797  Hydromancer Thespia (rank=1) =====
-- boss_17797 脚本: src/game/AI/ScriptDevAI/scripts/outland/coilfang_reservoir/steam_vault/
-- boss_17797 技能（creature_spell_list 1779701，目标都是 100 = 随机玩家）:
-- boss_17797 小怪: 盘牙水元素 Coilfang Water Elemental 17917（map 545 两个固定刷新点，
-- boss_17797 机制: 全程躲落雷之云 25033。它是**持久区域光环**（spell_template: Effect2=27
-- boss_17797 注: `has area debuff > flee` 已由引擎内置反应策略覆盖（AiFactory.cpp:1327 反应引擎挂 "avoid aoe" → CombatStrategy.cpp → AvoidAoeStrategy），
-- boss_17797 规则1 证据: triggers/GenericTriggers.cpp → HasAreaDebuffTrigger::IsActive()
-- boss_17797 备注: 引擎另有常驻的 avoid aoe（strategy/generic/CombatStrategy.cpp →
-- boss_17797 机制: 包围之风 31718 是 6 秒昏迷（Mechanic=12 STUN，Dispel=1 魔法）⇒ 中招后先尝试解控，
-- boss_17797 规则2 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（解析
-- boss_17797 规则2 拿不准（见回报）: ① 昏迷期间引擎**没有**门闩（Engine.cpp 不检查 stun），
-- boss_17797 机制: 内爆 31481 是魔法持续伤害（Dispel=1，每跳 602，攻略口径"每 2 秒 600 持续 10 秒"）
-- boss_17797 规则3 证据: HasAuraTrigger（同上，只查自己）；动作 actions/UseItemAction.h →
-- boss_17797 备注: 魔法 debuff 的**自我**驱散引擎已覆盖（triggers/CureTriggers.h →
-- boss_17797 机制: 优先击杀两只盘牙水元素 17917（16767 血），并制造"当前目标=元素"的机会让
-- boss_17797 规则4 证据: values/BossRuleValues.h → TriggerAsValue::Calculate()（把触发器当布尔值）
-- boss_17797 规则4 语义注意: ① 引擎默认的 "dps target"（values/DpsTargetValue.cpp →
-- boss_17797 TODO 做不到: 水箭之雨 34449 的"指定打断"
-- boss_17797 TODO 归 boss_common: "治疗把所有人血线保持 50% 以上" —— 属治疗档位配置
-- boss_17797 备注: 攻略与脚本一致（25033/31481/31718 三个技能就是技能栏里的三行），无冲突。
-- 原因: ① 没有"附近小怪正在读条/正在引导"的触发器（同 boss_17797 的说明）；
-- + UseHealingPotionAction。权重 60 与 boss_17797 规则3 一致，数值待定。
-- boss_17978 规则1 拿不准（见回报）: ① 与 boss_17797 规则2 同：`use trinket` 取的是身上第一个
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17797';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17797', 1, 0, 'has aura::spellid::31718>use trinket!95,try emergency!50'),
('boss_17797', 2, 0, 'has aura::spellid::31481>healing potion!60'),
('boss_17797', 3, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20');

-- ===== boss_17798  Warlord Kalithresh (rank=1) =====
-- boss_17798 TODO 的同一条原因）；`dps aoe` 只是让 bot 放 AOE 技能，不改变目标选择。
-- boss_17798 脚本: …/steam_vault/boss_warlord_kalithresh.cpp → boss_warlord_kalithreshAI
-- boss_17798 技能（creature_spell_list 1779801）:
-- boss_17798 蒸馏器: 17954（HP 10468，map 545 八个固定刷新点）；脚本 ExecuteAction() 每 15-20s
-- boss_17798 机制: 被穿刺 39061 点名的是"不在近战范围"的玩家（TargetId=107），可叠 3 层持续掉血
-- boss_17798 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（spellid::
-- boss_17798 备注: 规则行不会因为"近战不该有这 debuff"而误触 —— 穿刺只点非近战（TargetId=107），
-- boss_17798 TODO 做不到: 【本 BOSS 最关键的做不到项】第一时间转火纳迦蒸馏器 17954
-- boss_17798 TODO 做不到: 法术反射 31534 期间"停止对督军输出"
-- boss_17798 TODO 做不到: 绝不叠第二层督军之怒（36453/37076，Dispel=0 不可驱散）
-- boss_17798 TODO 做不到: 坦克主动把 BOSS 带到蒸馏器旁
-- boss_17798 备注: 裂颅 16172（耐力 -200，15 秒）无任何可做的规则行 —— 无 aura 可查（debuff 在
-- 原因: 规则行没有控制 BOSS 站位的入口（同 boss_17798 的那条）。
-- boss_19219       规则行改不了 —— 见 bossrules_H.tsv boss_17798 的同条说明）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17798';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17798', 1, 0, 'has aura::spellid::39061>healing potion!60');

-- ===== boss_17826  Swamplord Musel'ek (rank=1) =====
-- boss_17826 取证: ScriptName=boss_swamplord_muselek → .../underbog/boss_swamplord_muselek.cpp
-- boss_17826 机制: 猎人型 BOSS 会主动拉远（SetRangedMode 30 码），远程要自己走回施法距离继续输出
-- boss_17826 机制: 只给 **远程**（规则内 val::and::{…,is ranged}；近战本来就该贴）
-- boss_17826 规则1 证据:
-- boss_17826 TODO 做不到: "先杀熊（克劳恩 17827）再杀猎人"的目标优先级
-- boss_17826 TODO 做不到: 野性冲锋 39435 / 击退 18813 的"背对墙站以免被弹飞引怪"
-- boss_17826 TODO 做不到: 回响咆哮 31429（10 码内护甲 -75%? 本库实测是 MOD_RESISTANCE_PCT -50%）时加大治疗
-- boss_17826 TODO 做不到: 冰冻陷阱 31946/31932（魔法定身）+ 描准射击 31623 的连招
-- boss_17826 TODO 归内置策略: 熊 20% 血变形（ACTION_T_UPDATE_TEMPLATE 17894）后停战 —— 脚本已强制 evade，
-- （"ra" 需要 aura 名参数，见 boss_17826 同类说明）；
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17826';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17826', 1, 0, 'val::and::{trigger::enemy too close for melee,is ranged}>flee!50');

-- ===== boss_17848  Lieutenant Drake (rank=1) =====
-- 集里只有某几条限角色 → val::and::{trigger::…,is tank}（本文件 boss_17848）。
-- boss_17848 机制: 致死打击 31911 挂在坦克身上（治疗 -50%）+ 攻略"血量<4000 就果断吃糖/喝水/减伤" ⇒ 坦克自己嗑药
-- boss_17848 机制: 爆破射击 33792（2500 火焰 + 昏迷 6 秒）昏迷期间交徽章（与 bossrules_E 的 16808 规则2 同一写法）
-- boss_17848 TODO 做不到: 旋风斩 31909/31910 "触之即秒，看到就跑"
-- boss_17848 TODO 做不到（有替代写法但有风险，留给站长决定）: 爆破射击 33792 的"坦克别跑到 15 码外"
-- boss_17848 归 boss_common: 破胆怒吼 33789（aura7 MOD_FEAR）—— "被恐惧就自解"在 bossrules_common.tsv 规则1
-- boss_17848 备注（可写但攻略没要求，本组不写）: 断筋 9080 是 -61% 减速（可被"行动自由药水"清），
-- boss_17848 备注: 攻略"坦克务必吃铁盾药水**开怪**"——规则集只在战斗中由钩子挂载（BossStrategyHook.h → FightTargetEntry()
-- 触发器与动作证据同 boss_17848 规则1。数值待定
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17848';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17848', 1, 0, 'val::and::{is tank,trigger::has aura::spellid::31911,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),
('boss_17848', 2, 0, 'has aura::spellid::33792>use trinket!95');

-- ===== boss_17862  Captain Skarloc (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_17862_dps / boss_18096_dps）；
-- boss_17862 机制: 先杀看守（攻略: 直接全拉住，先击杀敦霍尔德看守）—— 看守 14674 血 < 精兵 18345 血 < 上尉 60108 血
-- boss_17862 机制: 制裁之锤 13005（昏迷 5 秒，魔法可驱散）→ 自己交徽章；能自己解魔法的职业（牧师/圣骑士）顺手自解
-- boss_17862 机制: 暗言术：痛 15654（看守的魔法 DOT）→ 自己中了自己解（攻略: 有余裕驱散）
-- boss_17862 TODO 做不到: 打断圣光术 29427 / 看守的治疗 15586（攻略: 务必打断治疗和圣光术）
-- boss_17862 TODO 做不到: 神圣之盾 31904（格挡 +75%、每次格挡造成神圣伤害）
-- boss_17862 TODO 做不到: 奉献 38385 "全程避开"
-- boss_17862 TODO 做不到: 对手下的控场会被清洁术 29380 驱散
-- boss_17862 备注: 攻略里"敦霍尔德精兵-肾击"与 DB 不符 —— 17860 的技能栏 1786001 只有 15581 Sinister Strike + 15582 Backstab；
-- boss_17862 归 boss_common: 看守的心灵尖啸 22884（aura7 MOD_FEAR，8 码 AoE）—— 被恐惧自解在 bossrules_common.tsv 规则1。
-- 规则1 证据: 同 boss_17862 规则1（HasNearestAddsTrigger + AttackLeastHpTargetAction，半径 FleeDistance 8 码）；
-- self-target 自解动作证据同 boss_17862 规则2。数值待定
-- 原因: 同 boss_17862 的"打断圣光术"—— 没有"按 entry 指定打断目标"的动作，职业打断只作用于当前目标且是各职业自己的触发器名
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17862';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17862', 1, 0, 'has aura::spellid::13005>use trinket!95,cleanse magic!50,dispel magic!50'),
('boss_17862', 2, 0, 'has aura::spellid::15654>dispel magic!55,cleanse magic!50');

-- ===== boss_17862_dps  Captain Skarloc (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_17862_dps / boss_18096_dps）；
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17862_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17862_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_17879  Chrono Lord Deja (rank=1) =====
-- ⇒ **英雄本里 GetEntry() 仍是 17879/17880/17881**（属性/技能栏取英雄模板），所以一套 boss_17879/17880/17881 覆盖两种难度；
-- boss_17879 技能栏 creature_spell_list 1787901（普通）/ 2073801（英雄；多 [3] 一条 38540）:
-- boss_17879   [0] 31457 Arcane Blast 奥术冲击       目标=当前目标(坦克)  18-23s / 15-25s
-- boss_17879       （spell_template：Effect1=98 SPELL_EFFECT_KNOCK_BACK(Misc=75) + Effect2=2 伤害 3063、
-- boss_17879        TgtA1/TgtA2=6 TARGET_UNIT_ENEMY、**无任何 aura**；英雄版 = 38538，伤害 4500）
-- boss_17879   [1] 31472 Arcane Discharge 奥术清偿   目标=自己           20-30s / 20-30s
-- boss_17879       （Effect1=2 伤害 2313、TgtA1=22 TARGET_LOCATION_CASTER_SRC + TgtB1=15
-- boss_17879        TARGET_ENUM_UNITS_ENEMY_AOE_AT_SRC_LOC = 以自己为圆心的全员 AOE、**无 aura**、
-- boss_17879        CastingTimeIndex=5 = 有读条；英雄版 = 38539，伤害 3700）
-- boss_17879   [2] 31467 Time Lapse 时间流逝         目标=自己           10-15s / 15-25s
-- boss_17879       （**两个难度同一个 id**；Dispel=1 DISPEL_MAGIC、Mechanic=11 SNARE、可叠光环
-- boss_17879        aura138 MOD_MELEE_HASTE -60 + aura33 MOD_DECREASE_SPEED -60、TgtA=22 + TgtB=15 ⇒ 近身一圈玩家全中）
-- boss_17879   [3] 38540 Attraction 吸引（**仅英雄**） 目标=自己          25-35s / 25-35s
-- boss_17879       （Effect1=124 SPELL_EFFECT_PULL_TOWARDS(Misc=125) + TgtA1=22 + TgtB1=15
-- boss_17879        ⇒ 把 50 码内所有玩家拽到身边，**无 aura**）
-- boss_17879 机制: [时间流逝] 是魔法减速（攻速/移速 -60%、10 秒、可驱散）⇒ 中招就自驱散
-- boss_17879 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（spellid:: 形式，目标恒 "self target"）
-- boss_17879   + NamedObjectContext.h → NamedObjectFactory<T>::Create()（在第一个 "::" 处切限定词）；
-- boss_17879   动作: 牧师的 strategy/priest/PriestAiObjectContext.cpp:247 `creators["dispel magic"] = CastDispelMagicAction`
-- boss_17879   （strategy/AiObject.h → CURE_ACTION；strategy/actions/GenericSpellActions.h → CastCureSpellAction::
-- boss_17879    GetTargetName() = "self target" = 对自己施放）、圣骑士的 PaladinAiObjectContext.cpp:373
-- boss_17879   `creators["cleanse magic"] = CastCleanseMagicAction`。非牧/骑职业没有这两个动作名
-- boss_17879   ⇒ Engine.cpp → InitializeAction() 取到 nullptr，只跳过（"名字不报错、静默失效"，不会崩、不会误伤）。
-- boss_17879 语义注意（**站长请定夺，这条与引擎内置重复**）: 牧师/圣骑的职业策略里本来就有等价节点
-- boss_17879   （PriestStrategy.cpp → "dispel magic"(自身) / "dispel magic on party"(队友)；
-- boss_17879    PaladinStrategy.cpp → "cleanse cure magic" / "cleanse party member cure magic"，
-- boss_17879    各扩展分支都有）⇒ 攻略"注意驱散 [时间流逝]"其实**引擎已经在做**（含对坦克）。
-- boss_17879   本行的价值只是"把时机钉进 BOSS 集并给 50 档以上的权重"；若站长认定冗余，删掉这一行即可
-- boss_17879   （代价：17879 变成 0 规则的小节，boss_rule_check.py 只把"有规则行的小节"的注释抄进 SQL，
-- boss_17879    本节的分析/TODO 就不会出现在生成的 SQL 里，需要另找地方记）。权重数值待定。
-- boss_17879 机制: 英雄版 [吸引] 38540 把 50 码内所有玩家拽到 BOSS 身边 ⇒ 非坦克要退出模型（别贴脸吃顺劈/奥术冲击）
-- boss_17879 规则2 证据: values/BossRuleValues.h → IsTankValue / TriggerAsValue（把触发器当布尔值）
-- boss_17879   + values/ValueContext.h → BoolAndValue/NotValue（values/OperatorValues.cpp → BoolAndValue::Calculate()
-- boss_17879   对 getMultiQualifiers(getQualifier(), ",") 的每个元素做 `AI_VALUE(bool, 元素)`）；
-- boss_17879   触发器 triggers/RangeTriggers.h → EnemyTooCloseForMeleeTrigger::IsActive()
-- boss_17879   （`target && AI_VALUE2(bool, "inside target", "current target")`）；动作
-- boss_17879   actions/MovementActions.cpp → MoveOutOfEnemyContactAction::isUseful()
-- boss_17879   （`MovementAction::isUseful() && AI_VALUE2(bool, "inside target", "current target")`）
-- boss_17879   + MoveTo(target, AiPlayerbot.ContactDistance 默认 0.5)。
-- boss_17879 语义注意: ① 这条的意图与 boss_common 规则3（`val::and::{inside target,not::is tank}`）**相同**，
-- boss_17879   但 boss_common 那条用了裸 `inside target` ⇒ 有限定词为空、空指针解引用的崩服风险（见文件头 §6）。
-- boss_17879   我在这里用等价的 `trigger::enemy too close for melee`（硬编码 current target）写一份**安全版**；
-- boss_17879   站长修好 boss_common 后这条对德亚之外没影响（同动作重复触发无害，可留可删）。
-- boss_17879   ② 元素顺序: 把 `trigger::…` 放最后（E 组口径：查不到的触发器名在 TriggerAsValue::Calculate() 里返回 false，
-- boss_17879   不会空指针），`is tank`/`not` 这类 BoolCalculatedValue 不解析限定词、放哪都安全。数值待定。
-- boss_17879 TODO 做不到: 奥术清偿 31472/38539（攻略：50 码内全员 4300 奥术，治疗要"提前抬满全团"）
-- boss_17879   原因: spell_template 里 Effect 只有直接伤害（无 aura）、TgtA=22/TgtB=15 ⇒ 玩家身上**没有任何可查的 debuff**；
-- boss_17879   而且规则行没有"提高治疗优先级/预读治疗"的动作（治疗目标选择在 HealStrategy / values "party member to heal" 里）。
-- boss_17879 TODO 做不到: 奥术冲击 31457/38538 的击退
-- boss_17879   原因: Effect1=98 SPELL_EFFECT_KNOCK_BACK 不挂 aura；用来识别"被扔上天"的 `falling`/`falling far`
-- boss_17879   （triggers/GenericTriggers.cpp → IsFallingTrigger）在本 core（MANGOSBOT_ONE=TBC）走 `#ifndef MANGOSBOT_TWO`
-- boss_17879   分支，判的是 MOVEFLAG_JUMPING＝"在跳"，不是"被击退" ⇒ 识别不了；落地的补救（回到近战距离）
-- boss_17879   由职业内置节点（"enemy out of melee range" → reach melee）自动接手。
-- boss_17879 TODO 做不到: [吸引] 38540 之后"回到远程/治疗距离"（50 码内全员被拽到身边）
-- boss_17879   原因: 被拽过去后要拉开的距离**大于**自己的施法距离 ⇒ `reach spell`（isUseful 只在 距离>spell 时为真）
-- boss_17879   不生效；`flee`（actions/MovementActions.cpp → MovementAction::Flee()）的语义不是"退到 15/25 码"：
-- boss_17879   带真人 master 的 bot 会 MoveNear 到"队伍里的坦克/治疗/远程队友"（落点由队友位置决定），
-- boss_17879   没有真人 master 时走 `mm->MoveChase(target, ai->GetRange("flee"))`，而 FleeDistance 源码默认 8.0 码
-- boss_17879   （x64_Debug/aiplayerbot.conf 里该项是注释掉的）＝"贴脸 8 码风筝"，都不是我们要的。
-- boss_17879   现状: 只有规则2 把非坦克从模型里推出去（≈0.5 码），"回到 15 码外"要人工或后续加动作。
-- boss_17879 归 boss_common: 时间流逝的"驱散"如果站长认为不该在本集重复，删规则1 后由 boss_common/职业策略接管。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17879';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17879', 1, 0, 'has aura::spellid::31467>dispel magic!60,cleanse magic!59'),
('boss_17879', 2, 0, 'val::and::{trigger::enemy too close for melee,not::is tank}>move out of enemy contact!80');

-- ===== boss_17880  Temporus (rank=1) =====
-- boss_17880 技能栏 creature_spell_list 1788001（普通）/ 2074501（英雄；[0] 换成 38593、多 [3] 一条 38592）:
-- boss_17880   [0] 31475 Wing Buffet 飞翼打击     目标=自己  概率=5  18-22s / 20-28s
-- boss_17880       （Effect1=98 SPELL_EFFECT_KNOCK_BACK(Misc=150) + Effect2=2 伤害 750、
-- boss_17880        TgtA=22 + TgtB=15 ⇒ 以自己为圆心约 15 码内敌人被击退+物理伤害、**无 aura**；英雄版 38593 伤害 1875）
-- boss_17880   [1] 31464 Mortal Wound 重伤[坦克]   目标=当前目标  3.5-7s / 4.5-7s
-- boss_17880       （**两个难度同一个 id**；StackAmount=7、aura118 MOD_HEALING_PCT 值 -10 ⇒ 每层"受到的治疗 -10%"、可叠 7 层）
-- boss_17880   [2] 31458 Hasten 时光加速          目标=自己  概率=2  13-18s / 17-21s
-- boss_17880       （Dispel=1 DISPEL_MAGIC、aura138 MOD_MELEE_HASTE +200 + aura31 MOD_INCREASE_SPEED +200、10 秒口径）
-- boss_17880   [3] 38592 Spell Reflection 法术反射（**仅英雄**）目标=自己  概率=10  17-22s / 25-35s
-- boss_17880       （aura28 SPELL_AURA_REFLECT_SPELLS 值 100 ⇒ 100% 反射，攻略口径"与时光加速同时存在时无法偷取"）
-- boss_17880 机制: [重伤] 31464 叠在坦克身上（叠 7 层 = 受到治疗 -70%）⇒ 叠起来就自己补减伤/治疗消耗品
-- boss_17880 规则1 证据: 触发器同 17879 规则1（HasAuraTrigger，只查自己；层数正则见文件头 §2）；
-- boss_17880   值: strategy/values/BossRuleValues.h → IsTankValue（Calculate() 直接调 PlayerbotAI::IsTank）+ TriggerAsValue；
-- boss_17880   动作: strategy/actions/ActionContext.h:244 `creators["stoneshield potion"] = UseStoneshieldPotionAction`
-- boss_17880   （actions/UseItemAction.h → UseItemAction 系；A 组 17306 的"重伤"用的是同一套动作，物品 13455 石盾药水）、
-- boss_17880   同文件:127 `healing potion` = UseHealingPotionAction、:185 `try emergency` = ImbueAction.h → TryEmergencyAction。
-- boss_17880 语义注意: ① 31464 的 TgtA1=6 TARGET_UNIT_ENEMY + 技能栏"目标=当前目标" ⇒ 它天然只落在坦克头上，
-- boss_17880   `is tank` 只是把规则写给"队伍里的坦克"，避免 BOSS 换目标时治疗/输出误触发（**若站长想覆盖"任何人中招"，删掉 is tank 即可**）。
-- boss_17880   ② 阈值 `greater or equal::4`（= 受到治疗 -40%）是我拍的保守值，**数值待定**：站长要更早/更晚改这个数字。
-- boss_17880   ③ 治疗药水在 -70% 治疗下有折扣，主要价值在石盾药水的护甲减伤。
-- boss_17880 TODO 做不到: [时光加速] 31458 的"进攻驱散 / 偷取"（攻略：可进攻驱散/偷取）
-- boss_17880   原因: 触发器**有**、但都在引擎的职业策略里常驻，不需要规则行：
-- boss_17880     mage = strategy/mage/MageTriggers.h → SpellstealTrigger（TargetAuraDispelTrigger，dispeltType=DISPEL_MAGIC，
-- boss_17880     GetTargetName()="current target"）+ MageStrategy.cpp → "spellsteal" → "spellsteal"；
-- boss_17880     shaman = ShamanTriggers.h → PurgeTrigger（同样 DISPEL_MAGIC、目标=current target）+ ShamanStrategy.cpp → "purge"。
-- boss_17880     底层判定 triggers/CureTriggers.cpp → NeedCureTrigger::IsActive() → PlayerbotAI.cpp → HasAuraToDispel()
-- boss_17880     （对敌对目标只认"非正面"光环；31458 是挂在 BOSS 身上的增益、Dispel=1 ⇒ 条件成立）。
-- boss_17880   ⇒ 本组不重复写（写了也只是重复触发同一动作）。
-- boss_17880 TODO 做不到: "与 [法术反射] 同时存在时无法偷取"这个前提
-- boss_17880   原因: 没有"目标身上有 aura"的触发器（HasAuraTrigger 只查自己）⇒ 规则行无法表达"BOSS 现在开着反射"。
-- boss_17880   缓解（引擎已有）: strategy/actions/GenericSpellActions.cpp → CastSpellAction::isUseful() 里按
-- boss_17880   `spellTarget->GetReflectChance(school) > 50 && IsReflectableSpell()` 拒绝施法；**近战平砍没有任何保护**。
-- boss_17880 TODO 做不到: 坦克"这时开减伤"（攻略：时光加速 + 法术反射 同时存在时坦克压力大）
-- boss_17880   原因: 触发时机=BOSS 身上有两个 aura，玩家侧查不到（同上）；只能靠血量档（low health 等）泛化处理，
-- boss_17880   那已属通用行为，本组不写。若站长要"凭血量硬触发减伤"，可加 `val::and::{is tank,trigger::low health} > stoneshield potion!80`。
-- boss_17880 备注: [飞翼打击] 31475/38593（15 码内击退）——攻略要"输出远程保持 15 码外"，
-- boss_17880   而本地配置 AiPlayerbot.SpellDistance = 26.0（x64_Debug/aiplayerbot.conf）⇒ 远程 bot 默认站位本来就在 15 码外，
-- boss_17880   默认行为已满足；**做不到的是"已经被 BOSS 贴近时强制退回 15 码外"**（触发器 `enemy fifteen yards` 有，
-- boss_17880   但没有后退到指定距离的动作，理由同 17879 的"吸引"TODO）⇒ 只能人工或后续加动作。
-- boss_17880 归 boss_common: 无（本 BOSS 给玩家的可查 debuff 只有坦克头上的 31464，已由规则1 处理）。
-- boss_17880 备注: 攻略"输出速战速决，在 [重伤] 叠到坦克扛不住前杀掉"= 输出节奏，没有对应动作（tank assist/dps assist 已是默认行为）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17880';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17880', 1, 0, 'val::and::{is tank,trigger::has aura::spellid::31464::greater or equal::4}>stoneshield potion!80,healing potion!70,try emergency!60');

-- ===== boss_17881  Aeonus (rank=1) =====
-- 角色分工两套并存（速查 §5）：整集只给某角色 ⇒ 集名后缀（本文件 boss_17881_melee，BossStrategyHook.h → RoleAllows()）；
-- boss_17881 技能栏 creature_spell_list 1788101（普通）/ 2073701（英雄；[0] 换成 39049，其余同）:
-- boss_17881   [0] 31473 Sand Breath 沙尘吐息   目标=自己  概率=4  15-30s / 15-25s
-- boss_17881       （Mechanic=11 SNARE、Effect1=2 伤害 3063 + Effect2=6 → aura138 MOD_MELEE_HASTE -100
-- boss_17881        + Effect3=6 → aura33 MOD_DECREASE_SPEED -50；**TgtA1/2/3=24 TARGET_ENUM_UNITS_ENEMY_IN_CONE_24
-- boss_17881        ＝正面锥形**；英雄版 39049 伤害 3937）
-- boss_17881   [1] 31422 Time Stop 时间停止      目标=自己  概率=2  10-15s / 20-35s
-- boss_17881       （**两个难度同一个 id**；Mechanic=12 STUN、Effect1=6 → aura12 SPELL_AURA_MOD_STUN、
-- boss_17881        TgtA1=22 + TgtB1=15 ⇒ 以自己为圆心的全员昏迷，攻略口径"半径 50 码停滞 4 秒"）
-- boss_17881   [2] 40504 Cleave 顺劈斩          目标=当前目标  5-9s / 7-12s
-- boss_17881       （Effect1=31 SPELL_EFFECT_WEAPON_PERCENT_DAMAGE 109 ⇒ 正面最多 3 个目标；无 aura）
-- boss_17881   [3] 37605 Frenzy 激怒[狂怒]      目标=自己  概率=8  30-45s / 20-35s
-- boss_17881       （**Dispel=9 DISPEL_ENRAGE**（可驱散！）、aura138 MOD_MELEE_HASTE 值 +50、攻略口径 8 秒）
-- boss_17881   自身 proc: boss_aeonus.cpp → Reset() 给自己上 8876 Thrash（普通）/ 19818 Double Attack（英雄）
-- boss_17881 机制: [时间停止] 是全团昏迷（4 秒）+ 攻略说的"与沙尘吐息连招" ⇒ 中招先想办法解控自救
-- boss_17881 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（只查自己）；
-- boss_17881   动作 actions/ActionContext.h:235 `creators["use trinket"] = UseTrinketAction`
-- boss_17881   （actions/UseTrinketAction.cpp → Execute() 遍历值 "trinkets on use" =
-- boss_17881    values/ItemCountValue.cpp → EquipedUsableTrinketValue::Calculate()，取两个饰品槽里
-- boss_17881    ItemSpellTrigger == ITEM_SPELLTRIGGER_ON_USE 且 spell 已冷却的第一个；isPossible() = 列表非空）。
-- boss_17881 语义注意（**拿不准，见回报**）: ① `use trinket` 不保证是"解昏迷"的 PvP 徽章，可能是输出饰品
-- boss_17881   （白交一次 CD）——站长若要严谨，可只保留 17881 规则1 但把权重要求降低，或删掉；
-- boss_17881   ② "被昏迷时动作照常执行"这件事我查实了：PlayerbotAI.cpp → DoNextAction() 传给 Engine 的
-- boss_17881   isStunned 实参是 `bot->IsTaxiFlying()`（历史误名），**不是**昏迷状态；Action::isUsefulWhenStunned()
-- boss_17881   只挡"坐飞机"。但"昏迷中能否真的使用饰品"取决于物品 spell 属性，服务器端行为**未实测**。
-- boss_17881   ③ 昏迷（aura12）只有饰品/种族技能能解：`will of the forsaken`/`every_man_for_himself` 解的是恐惧/魅惑/睡眠
-- boss_17881   （bossrules_common 规则1 已覆盖恐惧那条），`escape artist` 解的是定身/减速 ⇒ 对本条无效。数值待定。
-- boss_17881 机制: [激怒] 37605 是**可驱散的激怒**（Dispel=9）⇒ 猎人用宁神射击打掉（攻略"安抚动物/宁神射击"）
-- boss_17881 规则2 证据: 触发器 strategy/triggers/TriggerContext.h:200 `creators["dispel enrage"] =
-- boss_17881   DispelEnrageOnTargetTrigger`（GenericTriggers.h:1262 : DispelOnTargetTrigger(...,DISPEL_ENRAGE)，
-- boss_17881   GetTargetName() = "current target" = BOSS）；GenericTriggers.cpp → DispelOnTargetTrigger::IsActive()
-- boss_17881   用 `(1 << spellInfo->Dispel) & GetDispellMask(DISPEL_ENRAGE)` 判定，37605 的 Dispel=9 ✓；
-- boss_17881   动作 strategy/hunter/HunterAiObjectContext.cpp:261 `creators["tranquilizing shot"]`（CastTranquilizingShotAction）。
-- boss_17881 语义注意（**与引擎重复，站长定夺**）: HunterStrategy.cpp 本来就有完全相同的节点
-- boss_17881   （`"dispel enrage" → "tranquilizing shot"`，ACTION_INTERRUPT，三个扩展分支各一份）⇒ 本行不增加新能力，
-- boss_17881   只是把攻略这条明确写进 BOSS 集；**非猎人** bot 会每 tick 评估触发器（成立）但动作名查不到 ⇒ 静默跳过
-- boss_17881   （Engine.cpp → InitializeAction() 返回 nullptr，只记 "A:…UNKNOWN"，不执行、不崩）——若站长嫌日志噪音，删掉这一行即可。
-- boss_17881 机制: [沙尘吐息] 正面锥 + [顺劈斩] 正面最多 3 目标 ⇒ 近战绕到背后（"站后脚外侧，别在前脚附近"）
-- boss_17881_melee 规则1 证据: 集名后缀 `_melee` 由 playerbot/BossStrategyHook.h → RoleAllows() 在**挂载时**过滤
-- boss_17881_melee   （token "melee" → `ai->IsMelee(bot)`；后缀写错则整集不挂）；
-- boss_17881_melee   触发器 triggers/GenericTriggers.cpp → IsNotBehindTargetTrigger::IsActive()
-- boss_17881_melee   （`target && !AI_VALUE2(bool, "behind", "current target")`）；
-- boss_17881_melee   动作 actions/MovementActions.cpp → SetBehindTargetAction::Execute()/isUseful()/isPossible()
-- boss_17881_melee   （isUseful：`!bot->IsFacingTargetsBack(target) && bot->GetDistance(target,false) <= 15.0f`；
-- boss_17881_melee    isPossible：若当前目标的 victim 就是自己（=坦克）直接返回 false ⇒ **坦克不会被拉着绕背、不会把 BOSS 转向**）。
-- boss_17881_melee 语义注意: ① 只对**近战**生效（isUseful 要距离 ≤15 码，远程/治疗站在 26 码外不会触发）；
-- boss_17881_melee   ② 攻略说的"后脚外侧"（侧面偏后）比 `set behind` 的"正背后"更细，规则行表达不了，这是近似；
-- boss_17881_melee   ③ 权重 20 沿用内置同名节点（strategy/generic/MeleeCombatStrategy.cpp → SetBehindCombatStrategy，默认 Disabled）。数值待定。
-- boss_17881_melee 备注: "除坦克外不要站龙头"里的**远程**部分做不到 —— 没有"站到 BOSS 侧后方"的动作，
-- boss_17881_melee   而 `set behind` 对 >15 码的 bot 无效（isUseful 里那条距离判据）⇒ 远程只能靠默认站位，留人工。
-- boss_17881 TODO 做不到: [激怒] 用**安抚动物**驱散
-- boss_17881   原因: 规则行左侧只能是触发器名（`dispel enrage` 已经是"目标处于可驱散的激怒"），动作名由职业决定；
-- boss_17881   本仓库德鲁伊侧没有"安抚动物"这个动作（strategy/druid/DruidAiObjectContext.cpp 里没有对应 creators），
-- boss_17881   且 Soothe Animal 只对野兽有效（埃欧努斯是龙类）⇒ 只有猎人宁神射击这条路（见规则2）。
-- boss_17881 TODO 做不到: [痛击] 8876(普通)/19818 Double Attack(英雄) 的"额外 2 次攻击"
-- boss_17881   原因: 这两个是 boss_aeonus.cpp → Reset() 给自己上的 proc 光环（TgtA1=1 TARGET_UNIT_CASTER、
-- boss_17881   aura42 PROC_TRIGGER_SPELL）⇒ **在 BOSS 身上**，玩家侧无任何可查信息，也没有"提高坦克减伤"的动作可用。
-- boss_17881 TODO 做不到: [时间停止]+[沙尘吐息] 的连招应对（攻略：治疗随时保持坦克满血）
-- boss_17881   原因: 规则行只能触发动作，没有"提高治疗频率/预读"的动作；31473/39049 的减速与降攻速虽然挂在
-- boss_17881   玩家身上（`has aura::spellid::31473` 查得到），但**没有动作能解掉它**：
-- boss_17881     · `free action potion` = actions/UseItemAction.h → UseFreeActionPotionAction::isUseful() 要求 `target->IsPlayer()`，
-- boss_17881       PvE 里当前目标是 BOSS(Creature) ⇒ 永远为假（写上去就是死规则，本组不写）；
-- boss_17881     · `ra`（actions/RemoveAuraAction.cpp）需要"要移除的 buff 名"参数，规则行的 Trigger::Check() 不带 param
-- boss_17881       ⇒ PlayerbotAI::RemoveAura() 拿到空字符串，是死规则（bossrules_H 已实测）；
-- boss_17881     · `rooted` 触发器（GenericTriggers.h → RootedTrigger）只认 aura26 MOD_ROOT，沙尘吐息是 aura33 减速，不成立。
-- boss_17881 TODO 做不到: [顺劈斩] 40504 的"别站在前脚附近"
-- boss_17881   原因: 40504 只对正面最多 3 个目标做武器百分比伤害、**不挂 aura** ⇒ 没有"我正在吃顺劈"的信号；
-- boss_17881   只能靠 boss_17881_melee 的绕背近似缓解（坦克必须站正面，所以规则里用 isPossible() 自动排除坦克）。
-- boss_17881 TODO 做不到: 周期性小怪的"主动拦截/牵制"（攻略：小怪对麦迪文威胁大，要主动攻击并牵制）
-- boss_17881   原因（三段，都有源码依据，详见文件头【副本机制】）:
-- boss_17881     ① 钩子只按"已登记 entry"挂集: BossStrategyHook.h → EntryOfUnit()/FightTargetEntry() 要求单位 entry
-- boss_17881        出现在规则表或登记表里；波次里跑向麦迪文的小怪（17835/17892/18994/18995/21818/2113x…）**没登记**
-- boss_17881        ⇒ 非首领波次根本没有 boss_* 集在场，写在哪都管不到。
-- boss_17881     ② 首领波次里，攻击类动作也只认"已交战"目标: actions/ChooseTargetActions.h → AttackLeastHpTargetAction →
-- boss_17881        values/LeastHpTargetValue.cpp → values/TargetValue.cpp → TargetValue::FindTarget() 只遍历 "attackers"；
-- boss_17881        values/AttackersValue.cpp → AttackersValue::InCombat() = 该单位对我/我队友的仇恨 >0、或它的 victim 是我/我队友/pet。
-- boss_17881        而小怪的 victim 是麦迪文（友方 NPC、不在队伍里）⇒ 没被打过之前**进不了 attackers**，规则行选不中它。
-- boss_17881        （它身上 31326 Corrupt Medivh 的光环是护盾流失源，creature_ai_scripts 1783502 等:
-- boss_17881         EVENT_T_AGGRO → ACTION_T_REMOVE_AURA(31326) ⇒ **只要有人打出仇恨，护盾流失就停**。）
-- boss_17881     ③ 没有"按 entry 锁定某只怪"的攻击动作，也没有"去保护麦迪文/站到某点"的动作；
-- boss_17881        能按 entry 找怪的 `specific creature too close` 读的是预置 avoid creature list（规则行改不了）。
-- boss_17881   变通（都**没**写进规则行，交站长定夺）:
-- boss_17881     · 人工给目标打团队标记 → bot 的 "rti target" 优先级最高（同 bossrules_H 里 17798/17976 的口径）；
-- boss_17881     · 动作 `attack anything`（ChooseTargetActions.h → AttackAnythingAction::GetTargetName()="grind target"，
-- boss_17881       values/GrindTargetValue.cpp 确实会遍历 "possible targets" 且 `AttackersValue::IsValid(...,checkInCombat=false,...)`
-- boss_17881       ⇒ 理论上能咬没交战的怪）；但 AttackAnythingAction::isUseful() 里"非坦克 + 队里有坦克/真人 ⇒ 不许自己开怪"，
-- boss_17881       所以只有**坦克**能用；而 GrindTargetValue::FindTargetForGrinding() 对"非任务需求、也不给经验"的怪
-- boss_17881       有 `urand(0,50)` 的丢弃（≈2% 命中），在 70 级副本里基本是噪声，还会把坦克从 BOSS 身上拉走 ⇒ 我没写。
-- boss_17881 归 boss_common: [时间停止] 之外的昏迷/减速通用处理（恐惧自解、定身除根等）走 boss_common 与各职业策略，本组不重复。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17881';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17881', 1, 0, 'has aura::spellid::31422>use trinket!95'),
('boss_17881', 2, 0, 'dispel enrage>tranquilizing shot!40');

-- ===== boss_17881_melee  Aeonus (rank=1) =====
-- 角色分工两套并存（速查 §5）：整集只给某角色 ⇒ 集名后缀（本文件 boss_17881_melee，BossStrategyHook.h → RoleAllows()）；
-- boss_17881_melee 规则1 证据: 集名后缀 `_melee` 由 playerbot/BossStrategyHook.h → RoleAllows() 在**挂载时**过滤
-- boss_17881_melee   （token "melee" → `ai->IsMelee(bot)`；后缀写错则整集不挂）；
-- boss_17881_melee   触发器 triggers/GenericTriggers.cpp → IsNotBehindTargetTrigger::IsActive()
-- boss_17881_melee   （`target && !AI_VALUE2(bool, "behind", "current target")`）；
-- boss_17881_melee   动作 actions/MovementActions.cpp → SetBehindTargetAction::Execute()/isUseful()/isPossible()
-- boss_17881_melee   （isUseful：`!bot->IsFacingTargetsBack(target) && bot->GetDistance(target,false) <= 15.0f`；
-- boss_17881_melee    isPossible：若当前目标的 victim 就是自己（=坦克）直接返回 false ⇒ **坦克不会被拉着绕背、不会把 BOSS 转向**）。
-- boss_17881_melee 语义注意: ① 只对**近战**生效（isUseful 要距离 ≤15 码，远程/治疗站在 26 码外不会触发）；
-- boss_17881_melee   ② 攻略说的"后脚外侧"（侧面偏后）比 `set behind` 的"正背后"更细，规则行表达不了，这是近似；
-- boss_17881_melee   ③ 权重 20 沿用内置同名节点（strategy/generic/MeleeCombatStrategy.cpp → SetBehindCombatStrategy，默认 Disabled）。数值待定。
-- boss_17881_melee 备注: "除坦克外不要站龙头"里的**远程**部分做不到 —— 没有"站到 BOSS 侧后方"的动作，
-- boss_17881_melee   而 `set behind` 对 >15 码的 bot 无效（isUseful 里那条距离判据）⇒ 远程只能靠默认站位，留人工。
-- boss_17881   只能靠 boss_17881_melee 的绕背近似缓解（坦克必须站正面，所以规则里用 isPossible() 自动排除坦克）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17881_melee';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17881_melee', 1, 0, 'not behind target>set behind!20');

-- ===== boss_17882_tank  The Black Stalker (rank=1) =====
-- boss_17882_tank 机制: 只给 **坦克**（角色后缀 _tank）—— 被顶进 BOSS 模型里就退出来
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17882_tank';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17882_tank', 1, 0, 'enemy too close for melee>move out of enemy contact!80');

-- ===== boss_17941_dps  Mennu the Betrayer (rank=1) =====
-- boss_17941_dps 机制: 转火只让 **DPS**（角色后缀 _dps；坦克/治疗不挂这个集）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17941_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17941_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_17975_dps  High Botanist Freywinn (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 ⇒ 集名后缀（boss_17796_melee / boss_17975_dps）；
-- boss_17975_dps 机制: 优先击杀树苗（白>其它）与魔花保护者 19953 —— 集名后缀 _dps = 只给 DPS 挂
-- boss_17975_dps 规则1 证据: triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()
-- boss_17975_dps 规则1 语义注意（拿不准，见回报）: ① 树苗/保护者是**脚本召唤**且只调用了
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17975_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17975_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_17977  Warp Splinter (rank=1) =====
-- boss_17977 脚本: …/botanica/boss_warp_splinter.cpp → boss_warp_splinterAI（HP 191408）
-- boss_17977 技能（creature_spell_list 1797701；英雄 2158201 把 36705 换成 39133）:
-- boss_17977 树苗行为（实测脚本）: JustSummoned() 里 SetInCombatWithZone() + AttackClosestEnemy()
-- boss_17977 机制: 树苗碰到 BOSS 会给它回血（34742/SPELL_ANCESTRAL_LIFE），所以 8 码内出现树苗
-- boss_17977 规则1 证据: values/BossRuleValues.h → TriggerAsValue::Calculate()（触发器当布尔值）+
-- boss_17977 TODO 做不到: 非近战远离 25 码躲践踏 34716
-- boss_17977 TODO 做不到: 奥术箭雨 36705 的"绕场散开 / 与治疗抱团"
-- boss_17977 TODO 做不到: "多用缓速技能牵制树苗"
-- boss_17977 TODO 归 boss_common: 治疗保持全满应对奥术箭雨高额伤害 —— 属治疗档位配置/人工。
-- 怨灵在 JustSummoned() 里被显式 AttackClosestEnemy() ⇒ 在列表里（与 bossrules_H.tsv boss_17977
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17977';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17977', 1, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20');

-- ===== boss_17978  Thorngrin the Tender (rank=1) =====
-- boss_17978 脚本: …/botanica/boss_thorngrin_the_tender.cpp → boss_thorngrinAI
-- boss_17978 技能（creature_spell_list 1797801；英雄 2158101 把地狱烈焰换成 39131）:
-- boss_17978 机制: 被牺牲 34661 的玩家被传送 + 昏迷 + 每秒吸血，8 秒里最容易被地狱烈焰烧死
-- boss_17978 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（只查自己）+
-- boss_17978 规则1 拿不准（见回报）: ① 与 boss_17797 规则2 同：`use trinket` 取的是身上第一个
-- boss_17978 TODO 做不到: 全程躲地狱烈焰 34659（尤其近战）
-- boss_17978 TODO 做不到: 激怒 34670 的驱散
-- boss_17978 TODO 做不到: 坦克把 BOSS 带离原平台（保护被牺牲的玩家）
-- boss_17978 备注: 攻略"治疗重点关注被牺牲的玩家"= 治疗目标优先级，属职业治疗策略/人工。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17978';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17978', 1, 0, 'has aura::spellid::34661>use trinket!95');

-- ===== boss_17980  Laj (rank=1) =====
-- boss_17980 脚本: …/botanica/boss_laj.cpp → boss_lajAI（HP 121770）
-- boss_17980 技能（creature_spell_list 1798001）:
-- boss_17980 机制: 中过敏反应 34697 的人（疾病，会通过 PROC_TRIGGER_SPELL 传染给最近的盟友）
-- boss_17980 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（只查自己）；
-- boss_17980 规则1 近似点: Flee 以"当前目标"（=BOSS）为基点跑；带真人 master 的 bot 会先
-- boss_17980 备注: 疾病的自驱散引擎已覆盖（priest/shaman/paladin 的 NeedCureTrigger 家族 +
-- boss_17980 机制: 起源 34673 传送走后召唤两只荆棘，必须优先清掉（脚本 JustSummoned() 里
-- boss_17980 规则2 证据: values/BossRuleValues.h → TriggerAsValue::Calculate() + ValueContext.h →
-- boss_17980 规则2 语义: 荆棘（19919/19920，4890 血）比 BOSS 121770 血少很多，引擎默认的
-- boss_17980 TODO 做不到: 过敏反应的"驱散掉"（尤其对队友）
-- boss_17980 TODO 做不到: 元素转换 34703-34710 的"换抗性"应对
-- boss_17980 备注: "全程分散"没有"与队友距离"的触发器（`party member low health` 之类是状态，
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17980';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17980', 1, 0, 'has aura::spellid::34697>flee!85'),
('boss_17980', 2, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!20');

-- ===== boss_17991_healer  Rokmar the Crackler (rank=1) =====
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_17991_healer';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_17991_healer', 1, 0, 'low health>try emergency!80,healing potion!70');

-- ===== boss_18096_dps  Epoch Hunter (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_17862_dps / boss_18096_dps）；
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18096_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18096_dps', 1, 0, 'not behind target>set behind!20');

-- ===== boss_18105_dps_melee  Ghaz'an (rank=1) =====
-- boss_18105_dps_melee 机制: 只给 **近战 DPS**（角色后缀 _dps_melee；坦克/治疗/远程都不挂）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18105_dps_melee';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18105_dps_melee', 1, 0, 'not behind target>set behind!20');

-- ===== boss_18170  Infinite Slayer (rank=1) =====
-- boss_18170 机制: 他的致死打击 16856（普通）/ 15708（英雄）是 aura118 MOD_HEALING_PCT -51 ⇒ 坦克血线危险时嗑药（同 17848 规则1）
-- boss_18170 机制: 污染者的腐蚀术 21068（魔法 DOT）落在我方身上时自己解（钩子按 entry 挂集，三个手下都可能是当前目标 ⇒ 各留一份）
-- boss_18170 TODO 做不到: 打断暗影箭 15232/38386（攻略: 打断暗影箭）
-- 规则1 证据: 同 boss_18170 规则4（21068 Dispel=1 DISPEL_MAGIC、aura3 PERIODIC_DAMAGE）。数值待定
-- boss_18171 TODO 做不到: 打断暗影箭 15232/38386 —— 同 boss_18170 的说明。
-- 规则1 证据: 同 boss_18170 规则4（self-target 自解魔法）。数值待定
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18170';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18170', 1, 0, 'val::and::{is tank,trigger::has aura::spellid::16856,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),
('boss_18170', 2, 0, 'val::and::{is tank,trigger::has aura::spellid::15708,trigger::low health}>healing potion!70,stoneshield potion!60,try emergency!50'),
('boss_18170', 3, 0, 'has aura::spellid::21068>dispel magic!55,cleanse magic!50');

-- ===== boss_18170_dps  Infinite Slayer (rank=1) =====
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18170_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18170_dps', 1, 0, 'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20');

-- ===== boss_18171  Infinite Defiler (rank=1) =====
-- boss_18171 机制: 腐蚀术 21068（魔法 DOT）自己解
-- boss_18171 机制: 永恒之敌 Curse of Infinity 31977（aura118 MOD_HEALING_PCT -51 + aura87 MOD_DAMAGE_PERCENT_TAKEN +49，约1分钟）是自己中的诅咒
-- boss_18171 TODO 做不到: 打断暗影箭 15232/38386 —— 同 boss_18170 的说明。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18171';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18171', 1, 0, 'has aura::spellid::21068>dispel magic!55,cleanse magic!50'),
('boss_18171', 2, 0, 'has aura::spellid::31977>remove curse!55');

-- ===== boss_18172  Infinite Saboteur (rank=1) =====
-- boss_18172 机制: 腐蚀术/其他魔法 DOT 的处理 —— 钩子按 entry 挂集，破坏者是当前目标时这套规则才在（所以这里也留一份）
-- boss_18172 TODO 做不到: 进攻驱散暗影之盾 31976（攻略: 进攻驱散暗影之盾）
-- boss_18172 备注: 顺劈斩 15496 是正面顺劈（范围小、0-5 码），"非坦克别站正面"已由 bossrules_common.tsv 规则3 兜住。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18172';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18172', 1, 0, 'has aura::spellid::21068>dispel magic!55,cleanse magic!50');

-- ===== boss_18343_dps  Tavarok (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_18343_dps / boss_22930_dps）；
-- boss_18343_dps 机制: 正面锥规避只让 **DPS**（集名后缀 `_dps`；坦克会被 SetBehindTargetAction::isPossible() 排除）
-- boss_22930 规则1 证据: 与 boss_18343_dps 规则1 同（IsNotBehindTargetTrigger + SetBehindTargetAction
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18343_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18343_dps', 1, 0, 'not behind target>set behind!20');

-- ===== boss_18344  Nexus-Prince Shaffar (rank=1) =====
-- boss_18344 机制: 全程优先击杀[虚灵航标 18431]（否则很快变成学徒；起手自带三个）
-- boss_18344 规则1: DPS 恒定按"交战目标里血量最低的"打（航标 3548 血 / 学徒 7097 血 << 沙法尔 88056）
-- boss_18344 规则1 证据: 触发器 triggers/GenericTriggers.h → HasAttackersTrigger（继承 AttackerCountTrigger，
-- boss_18344 机制: 斩杀阶段"可停止清理，专心 Rush"（攻略口径）
-- boss_18344 规则2: 当前目标血量低（<20%，TargetCriticalHealthTrigger）时，DPS 用 attack 钉住当前目标、不被规则1拉走
-- boss_18344 规则2 证据: 触发器 triggers/HealthTriggers.cpp → HealthInRangeTrigger（ValueInRangeTrigger 严格小于，
-- boss_18344 机制: [冰霜新星] 32365（10 码定身 5 秒、Dispel=MAGIC）—— 攻略"记得驱散坦克与近战的冰霜新星（否则追不上怪）"
-- boss_18344 规则3: 自己中了冰霜新星就自驱（牧师/圣骑士），把自己从定身里解放出来
-- boss_18344 规则3 证据: 触发器/动作同 boss_18473 规则1（HasAuraTrigger 只查自己 + CastDispelMagicAction /
-- boss_18344 说明: [打断学徒] 32369 火球 / 32370 寒冰箭（InterruptFlags=15）—— **引擎已有**：
-- boss_18344 TODO 做不到: [火球术 32363 / 寒冰箭 32364] 的单体伤害与减速 / 原因: 单体点名 + 魔法减速，
-- boss_18344 TODO 做不到: [闪现术 34605] / 原因: 玩家身上没有可查光环（spell 34605 的效果都作用在施法者自己），
-- boss_18344 说明: 英雄版 20266（HeroicEntry=20266）无独立刷新点；脚本 m_isRegularMode=false 只改计时
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18344';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18344', 1, 0, 'val::and::{trigger::has attackers,is dps}>attack least hp target!70'),
('boss_18344', 2, 0, 'val::and::{trigger::target critical health,is dps}>attack!75'),
('boss_18344', 3, 0, 'has aura::spellid::32365>dispel magic!55,cleanse magic!50');

-- ===== boss_18371_dps_melee  Shirrak the Dead Watcher (rank=1) =====
-- boss_18371_dps_melee 机制: 血肉撕咬叠 4 层退开 —— 只让 **近战 DPS**（后缀 `_dps_melee`；
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18371_dps_melee';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18371_dps_melee', 1, 0, 'has aura::spellid::36383::greater or equal::4>flee!68');

-- ===== boss_18373  Exarch Maladaar (rank=1) =====
-- boss_18373 大主教玛拉达尔 Exarch Maladaar
-- boss_18373 机制→规则对照: [被偷走的灵魂 32346 → 32360 召唤 NPC 18441] 击倒+3000暗影、伤害/治疗-50%，灵魂攻击被撕者，灵魂死时 mob_stolen_soulAI::JustDied() 用 33326 解除 → 规则1（有 add 就转火最低血量目标）
-- boss_18373 机制→规则对照: [召唤化身 32424 → NPC_AVATAR_MARTYRED 18478(致死打击/破甲)] BOSS 血量<25% 时召唤（boss_exarch_maladaarAI::ExecuteAction(): GetHealthPercent() < 25.0f）→ 规则2（末阶段继续按死大主教，不主动追化身）
-- boss_18373 机制→规则对照: [灵魂尖啸 32421] 10码内迷惑2秒（boss_ability_scan：机制=MECHANIC_FEAR 但光环=SPELL_AURA_MOD_CONFUSE）→ 做不到（见下 TODO）
-- boss_18373 机制→规则对照: [灵魂缎带 32422] 对当前目标(坦克)暗影伤害 → 没有可执行的动作
-- boss_18373 规则1 证据: .../auchenai_crypts/boss_exarch_maladaar.cpp → SPELL_STOLEN_SOUL = 32346 / SPELL_STOLEN_SOUL_SUMMON = 32360 / NPC_STOLEN_SOUL = 18441 / SPELL_STOLEN_SOUL_DISPEL = 33326；creature_spell_list 1837301 → 32346（TargetId=101，随机非坦克）
-- boss_18373 规则1 触发器/动作: strategy/triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()（"nearest adds" 非空；strategy/values/NearestAdsValue.cpp → NearestAddsValue::AcceptUnit() 排除当前目标、范围=fleeDistance）；strategy/actions/ChooseTargetActions.h → AttackLeastHpTargetAction（目标名 "least hp target"；strategy/values/TargetValue.cpp → TargetValue::FindTarget() 在 "attackers" 里挑最低血量，LeastHpTargetValue.h → FindLeastHpTargetStrategy::CheckAttacker()）
-- boss_18373 规则1 注意: 默认输出策略其实做同一件事（strategy/generic/DpsAssistStrategy.cpp: not dps target active > dps assist!60，strategy/values/DpsTargetValue.cpp 无标记时=最低血量攻击者），这条只是把"灵魂优先"显式提到 62；化身也算 add 会被这条覆盖 → 靠规则2 在 20% 以下压制。权重 62：数值待定
-- boss_18373 机制: 被偷走的灵魂转火 + 末段按死 boss —— 只让 **DPS**（规则内 val::and::{…,is dps}）
-- boss_18373 规则2 证据: 化身在 25% 出，但可用的血量档触发器只有 strategy/triggers/HealthTriggers.h → TargetCriticalHealthTrigger（= 当前目标血量 <20；HealthTriggers.cpp → HealthInRangeTrigger::GetValue() 取血量百分比，ValueInRangeTrigger::IsActive() 是严格小于）→ 20%~25% 这段压不到；站长若要更早，需要新触发器（"BOSS 血量档"）
-- boss_18373 规则2 触发器/动作: TargetCriticalHealthTrigger（同上）；动作 attack = strategy/actions/GenericActions.h → MeleeAction（GetTargetName()="current target"，注册名 ActionContext.h → creators["attack"]）→ 语义是"继续打当前目标"、不主动换目标；治疗动作权重 70+ 高于 65，不会抢治疗
-- boss_18373 规则2 注意: 对全职业生效（含坦克、含治疗职业的空闲输出），没有"只让 DPS 执行"的角色条件。权重 65：数值待定（高于规则1的 62，低于 ACTION_MEDIUM_HEAL=70）
-- boss_18373 TODO 做不到: 灵魂尖啸(32421)的迷惑自保 / 原因: 现有控制类触发器只有 feared(SPELL_AURA_MOD_FEAR)（GenericTriggers.h → FearedTrigger::IsActive()）、stunned(SPELL_AURA_MOD_STUN)、charmed(SPELL_AURA_MOD_CHARM)（CharmedTrigger::IsActive()），本技能是 SPELL_AURA_MOD_CONFUSE，查不到；唯一提到 MOD_CONFUSE 的 WOtFTrigger::IsActive() 那行在 return 之后是死代码，等于没有
-- boss_18373 TODO 做不到: 坦克在化身(18478)出现时"立刻嘲讽" / 原因: taunt 是战士职业专属动作（warrior/WarriorAiObjectContext.cpp → CastTauntAction），规则行没有"只让坦克执行"的角色条件 → 写下去 DPS 战士也会嘲讽抢仇恨
-- boss_18373 TODO 做不到: 灵魂缎带(32422)对坦克的伤害规避 / 原因: 对当前目标的单体伤害，没有可执行动作（换坦/开技能属职业与坦克策略）
-- （GetTargetName()="current target"，语义是"继续打当前目标"、不主动换目标）。与 C 组 boss_18373 规则2 同款写法。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18373';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18373', 1, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!62'),
('boss_18373', 2, 0, 'val::and::{trigger::target critical health,is dps}>attack!65');

-- ===== boss_18472  Darkweaver Syth (rank=1) =====
-- 集里只有某几条限角色 → val::and::{trigger::…,is dps}（本文件 boss_18472/18344/22930）。
-- boss_18472 机制: 烈焰/冰霜/奥术/暗影震击（普通版 4 个 id，Dispel=DISPEL_MAGIC，DoT/减速）
-- boss_18472 规则1: 自己中了就自己驱散（牧师 dispel magic / 圣骑士 cleanse magic，其它职业没有这两个动作，
-- boss_18472 机制: 同上，英雄难度用的 4 个 id（15616 烈焰 / 21401 冰霜 / 38135 奥术 / 38136 暗影）
-- boss_18472 规则2: 英雄难度的震击同样自驱（英雄难度下跑的还是普通 entry 18472 的这套规则）
-- boss_18472 规则1/2 证据: 触发器 strategy/triggers/TriggerContext.h → creators["val"]=ValueTrigger，
-- boss_18472 机制: 元素 buffet（普通版 33526/33527/33528/33529）会叠层（StackAmount=5、每层受伤 +20）
-- boss_18472 规则3: 自己身上的 buffet 叠到 3 层以上就自驱（数值待定：阈值取 3/5 由站长定）
-- boss_18472 机制: 英雄版 buffet（38141/38138/38142/38143）StackAmount=20、每层受伤 +20 —— 攻略说的"可叠 20 层"就是它
-- boss_18472 规则4: 英雄难度 buffet 叠到 3 层以上就自驱（数值待定：20 层上限、阈值 3 偏保守）
-- boss_18472 规则3/4 证据: has aura 的"层数"写法来自 GenericTriggers.cpp → HasAuraTrigger::IsActive() 的正则
-- boss_18472 机制: 三波召唤元素（90%/55%/15% 各 4 只，会一路给全员叠受伤 debuff）——攻略要求第一时间击杀
-- boss_18472 规则5: 身边有 add（=召唤元素）时，DPS 改为打"交战目标里血量最低的"（元素 2705 血 << BOSS 85194）
-- boss_18472 规则5 证据: 触发器 triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()
-- boss_18472 TODO 做不到: "把本体血压太快会让小怪连着出 ⇒ 适当停手" / 原因: 三波召唤由 BOSS 血量档驱动
-- boss_18472 TODO 做不到: 第三波"可以选择不打" / 原因: 同上——没有"知道现在第几波"的触发器，
-- boss_18472 TODO 做不到: 坦克"让塞斯背对人群"（躲闪电链） / 原因: 规则行没有控制 BOSS 朝向/位置的动作
-- boss_18472 TODO 做不到: 治疗"每轮召唤前抬满团血" / 原因: 需要"召唤即将发生"的预判触发器（血量档或事件），
-- boss_18472 说明: 元素被击杀后没有"重新召唤"；BOSS 死亡 / JustReachedHome() 会 RemoveGuardians() 清掉残留元素。
-- 动作同 boss_18472 规则1（PriestAiObjectContext.cpp → creators["dispel magic"]=CastDispelMagicAction、
-- 动作: 同 boss_18472 规则5（AttackLeastHpTargetAction → values/LeastHpTargetValue.h → 取 attackers 里血最少）。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18472';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18472', 1, 0, 'val::or::{trigger::has aura::spellid::15039,trigger::has aura::spellid::12548,trigger::has aura::spellid::33534,trigger::has aura::spellid::33620}>dispel magic!55,cleanse magic!50'),
('boss_18472', 2, 0, 'val::or::{trigger::has aura::spellid::15616,trigger::has aura::spellid::21401,trigger::has aura::spellid::38135,trigger::has aura::spellid::38136}>dispel magic!55,cleanse magic!50'),
('boss_18472', 3, 0, 'val::or::{trigger::has aura::spellid::33526::greater or equal::3,trigger::has aura::spellid::33527::greater or equal::3,trigger::has aura::spellid::33528::greater or equal::3,trigger::has aura::spellid::33529::greater or equal::3}>dispel magic!60,cleanse magic!55'),
('boss_18472', 4, 0, 'val::or::{trigger::has aura::spellid::38141::greater or equal::3,trigger::has aura::spellid::38138::greater or equal::3,trigger::has aura::spellid::38142::greater or equal::3,trigger::has aura::spellid::38143::greater or equal::3}>dispel magic!60,cleanse magic!55'),
('boss_18472', 5, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!80');

-- ===== boss_18473  Talon King Ikiss (rank=1) =====
-- boss_18473 机制: [减速术] 35032 —— 英雄难度专有（脚本 `if (!m_isRegularMode)`），AoE 减速、Dispel=MAGIC
-- boss_18473 规则1: 自己中了减速就自驱（牧师/圣骑士），好让近战追得上、来得及躲魔爆术
-- boss_18473 机制: [变形术] 38245（普通）/43309（英雄）—— 随机一名非坦克玩家变羊 6 秒、Dispel=MAGIC
-- boss_18473 规则2: 自己中了变形就自驱（普通/英雄两个 id 一起写）
-- boss_18473 规则1/2 证据: 触发器 GenericTriggers.cpp → HasAuraTrigger::IsActive()（spellid::<id>，只查自己）；
-- boss_18473 拿不准: 被变形的 bot 还能不能自己施法 —— Entities/Unit.cpp → Unit::SetConfused() 只做
-- boss_18473 说明: [魔爆术] 38197/40425 "躲到柱子后面" ⇒ 做不到：① 没有通用的"BOSS 正在施放某法术"触发器
-- boss_18473 说明: [奥术箭雨] 35059/40424（100 码、纯伤害、不留光环）⇒ 无处可躲、没有可触发条件 ⇒ 不写规则。
-- boss_18473 TODO 做不到: [法力护盾] 38151（<15% 血、BOSS 自身 aura、Dispel=MAGIC、吸收 9999）
-- boss_18473 说明: 每次魔爆术后 DoResetThreat()（坦克重新建仇 / 输出别立刻暴打）引擎已有，不需要规则：
-- boss_18344 规则3 证据: 触发器/动作同 boss_18473 规则1（HasAuraTrigger 只查自己 + CastDispelMagicAction /
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18473';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18473', 1, 0, 'has aura::spellid::35032>dispel magic!55,cleanse magic!50'),
('boss_18473', 2, 0, 'val::or::{trigger::has aura::spellid::38245,trigger::has aura::spellid::43309}>dispel magic!55,cleanse magic!50');

-- ===== boss_18667  Blackheart the Inciter (rank=1) =====
-- boss_18667 机制: 防击退[重要] 战争践踏33707 会对 20 码内所有敌人上击退；坦克被击退后拉开 →
-- boss_18667 机制: 施法职业别站在战争践踏 33707 的 20 码圈里（治疗/远程常因追目标走进近战范围）。
-- boss_18667 机制: 贴脸拉开只让 **远程**（规则内 val::and::{…,is ranged}；近战 DPS 本来就该贴）
-- boss_18667 TODO 做不到: 煽动混乱 33676/33684（15秒自相残杀）
-- boss_18667 TODO 做不到: 冲锋 33709 的昏迷2秒
-- boss_18667 TODO 做不到: "战争践踏削坦克威胁值" 的应对（脚本 OnSpellCast() 里 SPELL_CHARGE 之后 DoResetThreat()）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18667';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18667', 1, 0, 'enemy too close for melee>move out of enemy contact!90'),
('boss_18667', 2, 0, 'val::and::{trigger::enemy too close for melee,is ranged}>flee!60');

-- ===== boss_18732  Grandmaster Vorpil (rank=1) =====
-- boss_18732 机制: 虚空旅者(19226)必须第一时间转火（它靠近 boss 3 码就 Shadow Nova 33846 + 治疗 boss 33783）
-- boss_18732 机制: 虚空旅者(19226)转火只让 **DPS**（规则内 val::and::{…,is dps}）
-- boss_18732 机制: 被打散/被拉走时（暗影牵制后）保持远程施法距离，别贴着 boss 吃 32963 暗影箭雨
-- boss_18732 机制: 贴脸拉开只让 **远程**（规则内 val::and::{…,is ranged}；近战 DPS 本来就该贴）
-- boss_18732 TODO 做不到: 放逐术 38791 的驱散（尤其坦克被放逐）
-- boss_18732 TODO 做不到: 暗影牵制 33563 + 火焰之雨 33617 的"迅速远离"
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_18732';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_18732', 1, 0, 'val::and::{trigger::has nearest adds,is dps}>attack least hp target!90'),
('boss_18732', 2, 0, 'val::and::{trigger::enemy too close for melee,is ranged}>flee!50');

-- ===== boss_19218  Gatewatcher Gyro-Kill (rank=1) =====
-- boss_19218 脚本: **EventAI**（creature_template.AIName=EventAI，ScriptName 空、SpellList 空；
-- boss_19218   脚本全在 creature_ai_scripts 1921801-1921808，只有喊话 + 4 个定时施法；HP 92250，
-- boss_19218   英雄模板 21525 HP 124538）
-- boss_19218 技能（creature_ai_scripts，EVENT_T_TIMER_IN_COMBAT）:
-- boss_19218   1921804/1921805 (13700-48200ms) 35318 Saw Blade 锯齿利刃(普通) / 39192(英雄)，
-- boss_19218     ACTION_T_CAST(...,1,0) = 打当前目标；
-- boss_19218     spell_template: Effect1=2 直接物理 1758(英雄 3515) + Effect2=6/Aura2=3
-- boss_19218     SPELL_AURA_PERIODIC_DAMAGE 523(英雄 1045)、EffectImplicitTargetA1=6
-- boss_19218     TARGET_UNIT_TARGET_ENEMY、DurationIndex=31
-- boss_19218   1921806/1921807 (24100-48200ms) 35322 Shadow Power 暗影能量(普通) / 39193(英雄)，
-- boss_19218     ACTION_T_CAST(...,0,0) = **打自己**；
-- boss_19218     spell_template: EffectImplicitTargetA1=1 施法者自身、Dispel=1 DISPEL_MAGIC、
-- boss_19218     Aura1=138 MOD_MELEE_HASTE +100、Aura2=61 MOD_SCALE +19、DurationIndex=8、
-- boss_19218     CastingTimeIndex=5（非瞬发）、InterruptFlags=9、AttributesEx=0
-- boss_19218   1921808 (10800-40800ms) 35311 Stream of Machine Fluid 流动机蒸汽，
-- boss_19218     ACTION_T_CAST(...,1,0)；
-- boss_19218     spell_template: Dispel=4 DISPEL_POISON、EffectImplicitTargetA1=24 正面锥、
-- boss_19218     Aura1=193 MOD_ATTACK_POWER_PCT -37、Aura2=101 MOD_TARGET_RESISTANCE -37、DurationIndex=1
-- boss_19218 机制: 锯齿利刃 35318/39192 会在被打的人身上留一个持续伤害 debuff（每 2 秒跳一次）
-- boss_19218 规则1 证据（触发器）: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()
-- boss_19218 规则1 证据（动作）: actions/UseItemAction.h → UsePotionAction::isUseful()
-- boss_19218 数值待定: 权重 60；是否加 `try emergency!50`
-- boss_19218 TODO 做不到: Shadow Power 35322/39193 的"打断或进攻驱散"
-- boss_19218   原因（规则行侧）: 35322/39193 是挂在 **Boss 自己**身上的魔法光环
-- boss_19218     （EffectImplicitTargetA1=1 施法者自身），而引擎没有"目标/BOSS 身上有 aura"的触发器
-- boss_19218     （HasAuraTrigger 只查自己）；也没有"打断指定怪"的动作
-- boss_19218     （InterruptSpellTrigger 的 GetTargetName() = "current target"，规则行无法指名法术）。
-- boss_19218   **引擎已覆盖（留人工确认即可，不用写规则）**: 该法术 CastingTimeIndex=5（非瞬发）、
-- boss_19218     InterruptFlags=9、AttributesEx=0 ⇒ 可打断；Boss 就是 bot 的 current target，
-- boss_19218     各职业内置打断（counterspell/kick/pummel/wind shear…）会自动打断；
-- boss_19218     另外 Dispel=1(DISPEL_MAGIC) ⇒ 法师内置 `spellsteal`
-- boss_19218     （mage/MageTriggers.h → SpellstealTrigger : TargetAuraDispelTrigger(ai,"spellsteal",DISPEL_MAGIC)，
-- boss_19218     目标 = current target）会自动偷走它，正好等于攻略的"进攻驱散或偷取"。
-- boss_19218 TODO 做不到: "分散站位（8 码）" / "坦克背对人群、靠墙坦住" / "近战别站正面"
-- boss_19218   原因: ① DB 里 35318/39192 **没有**范围目标（无 EffectImplicitTargetB、无链式、
-- boss_19218     无 DynamicObject）⇒ 攻略说的"对一名玩家及其周围约 8 码"在本 core 不成立，
-- boss_19218     没有可查的"我周围有人被齿轮打了"信号；② 没有任何"控制 BOSS 朝向/位置"或
-- boss_19218     "拉开队友间距"的触发器/动作（站位与转向由核心与职业策略决定）⇒ 只能人工。
-- boss_19218 归 boss_common / 引擎已覆盖: 流动机蒸汽 35311（Dispel=4 中毒）
-- boss_19218   —— 引擎反应引擎常驻 `potions` 策略（AiFactory.cpp:1327 →
-- boss_19218   reactionEngine->addStrategies("react","chat","avoid aoe","avoid specific creatures","potions","dungeon")），
-- boss_19218   它自带 "has poison debuff"（triggers/GenericTriggers.h:1268 → HasPoisonDebuffTrigger → ai->HasAuraToDispel(bot, DISPEL_POISON)）
-- boss_19218   → "anti-venom"（strategy/generic/UsePotionsStrategy.cpp:50-52）⇒ 规则行不重复
-- boss_19218 备注: 攻略说"驱散[流动机蒸汽]"、"[暗影能量]打断或进攻驱散"两条都能落地，
-- boss_19218   但都不是靠规则行（前者靠引擎 potions，后者靠职业打断/法师偷取），已在上面写清。
-- boss_19710 TODO 做不到: Shadow Power 35322/39193 —— 同 boss_19218 的那条（引擎职业打断 + 法师 spellsteal 已覆盖）
-- boss_19710 归 boss_common / 引擎已覆盖: 流动机蒸汽 35311（中毒）—— 同 boss_19218 的说明（引擎 potions 策略）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_19218';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_19218', 1, 0, 'val::or::{trigger::has aura::spellid::35318,trigger::has aura::spellid::39192}>healing potion!60'),
('boss_19218', 2, 0, 'has aura::spellid::35311>cure poison!85,anti-venom!80');

-- ===== boss_19219  Mechano-Lord Capacitus (rank=1) =====
-- 集里只有某几条限角色 ⇒ val::and::{…,is tank}（本文件 boss_19219 规则1）。
-- boss_19219 脚本: ScriptDevAI/.../the_mechanar/boss_mechano_lord_capacitus.cpp →
-- boss_19219   boss_mechano_lord_capacitusAI（CombatAI）+ NetherChargeAI（虚灵充能 35153/35904/35905/35906 召唤物）
-- boss_19219   + 三个 SpellScript: NetherChargePassive / NetherChargeTimer / PolarityShiftCapacitus
-- boss_19219   （HP 121770，英雄模板 21533 HP 258300）
-- boss_19219 技能栏 creature_spell_list:
-- boss_19219   1921901（**普通**）: [0] 35161 Head Crack 裂颅 TargetId=1 当前目标 16.1-18.6s 起、19.5-33.5s 重复
-- boss_19219     （spell_template: EffectImplicitTargetA1=6 目标、Aura1=29 MOD_STAT -201、DurationIndex=8）
-- boss_19219     [1] 26662 Berserk 180s 起、每 300s
-- boss_19219     [2] 35159 Reflective Damage Shield 15s 起**只放一次**（Aura1=15 DAMAGE_SHIELD +749、TargetA1=1 自身）
-- boss_19219     [3] 35158 Reflective Magic Shield 35s 起**只放一次**（Aura1=28 REFLECT_SPELLS 100%、TargetA1=1 自身）
-- boss_19219   2153301（**英雄**）: [0] 35161、[1] 26662、[2] **39096 Polarity Shift 极性转换** 30s 起、27-34s 重复
-- boss_19219   **注意**: 普通难度技能栏里**根本没有 Polarity Shift**，英雄才有；反过来英雄没有那两面反射盾
-- boss_19219     （实测 creature_spell_list 逐行导出，不是扫描工具的省略）——攻略与 DB 不一致，请站长核对。
-- boss_19219 极性链（39096 的脚本 + 核心）:
-- boss_19219   boss_mechano_lord_capacitus.cpp → PolarityShiftCapacitus::OnEffectExecute() 给每个目标随机挂
-- boss_19219   39088 Positive Charge 或 39091 Negative Charge（都是 Effect1=6/Aura1=4 DUMMY +
-- boss_19219   Effect2=6/Aura2=23 PERIODIC_TRIGGER_SPELL，TriggerSpell2 分别 39090/39093、TargetA1=1 自身）
-- boss_19219   → game/Spells/Spell.cpp:8755-8762: 39090 只在目标带 39091 时才生效、39093 只在带 39088 时才生效
-- boss_19219     （**只打"相反电荷"**）；
-- boss_19219   → game/Spells/SpellAuras.cpp:1955-1985: 每跳扫 `GetPlayerListWithEntryInWorld(target, 10.f)`，
-- boss_19219     数出 10 码内**同电荷**玩家数 curCount，先 RemoveAurasDueToSpell 再叠 curCount 层
-- boss_19219     39089/39092 Positive/Negative Charge（Aura1=79 MOD_DAMAGE_PERCENT_DONE +99 = 每层 +100% 伤害）
-- boss_19219   ⇒ 攻略的"同电荷 10 码内互相增伤 / 每 5 秒对 10 码内相反电荷造成自然伤害"完全成立。
-- boss_19219 虚空充能: HandleSummonCharge() 随机用 35153/35904/35905/35906 召唤
-- boss_19219   （spell_template Effect1=28 SUMMON、DurationIndex=18）；NetherChargeAI 构造里
-- boss_19219   `SetReactState(REACT_PASSIVE)` + 10 秒后停下不动，JustRespawned() 自放
-- boss_19219   35150 Nether Charge Passive（Aura1=4 DUMMY，AuraScript 强制 2 秒一跳，第 5/6/7 跳放 35151 Pulse）
-- boss_19219   与 37670 Nether Charge Timer（Aura1=23 → EffectTriggerSpell1=35152 Nether Detonation，
-- boss_19219   Effect1=2 奥术 2269、TargetA1=22 + B1=15 范围）
-- boss_19219 机制: 裂颅 35161 只打 Boss 的当前目标（=坦克），减 200 耐力（≈掉一截最大生命）
-- boss_19219 规则1 证据: values/BossRuleValues.h → IsTankValue（PlayerbotAI::IsTank(bot)，
-- boss_19219   注册在 ValueContext.h:298 `creators["is tank"]`）+ TriggerAsValue::Calculate()；
-- boss_19219   values/OperatorValues.h:6 → BoolAndValue；触发器 HasAuraTrigger::IsActive()
-- boss_19219   （只查自己）；动作 actions/UseItemAction.h → UsePotionAction::isUseful() +
-- boss_19219   UseHealingPotionAction（权重 70 = MEDIUM_HEAL）。
-- boss_19219 语义注意（拿不准，见回报）: 35161 只落在"当前仇恨目标"身上，正常情况下就是坦克；
-- boss_19219   若有人抢到仇恨，他会一起吃到裂颅但被 `is tank` 挡住本规则 —— 那时的兜底是引擎自带的
-- boss_19219   `low health`/`critical health`（strategy/generic/UsePotionsStrategy.cpp:32-44 →
-- boss_19219   healthstone / use bandage）。站长若想放宽，删掉 `is tank,` 即可。
-- boss_19219 数值待定: 权重 70；要不要给坦克加 stoneshield potion（**不建议** —— 35159/护甲对奥术近战没用）
-- boss_19219 TODO 做不到: 【本 BOSS 最核心】极性转换的"同电荷站一起、远离不同电荷"
-- boss_19219   原因: 电荷**可以查**（`has aura::spellid::39088` 正 / `39091` 负，甚至 `39089`/`39092`
-- boss_19219     的层数），但规则行里**没有任何"移动到某个队友附近"或"离开某个队友"的动作**：
-- boss_19219     · `flee`（actions/MovementActions.cpp → MovementAction::Flee()）是以**当前目标（Boss）**
-- boss_19219       为基点拉开，不是"离开相反电荷的队友"，用它只会丢掉 10 码同电荷的 +100% 增伤，
-- boss_19219       还可能把自己拉出治疗范围 ⇒ 判为有害，不写；
-- boss_19219     · movement/strategy 里没有"按电荷分组站位/集合"的触发器或动作，
-- boss_19219       通用触发器的距离关系只有 inside target / enemy too close for melee|spell（都不是"与队友 N 码"）
-- boss_19219     ⇒ 只能人工站位，或后续加"目标 aura + 队友电荷"类新触发器/动作。
-- boss_19219 TODO 做不到: 躲虚空充能（35153/35904/35905/35906 → 35150/35151/37670→35152）
-- boss_19219   原因: 充能是 **REACT_PASSIVE 的召唤物**（NetherChargeAI 构造 SetReactState(REACT_PASSIVE)，
-- boss_19219     不还手、不进场仇恨）⇒ ① 攻击类动作只遍历 "attackers"
-- boss_19219       （values/TargetValue.cpp → TargetValue::FindTarget()，IsValid 要求 InCombat），选不中它；
-- boss_19219     ② 爆炸 35152 是**生物施放的范围法术**（TargetA1=22 施法者位置 + B1=15），
-- boss_19219       不产生 DynamicObject ⇒ `has area debuff`（values/AoeValues.cpp → HasAreaDebuffValue::Calculate()
-- boss_19219       只遍历 "nearest dynamic objects no los"）永远为假；
-- boss_19219     ③ 没有任何"远离某只怪/某个坐标"的通用动作（能按 entry 找怪的只有
-- boss_19219       `specific creature too close`，它读预置的 "avoid creature list"，
-- boss_19219       规则行改不了 —— 见 bossrules_H.tsv boss_17798 的同条说明）。
-- boss_19219   ⇒ "躲空中的鹅黄色炸弹"只能人工，或后续给 NetherCharge 加 hazard 触发器/动作。
-- boss_19219 TODO 做不到: "坦克喝奥抗药水"（攻略明确要求）
-- boss_19219   原因: 动作表里**没有**奥术防护药水动作 —— actions/UseItemAction.h 只有
-- boss_19219     UseFireProtectionPotionAction("fire protection potion", 行 612) / UseStoneshieldPotionAction
-- boss_19219     / UseFreeActionPotionAction / UseHealingPotionAction / UseManaPotionAction
-- boss_19219     / UseAntiVenomAction / UseDarkRuneAction / UseWhipperRootTuberAction（+healthstone）；
-- boss_19219     需要新增一个动作（或让站长改用别的手段）才能落地。
-- boss_19219 TODO 做不到: 反射盾期间"停手/切目标"（普通难度 35159 15s、35158 35s 各一次）
-- boss_19219   原因: 两面盾都是 **Boss 自身**的光环（TargetA1=1 自身）⇒ 没有"目标/BOSS 身上有 aura"的触发器；
-- boss_19219   缓解: 施法动作内部本来就有一层静态保护（actions/GenericSpellActions.cpp →
-- boss_19219     CastSpellAction::isUseful() 里按 `spellTarget->GetReflectChance(school) > 50 &&
-- boss_19219     IsReflectableSpell()` 拒绝施法），但近战平砍没有保护
-- boss_19219     （35159 是 DAMAGE_SHIELD +749 ⇒ 每次平砍反 750，需要人工停手）。
-- boss_19219 备注: 26662 Berserk（180s 起、每 300s；Aura1=79 +500%、Aura2=138 +150%）—— 属"打太慢"的
-- boss_19219   通用后果，没有可写的应对（只能人工控 DPS/换装），攻略"狂暴 >3 分钟秒杀一切"与 DB 一致。
-- boss_19219 备注: "把 Boss 拉到王房外、非坦克站楼梯棱线上（不同平面可无视）"—— 规则行没有控制
-- boss_19219   BOSS 站位/指定点位的入口（坦克选位由核心与职业策略决定），只能人工。
-- boss_19219 规则1 用**方案 B（val::and::{is tank,trigger::…}）**。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_19219';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_19219', 1, 0, 'val::and::{is tank,trigger::has aura::spellid::35161}>healing potion!70');

-- ===== boss_19220_dps  Pathaleon the Calculator (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 ⇒ 集名后缀（本文件 boss_19220_dps）；
-- boss_19220_dps 机制: 优先击杀虚空怨灵 21062（Boss 会周期性召 3 只，怨灵碰面期间会掉 8384×3 血，
-- boss_19220_dps 规则1 证据: triggers/TriggerContext.h:84 → HasNearestAddsTrigger::IsActive()
-- boss_19220_dps 规则1 语义: 怨灵 8384 血 vs Boss 100351(英雄 135474) 血 ⇒ 引擎默认的 "dps target"
-- boss_19220_dps 角色分工备注: 本文件同时演示两套写法 —— 本集用**方案 A（集名后缀）**，
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_19220_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_19220_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_19221  Nethermancer Sepethrea (rank=1) =====
-- boss_19221 脚本: ScriptDevAI/.../the_mechanar/boss_nethermancer_sepethrea.cpp →
-- boss_19221   boss_nethermancer_sepethreaAI（CombatAI）+ npc_raging_flamesAI（暴怒的烈焰 20481）
-- boss_19221   + RagingFlamesInferno SpellScript（HP 97400，英雄模板 21536 HP 131489）
-- boss_19221 技能栏 1922101（普通与英雄**同一个技能栏**）:
-- boss_19221   [0] 35314 Arcane Blast 奥术冲击 TargetId=1 当前目标 14-25s 起、15-30s 重复；
-- boss_19221     spell_template: Effect1=98 SPELL_EFFECT_KNOCK_BACK +74、Effect2=2 奥术 874、
-- boss_19221     TargetA1=6（无 aura）；脚本 OnSpellCast() 额外 `modifyThreatPercent(target, -50.0f)`
-- boss_19221    [1] 35250 Dragon's Breath 龙息术 TargetId=0（自身范围）20-26s 起、20-35s 重复；
-- boss_19221     spell_template: Dispel=1 DISPEL_MAGIC、EffectImplicitTargetA1=24 正面锥、
-- boss_19221     Effect1=2 火焰 679 + Effect2=6/Aura2=5 SPELL_AURA_MOD_CONFUSE +
-- boss_19221     Effect3=6/Aura3=33 MOD_DECREASE_SPEED -61、DurationIndex=27、CastingTimeIndex=1 瞬发
-- boss_19221 暴怒的烈焰 20481（HP 121770，ScriptName=npc_raging_flames）:
-- boss_19221   Aggro() → FixateRandomTarget(): DoResetThreat() + 对召唤者随机挑一名玩家 AddThreat(1000000)
-- boss_19221   （=攻略的"锁定"，无视仇恨追一人）；技能栏 2048101 → 35268 Inferno 地狱火 15.7-28.9s 一轮
-- boss_19221   （spell_template: TargetA1=1 自身、Aura1=23 PERIODIC_TRIGGER_SPELL +1500、
-- boss_19221     Aura2=26 MOD_ROOT、Aura3=25 MOD_PACIFY、DurationIndex=31）；
-- boss_19221   Reset() 自放 35281 Raging Flames（Aura1=23 → EffectTriggerSpell1=35278，
-- boss_19221     35278: Effect1=27 SPELL_EFFECT_PERSISTENT_AREA_AURA + TargetA1=18/B1=16 → 触发 35312 火焰）
-- boss_19221   RagingFlamesInferno::OnApply() 在 **Inferno 光环消失时** 重新 FixateRandomTarget()
-- boss_19221   （=攻略的"每 15 秒或地狱火引导结束更换锁定目标"）
-- boss_19221   Sepethrea 侧: Aggro() 里 DoCastSpellIfCan(nullptr, 45196 Frost Attack, AURA_NOT_PRESENT)
-- boss_19221     + 35275(普通)/39084(英雄) Summon Raging Flames（35150 那条：Effect1=28 SUMMON 20481、×3）
-- boss_19221   Frost Attack 45196: Aura1=42 PROC_TRIGGER_SPELL → 45195（Effect1=2 冰霜 737 +
-- boss_19221     Effect2=6/Aura2=33 MOD_DECREASE_SPEED -26、Mechanic=11 MECHANIC_SNARE、DurationIndex=31）
-- boss_19221 机制: 全程风筝暴怒的烈焰 20481 —— 引擎**已经有现成的触发器+动作**
-- boss_19221 规则1 证据: triggers/TriggerContext.h:364 → creators["raging flames too close"] =
-- boss_19221 规则1 备注（重要，站长请裁）: 引擎内置策略 **已经**做同一件事 ——
-- boss_19221 机制: 龙息术 35250 是**瞬发**（CastingTimeIndex=1）的正面火焰 + 迷惑 3 秒
-- boss_19221 规则2 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（只查自己）+
-- boss_19221 规则2 拿不准（见回报）: ① 35250 的 **Mechanic 字段是 0**（迷惑走 Aura2=5，不是 Mechanic 位），
-- boss_19221 归 boss_common / 引擎已覆盖: 龙息术的"驱散"本身 ——
-- boss_19221 TODO 做不到: 对**队友**秒驱龙息术（攻略：否则她会无视被迷惑的坦克去打别人）
-- boss_19221 TODO 做不到: 火焰（地板火）35278 → 35312 的"别踩/别烫到别人"
-- boss_19221 TODO 做不到: 地狱火 35268/39346 期间（Boss 自己定身+沉默，8 秒）的应对 + 锁定换人
-- boss_19221 TODO 做不到: 奥术冲击 35314 的击退 + 威胁值减半（坦克仇恨不稳）
-- boss_19221 TODO 做不到: 冰霜攻击 45195 的减速
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_19221';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_19221', 1, 0, 'raging flames too close>move away from raging flames!90'),
('boss_19221', 2, 0, 'has aura::spellid::35250>use trinket!95');

-- ===== boss_19710  Gatewatcher Iron-Hand (rank=1) =====
-- boss_19710 脚本: **EventAI**（AIName=EventAI，ScriptName 空；creature_ai_scripts 1971001-1971009；
-- boss_19710   HP 121770，英雄模板 21526 HP 164389）
-- boss_19710 技能:
-- boss_19710   1971009 (11800-42700ms) 35326 Hammer Punch 锤击，ACTION_T_CAST(...,1,0) = 当前目标；
-- boss_19710     spell_template: Effect1=58 武器伤害 +9、Effect2=6/Aura2=12 SPELL_AURA_MOD_STUN、
-- boss_19710     EffectImplicitTargetA2=6 目标、DurationIndex=32、Mechanic=0
-- boss_19710   1971006/1971007 (14400-59500ms) 35327 Jackhammer 风钻(普通) / 39194(英雄)，
-- boss_19710     ACTION_T_CAST(...,0,0) = **打自己**；
-- boss_19710     spell_template: EffectImplicitTargetA1=1 施法者自身、Aura1=23 PERIODIC_TRIGGER_SPELL
-- boss_19710     → EffectTriggerSpell1=35330(英雄 39195) 的"Jackhammer Effect"、
-- boss_19710     Aura3=26 MOD_ROOT（Boss 定身自己）、CastingTimeIndex=16、InterruptFlags=9、
-- boss_19710     AttributesEx=4 SPELL_ATTR_EX_IS_CHANNELED（引导）、DurationIndex=31；
-- boss_19710     35330/39195: Effect1=2 范围物理 1567(英雄 3134)、TargetA1=22 + B1=15
-- boss_19710   1971004/1971005 (22100-50000ms) 35322/39193 Shadow Power 暗影能量（同 19218）
-- boss_19710   1971008 (31400-63200ms) 35311 Stream of Machine Fluid 流动机蒸汽（同 19218）
-- boss_19710 机制: 锤击 35326 直接给当前目标上 MOD_STUN（昏迷）⇒ 被控住时先尝试解控
-- boss_19710 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()
-- boss_19710 数值待定: 权重 95；是否加 `try emergency!50`
-- boss_19710 TODO 做不到: 【本 BOSS 最关键】风钻 35327/39194 的"看到提示第一时间跑出 15 码范围"
-- boss_19710   原因① 预警抓不到: 攻略的"看守者埃隆汉邪恶地举起战锤……"来自
-- boss_19710     creature_ai_scripts 1971006 `ACTION_T_TEXT(18662,20029,0)` + 英雄 1971007
-- boss_19710     `ACTION_T_TEXT(20710,0,0)`（喊话/表情广播）⇒ 走 SMSG_EMOTE/SMSG_MESSAGECHAT，
-- boss_19710     而 PlayerbotAI.cpp:2046-2057 `case SMSG_EMOTE: // do not react to NPC emotes`
-- boss_19710     **明确丢弃 NPC 表情包**（只有 source.IsPlayer() 才转发给触发器），
-- boss_19710     所以 `receive emote` / `receive text emote`（WorldPacketTriggerContext.h:62-63）永远不触发。
-- boss_19710   原因② 玩家侧没有 aura: 35327/39194 的 EffectImplicitTargetA1=1 = 打在 Boss 自己身上，
-- boss_19710     伤害由它周期触发 35330/39195（范围在 **Boss 脚下**），玩家身上不留任何 debuff
-- boss_19710     ⇒ `has aura` 查不到。
-- boss_19710   原因③ 没有"离目标 > N 码"的触发器（RangeTriggers.h 的 enemy too close for melee
-- boss_19710     读的是 PlayerbotAIConfig.tooCloseDistance≈5 码，enemy too close for spell 是
-- boss_19710     "小于自己的施法距离"；值 distance/range 在规则行里没法与常量比较），
-- boss_19710     而 `flee` 是"以当前目标为基点拉开"，无法用"风钻已开始"当条件 ⇒ 做不到。
-- boss_19710   **引擎部分覆盖（留人工确认）**: 35327/39194 是 AttributesEx=IS_CHANNELED + InterruptFlags=9
-- boss_19710     的非瞬发引导，目标正是 bot 的 current target ⇒ 各职业内置打断有机会直接把它打断；
-- boss_19710     但"提前跑出范围"仍然做不到（不能把整场战斗都建立在"打断一定成功"上）。
-- boss_19710 TODO 做不到: Shadow Power 35322/39193 —— 同 boss_19218 的那条（引擎职业打断 + 法师 spellsteal 已覆盖）
-- boss_19710 归 boss_common / 引擎已覆盖: 流动机蒸汽 35311（中毒）—— 同 boss_19218 的说明（引擎 potions 策略）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_19710';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_19710', 1, 0, 'has aura::spellid::35326>use trinket!95'),
('boss_19710', 2, 0, 'has aura::spellid::35311>cure poison!85,anti-venom!80');

-- ===== boss_20870  Zereketh the Unbound (rank=1) =====
-- boss_20870 数据: AIName=EventAI（**没有** ScriptName ——
-- boss_20870 技能（creature_spell_list 2087001 + creature_spell_targeting 解码）:
-- boss_20870 机制: 被 [腐蚀之种] 点名的人要离开人群（攻略口径 10 码分散，
-- boss_20870 规则1 证据: values/BossRuleValues.h → TriggerAsValue::Calculate()（把任意触发器当布尔值）
-- boss_20870 规则1 近似点（重要，别当成严格分散）: MovementAction::Flee() 在**有队伍**时优先挑队友当落点
-- boss_20870 机制: 攻略"输出：新星读条时血 <5000 开技能/吃糖喝红" —— 规则行只能按**血量档**近似。
-- boss_20870 规则2 证据: OperatorValues.cpp → BoolAndValue::Calculate() + values/ValueContext.h →
-- boss_20870 规则2 限制与拿不准（见回报）: ① 引擎**没有**"目标正在读条某技能"的触发器
-- boss_20870 TODO 做不到: 躲脚下的 [虚空领域]（36119 → NPC 21101 → 36120/39003 → 36121/39004）
-- boss_20870 TODO 做不到: [暗影新星] 的"卡视角 / 出 45 码躲"与"读条时开减伤"
-- boss_20870 备注: 坦克"靠墙坦住 / 被击退后重新定位"属控制 BOSS 站位，规则行没有入口（坦克选位由核心 +
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20870';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20870', 1, 0, 'val::or::{trigger::has aura::spellid::36123,trigger::has aura::spellid::39367}>flee!85'),
('boss_20870', 2, 0, 'val::and::{trigger::low health,is dps}>try emergency!80');

-- ===== boss_20885  Dalliah the Doomsayer (rank=1) =====
-- boss_20885 数据: ScriptName=boss_dalliah（…/tempest_keep/arcatraz/boss_dalliah.cpp），HP 132480，
-- boss_20885 技能（creature_spell_list 2088501 / 英雄 2159001）:
-- boss_20885 机制: 英雄模式中了 [暗影波] 39016 的人受到暗影伤害 +50%（可叠 4 层）⇒ 自己拉起血线。
-- boss_20885 规则1 证据: triggers/GenericTriggers.cpp → HasAuraTrigger::IsActive()（只查自己）；
-- boss_20885 TODO 做不到: 打断优先级（[治疗术] > [末日预言者的礼物]，其次 [暗影波]）
-- boss_20885 TODO 做不到: 近战躲 [旋风斩] 36142
-- boss_20885 TODO 做不到: "治疗尽量别治疗中了 [礼物] 的人" / 被点名者自救
-- boss_20885 备注: 双重攻击 19818 是 BOSS 自身光环，没有"目标有 aura"的触发器 ⇒ 近战无法据此规避；
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20885';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20885', 1, 0, 'has aura::spellid::39016>healing potion!60');

-- ===== boss_20886  Wrath-Scryer Soccothrates (rank=1) =====
-- boss_20886 数据: ScriptName=boss_soccothrates（…/tempest_keep/arcatraz/boss_soccothrates.cpp），
-- boss_20886 技能（creature_spell_list 2088601 / 英雄 2162401）:
-- boss_20886 机制: [邪火震击] 只点当前目标（=坦克），是**可驱散的魔法** DoT ⇒ 坦克先把血线拉起。
-- boss_20886 规则1 证据: BossRuleValues.h → TriggerAsValue::Calculate() + OperatorValues.cpp →
-- boss_20886 备注: [邪火] 35769 是 DynamicObject（Effect1=27，见上）⇒
-- boss_20886 TODO 做不到: 躲 [邪火] 冲锋路径 / 坦克把 BOSS 带离火墙
-- boss_20886 TODO 做不到: 全员离开 [邪能献祭] 36051/39007 的 15 码光环
-- boss_20886 备注: 若站长认可"火系伤害前吃火焰防护药水"，可另写
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20886';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20886', 1, 0, 'val::or::{trigger::has aura::spellid::35759,trigger::has aura::spellid::39006}>healing potion!60,try emergency!50');

-- ===== boss_20912  Harbinger Skyriss (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 ⇒ 集名后缀（boss_20912_dps）；
-- boss_20912 数据: ScriptName=boss_harbinger_skyriss（…/tempest_keep/arcatraz/boss_harbinger_skyriss.cpp），
-- boss_20912 技能:
-- boss_20912 机制: 被 [心灵撕裂] 昏迷 + 每秒暗影 ⇒ 先解控自救（昏迷里被打死风险最高）。
-- boss_20912 规则1 证据: BossRuleValues.h → TriggerAsValue + OperatorValues.cpp → BoolOrValue
-- boss_20912 规则1 拿不准（见回报）: ① `use trinket` 取的是身上第一个可用 on-use 饰品，**不保证**是解控饰品
-- boss_20912 机制: 幻象的 [心灵撕裂] 36929/39021 **不带昏迷**（只有持续伤害）⇒ 别浪费解控饰品，
-- boss_20912 规则2 说明（2026-10-16 修正）：36929/39021 是**幻象**（21466/21467）的 EventAI 施放
-- boss_20912 规则2 证据: TriggerAsValue + BoolOrValue（同上）；HasAuraTrigger::IsActive()（只查自己）——
-- boss_20912 机制: 优先击杀 [预言者的幻象] 21466/21467（17709 血 vs 本尊 194799，但伤害同本尊）。
-- boss_20912_dps 规则1 证据: triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()
-- boss_20912_dps 规则1 语义注意（见回报）: ① 判定半径是 fleeDistance（源码默认 8 码）——
-- boss_20912 TODO 做不到: [恐惧] 的"即时驱散"与 [支配] 的"提前把强控用掉"
-- boss_20912 TODO 做不到: [法力燃烧] 39020（仅英雄）的应对
-- boss_20912 TODO 做不到: 治疗的"重点关注被 [心灵撕裂] 的队友" / "除坦克外不要站怪正面"
-- boss_20912 备注: 一阶段四个牢房（Warden Mellichar 与各牢房召唤物）**不是 BOSS entry**，拿不到
-- boss_20912 备注: 本文件只登记 20912，BossStrategyHook.h → FightTargetEntry() 用 GetEntry() 找 BOSS
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20912';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20912', 1, 0, 'val::or::{trigger::has aura::spellid::36924,trigger::has aura::spellid::39017}>use trinket!95,try emergency!50');

-- ===== boss_20912_dps  Harbinger Skyriss (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 ⇒ 集名后缀（boss_20912_dps）；
-- boss_20912_dps 规则1 证据: triggers/GenericTriggers.cpp → HasNearestAddsTrigger::IsActive()
-- boss_20912_dps 规则1 语义注意（见回报）: ① 判定半径是 fleeDistance（源码默认 8 码）——
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20912_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20912_dps', 1, 0, 'has nearest adds>attack least hp target!20');

-- ===== boss_20923  Blood Guard Porung (rank=1) =====
-- boss_20923 技能: creature_ai_scripts 2092306 = EVENT_T_TIMER_IN_COMBAT(3-12s / 8-16s) → ACTION_T_CAST(15496 Cleave,
-- boss_20923   target=1 当前目标)，注释写明 **Heroic**；其余 2092301-2092305 = spawn 隐身侦测 18950 /
-- boss_20923   aggro（写实例数据 TYPE_GAUNTLET=4 结束通道 + 喊话）/ death（写 3）/ evade（写 2）—— **没有 Fear**
-- boss_20923 通道小怪: 同普通版 17461（碎手弓箭手 17427 两只，站首领旁边；火箭落地火的 TODO 见 17461 那节）
-- boss_20923 机制: 开怪后先点掉身边的弓箭手/狂热者
-- boss_20923 规则1 证据: 同 boss_16808 规则1；弓手 17427=20283 血 / 首领 20923=103320 血 ⇒ 实战会选弓手/狂热者。数值待定
-- boss_20923 TODO 做不到: 顺劈斩 15496 的"坦克把他背朝人群"
-- boss_20923   原因: 15496 是 target=1 的正面顺劈、玩家身上无 aura，也没有控制 BOSS 朝向/位置的动作
-- boss_20923   ⇒ 同 16807 的顺劈，无规则可写。
-- boss_20923 TODO 做不到: 治疗"盯住被弓箭手点名的队友"
-- boss_20923   原因: 17427 是普通远程怪（TargetId=1 打当前目标 + 30990 多重射击），没有"谁被盯上"的触发器，
-- boss_20923   也没有"优先治疗某个被怪盯上的队友"的动作（values "party member to heal" 只按血量/威胁挑人）⇒ 留人工。
-- boss_20923 备注: 攻略"碎手弓箭手-驱散射击（物理伤害 + 迷惑 4 秒）"与 DB 不符 ——
-- boss_20923   17427 的技能栏只有 16100 Shoot / 30990 Multi-Shot；带 aura5(MOD_CONFUSE) 的驱散射击 23601 挂在
-- boss_20923   NPC 16704 Shattered Hand Sharpshooter 与 17622 Sharpshooter Guard（卡加斯战的卫兵）身上，本 BOSS 战不出现
-- boss_20923   ⇒ 本组不写该条（卡加斯那边已覆盖）。
-- boss_20923 归 boss_common: 无。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_20923';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_20923', 1, 0, 'val::and::{is dps,trigger::has nearest adds}>attack least hp target!20');

-- ===== boss_21466  Harbinger Skyriss (rank=1) =====
-- 而队伍打幻象时目标 entry=幻象 ⇒ 本体的集会被摘掉 ⇒ 该规则已移到 boss_21466 / boss_21467。
-- boss_21466 预言者斯克瑞斯的幻象 1（boss_harbinger_skyriss.cpp → SPELL_66_ILLUSION=36931 召唤）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_21466';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_21466', 1, 0, 'val::or::{trigger::has aura::spellid::36929,trigger::has aura::spellid::39021}>healing potion!55,try emergency!50');

-- ===== boss_21467  Harbinger Skyriss (rank=1) =====
-- 而队伍打幻象时目标 entry=幻象 ⇒ 本体的集会被摘掉 ⇒ 该规则已移到 boss_21466 / boss_21467。
-- boss_21467 预言者斯克瑞斯的幻象 2（SPELL_33_ILLUSION=36932 召唤，EventAI 同样 36929/39021）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_21467';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_21467', 1, 0, 'val::or::{trigger::has aura::spellid::36929,trigger::has aura::spellid::39021}>healing potion!55,try emergency!50');

-- ===== boss_22930  Yor (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_18343_dps / boss_22930_dps）；
-- 变身后 GetEntry()=22930，所以策略名就是 boss_22930（BossStrategyHook.h → EntryOfUnit() 用 GetEntry()）。
-- boss_22930 机制: [双重吐息] 38361 → 38369（TgtA1=24 正面锥、火焰）—— 站正面就吃
-- boss_22930_dps 机制: 正面锥规避只让 **DPS**（集名后缀 `_dps`；坦克被 isPossible() 排除，见 boss_18343 规则1）
-- boss_22930 规则1 证据: 与 boss_18343_dps 规则1 同（IsNotBehindTargetTrigger + SetBehindTargetAction
-- boss_22930 机制: [践踏] 36405 是"尤尔自己脚下 10 码"的物理 AoE + 击退 —— 攻略"除近战外都与尤尔保持 10 码以上"
-- boss_22930 规则2: 远程（is ranged）在 10 码内就往外跑（近战不触发，坦克/治疗按自己职业策略走）
-- boss_22930 规则2 证据: 触发器 triggers/RangeTriggers.h → EnemyInRangeTrigger（"enemy ten yards" =
-- boss_22930 TODO 做不到: "使尤尔背对人群" / 原因: 没有让坦克移动/转向 BOSS 的动作（见 boss_18343 说明）。
-- boss_22930 TODO 做不到: [践踏] 36405 的击退与 10 码 AoE 本身 / 原因: Effect1=58+Effect2=98，玩家身上
-- boss_22930 说明: 尤尔没有英雄版（creature_template.HeroicEntry=0），单 entry，不需要写第二套。
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_22930';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_22930', 2, 0, 'val::and::{trigger::enemy ten yards,is ranged}>flee!45');

-- ===== boss_22930_dps  Yor (rank=1) =====
-- 角色分工两套并存（速查 §5）：整个集只给某角色 → 集名后缀（本文件 boss_18343_dps / boss_22930_dps）；
-- boss_22930_dps 机制: 正面锥规避只让 **DPS**（集名后缀 `_dps`；坦克被 isPossible() 排除，见 boss_18343 规则1）
DELETE FROM `tbccharacters`.`ai_playerbot_custom_strategy` WHERE `owner` = 0 AND `name` = 'boss_22930_dps';
INSERT INTO `tbccharacters`.`ai_playerbot_custom_strategy` (`name`, `idx`, `owner`, `action_line`) VALUES
('boss_22930_dps', 1, 0, 'not behind target>set behind!20');

-- [2026-10-19] 补登记：有专属集但漏登记的 4 个 BOSS（放在文件末尾，避免被上面的 DELETE 清掉）
INSERT INTO `tbccharacters`.`ai_playerbot_boss_strategy` (`entry`, `note`) VALUES
(17461, '破碎大厅：破碎之手血卫（带小弟/斩杀）'),
(18170, '时光之穴：无限杀戮者（致死打击/暗影箭）'),
(18171, '时光之穴：无限玷污者（驱散/解除诅咒）'),
(18172, '时光之穴：无限破坏者（驱散魔法）')
ON DUPLICATE KEY UPDATE `note` = VALUES(`note`);
