# 已知问题记录 (KNOWN ISSUES)

> 本文件 = **Bug 修复手册 / 已知问题与技术笔记**（随源码提交）：记录服务器遇到的已知问题、排查信息、已修复项与技术性内容（含水中移动、寻路、地图瓦片等），供后续会话接续处理。
> 功能性更新见同目录《功能更新手册_卡布魔兽.md》；运维内容见本地《HANDOFF_卡布魔兽运维.md》（不提交）。
> 技术性笔记一律写入本文件（不再另开 md），仓库根/根目录散落的旧技术 md 已陆续归并。
> 更新时间: 2026-08-25

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

## [任务] 击杀计数类任务"不计入进度"排查 — 2026-08-20 数据核实
### 现象（用户报告，待实测确认）
- 2459 Ferocitas the Dream Eater：杀 7235 不计入（用户自述"存疑，插件没提示但已完成"）
- 9594 Signs of the Legion（军团徽记）：杀纳兹维安萨特(17337)不计入
- 9569 Containing the Threat（化解危机）：杀阿克萨林暗影行者(17494)不计入

### 数据核实结论（本地=云端=原版 tbcmangos_orig，三库一致）
| 任务 | 击杀目标 | 数量 | 位置 |
|---|---|---|---|
| 2459 | 7235 Gnarlpine Mystic | 7 | ReqCreatureOrGOId2 |
| 9594 | 17337 Nazzivus Satyr + 17339 | 8+8 | ReqCreatureOrGOId2/3（另需物品 23900×1）|
| 9569 | 17494 Zevrax | 1 | ReqCreatureOrGOId1 |

**推断**：任务数据本身正确，击杀目标在 Id2/Id3 列（非 Id1）——客户端任务插件通常只显示/追踪第一个目标槽，
可能因此误报"不计入"。2459 用户已完成佐证服务端在正常计数。
### 待办
- [ ] 玩家实测 9594/9569：确认击杀后服务端计数（插件进度条可能不显示）
- [ ] 若实测确实不计入：查 ObjectMgr 击杀计数代码（creature 死亡时 quest 统计），确认是否只处理 Id1

## [机制] 任务物品 maxcount 服务端强制（014/016 修正）— 2026-08-20
### 结论
- 服务端**本来就有** maxcount 强制：Player::_CanTakeMoreSimilarItems（Player.cpp:9091-9101）
  所有进包途径（拾取/交易/商人/邮件/任务奖励）都检查"背包+银行总持有量 ≤ maxcount"，
  超限返回 EQUIP_ERR_CANT_CARRY_MORE_OF_THIS（"你不能再携带更多该物品"）。
- 原版（tbcmangos_orig）任务物品 maxcount 只有 0（无限，44.5%）或 1（唯一标记，55%），
  **没有"任务所需数量"这种值**；10639 原版 maxcount=0（无限拾取是原版行为）。
- 014 将 maxcount 设为"任务所需"是自定义限制，但**误伤货币类**（ZG硬币/声望徽章等 107 个
  stackable≥100 物品被限死，如 Zulian Coin maxcount=1）。
- 016 修正：只对被【不可重复任务】(SpecialFlags&1=0) 引用的物品设 maxcount=MAX(任务所需)；
  被可重复任务引用的（货币/兑换品）恢复 maxcount=0。

### 016 执行结果（本地）
- 10639=7、10641=4（不可重复任务 → 限制）✓
- Zulian Coin/Argent Dawn Token/Mark of Kil'jaeden=0（可重复 → 不限）✓
- 货币类残留受限=0；被限任务物品 2514 个
- 21100 Coin of Ancestry=5（农历新年任务 SpecialFlags=0 判不可重复，需确认是否额外排除）

### 待办
- [x] 云端执行 016（合并版，2026-08-20 已执行；014 已废弃删除）
- [ ] 确认 21100 是否保留限制（农历新年任务 SpecialFlags=0 判不可重复，限 5）

### 2026-08-20 追加：改用官方机制（放弃任务销毁任务物品）
用户指出：核心诉求是"完成任务/放弃任务后，背包里不应残留垃圾任务物品"——这正是官方机制。
- **官方 2.4.3 行为**：
  - 任务物品无持有上限（maxcount=0，可无限拾取）。
  - **放弃任务**：客户端 UI 提示"将摧毁以下物品"（物品 ID 来自服务端
    SMSG_QUEST_QUERY_RESPONSE 下发的 ReqItemId），服务端销毁该任务 ReqItemId **全部持有量**（防囤积）。
  - **完成任务**：只扣所需数量，多余任务物品保留（玩家自行卖店/摧毁/再交）——官方原版如此。
- **cmangos 缺陷**：`HandleQuestLogRemoveQuest`（放弃任务）只销毁 ReqSourceId（源物品），
  **漏了 ReqItemId（收集物品）** → 玩家放弃任务后任务物品保留 → 囤积/占包。
- **代码修复（本地已改 + 编译通过）**：
  - `QuestHandler.cpp HandleQuestLogRemoveQuest`：放弃任务时销毁 ReqItemId **全部持有量**
    （`GetItemCount(entry, true)` 含银行）——与客户端 UI 提示一致（官方行为）。
  - `Player.cpp RewardQuest`：**保持官方原版**（只扣所需数量，多余保留），已回滚中间"销毁全部"尝试
    （曾考虑不可重复任务销毁全部，但会误伤通用材料如 Light Leather/铁锭等既被一次性又被可重复任务引用的物品）。
- **maxcount 定位变化**：不再是核心手段，仅作兜底（016 保留）；放弃任务销毁（防囤积）才是正解。
- **maxcount 最终决定（2026-08-20）**：不再用 maxcount 限制任务物品（014/016 全部废弃删除）。
  防囤积靠"放弃任务销毁 ReqItemId"官方机制，完成任务只扣所需（官方原版）。
  014 已 git rm；016 合并版已删除；016b 已恢复本地+云端 1442 个物品为原版 maxcount（flags 2048 保留），本地与原版差异=0。

## [天赋] 战士狂暴·武器掌握 缴械时间减半 — 已解决（2026-08-20，commit ec8dbfef9）
### 结论
- 武器掌握（20504/20505，aura 234 = SPELL_AURA_MECHANIC_DURATION_MOD_NOT_STACK，MiscValue=3 = DISARM；
  等级 1 减 26%，等级 2 减 50%）已生效。
### 根因与修复
- 缴械时长修正链路：Spell::AddUnitTarget → Unit::CalculateAuraDuration 读
  GetMaxNegativeAuraModifierByMiscValue(234, mechanic) → duration = duration*(100+durationMod)/100。
- 修复 1（Spell.cpp AddUnitTarget）：混合法术（36208 窃取武器 = 召唤 + MOD_DISARM）被
  IsAuraApplyEffects 误判（要求所有命中效果都是 aura，召唤不满足）→ 改 IsSpellAppliesAura
  （任一命中为 aura 即计算时长修正）。
- 修复 2（Spell.cpp 施放链路）：holder 时长覆盖用 target->effectDuration，且 originalDuration
  在修改前保存，否则 SetAuraMaxDuration 不生效（曾导致玩家仍 6 秒）。
### 验证
- 实测 36208（窃取武器）对玩家缴械 3000ms（-50% 生效）。

## [任务] 搁浅的海龟 / 搁浅的海洋巨兽 任务物品核实 — 2026-08-21
### 结论（wowhead 核对一致）
- 奥伯丁（Auberdine）搁浅系列任务的**任务物品是复用的**：同一个任务物品被多个任务共用，
  本地数据库与 wowhead（classic）完全一致，属于官方原版行为。
- 任务链：4681 Washed Ashore（被冲上岸，14级）→ 解锁 9 个搁浅任务（13~19级，全在奥伯丁交）。

### 任务 → 物品映射（本地 tbcmangos = 云端）
| 任务物品 | 物品 ID | 使用它的任务 |
|---|---|---|
| Sea Turtle Remains 海龟残骸 | 12289 | 4681（前置）+ 4722 / 4727 / 4732（Beached Sea Turtle）|
| Sea Creature Bones 海洋生物骸骨 | 12242 | 4723 / 4728 / 4730 / 4733（Beached Sea Creature）|
| Strangely Marked Box 奇怪标记盒子 | 12292 | 4725 / 4731（Beached Sea Turtle）|

### 掉落来源（gameobject → loot 表，-100 必掉）
| 尸体游戏对象 | type | loot 表 → 物品 |
|---|---|---|
| 176189 Skeletal Sea Turtle（骨架海龟）| 3 CHEST | data1=12681 → 12289 海龟残骸 |
| 175207 Beached Sea Creature（搁浅巨兽）| 3 CHEST | data1=12620 → 12242 海洋骸骨 |
- 其余搁浅尸体（175226/175227/175230/175233、176190/176191/176196/176197/176198）为 type 2 QUESTGIVER，
  data1=3871~3880 指向**不存在的 quest**（数据冗余，无实际影响）。

### 12292 获取方式（已确认，无问题）
- **12292 Strangely Marked Box 从游戏对象（object）获得**——玩家实测确认可获得，任务 4725/4731 无问题。
- 说明：数据库 loot 表/任务奖励中无 12292 引用是正常的，它由搁浅尸体的 object 交互机制产出
  （wowhead source=4、objective-of=4725/4731 与此一致），**不是 bug**，无需处理。

## [配置] mangosd "Could not find configuration file" 实为 UTF-8 BOM 解析失败 — 2026-08-21 已修
### 现象
- mangosd 启动立即报 `Could not find configuration file mangosd.conf.` 并退出（exit 1）。
- 任何启动方式都失败：PS 直接运行、`cmd /k "cd /d ... && mangosd.exe"`（build_deploy_restart.bat 方式）、
  `-c <绝对路径>` 全部同样报错。
### 排查结论（已定位根因）
1. 配置文件**存在、可读、未被锁定**；工作目录正确（cmd 里 `echo %CD%` = x64_Debug）。
2. 同目录 `mangosd.conf.dist` 用 `-c` 能正常加载（banner 正常输出）→ 问题出在 mangosd.conf 这个**文件本身**。
3. `copy mangosd.conf testA.conf` 后 `-c testA.conf` 同样失败 → 内容/编码问题，与路径、属性、占用无关。
4. 字节对比：mangosd.conf 前 3 字节 = `EF BB BF`（**UTF-8 BOM**）+ 全文件几乎全是 LF 换行（CRLF 仅 1 处）；
   mangosd.conf.dist 无 BOM、CRLF 换行。
- **根因**：`Config::Reload`（src/shared/Config/Config.cpp）解析时**每一行必须含 `=`，否则直接 `return false`**
  （第 73 行 `if (equals == std::string::npos) return false;`）。第一行是 BOM+注释 `###...`，
  `boost::trim_left` **不去 BOM** → line[0]=0xEF 不是 `#` → 当作配置行找 `=` → 找不到 → return false →
  Main.cpp 报 `Could not find configuration file`（**误导性报错，实际是解析失败，不是文件缺失**）。
- **BOM 来源**：2026-08-21 13:08 用 PowerShell 5.1 `Set-Content -Encoding UTF8` 重写该配置时**自动加了 BOM**
  （PS 5.1 的 UTF8 编码默认带 BOM；且 Set-Content 重写后换行也变成了 LF）。
### 修复
- 去掉文件头 3 字节 BOM（`[System.IO.File]::ReadAllBytes` 后写 `bytes[3..]`）→ 启动恢复正常。
- 已留备份：`x64_Debug/mangosd.conf.bak_bom_20260821`（含 BOM 的原文件）。
### 教训（重要）
- **改配置文件（mangosd.conf/anticheat.conf/realmd.conf 等）不要用 `Set-Content -Encoding UTF8`**（PS 5.1 会加 BOM，
  而本 fork 的 Config 解析器不兼容 BOM → 启动报"找不到配置"）。
- 安全方式：`[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`
  （无 BOM）或保持原编码（ANSI/GBK）用 `-Encoding Default`；编辑后用 `mangosd -c <路径>` 快速验证。
- 附带现象：13:14 曾出现 31MB 的 Debug 版 mangosd.exe 被部署到 x64_Debug（配置查找行为正常，仅体积差异）；
  13:21 用户重跑 build_deploy_restart.bat 后已恢复为 Release 版（10MB）。

---

## [寻路] 8-23 全量改动总结（掉坑/卡闪避/生成规则 v8 定稿）

> 涉及 commit：`ef57762d9`（修复寻路）、`1338e458c`（更新mmap生成规则）、`33fe41ec4`（版本号 8→9，后定回 8）。
> 根目录旧报告 `mmap_掉洞飘顶调查报告.md`（8-19）已被本手册章节取代。

### 一、运行时修复（src/game，与 mmap 数据无关，编译即生效）

| 文件 | 改动 | 解决的问题 |
|---|---|---|
| TargetedMovementGenerator.cpp | **RefineWaterPath 只在 ownerInWater 时调用** | **掉坑根因**：陆地 Chase 也被重采样+GetHeight 覆盖 z，WMO 边缘 GetHeight 穿透到 ADT 深坑（z=-65.7），spline 把怪带进坑 |
| TargetedMovementGenerator.cpp | RefineWaterPath 陆地分支 10 码保护 | 兜底：GetHeight 与 navmesh z 差 >10 不覆盖 |
| TargetedMovementGenerator.cpp | Chase 陆地直线分支禁用（仅 ownerInWater 走直线） | BuildPointPath straightLine 重采样吸附坑 poly |
| PathFinder.cpp | **BuildShortcut 恢复 2 点直线**（撤销"地面单位原地 NOPATH"临时改动） | 无 navmesh tile 的地面怪卡死（卡闪避） |
| PathFinder.cpp | calculate() 无 tile 分支恢复 shortcut（NOT_USING_PATH） | 同上 |
| PathFinder.cpp | ZSnap 兜底：平滑路径点 z 与 unitZ 差 >10 → 拉回 unitZ+0.5 | 防路径点被平滑滑到深坑 |
| Unit.cpp | UpdateAllowedPositionZ 10 码 z 拉回上限 | 防 GetHeight 错层把怪一帧帧拉下深坑 |
| TargetedMovementGenerator.cpp | spline path.size()<2 保护 | 防空路径崩溃（Validate 断言） |

### 二、生成器规则（contrib/mmap + recast，需重新生成 mmtile）

| 规则 | 原版（8/16） | 新规则（v8 定稿） | 影响 |
|---|---|---|---|
| ADT 坡度 | 60° 清除（rcClearUnwalkableTriangles） | **60° 清除（改回原版）** | 虚空 tile 不超限；陡坡无 navmesh |
| WMO 坡度 | 60° 清除（墙=空洞，可穿） | 60° 标 **STEEP 障碍** | 怪不穿墙，绕门走 |
| M2 判定 | 60° 坡度 | **高度**：>1.07码（walkableClimb×0.2667）全障碍；≤1.07 贴地判定 | 柱子/大石头不可爬，矮箱可踩 |
| WMO 覆盖 ADT 检查 | 无（ADT 全保留） | **移除**（我们曾加 cy-15..cy-0.5 检查，误删洞口 ADT → 门口缝隙 → 卡闪避） | 洞口/入口 ADT 保留 |
| rcErodeWalkableArea | 薄墙被蚀掉（消失） | **STEEP 不侵蚀 + 视为边界** | 薄墙保留为障碍 |
| MMAP_VERSION | 8 | **8（定稿，匹配云端）** | 与云端兼容 |

**生成规则中间态**（曾尝试后放弃，勿回退）：
- ADT 89° 可走 → 保留太多陡坡，虚空 tile 顶点超 0xffff → **改回 60°**
- 版本号 9 → 云端旧代码不认 → **定回 8**

### 三、关键排查教训（重要）

1. **.mmtile 的 neis 解码**：存储为「邻居索引+1」，bit15(0x8000)=border/portal 标志。
   之前用 int16 直读 → 邻居全部错位 → 误判"洞口不联通""绕行 55/79 码"——**全是解析假象**。
   正确：`nei = raw & 0x8000 ? 0 : raw - 1`。
2. **面相交 ≠ 邻居**：detour 邻居的唯一条件是共享一条完整边（两顶点相同，方向可反）。
   2D 重叠/共享单顶点都不是邻居。
3. **MoveMapGen 部署**：改动后必须复制到 `x64_Debug/Extractors/MoveMapGen.exe`
   （bat 用那里的 exe，不是 build 目录）。
4. **--tile 参数顺序**：`--tile <tileX>,<tileY>`（tileX 在前）；`--workdir ..` 相对 Extractors。
5. **MMAP_VERSION 语义**：版本号不变 → shouldSkipTile 跳过旧文件（增量）；变了 → 全量重建。
   规则改了但不升版本号，必须手动删旧 mmtile 或清空输出目录。
6. **云端 github 直连被墙**：git pull 超时，需 gh-proxy 镜像或 scp 补丁/文件。

### 四、部署状态（8-23 晚）

- 本地：新规则（v8）mmap 全量生成完成（2764 tile，各地图全覆盖），打包 `mmaps_new_v8.zip`（735MB）
- 云端：代码文件已 scp（版本 8 + 60° 规则）；mangosd 编译中（-j2，玩家下线后执行）；
  编译完成后需：部署新 mangosd → 上传新 mmap 到 `/opt/mangos/data/mmaps` → 重启验证 8086
- 云端部署注意：mangosd 优雅停服可能失败（`.server shutdown` 卡住），需 `pkill -9 -x mangosd` 强杀；
  watchdog 在 `/etc/cron.d/mangos_watchdog`（禁用必须删文件，.bak 无效）

### 五、验证记录（本地实测）

- 58279/58281（地狱火堡垒）：掉坑已修复（STrace 不再有 -65.7，zMin=-8~-2.5）
- 67211/67212/67213（矿洞）：追击/EVADE/回家正常，无飘顶
- 矿洞门口：玩家站门口 5 码内，怪不再卡闪避（覆盖检查移除后门口 ADT 保留）
- 本地服务器已重启加载新 mmap（8086 正常）

---

## [水移动] 水中移动问题总结（2.4.3 私服）— 最终版

> 本文档由仓库根 WATER_MOVEMENT_NOTES.md 整合而来，后续水移动相关技术内容统一写入本手册。

### 目标与原则

- 修水中移动三件事：不卡闪避 / 不抽搐 / 不穿模
- 原则：**服务器逻辑向客户端靠拢**（客户端是原版，服务器应匹配）
- 分类：会游泳的永远游泳；不会游泳的永远不游泳（贴水底/水面上方走路）；CREATURE_EXTRA_FLAG_WALK_IN_WATER（螃蟹）永远贴水底
- 2.4.3 客户端 movement flags：**SWIMMING = 0x00200000**（玩家 MSG_MOVE_START_SWIM 包证实）

### 核心发现：客户端如何判定怪物游泳

**客户端判定怪物游泳，看的是 UNIT_FIELD_FLAGS 里的 UNIT_FLAG_SWIMMING（0x8000），不是 movement flags（m_movementInfo）！**

- 水生怪 spawn 时 Creature.cpp 会把它写进 UNIT_FIELD_FLAGS（CREATE 锚定）-> 一直游泳
- 陆地怪下水：动态游泳判据触发 SetSwim(true) -> **SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SWIMMING)** -> 客户端通过字段更新持久获得游泳状态
- 这是 boss_the_lurker_below.cpp 里官方用法（JustSummoned 里 SetFlag 让娜迦游泳）

### 完整方案（组件）

1. **动态游泳判据**（Unit::Update，迟滞式）：进入游泳 z < 水面 - 0.5（浅水也游，不贴浅滩）；退出游泳 z > 水面 + 0.5（完全出水才走路）；中间 +-0.5 迟滞带保持当前状态（防水面边缘翻转）；跳过 WALK_IN_WATER
2. **SetSwim**：m_movementInfo 加 SWIMMING + **SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SWIMMING)** + 发 0x30B（原版行为）
3. **Launch 统一水中路径处理**（MoveSplineInit，对所有 creature 移动生效）：游泳者路径点约束 [水底+0.5, 水面]，不穿底不冒头，**跟随目标深度**（不强制固定深度）；陆地点（groundZ > waterLevel）保持原 z
4. **RefineWaterPath**（Chase）：GetWaterLevel（浅水也有效）替代 GetWaterOrGroundLevel（浅水返回地面导致贴底），groundZ 判别 + walkInWater 贴底
5. **双方都在水中且会游泳 -> 直线游到目标深度**（Chase/Follow）：水下导航网格是水底，走廊路径会潜到水底够不到目标；WALK_IN_WATER 保持走廊
6. **swim 状态变化强制重新寻路**（Chase/Follow relaunch，m_lastSwimState）：下水/上岸切换路径模式，防旧陆地路径卡住闪避
7. **PathFinder**：CanSwim() || IsInWater() -> 快捷路径（浅水 IsSwimmable()==false 会 NOPATH -> 闪避）；随机点水中保持当前深度
8. **UpdateAllowedPositionZ**：水中单位跳过 z 修正（防水面/水底弹跳）
9. **UpdateSplinePosition 同步 m_movementInfo.pos**：防 CREATE/movement 块带陈旧出生点位置

### 排查经验：为什么"投递游泳状态"各种方法都失败

| 方法 | 结果 |
|---|---|
| SMSG_SPLINE_MOVE_START_SWIM (0x30B) 单发 | 有效但 ~2 秒后客户端自己衰减回走路 |
| 0x30B 周期重发（1s/500ms） | 保持游泳但**抖**（每次重发动画状态机重置） |
| CREATE_OBJECT2 重建（对已存在单位） | 不应用，无效 |
| destroy + create（强制重建） | 短暂游泳后仍回走路（客户端不重新锚定） |
| monster move 带状态 | **SMSG_MONSTER_MOVE 协议不带 movement flags**（查实），无此通道 |
| UPDATETYPE_MOVEMENT | 4 次实验全失败（位置错乱/怪消失），放弃 |

**结论：客户端游泳 = UNIT_FIELD_FLAGS 的 UNIT_FLAG_SWIMMING 锚定，0x30B 只是临时动画提示。动态 SetFlag 是唯一持久方案。**

### 其他经验

- monster move 的 spline_id 字段 = 自增计数器，不是动画 ID（客户端动画不靠它）
- 客户端水底高度 = 服务器一致（实测 -6），无地形认知差异
- "怪物被拉到 -2"问题：早期 clamp 强制深度，已删（跟随目标深度）
- 玩家跳跃时怪物"瞬移"：未确认是位置跳变还是模型朝向/动画切换（日志已清无法复现）；已尝试水中忽略 z 防 relaunch（未验证，已还原）

### 0.5 数值来源（2026-08-25 核实）

- `groundZ + 0.5f` 离地半码余量**继承自 CMaNGOS 原版**：官方 PathFinder.cpp 的 `result[1] += 0.5f` / `iterPos[1] += 0.5f`（navmesh 平滑路径点 z 抬高半码，避免怪贴地/穿地）在 fork 之前的官方父提交就存在，d64379342 未改这两行。
- 我们 fork 的 MoveSplineInit 水处理块（含 groundZ+0.5）本身是 d64379342 加的，但 **0.5 这个数值取自原版 navmesh 惯例**，不是凭空定的。

### 2026-08-25 游泳怪"上岸前卡住" + 高度上限（本次改动）

- **现象**：游泳怪游向岸边目标，会游到浅水/岸贴地走一小段（"上岸一小段才卡"）。
- **根源**：RefineWaterPath 是 z 修正型护栏，只夹 z 不拦路径方向；浅水/岸段被贴地放行。
- **修复 A（RefineWaterPath 截断）**：只游泳怪（CanSwim && !CanWalk，如鱼）细分点水深 <= 1.5 或岸边/无水面时**截断路径**，终点停在最后一个深水点，不贴地上岸；两栖怪不受影响。截断后仅 1 点则复制起点保证 spline 校验通过。
- **修复 B（MoveSplineInit 高度上限）**：游泳怪路径点 clamp 到 [水底+0.5, 水面-1.5]，**z 任何情况不高于水面下 1.5**（完全没入水中），不潜入地。

### 死怪攻击问题（2026 检查）

- 现象：已死亡怪物偶尔还能发动攻击（玩家掉血）。
- 根因（GM 技能复现）：GM 的 area death（INSTAKILL 类伤害）把血量归零但**跳过 SetDeathState** -> m_deathState 仍为 ALIVE -> IsAlive() 返回 true -> 死怪继续攻击。
- 修复（防御，已保留）：UpdateMeleeAttackingState：!IsAlive() || GetHealth() == 0 才允许挥砍；UnitAI::UpdateAI 开头 !IsAlive() || GetHealth() == 0 提前返回。
- 云端未见此问题，防御无害保留。附带发现：阿图门"被杀死后复活"= GM 技能 INSTAKILL 绕过 SetDeathPrevention，非服务器 bug。

### 2026-08-23 水中随机移动修复（2 处）

- 现象：水中随机移动怪被拉到水面 / 游进地面下的水里（dbguid 10898 蓝鳃突袭者复现）。
- 根因：随机点只保留起始深度（endPoint.z = currPos.z），不校验目的地水柱；直线路径可能穿过岸边/坡地。
- 修复（PathFinder.cpp ComputePathToRandomPoint 水分支）：①目的地水柱校验 destGroundZ+0.5 <= 当前深度 <= destWaterLevel-0.5，不满足或非水 → PATHFIND_NOPATH 重掷；②沿途地形采样 4 点，任何一点地形高于游泳深度 → NOPATH 重掷。
- 效果：随机点要么落在合理水柱内，要么重掷；既不拉水面、也不钻地底。

---

## [部署] mmap 热替换导致 mangosd 崩溃循环（2026-08-25 排查）

### 现象
- 23:05 起云端 mangosd 崩溃循环：23:05/23:06/23:07/23:08/23:09/23:10 连续 6 次启动→加载→崩溃，watchdog 每分钟拉起又崩。
- 崩溃发生在启动加载地图数据阶段（Server.log 显示 Load 到一半）。

### 根因（用户指正 + 确认）
- 不是 mmap 版本不匹配：新旧 mmtile 头部都是 magic=MMAP ver=8 dt=7（MoveMapSharedDefines.h:29 MMAP_VERSION=8），版本完全一致。
- 真正原因：在 mangosd 运行中热替换了它正在使用的 mmaps 目录。
  - 20:46 操作：mv mmaps → mmaps_old_20260627，再新建 mmaps 目录解压 v8。
  - 运行中的旧 mangosd（04:08 二进制）仍持有旧 inode/句柄，但按需加载新 tile 时按路径重新打开 → 路径已指向新 v8 目录 → 读到内容不同的数据 → 解析崩溃。
  - 触发时机：23:05 玩家进入需要按需加载 tile 的地图（如毒蛇神殿 548 测试 21508）。

### 教训（重要）
1. 绝不能在 mangosd 运行时替换/移动它正在使用的 mmaps 目录（同理 vmaps/maps/dbc）。
2. 换 mmap 必须：先停进程 → 再换文件 → 再启动。
3. 部署顺序固定为：4:00 整机重启（无进程）→ 4:02 放 v8 mmap → 4:06 新二进制启动加载。
4. 云端已加安全脚本 /root/deploy_v8_mmap.sh：pgrep mangosd 存在则 abort 跳过，防止再踩。

### 当前部署方案（2026-08-25 定稿）
| 时间 | 动作 |
|---|---|
| 3:00 | restart_server.sh 发 server shutdown 3600（4:00 关闭） |
| 4:00 | 整机重启 |
| 4:02 | deploy_v8_mmap.sh：pgrep 检查无进程 → 旧 mmaps 备份为 mmaps_old_20260627 → mv mmaps_v8_new → mmaps（原子改名） |
| 4:06 | nightly_build_restart.sh：用 ec714992c 编译新二进制 → 部署 → 启动 → 加载 v8 |

- mmap 部署方式（2026-08-25 改进）：v8 提前解压到独立目录 mmaps_v8_new（运行中 mangosd 无感知），部署时仅两次 mv（备份旧目录 + 改名上线），原子且不产生"读到一半文件"状态。
- 回滚保险：mmaps_old_20260627（旧版 2777 tile）保留不清，正常运行一段时间确认稳定后再删。
- 运行中二进制核对法：md5sum /proc/PID/exe = /opt/mangos/bin/mangosd = /root/Nmangos-tbc-build/src/mangosd/mangosd。
- 云端当前运行 = 04:08 编译（48b7c8463 版本，不含 8-25 水下寻路修复），需凌晨重编译。

---

## [寻路] 2026-08-26/27 多项修复与调查结论

### 1. 鱼类上岸修复（commit 3e341792a）
- RefineWaterPath gate：纯游泳怪（CanWalk=false）跳过 IsInSwimmableWater 检查，浅水/埋地鱼也能触发截断。
- 截断阈值结束于 depth<=1.5 的浅水位（鱼停在深水边界不上岸）。

### 2. 空中寻路修复（commit 17884f7dd，PathFinder）
- INVALID_POLY 捷径分支改为「起点和终点都必须在可游泳水域」：
  - `CanSwim() && IsSwimmable(startPos) && IsSwimmable(endPos)`
  - 空洞分支同样要求两端可游泳。
- 效果：地面怪（InhabitType=3 但当前位置不在水区）追飞行玩家 → NOPATH → 回营，不再飘天。

### 3. loadMap 崩溃修复（MoveMap.cpp，未 commit）
- 现象：v8 mmap 启动崩在 Loading WorldState。/ 打怪崩（calcTileLoc NaN）。
- gdb 抓栈：SIGABRT in MMapManager::loadMap → `MANGOS_ASSERT(itr != loadedMMaps.end())`（map 未预加载）。
  触发链：WorldState::RespawnEmeraldDragons → IsSwimmable → GetHeightStatic → loadMap(530) → assert。
- 修复：loadMap 遇到 map 未加载时自动调用 loadMapData（加载 .mmap + navmesh），不再 assert。

### 4. v8 mmap 缺 .mmap 文件（关键教训）
- **v8 zip（mmaps_v8_0824.zip）只含 2764 个 .mmtile，缺 72 个 .mmap**（navmesh 全局参数，各地图 28 字节）。
- 没有 .mmap → loadMapData 无法初始化 navmesh → 后续 calcTileLoc 用无效 navmesh → NaN/崩溃。
- **修复：从旧版 mmaps 复制 .mmap 到 v8 目录**（.mmap 只含地图边界/tile 尺寸，与 tile 生成规则无关，可复用）。
- 教训：打包/部署 mmap 时必须同时包含 .mmap 和 .mmtile，两者缺一不可。

### 5. 任务物品每人一份（commit 68d5d1d15 + dev/035 SQL）
- item_template class=12（Quest 物品）全部加 ITEM_FLAG_MULTI_DROP（0x800=2048）：队伍里每人可拾取自己的一份。
- 云端已执行：3865/3865 全部带 MULTI_DROP。
- 生效前提：需重启 mangosd 加载新 item_template（内存缓存）。

### 6. 多层地形穿模：接受现状（未解决）
- 现象：Duskwood 下层怪追上层目标时，路径 z 跳变（20→34→29→34），本地平滑（24→27→29）。
- 同起点同目标确凿对比：本地平滑、云端跳变。
- 已排查全部因素均一致：mmtile 2764 全量 MD5、.mmap、源码(68d5d1d15)、recast库(去行尾符MD5)、优化级别(-O3/-O2都跳变)、DT_POLYREF64 宏。
- polyPath（navmesh 路径）两边相同且平滑，FINAL（findSmoothPath）跳变 → 问题在 findSmoothPath 插值。
- 结论（2026-08-27 修正）：现象 = findSmoothPath 逐点 getPolyHeight 在多层共享 poly 间的"判层歧义"（z 台阶、x/y 平滑）；差异源 = 输入微差（%.2f 掩盖完整 float）+ 平台浮点细节，且 GCC 代码生成确参与（O3→O2 穿模减少，见下）。非逻辑 bug，不动算法。
- 拒绝 z 斜率限制方案（会引入卡闪避/新穿模/卡战斗风险，且 ZSnap 曾因压平下坡被移除）。
- 缓解（2026-08-27 确认）：编译优化 -O3 改 -O2 后部分怪穿模消失（同批怪穿模减少，用户实测确认有区别）。
- 决策：改用 -O2 编译（云端 CMakeCache + flags.make 已设为 -O2，凌晨编译沿用；O3 版备份 mangosd.bak_O3_bf86ba2d）。
- 性能影响：2 核云机上差异可忽略；穿模虽未完全消除但明显减少，接受现状（不再深挖）。
- 二次分析（2026-08-27，深挖"polyPath 相同、FINAL 不同"）：
  - 实证（云端 02:40:45 样本，下层怪追地表目标）：polyPath 10 个 poly 的 z 单调平滑
    （16.76→20.00→…→35.18）；FINAL 的 x/y 连续平滑、**仅 z 跳变**
    （34.00→34.08→29.81→34.70→35.09）。
  - 机制：polyPath = Detour 离散图搜索（鲁棒，微差不改 poly 链 → 两台必然一致）；
    FINAL = moveAlongSurface 连续插值 + 逐点 getPolyHeight 重心插值补表面高度
    （对 (x,y) ULP 级微差敏感），多层共享边处点被判到不同楼层 → z 台阶。
    "polyPath 相同、FINAL 不同"因此**不矛盾**。
  - 差异源排序：① 输入微差（%.2f 只到 0.01 码，"同起点同目标"未严格证明；真要实锤
    需 %.8f 打印或离线同一 .mmap + 同输入复现）② 平台浮点细节（云端 flags =
    -O2 -DNDEBUG -std=c++2a / GCC 10.2.1，**无 -mfma/-march=native/-ffast-math
    → FMA 差异排除**；O3→O2 穿模减少说明代码生成仍参与）③ detour 固有判层歧义（放大器）。
  - 决定（2026-08-27）：**不做防御性修复**（同层校验/LOS 拦截等）——问题偶发不严重，
    防御补丁有回归风险（误杀正常爬坡/绕路路径、重新引入卡闪避），维持接受现状。

### 7. PlayerSave.Interval 改 1 分钟
- 云端 mangosd.conf：PlayerSave.Interval = 300000 → 60000（1分钟），重启生效。
