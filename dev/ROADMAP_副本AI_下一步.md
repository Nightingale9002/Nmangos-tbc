# 副本 AI 下一步可行性分析（汇总，2026-10-18）

> 站长口径："我说的不一定每一条都要立刻实现 而是要总结起来分析可行性，然后统一做下一步"。
> 本文把最近提出的所有问题按 **已实现（待部署） / 待做（含可行性、风险、工作量、建议批次）** 归档；
> 不再逐条立刻动代码。下一步由站长点批次。

---

## 〇、当前状态

| 项 | 值 |
|---|---|
| 本地编译 | ✅ 全绿 `errors=0`，产物 `md5=03c80a5a81344943d2009cf9fe6ffab9`（父 `d679731fa` / 子模块 `agent/los` 最新） |
| 云端二进制 | `01ed9a5a6051868cb0bc38b4a0ae3802`（旧版；等站长下令重启部署新版） |
| 云端 DB | `tbcmangos.ai_playerbot_pull_log` 已建；`tbcmangos.ai_playerbot_priority_target`（2026-10-19 起策略表迁到世界库）；`ai_playerbot_priority_obs` **等新版部署时一起建**（现 `dev/186_副本拉怪记录与优先级观测.sql`） |
| 开关默认值 | 自动开怪 **默认关**（`.bot route on` 才开）；跳过 critter 默认开；标记/拉怪日志只写不读 |
| 本地仿真（2026-10-19） | 模式A 推进（最近目标 + 30 码视线即停 + 波中心路点）、波锁定 150s、15 秒零伤害跳过、纯 NPC 波开局跳过、角色不足换人重选、`attempts=0` 无限跑；map 547 实测 `cleared=6/30`、4~6 只一波能在 60~100 秒清掉 |

---

## 一、已实现（代码已提交、已编译，等部署）

| # | 内容 | 关键符号 | 备注 |
|---|---|---|---|
| 1 | 拉怪顺序 + 每次结果落库/落日志 | `dungeonroute::PullBegin/PullEnd/PullTick`、`[PULL]` 行、表 `ai_playerbot_pull_log`（dev/192） | 每轮副本 = 一个 `instance_id`；`result`: cleared/skipped/died/left |
| 2 | 骷髅等团队标记的标记/改标/清标落日志 | `Group::SetTargetIcon()` → `[MARKER]` 行（含 `changer`、`old_entry/new_entry`） | 客户端改标传玩家 guid，可复盘"谁标的" |
| 3 | 标记日志 → 自动分析优先级 | `dev/analyzers/analyze_marker_priority.py` | 离线生成 `source='skull-log'` 的 upsert SQL，人工复核后执行 |
| 4 | 拉怪日志 → 分析波次顺序 | `dev/analyzers/analyze_pull_order.py` | 每轮 ord 序列是否递增 / 漏波 / 跳过 / 用时 / 死亡；可对路线表比对、导 JSON |
| 5 | 威胁等级表语义 5/3/2/1 | `PossibleAttackTargetsValue::ThreatTier()` | 5=立刻转火杀（不降级）；3=优先杀；2=无对应驱散才优先；1=只打断不优先杀；吃控制降 1 级 |
| 6 | 被控目标不打醒 | `PossibleAttackTargetsValue::RemoveNonThreating()` | 被控（羊/闷/冰/恐惧/眩晕）**一律不进攻击候选**，控制结束后下一 tick 自然恢复 ⇒ 等价"最后才轮到它" |
| 7 | 控制给"输出最高的怪" | `CcTargetValue.cpp → FindTargetForCcStrategy` | 近战/远程 DPS 取大者排序，纯法系按等级兜底；RTI 手动指定仍最高优先 |
| 8 | 自动开怪做成开关 | `DungeonRoute.h → RouteEnabled()/RouteRuntimeSwitch()`、`PlayerbotMgr::HandleRoute` | `.bot route on/off/reset`；配置 `AiPlayerbot.DungeonRoute` 默认 0；再叠 `verified=1` |
| 9 | 战斗跳过小动物 | `PossibleAttackTargetsValue::IsPossibleTarget()`、`AiPlayerbot.SkipCritters` | critter 在候选层摘掉 |
| 10 | 自动装备不如当前装备的物品（修） | `EquipAction.cpp → EquipUpgradesAction::Execute()` | 不再先脱后穿；只穿 `ITEM_USAGE_EQUIP`（严格升级）；开关对所有 bot 生效 |
| 11 | verified 热重查 | `dungeonroute::GetMapRoute()` + `ROUTE_RECHECK_MS` | 改库 5 秒内生效，不用重启 |
| 12 | 优先级观测层（读条治疗/控制自适应） | `PossibleAttackTargetsValue::ObservePriorityCast/ObservedPriorityRank/FlushPriorityObs`、表 `ai_playerbot_priority_obs`（dev/193） | 读条治疗 → priority 5、读条控制 → priority 3（不含缠绕）；同 entry 观察 ≥2 次生效；chars 库持久化、跨重启保留；表不存在只记内存 |
| 13 | 优先级变化日志 | `[PRIO-CHANGE]`（人工表增/改/删 + 观测首次生效）、`[PRIO-OBS]`（达到生效门槛）、`[PRIO-DB]`（落库行数 + 两表行数） | 落库触发：`PullEnd()` + 每 120s 兜底；批量 upsert、`count` 只增（`GREATEST`） |
| 14 | 拉怪记录覆盖**所有玩家 / 所有副本图** | `pullrec::Update()`（`game/Combat/InstancePullRecorder.cpp`，由 `Map::Update()` 调） | 站长口径："拉怪日志是记录所有玩家在副本的日志…所有图都放行"。不再要求 verified=1/自动开怪；`source=player/bot`、`group_id`、`members`；模块只补 ord |
| 15 | 拉怪表列/键迁移（同实例多队伍不互相覆盖） | `dev/194_副本拉怪记录_所有玩家.sql` | 加 `group_id/source/members`；`tank_guid` 放宽为"记录者/队长"；唯一键 `(map,instance_id,tank_guid,seq)`；全幂等 |
| 16 | 服务端战斗日志（与客户端 CombatLog 同口径） | `combatlog::OnDamage/OnHeal/OnCastStart/OnCastSuccess/OnDeath`（`game/Combat/CombatLogRecorder.*`）→ `logs/combatlog_instances.csv` | 只记副本图里"至少一方是玩家（宠物追溯主人）"的事件：SWING/SPELL/PERIODIC 伤害、治疗、读条开始/成功、死亡；离线读取 `dev/analyzers/analyze_combatlog.py`（还原每波拉怪/结果/伤害治疗/敌方读条） |
| 17 | **队伍统一跑位决策层**（每队一个决策者，槽位下发） | `partypos::ComputeIfLeader/Compute/SlotFor`（`playerbot/PartyPositionCoordinator.h`）、动作 `move to party slot`、触发器 `party position active` | 每 500ms 只由一个决策者算（队内最小 guid 的 bot），其余 bot 只读自己的槽位；`[POSITION]` 日志 |
| 18 | 跑位模式：`los_all / los_pull / los_backline / los_break / frontal / knockback / stack / spread / wall` | 同上；数据来自 `ai_playerbot_boss_ability.category` | 各模式 = 角色 × 距离带 × 相对 BOSS 朝向的角度；卡视野优先 |
| 19 | 跑位硬约束（全部用服务端场地数据判定） | 同上 | ①leash ≤40 码且 ≥3 码；②非坦克禁站扇区（front/right/back/left，60° 一档）；③同层 + 不在实体里（`GetHeight` + vmap LOS）；④不引到未参战怪（战斗半径+8 码）；⑤远程/治疗最小间距 5 码；⑥直线不可走（逐段地形+vmap）就不下发 |
| 20 | 跑位数据种子 | `dev/196/198/200` + `dev/analyzers/seed_boss_*.py` | 攻略→`locales_creature.name_loc4` 中文名→entry→`ai_playerbot_boss_spawn.map`；当前 frontal 7 / knockback 11 / los 2 / wall 4 行 |

---

## 二、待做项 + 可行性

### A. 魅惑队友被集火（含"魅惑影响阵营属性"）——**建议第一批做**

**现象**：副本里魅惑类技能把队友变成敌对阵营/敌对关系，bot 会**优先击杀被控制的队友**。
**根因假设**：选怪链只看 `IsHostileTo`（阵营翻转后为敌对），没有"队友永远不是攻击目标"的硬过滤；
被魅惑队友同时满足"正在打我们 / 可攻击"，于是被当成怪。

**改法（分层，全部便宜）**：
1. 攻击候选硬过滤：`AttackersValue` / `PossibleAttackTargetsValue::IsValid()` 里
   `bot->IsInGroup(target)` 或 `bot->IsFriendlyTo(target)` ⇒ 直接 false（**任何阵营状态都成立**）。
2. 被魅惑队友改为**控制目标**：`CcTargetValue` 允许选"被魅惑的队友"（它是全队最大威胁），
   用变羊/恐惧/眩晕/束缚等控住，而不是打伤害。
3. 治疗/驱散侧同步：不要把被魅惑队友当敌人；驱散类法术优先解魅惑（牧师驱散魔法/萨满净化等）。
4. 记录日志：`[CHARM] bot=.. target=.. faction=.. 结果=控住/忽略`，便于复盘。

**风险**：低。PvP 里敌对阵营玩家不在 `IsInGroup`，不受影响；唯一要注意是"同队但内战"场景（竞技场）——
竞技场队友本来不会变敌对，也不受影响。
**工作量**：小（0.5~1 天）。**优先级：高**（现在会让副本队伍自相残杀）。

---

### B. 冰环/定身时怪物来回切目标，不打"距离内仇恨最高"——**建议先加日志验证，再改核心**

**事实**：怪物选目标在 `ThreatManager.cpp`：
- `ThreatContainer::sort()`：`force` 排序时用 `CanReachWithMeleeAttack` 做前列判据；
- `ThreatContainer::selectNextVictim()`：当前目标可达时按 1.1/1.3 仇恨阈值切换，不可达则换人。

**根因假设**（需日志确认）：
1. 冰环后怪物无法移动，只有"近战可达"的目标能被打 ⇒ 排序把 reach 当硬条件；
2. 两个人都可达时，若有人**来回进出攻击距离**（或 reach 判定抖动、模型半径差异），排序每帧翻转 ⇒ victim 抖动；
3. 也可能是"当前目标可达但 threat 不是最高，另一个可达目标超过 1.1 倍"反复跨越阈值。

**改法（从保守到激进）**：
1. **先加观测**：在 `selectNextVictim` 换目标处加 `[THREAT-SWITCH]` 日志（旧目标/新目标/threat/reach 状态），
   跑一次冰环场景，拿到真凭实据再改（避免拍脑袋改核心）。
2. 若确认是 reach 抖动 ⇒ 加**滞回**：当前目标可达时，只有新目标 threat 超过当前 **1.15 倍且持续 N 毫秒**才换；
3. 若确认是"出近战范围就换" ⇒ 在 root 状态下允许打"可达目标里 threat 最高的"，但**加最小停留时间**（如 1 秒）防抖；
4. 换目标时把原因写日志，便于站长复盘。

**风险**：中高。`ThreatManager` 是核心战斗逻辑，影响所有怪 + PvP + PvE，回归面大；
**不能盲改**，必须"先日志 → 再小步改 → 副本实测"。
**工作量**：日志 0.5 天；改动 1~2 天 + 实测。**优先级：中高**。

---

### C. 击晕/死亡缠绕/恐惧当作"另一类打断"（可打断不可打断技能）——**建议第三批**

**事实**：现有打断链是 `enemy casting interruptible`（触发）→ `interrupt current spell`（动作）→
`Unit::InterruptSpell()`；不可打断的技能现在没有任何手段。

**改法**：
1. 判据：目标在施法 且 `!CanBeInterrupted()` 且 吃硬控（眩晕/恐惧/死亡缠绕等，见 `IsCcAble` 同类判据）；
2. 能力表：按职业列"硬控打断"技能（战士震荡猛击/拦截、术士死亡缠绕、法师冰环/龙息、盗贼肾击、德鲁伊猛击等），
   做成**数据表**（沿用 `ai_playerbot_action_weight` 风格）而不是硬编码；
3. 决策：只在"这次施法会造成致命效果"（治疗/群体控制/召唤/高伤）时用，且与 CC 分配互斥（不重复控）；
4. 资源/冷却检查（怒气/蓝/CD），失败回落普通打断。

**风险**：中。误控会破坏队伍节奏；需要按职业细化，且要处理"控了又被打破"。
**工作量**：能力表 + 决策 2~3 天。**优先级：中**（先做 A/B 稳定再上）。

---

### D. 威胁等级表自动学习（骷髅标记 → 优先级）——工具已好，**缺"写回流程"**

- 已实现离线分析：`analyze_marker_priority.py` 把 `[MARKER]` 聚合成候选 SQL。
- 待定策略（建议）：**不自动写库**，每天生成候选 + 站长确认；写入 `source='skull-log'`；
  只对"被标骷髅 ≥2 次"的 entry 提优先级，避免误标。
- **2026-10-18 补充**：另一条"自动学习"已经落地且不依赖人工标记 ——
  `ai_playerbot_priority_obs`（dev/193）由引擎**观测读条**（治疗/控制，不含缠绕）自动攒证据，
  同一 entry ≥2 次生效；人工表仍优先，观测只补人工表没有的 entry。见 §一 第 12/13 条。
- 工作量：0.5 天（脚本已就绪，只差定时/审批流程）。**优先级：低中**。

### E. 拉怪日志 → 波次顺序校正（生成器侧）——工具已好，**缺"回写路线表"**

- 已实现离线分析：`analyze_pull_order.py` 输出实际 ord 序列、漏波、乱序、耗时、死亡。
- 下一步：把"实际顺序"与 `ai_playerbot_dungeon_route.ord` 比对，**人工核对后**再改数据；
  绝不让运行时自动改路线表（会破坏 verified 门控的意义）。
- 工作量：1 天（含核对）。**优先级：低中**（等 L3 真正跑起来有数据再说）。

### F. 部署（所有已实现项）——**等站长一句话**

- 需要：上传 `7e2cbaa…`（父 `ca95419f0`，子模块 `8e6c90a4`）→ 备份旧二进制 → `install` → 重启
  （先确认无真人在线）→ 验证 8086/realmd。
- 上云后还要跑 `dev/192_副本拉怪记录表.sql`（`ai_playerbot_pull_log` **已建**，可跳过）、
  **`dev/194_副本拉怪记录_所有玩家.sql`**（world 库；加 `group_id/source/members` + 唯一键迁移；
  **不跑则新二进制自动退回旧列写库，只是少三列**）与
  **`dev/193_优先级观测表.sql`**（建 `ai_playerbot_priority_obs`，chars 库；不建则观测只记内存）。
- 建议部署后先做 10 分钟冒烟：`[MARKER]`/`[PULL]`/`[PRIO-*]` 日志出现、`.bot route on` 生效、critter 不被拉；
  真人进一次 5 人本后再看 `logs/combatlog_instances.csv` 是否有事件、`ai_playerbot_pull_log` 是否有一行。

---

## 三、建议的统一下一步（按批次）

| 批次 | 内容 | 理由 |
|---|---|---|
| **第 1 批** | A（魅惑队友）+ 部署 F + 云端建 `pull_log` 表 | 直接影响副本可用性；改动小、风险低 |
| **第 2 批** | B（冰环切目标）先加 `[THREAT-SWITCH]` 日志 → 拿现场 → 小步改 | 核心战斗逻辑，必须证据驱动 |
| **第 3 批** | C（硬控打断）+ D/E 的写回流程 | 体验增强，依赖前两批稳定 |

---

## 四、附：相关符号速查（按符号 grep，行号会漂移）

- 选怪/威胁：`PossibleAttackTargetsValue::ThreatTier()`、`::RemoveNonThreating()`、`::IsPossibleTarget()`
- 控制：`CcTargetValue.cpp → FindTargetForCcStrategy`、`PossibleAttackTargetsValue::HasBreakableCC()/HasUnBreakableCC()`
- 怪物核心：`ThreatManager.cpp → ThreatContainer::sort()`、`::selectNextVictim()`
- 魅惑/阵营：`Unit::IsCharmed()`、`Unit::GetCharmer()`、`Player::IsInGroup()`、`Unit::IsHostileTo()`
- 副本推进：`DungeonRoute.h → ShouldDrive()/RouteEnabled()/AllowAttack()/FindTarget()`、`PullBegin()/PullEnd()/PullTick()`
- 标记日志：`Group::SetTargetIcon()`
- 自动装备：`EquipAction.cpp → EquipUpgradesAction::Execute()`
- 配置：`AiPlayerbot.DungeonRoute`、`AiPlayerbot.SkipCritters`、`AiPlayerbot.AutoEquipUpgradeLoot`
