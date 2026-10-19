# 真人跳跃 / 电梯标注观测（PlayerNavObs）

> 2026-10-19 站长口径："在服务器上部署一个日志，抓客户端真人跳跃的动作，以及起点和落点，和起点落点的方块，做人工标注。还有电梯的标注。"

## 1. 实现位置（符号名检索，不看行号）

- 采集：`src/game/MotionGenerators/PlayerNavObs.h` → `navobs::OnClientMove()` / `navobs::OnServerJump()` / `navobs::Init()`
- 客户端移动包入口：`WorldSession::HandleMovementOpcodes()`（`src/game/MotionGenerators/MovementHandler.cpp`）
- 服务端跳跃：`MotionMaster::MoveJump()`（`src/game/MotionGenerators/MotionMaster.cpp`，本 fork 原来只有声明没有实现，2026-10-19 补）
- 启动日志：`World::SetInitialWorldSettings()` 调 `navobs::Init()`，日志 `[NAVOBS] …`

## 2. 抓什么

| 事件 | 触发 | 记录 |
|---|---|---|
| 跳跃 | `MSG_MOVE_JUMP`（起跳）→ `MSG_MOVE_FALL_LAND`（落地，兜底"下落标志消失/超时6s"） | 起点 `src_x/y/z` + 落点 `dst_x/y/z`、**起点/落点所在 mmap tile（方块）** `src_tile(_x/_y)`、`dst_tile(_x/_y)`、落差 `dz`、水平 `dist2d`、耗时 `duration_ms` |
| 电梯/升降台 | 移动包竖移特征：水平位移 <0.9 码、持续上下移动、非下落/游泳/飞行；累计竖移 ≥4 码算一次 | 上/下点 `src_*`/`dst_*`、两端 tile、`d_z`、`duration_ms` |
| bot 跳跃 | 服务端 `MotionMaster::MoveJump`（本地仿真用） | 同 jump_obs，`is_bot=1` |

tile 计算（与 mmap 文件名对齐）：`tile_x = 32 - floor(y/533.3333)`，`tile_y = 32 - floor(x/533.3333)`，
`src_tile = tile_x*100 + tile_y`（例：558 入口 → `3231` = `5583231.mmtile`）。

## 3. 数据表（世界库 `tbcmangos`）

- `ai_playerbot_jump_obs`：`verified=0` 待人工标注（1 = 确认可用的跳点样本）
- `ai_playerbot_lift_obs`：`verified=0` 待人工标注（1 = 确认可用的升降台样本）
- 两表都有 `note` 列供标注备注；`is_bot=0` 才是真人客户端样本。

标注后的用途：
1. 汇总成路线"跳点/升降台"数据 `ai_playerbot_route_link`（`DungeonRoute.h → TryRouteLink()` 直接使用）；
2. 反推某张图 mmap 缺哪块/哪层（按 `src_tile/dst_tile` 找 .mmtile）。

## 4. 部署记录（2026-10-19）

- 云端二进制 `md5=a82908dfff03755956ae586904d72cb6`，已按"只传二进制 + 两侧 md5 对齐"部署；
- 部署前闸门：`Sessions online=0`、8086 established=0；
- 重启后验证：`World initialized`、`[NAVOBS] 真人跳跃/电梯标注观测已启用`、8086/3724 监听、`Sessions online: 0`；
- 旧二进制备份：`/opt/mangos/bin/mangosd.bak_<时间戳>`；
- 部署脚本：`_agent_tmp/deploy_navobs.sh`（含在线闸门/DDL/回滚）、`_agent_tmp/navobs_tables.sql`。

## 5. 已知限制

- 电梯识别是"竖移特征"启发式：传送、升降梯、电梯都会命中；按 `duration_ms` 和 `d_z` 人工筛。
- 客户端不是每次落地都发 `MSG_MOVE_FALL_LAND`（TBC 2.4.3 实测视客户端/网络），兜底用"下落标志消失"与 6 秒超时。
- 表中 `is_bot=1` 的样本来自本地仿真/服务端跳跃，**不要**当真人标注数据用。


## 6. boss 战后开关（2026-10-19 站长口径）

站长原话："使用附近开关应该是boss策略，挂在蒸汽地库和毒蛇神殿的boss上。"
"在这些boss战斗结束后，需要点这个开关才能继续。"

实现（**不是**通用的"卡住就开锁"，是挂在 boss_entry 上的策略）：

- 数据表 `ai_playerbot_boss_switch(map, boss_entry, go_guid, go_entry, x,y,z, kind, note)`；
- 运行期 `DungeonRoute.h → FindPendingBossSwitch()`：仅当**该 boss 的刷点已死且见过**、
  队伍脱战、开关未点过时，才让驱动坦克走到开关旁并 `GameObject::Use()`；
  开关没加载（网格未到）最多等 10 秒后跳过，避免卡死；
- 已种数据：
  - 545 蒸汽地窟：`17797 水术师塞斯匹亚` → `5450035 Main Chambers Access Panel`（开主厅门）；
    `17796 机械师蒸汽触发器` → `5450036`（开瓦洛克门）；
  - 548 毒蛇神殿：`21214 深水领主卡拉瑟雷斯` → `5480006 Lady Vashj Bridge Console`；
    `Serpentshrine Console`（185114/185115/185116）暂挂 海德斯/潜伏者/盲眼者，标注 **待站长确认**。

## 7. 电梯位置与"联通两端"（服务器数据可反推）

原理（与 `ElevatorTransport::Update()` 一致）：

1. `gameobject` JOIN `gameobject_template` `type=11` → 电梯刷点（位置 + 四元数旋转）；
2. `TransportAnimation.dbc` → 该 entry 的**局部空间**运动节点 `(TimeSeg, X, Y, Z)`；
3. 世界坐标 = 四元数旋转(局部节点) → **y 取反** → 加刷点位置（TBC 的符号约定）；
4. 取世界 Z 最低/最高的两个节点 = **电梯联通的两端**。

工具：`dev/tools/gen_lift_links.py`（读 `_agent_tmp/elevator_spawns.tsv` + `TransportAnimation.dbc`），
产出 `ai_playerbot_route_link(kind=1)` 的 SQL；已导出 48 个电梯/运输平台并写入本地库与
`dev/189_副本导航_跳点与升降台.sql`。

实例：
- 548 毒蛇神殿：`183490` → (-59.1,-98.8,-52.9) ↔ (-59.1,-98.8,7.2)（dz=60）；
  `183407` → (50,0,-72.1) ↔ (50,0,820.3)（dz=892，大厅升降梯）；
- **554 能源舰：服务器数据是占位符** —— `gameobject` guid 5540001（entry 183788 `Doodad_FactoryElevator01`）
  位置为 (0,0,0)，且 `ScriptDevAI/scripts/outland/tempest_keep/the_mechanar/mechanar.cpp`
  明确注释 "Elevator needs core support" ⇒ **服务端 DB 拿不到真实位置**。
  解决顺序：① 用 `ai_playerbot_lift_obs`（已部署）抓真人坐电梯的上下点；② 补核心支持/正确刷点；③ 客户端数据反推。
