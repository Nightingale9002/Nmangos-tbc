# 已知问题记录 (KNOWN ISSUES)

> 本文件记录服务器遇到的已知问题及排查信息，供后续会话接续处理。
> 更新时间: 2026-08-18

---

## [地图] 湿地·维尔加挖掘场桥 — 宠物/服务端单位站到桥下

### 现象
- 玩家站在**湿地维尔加挖掘场 (Area 118)**的一座**模型桥 (WMO)**上时，跟随的宠物 (以及任何由服务端计算位置的单位) 会**绕路走到桥下地面**，而不是站到桥面上。

### 玩家坐标（桥面）
```
Map: 0 (东部王国)  Zone: 11 (湿地)  Area: 118 (维尔加挖掘场)
X: -3438.508   Y: -1787.874   Z: 23.84 (桥面)
GroundZ: 16.39  FloorZ: 16.39 (桥下地面)
```

### 判定结论
- 桥是**模型桥 (WMO)**，有栏杆/桥墩/独立模型（非 GameObject，DB 里查不到 Bridge GameObject）。
- **玩家位置 = 客户端计算**（有桥面碰撞，能站桥上）。
- **宠物/生物位置 = 服务端计算**，服务端在桥位置读到的地面高度是 **16.39 (桥下)**，而非桥面 23.84。
- 桥所在 tile 的 vmap/.map 数据**实际都存在**（见下 vmap tile 分析修正），但服务端高度查询 (GetHeightInRange) 在该点仍读回 **16.39 (桥下)**，未命中桥面 23.84。
  → 属于 vmap 内**桥面 WMO 层未被服务端高度查询命中**（同类多层地形问题，与 Duskwood 洞穴案同源）。

### vmap tile 分析（2026-08-18 已修正）
> 早期误用未翻转坐标认为 tile 缺失，实际是查错了文件名。

- 桥坐标 (-3438.5, -1787.9)：grid=(25,28) → **翻转后 gx=38, gy=35**（见本文档[机制]章）。
- **对应文件实际都存在**：.map=`0003835.map`、.vmtile=`000_35_38.vmtile`、.mmtile=`0003835.mmtile`。
- 之前记录的 `000_28_25.vmtile` (未翻转) 不是服务端真正读取的文件，所以"缺失"是误报。
- 真正问题：vmap 存在但服务端 GetHeightInRange 未命中桥面 → 桥面 WMO 碰撞层未写入/未被查询到。

### extractor 日志（08-16 全量生成）
- extractor 正常完成 (DBC/地图/vmap/mmaps 均成功)。
- 湿地 WMO 均被 Converting；桥所在 tile 的 vmtile 已生成（000_35_38.vmtile 存在），此前'未生成'是查错文件名的误报。

### 待办/方向（未处理）
- [ ] 确认这座桥的具体 WMO 文件名（ADT 解析未完成）。
- [ ] 顺 GetHeightInRange 排查：为何 vmap 数据存在却未命中桥面（多层取层，与 Duskwood 洞穴案同源）。
- [ ] 若只是个别桥受影响，可考虑 DB 悬浮 GameObject 规避（不优雅，待定）。

---

## [机制] 地图瓦片 (Map/VMap/MMap) 编号与命名规则

> 本节的目的是把服务端"世界坐标 → 瓦片文件"的换算、以及三个文件类型的命名差异讲清楚，
> 供排查地形/穿地问题复用。此前多起"瓦片缺失"的结论都源于把文件名的 x/y 顺序看反了。

### 1. 世界坐标 → 服务端网格 (grid)

定义 (src/game/Maps/GridDefines.h)：

```
SIZE_OF_GRIDS = 533.33333   (每个 grid 的码数)
MAX_NUMBER_OF_GRIDS = 64
CENTER_GRID_ID = 32

grid_x = int( (x - 266.67) / 533.3333 + 32.5 )
grid_y = int( (y - 266.67) / 533.3333 + 32.5 )
```

服务端加载该 grid 时会把坐标**翻转** (src/game/Maps/Map.cpp:356-357)：

```
gx = (MAX_NUMBER_OF_GRIDS - 1) - grid_x = 63 - grid_x
gy = (MAX_NUMBER_OF_GRIDS - 1) - grid_y = 63 - grid_y
LoadMapAndVMap(gx, gy)
```

**关键：后面所有文件名里的数字，用的都是翻转后的 gx/gy，不是原始的 grid_x/grid_y。**

### 2. 三个文件类型的命名（数字顺序不同！）

| 类型 | 文件名格式 | 数字含义 | 出处 |
|---|---|---|---|
| 地形 .map | `maps/%03u%02u%02u.map` = `<mapId><gx><gy>` | **gx 在前**（x 是第 1 个两位数） | src/game/Maps/GridMap.cpp:1264 |
| vmap .vmtile | `vmaps/%03u_%02u_%02u.vmtile` = `<mapId>_<gy>_<gx>` | **gy 在前**（与 .map 相反） | src/game/vmap/MapTree.cpp:89 |
| mmap .mmtile | `mmaps/%03u%02u%02u.mmtile` = `<mapId><gy><gx>` | **gy 在前**（同 vmap） | contrib/mmap/src/MapBuilder.cpp:979 |

> ⚠️ **最容易踩的坑：.map 是 gx 在前，而 .vmtile/.mmtile 是 gy 在前。**
> 同一个位置，.map 和 .vmtile 文件名的两位数顺序正好相反。
> 例子：Duskwood 某点 → .map=`0005131.map`、.vmtile=`000_31_51.vmtile`，数字互反。

### 3. 换算生效的关键（为何不能只看范围/猜测）

- 判断某个位置有没有数据，**必须用翻转后的 (gx,gy) 查文件**，不要拿原始 grid 或直接猜。
- 例：Duskwood 乌鸦丘洞穴 (-10335, 164)：grid=(12,32) → gx=51, gy=31 →
  `.map`=`0005131.map`(存在)、`.vmtile`=`000_31_51.vmtile`(存在)、`.mmtile`=`0005131.mmtile`(存在)。
- 检查"有没有 vmap"时，用 `GridMap::ExistMap/VMap(map, gx, gy)` 或直接查上面三个文件。

### 4. 规模参考（东部王国 map=0，本地+云端一致）

- 地形 .map：**687 个**，gx 24~44，gy 20~61。
- vmap .vmtile：**354 个**，vmtile 覆盖 gx 23~60 / gy 27~42。
- mmap .mmtile：2774 个（全地图合计；map0 的瓦片覆盖与 .map 一致）。
- **vmtile 数量 < .map 数量是正常的**：只有含可碰撞模型（建筑/桥/洞穴）的 tile 才有 vmap，纯地形/开阔海面没有 vmap。已验证：**所有 354 个 vmtile 都能找到一一对应的 .map**（`vmtiles_without_map = 0`），符合"vmap 从 ADT(.map) 提取，不可能有 vmap 却没 map"。

### 5. 本次 Duskwood 乌鸦丘洞穴穿地案的关键结论（2026-08-18）

- 生物 4964 (Flesh Eater)/6094 (Rotted One)，map 0，spawndist 10，MovementType 1。
- 出生点：(-10336.7, 139.7, **Z=34.17**) / (-10335.2, 164.2, **Z=36.06**)。
- 解析 .map 得该点地面高度：34.17 / 36.02 —— **出生点精确站在地表**（△<0.05）。
- 该 tile 三种数据（.map/.vmtile/.mmtile）**全部存在**。
- **结论：不是数据缺失**。出生点旁就是一个地下墓穴/洞穴（其内生物 Z≈0~16，地表 ~34，差值 20~30 码），即**多层地形**。
- 可能的根因方向：`GetHeightInRange`(Map.cpp:2796) 在洞穴/洞口多层处取层/取值错误（见其 2822 行注释），或随机游走路径点 Z 在该处不被正确修正。
- 已在 `RandomMovementGenerator.cpp::_setLocation` 的反掉落修正里加诊断日志（`[WANDERDBG]`，entry 3/948 触发），待重编译部署后观察 `GetHeightInRange` 返回值。

---

## [寻路] 全部寻路相关修改汇总（commit + 工作区改动，截至 2026-08-19）

> 本章按时间顺序汇总本 fork 所有针对**寻路/穿地/多层地形**的改动（已提交的 commit + 尚未提交的工作区修改）。
> 相关文件：MotionGenerators/（Random/Waypoint/Chase/Follow/PathFinder）、vmap/（MapTree/ModelInstance/WorldModel）、Maps/GridMap.cpp、Maps/Map.cpp。

### 0. 工作区未提交改动（本次会话，2026-08-19）

```
git status:  M dev/KNOWN_ISSUES.md
             M src/game/Maps/GridMap.cpp                            <- GetHeightStatic 多层取层修复 + HEIGHTDBG 日志
             M src/game/MotionGenerators/PathFinder.cpp             <- [RANDDBG] 调试日志
             M src/game/MotionGenerators/RandomMovementGenerator.cpp <- [WANDERDBG] 调试日志（含 FAR 距离过滤）
```

**（A）`GridMap.cpp::TerrainInfo::GetHeightStatic`（828~933 行）— 多层地形取层修复（核心）**

背景：`.go name`/宠物跟随/`.gps floor_z`/`UpdateAllowedPositionZ` 全部走 `Map::GetHeight → GetHeightStatic`。
原实现**没有 vmap 高度与 z/.map 地表的接近性判断**，且 vmap 搜索失败后会用 **10000 码无限向下搜索**——
在荒弃鬼屋/乌鸦丘这类"地表 + 地下墓穴"多层处，射线穿透地表洞口命中地下层（15.68），
且 `if (z < mapHeight) return vmapHeight` 因浮点微差（z=59.71 vs mapH=59.69）误判 → 单位被拉到地下。

修复（两处）：
- **[FIX-1] 限制 10000 无限搜索**：当 `mapHeight 有效 && z2 > mapHeight`（调用者位于 .map 地表上方）时，
  兜底搜索距离封顶为 `z2 - mapHeight + 2.0f`（地表附近 + 2 码余量），不再无限穿到地下层；
  调用者位于地表下方（洞内怪）时保留 10000（需穿透找洞内地板）。
- **[FIX-2] 选择逻辑加接近性判断**：
  ```
  vmapCloseToZ   = |vmapHeight - z|        <= 1.0f   // 洞内怪 z 与洞底差 0.00~0.06 码，安全放行
  vmapCloseToMap = |vmapHeight - mapHeight| <= 3.0f   // 同层差 <1 码；跨层（地表 vs 地下）差 >20 码
  两者都不满足 → 用 mapHeight（.map 地表），拒绝远层 vmap
  ```
  - 阈值依据（本地实测日志）：同层（地表↔地表、洞底↔洞底）vmap 与 .map 差 **<1 码**（0.00~0.06）；
    跨层（地表↔地下）差 **>20 码**（如 59.69 vs 16.03 差 43.7）。3.0 可严格区分，即使两层只差 ~10 码也不会混淆。
  - closeToZ 用 **1.0**：怪不会跳跃，单位永远贴自己那层的地面（差 <0.1 码），1.0 足以放行洞内怪，
    同时把"下落单位经过错误层被吸住"的窗口压到 ±1 码。
  - 洞内怪不受影响：比较对象是 vmap 与 **z**（单位自己的 z），洞深不设上限。

- **[HEIGHTDBG] 防刷屏日志**（912~932 行）：仅 map 0 + Raven Hill 区域（x∈[-10500,-10100], y∈[50,450]）；
  只打"危险决策"（`|z-mapH|<=5 && vmapH < mapH-20`，即地表单位却收到地下层）；每秒最多 1 条 + 每 10 码 1 条。

验证（本地部署后 Server.log，23:33 起）：
- 地表单位：`z=59.71 mapH=59.69 vmapH=16.03 -> 59.69 (closeZ=0 closeMap=0)` —— 拒绝地下层，站回地表 ✓
- 洞内单位：`z=3.42 mapH=32.70 vmapH=3.46 -> 3.46 (closeZ=1)` —— 正常站洞底 ✓
- 荒弃鬼屋地表：`z=61.69 mapH=59.77 vmapH=15.69 -> 59.77` —— 云端 `.go name` 传送到 15.68 场景的本地复现被修复 ✓
- 用户实测：荒弃鬼屋放宠物跟随，**不再跑地下**；观察无怪掉下来 ✓

**（B）`PathFinder.cpp::ComputePathToRandomPoint` — [RANDDBG] 调试日志（1433~1524 行）**
- 目标：追踪随机漫步随机点生成异常（此前观察到 path 里出现数千码外的垃圾点）。
- 只对 entry 3/210/948 打印：起点/当前点/终点/range/centerPoly/distToPoly；`getPolyHeight` 后终点若距起点 >100 码再打一条。
- 距离过滤（>100 码才打）避免刷屏；结论：本地触发时无输出，垃圾点生成与 mmap 数据无关，非本修改引入。

**（C）`RandomMovementGenerator.cpp::_setLocation` — [WANDERDBG] 调试日志（119~159 行）**
- 对每条路径点做 `GetHeightInRange` Z 修正（来自 commit b82434357，见下），并加日志：
  只在距锚点 >100 码的点打印（FAR pt + z:before→after + GetHeightInRange 成功与否），防刷屏。
- 结论：此前完整日志 95,917 行刷屏；距离过滤后 0 行——垃圾点/掉地不发生在随机漫步取点处。

### 1. commit `b82434357 防止怪物掉到地下`（2026-08-14）

```
RandomMovementGenerator.cpp  +9    _setLocation: 路径所有点 GetHeightInRange(p.x,p.y,p.z) Z 修正
WaypointMovementGenerator.cpp +9   SendNextWayPointPath: 巡逻路径所有点同上
```
- 背景：随机漫步/巡逻怪偶发掉到地下，猜测路径点 Z 与地面不符。
- 做法：对非飞行/非悬浮/非潜水的地面单位，把路径每个点 Z 用 `GetHeightInRange` 吸到实际地面。
- 局限（后续发现）：`GetHeightInRange` 本身在多层地形处可能选错层（→ 本次会话改为修 `GetHeightStatic`，见 0-A）。

### 2. commit `3e3173fd7 修复寻路`（2026-08-15）— 核心寻路修复

```
PathFinder.cpp                +76  终点贴 navmesh 表面 + 同 poly 距离校验 + smooth path 高度修正 + NOPATH 语义
TargetedMovementGenerator.cpp  +65  Chase 去除手动楼层吸附；Follow 路径点 Z 修正 + 陡段 LOS 校验
MapTree.cpp/MapTree.h          +11  射线回调加 frontFacesOnly 参数
ModelInstance.cpp/.h            +4  intersectRay 透传 frontFacesOnly
WorldModel.cpp/.h              +31  高度查询只接受 60° 内的"朝上面"（墙/天花板背面/悬挑不算地板）
```
- **PathFinder.cpp**：
  - `calculate`：无 mmap tile 时，飞/游/悬浮/`IGNORE_PATHFINDING` 才走 shortcut；其余地面单位标记 `PATHFIND_NOPATH`（不再直线穿墙）。
  - `BuildPolyPath`：路径终点 `closestPointOnPoly` 贴 navmesh 表面（防终点在模型斜面下/上方导致穿模或空中抬升）。
  - `startPoly==endPoly`：两点都必须在 poly 表面 1.5 码内，否则 NOPATH（防多层 poly 桥接楼层时直线穿空气）。
  - `findSmoothPath`：iterPos/targetPos 用 `getPolyHeight` 补高度（closestPointOnPolyBoundary 不改高度）。
- **TargetedMovementGenerator.cpp**：
  - Chase：删除原"怪物走空气"的楼层吸附 hack（改由 PathFinder 终点贴面处理）。
  - Follow：路径每点 `GetHeight(p.x,p.y,p.z)` 修正 Z；若 vmap floor 比 navmesh 低 2 码以上（落到下层）则跳过不拉低；
    相邻点 Z 差 >3 码且 LOS 不通 → 路径非法，阻止宠物穿墙/穿洞。
- **vmap**：`getHeight` 射线只认 60° 内的朝上面（`frontFacesOnly`），墙/天花板背面/悬挑不再被当作"地板"。

### 3. commit `973ba7ae2 修复怪物走空气`（2026-07-17）→ `e3d85ffd9 Revert`（2026-08-17）

- 最初在 `ChaseMovementGenerator::_getLocation` 加"目标点楼层吸附"：`GetHeight(x,y,groundZ)` 成功且
  `|groundZ-ownerZ|<6` 或 `|z-targetZ|>5` 时 `z=groundZ+0.5f`，失败回退 ownerZ。
- **已 revert**（8-17）：该 hack 与后续 PathFinder 终点贴面冲突/过度吸附，删掉后由 `3e3173fd7` 的正式方案替代。

### 4. commit `dbec01ae2 修改mmap卸载`（2026-08-18；另有同内容 `6ccfb0f69`）

```
MoveMap.cpp +26  TrimMmapMemory(): 卸载 mmtile/.mmap/query 后 30 秒节流的 _heapmin()/malloc_trim(0)
```
- 背景：mmap 卸载后堆保留空闲页，RSS 不降。
- 做法：`MMAP::unloadMap` 三处卸载路径后调 `TrimMmapMemory()`（Windows `_heapmin` / Linux `malloc_trim`），30 秒节流。
- 备注：同名 commit 出现两次（`dbec01ae2`/`6ccfb0f69`）为相同改动，勿重复合入。

### 5. commit `a10ae3aa4 水下路径修复`（2026-08-18）

```
PathFinder.cpp                +31  水中单位：无 tile 走 shortcut、终点不贴面、同 poly 直接 shortcut
TargetedMovementGenerator.cpp +87  Chase 水下：跳过距离/LOS/z 检查直游；RefineWaterPath 细分泳线贴地形
```
- **PathFinder**：`calculate` 加 `IsInWater()` 条件（水中也允许 shortcut）；`BuildPolyPath` 终点贴面排除水中单位
  （避免把水下目标拖到 navmesh 表面=海底）；同 poly 时水中直接 shortcut 不走表面校验。
- **Chase**：追单位在水中时跳过所有陆地检查（距离/LOS/z 差/非水）直线游向目标；navmesh 无水下路径时
  退化为 start→end 两点直游；`RefineWaterPath` 按 `SMOOTH_PATH_STEP_SIZE` 细分泳线，每点夹在
  `[floor+0.5, 水面]` 区间，防潜水单位扎进海底卡住。
- **Follow**：`GetHeight` floorZ 修正对水下单位豁免（不拉低）；NOPATH 处理对水中单位豁免。

### 6. 结论与遗留

- **掉地根因链**：`GetHeightStatic`（.go name/宠物/UpdateAllowedPositionZ 共用）在多层地形无限向下搜索
  + 无接近性判断 → 选到地下层。已修（0-A）。
- **随机漫步垃圾点**（数千码外）：`[WANDERDBG]`/`[RANDDBG]` 距离过滤后本地 0 输出，与 mmap 数据无关；
  若再出现，从 `ComputePathToRandomPoint` 的 `getPolyByLocation`/`getPolyHeight` 返回值方向排查（日志已就位）。
- **待办**：本次工作区改动（0-A/B/C）尚未 commit；确认本地验证充分后建议提交，再同步到云服（Linux 需重新编译）。

---

## [内存] mangosd 内存持续增长（active 怪网格永不卸载）— 2026-08-20 已修

### 现象
- 云端 mem_monitor.log：每次重启后 mangosd 以 **25-80MB/小时** 持续增长，峰值 1485-1539MB 后 OOM 崩溃（load 飙到 27+）。
- 8-16 20:25→20:45 玩家外域移动：20 分钟 +680MB。
- 无玩家时段也涨（8-17 14-18h：1402→1465MB）——非玩家活动引起。

### 根因链（通过 [GRIDDBG] 日志证实）
1. **`Autoload.Active = 1`**（配置）→ 启动时 `ObjectMgr::LoadActiveEntities` 对 227 个
   `CREATURE_EXTRA_FLAG_ACTIVE` 怪物的坐标调 `ForceLoadGrid` → **启动即加载 74 个网格/9479 只怪**。
2. `ForceLoadGrid`（Map.cpp）调用 `setUnloadExplicitLock(true)` **永久锁定**网格（上游 cmangos 原版问题，
   无任何地方调用 false 清除）。
3. active 怪的事件 AI **无玩家也在运行**（这正是 active 的意义）→ 跨网格移动/召唤 →
   `EnsureGridLoadedAtEnter` 加载新网格 → 网格含 active 怪 → `ActiveObjectsInGrid()>0` +
   `ActiveObjectsNearGrid()`（检查 `m_activeNonPlayers`）→ **网格永不转 IDLE/永不卸载**。
4. 循环：网格只增不减 → 内存无限增长。

实测（本地 GRIDDBG）：启动后无玩家，网格 74→86（+12），怪物 9479→10957（+1478），全部 playersInMap=0。

### 修复（2026-08-20，本地验证有效）
1. **`ForceLoadGrid` 去掉 `setUnloadExplicitLock(true)`**（Map.cpp）——该锁由
   `AddToActive`/`RemoveFromActive` 的 `inc/decUnloadActiveLock()` 引用锁覆盖，冗余且泄漏。
2. **`Map::ActiveObjectsNearGrid` 只检查玩家 + transports**（Map.cpp）——移除 `m_activeNonPlayers`
   检查（active 怪不再阻止网格卸载）。
3. **`GridStates.cpp` ActiveState::Update**：转 IDLE 只依据 `!ActiveObjectsNearGrid`（即玩家/transport），
   去掉 `ActiveObjectsInGrid()==0` 条件。
4. **Transport 保护**：`ActiveObjectsNearGrid` 对 `m_transports`（船/飞艇/电梯）所在网格返回 true——
   运输工具是地图级对象，网格卸载会删除其所在网格，故必须保留（防载具消失）。
5. **`Autoload.Active = 0`**（云端+本地配置）：启动不再预加载 active 网格。

### 验证结果（本地）
| 配置 | 启动内存 | 启动网格 | 10分钟增长 |
|---|---|---|---|
| Autoload.Active=1（修复前） | ~1180MB | 74 | 25-80MB/小时 |
| Autoload.Active=0（修复后） | ~600MB | 1-3 | ~9MB/10分钟 |

- 启动内存 **省 ~600MB（50%）**；网格加载从 74 → 1-3（仅 transport 网格）。
- 行为变化：**完全懒加载**——无玩家时网格（含 active 怪）卸载，事件怪只在玩家附近活动
  （玩家离开区域 → 网格卸载 → 事件怪消失，回到懒加载语义）。用户确认接受此权衡。

### 遗留/注意
- `[GRIDDBG]` 日志（Map.cpp LoadN/Unload、ObjectGridLoader LoadN）**保留**，便于云端检查网格加载/卸载。
- 云端需等凌晨脚本编译部署新二进制 + `Autoload.Active=0` 配置（已改 `/opt/mangos/bin/mangosd.conf`，
  备份 `mangosd.conf.bak_autoload_20260820_022208`）。
- 若未来需要 active 怪无玩家推进事件（如跨服事件），需重新评估此改动。