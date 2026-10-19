# 可控场景注入（本地仿真）设计 — 2026-10-18，2026-10-18 修订（多组并发）

> 目的：不再依赖"随机 bot 自己组队/自己进本"，而是在**本地**用一条命令注入可复现场景：
> 指定副本 + 组数 + 队伍人数 → bot 登录、组队、传送进本、打开路线 → 采集指标。
> 云端默认关闭（`AiPlayerbot.SimMode = 0`），且只允许 GM 执行 ⇒ 不影响真人玩家。

## 〇、实现状态（2026-10-18）

| 能力 | 状态 |
|---|---|
| `.bot sim start <mapId> [groups=1] [partySize=5]` / `stop [runId\|all]` / `status` | ✅ 已实现（`playerbot/SimScenario.h/.cpp`） |
| 控制台入口 `.rndbot sim ...`（`CliHandler` 只放行 `rndbot`） | ✅ 已实现（见 §四） |
| 多组并发（每组独立组队 + 独立 instance） | ✅ 支持，`groups` 上限 5 |
| bot 登录（复用库里已有随机 bot 角色，**不新建**） | ✅ 实测 5/5 在 3~5 秒内上线 |
| 组队 + **真专精**挑坦/奶（不加载则失败，绝不用 DPS 顶替） | ✅ 已实现（见 §三 的"真坦真奶"） |
| 传送进本（队长先进、其余后进，同 instance） | ✅ 实测 7 秒内 5/5 落在副本图 |
| DungeonRoute 按波推进（`[DUNGEONROUTE]` / `[PULL]`） | ⏳ 联调中（见 §五 已知问题） |
| 跑位（`[POSITION]`，队伍统一决策层的槽位） | ⏳ 同上（需要先打起来） |

## 一、命令与配置

```
.bot sim start <mapId> [groups=1] [partySize=5] [policy=reset|continue] [attempts=3] [seed=N]
.bot sim stop [runId|all]        # 停止（只下线本 run 拉起的 bot）
.bot sim status                  # 当前组（attempt/seed/best/deaths）+ 历史小结
.bot sim prepare <n>             # 把 RNDBOT 账号上的 1 级空壳升到 70 级并登记为随机 bot（本地制备）
```

- 权限：`SEC_GAMEMASTER`；
- **必须** `AiPlayerbot.SimMode = 1`（本地配置默认 1、云端默认 0）；启动时会打一行 `[SIM] AiPlayerbot.SimMode = 1 ...` 作为审计；
- 控制台等价命令：`.rndbot sim ...`（`Chat.cpp` 里 `.bot` 的 console 标志是 false，`rndbot` 才是 true，落到同一个 `PlayerbotHolder::HandleSim`）。

### 实验参数（2026-10-18 站长口径："每次灭团重置测试"）

| 参数 | 含义 |
|---|---|
| `policy=reset`（默认） | **灭团即重置**：记一次 attempt（推到第几波/死亡/时长）→ 复活+回主城+下线 → 重新选阵容/新 instance → 下一 attempt，最多 `attempts` 次 |
| `policy=continue` | **死即复活续推**：全员同时死亡时直接复活并拉回副本入口，不重开，直到通关/卡死/超时 |
| `attempts=N` | reset 模式最多尝试次数（1~20，默认 3） |
| `seed=N` | 实验种子：决定候选洗牌/阵容；`attempt` 参与派生（`baseSeed + group*7919 + attempt*104729`）⇒ **同 seed 可复现、不同 attempt 阵容不同** |

判定（两种 policy 共用）：**灭团** = 全员同时死亡持续 3 秒；**通关** = 波次全清且 boss 刷点全灭；**卡死** = 5 分钟无波次推进且无战斗；**硬上限** = 单 attempt 45 分钟。
每次 attempt 结束打 `[SIM] … attempt N result=wipe|cleared|stuck waves=x/34 deaths=… dur=… seed=…`；整组结束打 `attempts=… best=…/34` 汇总。

## 二、一次 start 做的事（状态机，全在**世界线程**）

`RandomPlayerbotMgr::UpdateAIInternal()` 开头调 `simscenario::Update()`（在 autologin 闸门前，所以轮换关着也能跑）。
每个组一条独立状态机（`PHASE_LOGIN → FORM → TELEPORT → MOVEIN → RUN`，灭团后 `PHASE_RESET → LOGIN`）：

1. **LOGIN**：从候选池挑 bot → `AddPlayerBot(guid, 该 bot 自己的 accountId)`（`masterAccount == botAccountId` ⇒ 必过 `HandlePlayerBotLoginCallback` 的放行检查）。15 秒重试、90 秒超时。
2. **FORM**：等 3 秒（AI 初始化）→ 直接组队：`new Group` → `AddLeaderInvite(队长)` → `RemoveInvite` → `Create()` → `sObjectMgr.AddGroup` → 逐个 `AddMember`；然后逐个 `ResetStrategies()`，再按真实专精挑**1 真坦 + 1 真奶 + 其余真 DPS**（DPS 位排除坦/奶，避免"多坦导致实际驱动坦克 ≠ 预期坦克"）。
3. **TELEPORT**：**先传队长**（由队长触发 `MapManager::CreateInstance` 并把**队伍**绑定到 instance，见 `DungeonMap::Add` 的 `pGroup->BindToInstance`），等队长落地后再传其余成员 ⇒ 全队同一个 instance。
4. **MOVEIN**：等全员 `GetMapId()==目标图 && !IsBeingTeleported()`（60 秒超时）→ 打 `[SIM] IN DUNGEON ... inst=<id> attempt=x/y`，随后打一次 `[SIM] ... diag ...`（驱动判据 + route 数据）。
5. **RUN**：每 tick 统计 alive/deaths/已清波数；`combat==0` 时补打 diag；按上面的判定处理灭团/通关/卡死。
   - **推进策略 = 模式A（2026-10-18 站长口径）**：不要求踩精确拉怪锚点。
     ① 选目标只按"最近"（不看 ord 顺序，ord 只记日志）；
     ② 目标波里有一只 **≤30 码且视线内**（`Map::IsInLineOfSight`）的敌对怪 ⇒ **就地停下开拉**（拉怪位 = 坦克当前位置）；
     ③ 否则朝最近目标/波中心走；目标怪没加载 ⇒ 用**波中心**（`ai_playerbot_dungeon_route` JOIN `creature` 的刷点均值）当路点走过去；
     ④ 波全清/被放弃完 ⇒ boss 阶段（boss 没加载也先走过去）。
   - **波锁定**：选中一波后锁 `LOCK_MS=150s`（`BotState.lockOrd/lockUntil`），期间只打这一波，
     避免"多波同时可见时来回横跳"；该波被清/被跳过/超时自动解锁换下一波。
   - **纯 NPC/小动物波开局跳过**：`LoadMapRoute` 用全图清单判 `Wave.allNonHostile`（整波没有敌对怪），
     这种波不参与选目标和"走过去"（不用浪费 5 秒站桩），日志计入 `纯NPC波 N`。
   - **走不过去守卫**：朝同一波移动 **12 秒**（`MOVE_STUCK_MS`）距离都没缩短（mmap 不可达 / 卡门 / 卡几何）
     ⇒ `MarkSkipped(该波, "move no progress")`，不再原地撞墙到 90 秒/5 分钟。
   - **15 秒零伤害守卫（两只判据）**：
     ① 坦克当前目标血量 15 秒没变化；
     ② **整队** 15 秒没有任何"玩家→怪"伤害（核心 `combatlog::LastPlayerDamageMs(mapId)`，按图记录）
     ⇒ `MarkSkipped(当前波, "no damage 15s")` 换下一波；覆盖"打死盘牙监工荒土工人就脱战"、"目标在墙后打不到"等。
6. **RESET**（policy=reset）：解散队伍 → 复活 → `TeleportToHomebind`（必须先离开副本图，否则同图近传不会换 instance）→ 下线旧 bot → 用 `(attempt + roleRetries)` 派生新 seed 重新选人 → 回 LOGIN（新 group id ⇒ 新 instance）。
   - **角色不足不终止 run**：候选里没有真坦/真奶时 `roleRetries++` 并走一次重置换人重选（`pickSeed` 叠加 `roleRetries`，保证换到不同的人），20 次后才失败。
7. **停**：`Group::Disband(true) → sObjectMgr.RemoveGroup → delete`，逐个 `LogoutPlayerBot`，并恢复路线开关/活跃度优先级。

## 二·五、全图怪物清单（与服务器共享 ObjectMgr）

- 数据源**只有一份**：`sObjectMgr.DoCreatureData()`（启动时加载的 `creature` 全表，与 grid 是否加载无关）
  + `sObjectMgr.GetCreatureTemplate(entry)` 的静态属性；不新建表、不重复读库存。
- `dungeonroute::RosterOf(mapId)`：每图首次访问建 `guid -> (CreatureData const*, CreatureInfo const*)` **指针索引**并缓存，
  日志：`[DUNGEONROUTE] 全图怪物清单 map=…：刷点 N（敌对 x / 小动物 y / NPC z / 无模板 w）`。
- 用途：
  1. 选目标前排除小动物 / 任务 NPC（运行期 `CanAttack` 之外的静态兜底）；
  2. 统计波里的**数据缺口**（运行期动态刷怪 `9,000,xxx` 不在 ObjectMgr）：
     `[DUNGEONROUTE] map … 波成员 …：数据缺口(动态刷怪) … / 小动物 … / 非敌对NPC …`；
  3. 后续"策略层知道副本里总共有什么怪"的唯一数据源（可达性预计算/进度口径都从它来）。
- 小动物已在**数据源头**处理：`route_v2.py`（候选查询）、`patrol.py`、`dungeon_route_gen.py` 全部加
  `AND t.CreatureType <> 8`；本地波次表已删 1041 行小动物（547 从 34 波降到 30 波）。


## 三、候选池与职能

- 候选池 SQL：`characters` ⋈ `ai_playerbot_random_bots(owner=0)`，**排除** `event='add'`（轮换池，会被 `ProcessBot` 随机传送/换策略）、排除已在队伍里的、排除已在线或在别的 run 里的；
- 等级门槛取 `areatrigger_teleport.required_level`；
- 选人：1 个坦克职业（战/骑/德/死骑）+ 1 个治疗职业（牧/骑/德/萨）+ 其余 DPS，**同阵营**（`Player::TeamForRace`）；
- **真坦真奶**（2026-10-18 站长口径："只用正确的坦克和治疗"）：每组先多登 3 个候选，登录后按
  `PlayerbotAI::IsTank` / `IsHeal`（天赋专精 → 默认策略）分类，只挑**真专精**的坦/奶组队；
  选不到就明确报错（日志列出每个候选的真实职能），**不再强挂** `tank assist` / `holy` / `pull`；
  组队后每 5 秒只做校验（真坦/真奶掉了策略就 WARN），不改策略。
- 拉怪链路（`PullStrategy` 的远程起手）目前只有真·防护坦才有；**完整的拉怪链路还没做**，
  暂时在 `DungeonRoutePullAction` 里退回 `attack anything`（直接开怪），日志 `[DUNGEONROUTE] ... 退回直接开怪`。

## 四、本地跑测脚本

`_agent_tmp/wsl_sim_sim.sh [秒数=720] [map=547] [组数=1] [人数=5] [policy=reset] [attempts=3] [seed=0] [stuck=秒]`：

- **秒数=0** ⇒ 无限跑（脚本不再计时收工，直到手动 kill / `.rndbot sim stop all`）；**attempts=0** ⇒ 灭团/卡死都自动重置继续，永不结束。

1. 备份并改写 `/root/run_local/aiplayerbot.conf`：`SimMode=1`、`RandomBotAutologin=0`（关轮换、减噪音）、`DungeonRoute=1`、`AutoDungeonRun=0`（仿真自己传送，不靠世界自动进本）、`DisableActivityPriorities=1`（否则实例里 non-combat 会走 minimal ⇒ route 触发器被跳过）、`ReactDelay=40`、`GlobalCooldown=300`（仿真提速）、`MapUpdate.Threads=4`（多实例并行 tick）；
2. 起 mangosd，stdin 接 FIFO，**必须带 `--aiplayerbot=<run_local>/aiplayerbot.conf`** —— 默认路径是编译期 `SYSCONFDIR="../etc/aiplayerbot.conf"`（即 `/root/etc/`），改错文件就等于没改（`--aiplayerbot` 之前写的是不生效的 `_PLAYERBOT_CONFIG`，已修）；
3. 通过 FIFO 发 `.rndbot sim start <map> <groups> <party> policy=… attempts=… seed=…`，然后**每 15 秒轮询"各组是否已结束"**（`[SIM] run=… done|FAILED map=`），全部结束或到时限就收；
4. 打印 attempt 记录、`best=x/34` 汇总、`[PULL]`（含 cleared/left）、combatlog 行数，最后恢复配置。

## 五、已知问题 / 排查顺序

| 现象 | 先看 | 处理 |
|---|---|---|
| 没有 `[SIM] start` | 日志里有没有 `[SIM] AiPlayerbot.SimMode = 1` | 没这行 ⇒ conf 指错了（见 §四 第 2 条） |
| 登录超时 | `[SIM] run=... FAILED ... 登录超时` + bot 名字 | 候选池/账号问题；本地库要有 ≥5 个 level 够的随机 bot 角色 |
| 进本超时 | `[SIM] ... diag` | 看 `leader/lastError`；实例绑定只由队长创建，队长必须先落地 |
| 进本了但不打 | `[SIM] ... diag route ...` 与每行的 `drive=`/`dungeon route=` | `verified=0` 或 `waves=0`（route 表/creature join 缺数据）⇒ 数据问题；`drive=0` ⇒ 坦克策略被洗/不在战斗/地图不是副本 |
| 打起来但没跑位日志 | `[POSITION]` 只在"攻击者 entry 命中各模式表"时才有 | 目标图怪物的 entry 要补进 `ai_playerbot_boss_ability`（§模式表），否则跑位层不触发 |
| 打一波磨很久最后 `left`/零伤害 | `[SIM] ... 目标 15s 零伤害 ⇒ 跳过波 ord=…`、`[PULL] … => left（…）` | 该波有"打不到/不可达/脱战残留"的怪：15 秒守卫会跳过并换下一波；长期靠修 mmap / 补波次数据 |
| `cleared` 比例分母含 NPC 波 | `[DUNGEONROUTE] map … 波成员 …` 的"非敌对NPC"行 | 分母是 route 表总波数（会含少量 NPC/数据缺口波），看 `cleared` 绝对值即可 |

## 六、风险与对策

| 风险 | 对策 |
|---|---|
| 云端误开 sim | 配置默认 0 + GM 权限 + 启动审计日志 `[SIM]` |
| 仿真影响真人 | 只在本地 WSL 跑；云端 `SimMode=0`；不新建角色 |
| 候选池 bot 不够 | 明确报错（不会乱拉）；`groups`/`partySize` 有上限 |
| 进程被 kill 留下 DB 里的组 | 正常 `stop` 会 `Disband`；异常退出时残留的队伍行会让这几个 bot 不再进候选池（本地库可手工清 `groups/group_member`） |
| 组队触发自动散队 | 已有修复：路线开启/在副本内不解散；且仿真期间关掉了随机 bot 轮换 |
