# 已知问题记录 (KNOWN ISSUES)

> 本文件 = **Bug 修复手册 / 已知问题与技术笔记**（随源码提交）：记录服务器遇到的已知问题、排查信息、已修复项与技术性内容（含水中移动、寻路、地图瓦片等），供后续会话接续处理。
> 功能性更新见同目录《功能更新手册_卡布魔兽.md》；运维内容见本地《HANDOFF_卡布魔兽运维.md》（不提交）。
> 技术性笔记一律写入本文件（不再另开 md），仓库根/根目录散落的旧技术 md 已陆续归并。
> 更新时间: 2026-09-01

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
| mmap .mmtile | `mmaps/%03u%02u%02u.mmtile` = `<mapId><gx><gy>` | **gx 在前**（同 .map，与 .vmtile 相反） | contrib/mmap/src/MapBuilder.cpp:979 |

> ⚠️ **最容易踩的坑：.map 和 .mmtile 是 gx 在前，而 .vmtile 是 gy 在前（唯一相反者）。**
> 同一个位置，.map/.mmtile 与 .vmtile 文件名的两位数顺序正好相反（.map 与 .mmtile 数字相同）。
> 例子：Duskwood 某点 → .map=`0005131.map`、.vmtile=`000_31_51.vmtile`、.mmtile=`0005131.mmtile`，.map/.mmtile 互反于 .vmtile。
>
> **更正记录（2026-09-01）**：原表曾写 .mmtile「gy 在前（同 vmap）」——**错**，已改为 gx 在前（同 .map）。
> 实锤依据：服务端读 `mmaps/%03i%02i%02i.mmtile`（MoveMap.cpp:48）由 GridMap.cpp:1334 以 (gx,gy) 调用；
> 生成器 MapBuilder.cpp:979 虽写 `(mapID, tileY, tileX)`，但其 tileY 恰等于服务端 gx（getTileList 用 .map/.vmtile 两源解析出同一 packed ID 可证）——故文件名两位数仍是 X 坐标值在前。

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


- **category=3（禁售）**：ahbot 永不供给/收购的材料——不进做市商 book，也不进 loot 掉落流程（宇宙 SQL 排除之外的显式操作员级硬禁）。示例：太阳之尘(34664)/黑暗之心(32428)/虚空漩涡(30183)/原始虚空(23572) 等仅副本掉落+301+ 配方材料已标 3，并清理历史 ahbot_inventory/ahbot_price 残留。
- **Class7 供给路由规则**：book 成员(cat1/2)→仅 catalog；宇宙成员 cat0→回 loot 流程；cat3 与一切不在宇宙的 Class7(制成品/副本独占材料)→任何路径都不供给。

- **只有制作来源的物品 → category=3**：[2026-09-03 已废弃] 原 059 判定把"有制作配方(Effect24/43)且无任何掉落来源"的物品一律标 3（历史本地结果：36 项 cat3 = 4 副本独占 + 32 纯制作：锭/布卷/棒/硬化件/原始系列(本库无掉落)/棱柱石/奥金转化器等）。该规则已从 `055_ahbot_做市商与商品分类_整合.sql` 第 5 段移除，改为：仅 4 顶级副本材料(34664/32428/30183/23572) 严格 category=3，其余 category=3 一律复位为 category=0 库存管理（见 055 新第 5 段 5a/5b）。

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

---

## [资源] 矿点三方对比与修复（Questie / pfQuest / 当前服务器）— 2026-08-29

> 完整分析见 `dev/050_矿点三方对比分析.md`；修复 SQL 见 `dev/051_矿脉组MaxCount提高.sql`。
> 结论：**矿少不是数据缺失，是 spawn_group 动态生成机制 + MaxCount=1 导致**；数据库与原版逐项一致。

### 一、三方数据口径

| 来源 | 点数口径 | 刷新时间 |
|---|---|---|
| Questie（tbcObjectDB.lua） | 铜 2637 / 锡 2598 / 银 3524 等，**所有潜在位置** | 无 |
| pfQuest（objects-tbc.lua） | 铜 2180 / 富瑟 539 等 | 普通矿 45s、Ooze 360s |
| 当前服务器 gameobject 静态 | 仅铜 1843 多，其他个位数（银 0/瑟银 0/真银 1/金 3/铁 6/锡 5/秘银 25/富瑟 9） | — |

### 二、矿少根因（机制设计，非bug）

1. **高价值矿几乎全靠动态生成**：265 组矿脉组、633 条 spawn_group_entry（带 Chance 随机矿种），
   位置是 id=0 的占位 guid（spawn_group_spawn 3149 个），gameobject 静态实体只有铜矿。
2. **MaxCount 决定同时存在的矿数**：215/265 组（81%）MaxCount=1，一组即使有多个位置同一时间
   也只有 1 个矿，被采后整组空 + 45~90s 才随机重生 1 个。
3. **Chance 权重压低高价值矿**：瑟银总和 90、富瑟 180，远低于锡 1170；同组通常 3~4 候选矿种。

### 三、与原版一致性验证（不是我们改的）
矿脉组 265=265、entry 633=633、MaxCount 分布逐项一致、占位 guid 3149=3149。→ 100% 与原版一致。

### 四、修复（2026-08-29，dev/051）
将 215 个 MaxCount=1 的矿脉组改为 **2**（同时存在的矿翻倍），位置/Chance/刷新时间不动。
- 本地执行 `dev/051`，云端在停机窗口执行后 `.reload spawn_group` 热加载（已确认支持）。
- 回滚：脚本内备份表 `spawn_group_bak_maxcount_20260829`。
- 效果待玩家实测：若仍显少，可继续提高或调 Chance/刷新（见 050 方案 B）。

---

## [资源] 飞行生物"待机悬空 vs 移动贴地"观感 — 2026-08-30（分析，未改）

> 状态：**仅分析，未改代码**。影响疑似有限，暂缓修改；本文档供备查。

### 现象
- 提诉：飞行生物（如贪婪风蛇 18220）**待机动画看起来悬空，移动时却贴地爬行**，观感割裂。
- 服务器 `.gps` 实测 spawn 点：Windroc 18220，z=-4.68，**GroundZ=FloorZ=-4.68**（≈贴地）。

### 关键结论（站长指正后修正）
1. **飞行生物生来就在地面高度**（spawn z = 地面），**不是被移动逻辑拉下来的**。
2. **"保持当前高度直线飞"（上游）与"floorZ 吸附"（本 fork）对本身贴地的生物结果一样**——都是地面，
   **所以"移动被吸到地面"根本不构成问题**。
3. **服务器 z 自始至终贴地不变**，"待机悬空 vs 移动贴地"的差异**纯在客户端动画层**：
   - 待机：飞行/扇翅动画让模型视觉上浮起（似悬空）
   - 移动：走地/滑行动画 → 看起来贴地爬
   - 两类动画与"贴地碰撞点"组合不一致 → 观感割裂，**非高度问题**。

### 数据观察（spawn 高度分布）
飞行生物 spawn z 各不相同：Windroc 18220 z≈-4.68（外域低地）、Avian Flyer 21931 z≈27~61、
Air Force Alarm Bot 2615 z≈84~120（明显偏高/空中）。
→ spawn z 是**按各点地形/意图设置**，有高有低；**仅看 z 无法判断贴地与否，需对比该点 GroundZ**。

### 技术发现（备查，非本现象直接原因）
本 fork `PathFinder::ComputePathToRandomPoint`（PathFinder.cpp 1724-1748）有**上游没有**的陆地 `floorZ` 检查，
未排除飞行生物：`|floorZ-z|>1 → NOPATH；否则 z=floorZ（吸地）`。
- 对 **spawn 在空中**的飞行生物会误伤（NOPATH 卡死/吸地）；
- 对**本身贴地**的生物（本案例）**无影响**（z 已=地面，检查通过且不变）。
→ 该段并非本现象原因，仅当此类生物 spawn 在空中时才相关，现保留不处理。

### 结论与建议（暂缓）
- 野外低空飞行生物官方本多在低空贴地，观感轻微，**不值得为它改系统级寻路**（风险>收益）。
- 若确需处理，优先**数据层**：批量实测 GroundZ 对比 spawn 点，摸清贴地比例，再决定是否抬 spawn z
  或改移动姿势——比改寻路代码安全得多。

---

## [数据] Exotic Gear Purveyor 三商 NPC 装备层级（26090/26091/26092）— 2026-08-30 已修

### 现象
- 用户发现 26091（Olus）和 26092（Soryn）同卖 Merciless（S2），询问是否官服如此。
- 实测（本地+原版 tbcmangos_orig 一致）：两 NPC 的 vendor 模板 556=557 全套 Merciless S2，内容完全相同。

### 根治：对照官服（wowhead TBC Classic）逐 NPC 核实
| NPC | 官服售卖（wowhead 实测） | 兑换代价（ExtendedCost） | 修复前（本地） | 修复后 |
|---|---|---|---|---|
| 26090 Karynna | Gladiator's（S1）| Fallen（BT）| Gladiator's S1 ✓ | 不变 |
| 26091 Olus | Merciless Gladiator's（S2）| Vanquished（BT）| Merciless S2 ✓ | 不变 |
| 26092 Soryn | **Vengeful Gladiator's（S3）** | **Forgotten（太阳之井 T6.5）** | Merciless S2 ✗ | **Vengeful S3** |

**关键**：26092 Soryn 的 ExtendedCost 本是 **Forgotten 套件（31089-31103，太阳之井）**——最高端兑换，
官服对应换 **Vengeful Gladiator's（S3）**。但模板 557 的 item 错填为 Merciless（S2），
导致 26091=26092 且 26092 代价与内容不匹配。用户判断"用 T6 套件换不应该是 S1"完全正确。

### 修复（2026-08-30，dev/053，本地已执行）
- `dev/053_修复NPC26092_S3装备.sql`：将模板 557 的 85 件 item 从 Merciless(32xxx) 改为
  对应的 Vengeful(33xxx)，**ExtendedCost(1474-1524 Forgotten代价)/slot 保留**。
- 映射依据：从 wowhead NPC 26092 sells 数据抓取 85 件 Vengeful + 对应 Forgotten token，逐件匹配。
- 验证：557 全 85 件 Vengeful、0 残留 Merciless；与 556（S2）不再重复。
- 备份表：`npc_vendor_template_bak_557_20260830`（85 行）。回滚语句在 SQL 文件末尾。
- 注意：本地 vendor 需服务端 `npc_vendor` 内存缓存 reload（.reload npc_vendor / npc_vendor_template）生效。

### 附带核实
- 原版 tbcmangos_orig 也是这套错数据（557=Merciless+Forgotten代价），即数据源本身有误，非我们改出来的。
- 云端库尚未应用 053，需同步执行（回滚备份同步）。

---

## [平衡] 公正徽章商人 G'eras 装备分档解锁 — 2026-08-30 已设计+本地执行

> 本节及以下"虚空旋涡BoP / 铁匠Anwehu / 太阳之井对话"三段的数据改动，均已合并到
> **整合版 `dev/054_公正徽章与铁匠分阶段解锁_整合版.sql`**（可重放、含备份/回滚）。
> 原分散文件 054/054b/055/056 已删除。以下为过程记录。

### 需求
玩家早期就能用公正徽章直接换高级装备。设计：按**物品开放阶段**给 G'eras 徽章装备分档，
防止早期就入手高级货（延续"任务线限制进高难副本"的思路）。

### NPC
- **G'eras**，guid 96654 / entry 18525，奎尔丹纳斯岛，公正徽章（Badge of Justice 29434）商人。
- npc_vendor 里 137 件徽章装备，原 `condition_id` 全 0（全量开放）。

### 分档规则（用户定）
| 档 | 内容 | 开放时机 | 条件 |
|---|---|---|---|
| 无条件档 | 装等 **≤115**（110 + 115 Inferno 系列）+ **源生虚空(23572/1909)** | 团本前 | 无 |
| P3 档 | 装等 **≥128**（128/132/133/136）+ **虚空旋涡(30183/1642)** | P3（祖阿曼合并开放）| **已完成任务 10445「永恒水瓶」** |

- 128+ 官服 P4 才开，但无祖阿曼单独进度，合并到 P3，用海山开门任务 10445 当门槛。

### 实现（dev/054，本地已执行）
- 新增 `conditions(5800002)`：`type=8(CONDITION_QUESTREWARDED), value1=10445`。
- `npc_vendor` 里 G'eras 83 件（虚空旋涡 + ≥128）挂 `condition_id=5800002`；54 件（≤115+源生虚空）保持 0。
- 机制：`ItemHandler.cpp:780` 对不满足条件的物品 `continue`（玩家看不到）。
- 备份：`npc_vendor_bak_18525_20260830`、`conditions_bak_10445_20260830`。

### ⚠️ uint16 坑（061:25 实测，已修正）
- **npc_vendor.condition_id 服务端用 `uint16` 读取**（ObjectMgr.cpp:9684 `GetUInt16()`），范围 ≤65535。
- 初用 condition_entry=**5800002** → 被截断成 **32834**（5800002 的低 16 位）→ reload 报
  `condition_id=32834 not valid, ignoring`，**高档物品全部不加载**（而非"完成后可见"）。
- **修正**：改用 condition_entry=**28023**（≤65535，本地/云端均空闲）。本地+云端已切到 28023，
  重载验证无错误（Loaded 6444 vendor items）。
- **教训**：condition_id 必须 ≤65535；且 reload 顺序应先 `.reload conditions` 再 `.reload npc_vendor`。
- dev/054 SQL 已更新为 28023 并加注释。

### 生效与回滚
- 服务端需 `.reload conditions` + `.reload npc_vendor`（此顺序）。
- 已完成的玩家不受影响（QUESTREWARDED=已拿到奖励为真）。
- 回滚语句在 dev/054 文件末尾。云端已同步（条件28023 + 分档 + BoP）。

### 054b 补充：虚空旋涡(30183)改拾取绑定（2026-08-30，本地已执行）
- 054 把虚空旋涡纳入"需完成任务10445"高档兑换，但其原 Bonding=0（可交易），
  存在"一人兑换后交易给未完成者"的绕过漏洞。
- 修复：`Bonding 0→1`（拾取绑定 BoP，含掉落来源一并绑定），堵住绕过。
- 依据：用户明确"虚空旋涡应该设置为拾取绑定"，并确认整体改BoP（含掉落）。
- 注意：与官服不同（官服虚空旋涡可交易），此为配合自定义分阶段门槛的定制。
- 文件：~`dev/054b_虚空旋涡改为拾取绑定.sql`~（已并入整合版 `dev/054`）。生效需 `.reload item_template`。

---

## [任务] Exarch Nasuun(24932) 缺失对话补全 — 2026-08-30 已补（台服翻译）

### 现状
- NPC Exarch Nasuun(24932) 的 gossip 文本（军械库 12300 / 铁砧 12301）在全库 npc_text/locales 缺失，
  导致对话窗口空白（任务功能正常，仅台词缺失）。确认脚本 `npc_suns_reach_reclamation` 无 gossip 处理，
  纯数据库驱动。
- 查遍本地库：WotLK(wotlkmangos/ac_cmp/wlk_cmp) 也没有；英文原文在 classicmangos_ref、台服中文在 zh_ref。

### 修复（dev/055，本地+云端已执行；已并入整合版 dev/054）
- npc_text 补 12300/12301：英文为 fallback（classicmangos_ref 原文）
- locales_npc_text 补 12300/12301 的 Text0_0_loc4 = **台服中文**（zh_ref）
  - 12300 军械库："我很高兴你问了。我们完成了计画的$3233w％..."
  - 12301 铁砧："我从荷莎那边听来，她说我们才完成了目标的$3228w％..."
- ⚠️ 台服翻译（计画/日境/荷莎）非国服简体，如需国服风格需另行改写。已在 SQL 内注释。

### 坑
- npc_text 直接 INSERT 会因 locales_npc_text **无主键**产生重复行；SQL 已改为先 DELETE 再 INSERT。
- PowerShell/文件转义：`$B`/`$3233w` 通配符必须原样写入，不能加 `\$`（否则文本损坏）
  → 已用 UTF-8 无 BOM + 单引号保护重写。
- 生效需 `.reload npc_text`。

---

## [平衡] 铁匠 Anwehu(27667) P5 徽章装备加任务 10959 条件 — 2026-08-30 已执行

### NPC
- **Anwehu(安维赫)** entry 27667，奎尔丹纳斯岛，`VendorTemplateId=505`（template 505 仅它使用）。
- 57 件 P5 太阳之井徽章装备（装等141×45 + 146×12，34887-34952），全部用公正徽章
  （ExtendedCost 2049/2059/2329-2333）兑换。
- **Smith Hauthaa(铁匠霍尔萨)** entry 25046：由 game_event 307 脚本刷新、`VendorTemplateId=0` 且无 npc_vendor
  条目 → 游戏内无售货（确认脚本无 vendor 注入），本次**不处理**。

### 需求
给 Anwehu 的 57 件 P5 徽章装备加"完成任务 **10959**《The Fall of the Betrayer》(击败基尔加丹)"条件，
玩家未完成该任务前看不到/买不了，防止过早入手顶级徽章装。

### 实现（dev/056，本地+云端已执行；已并入整合版 dev/054）
- 新增 `conditions(28024)`：type=8(QUESTREWARDED), value1=10959（≤65535，避 uint16 截断坑）。
- `npc_vendor_template 505` 全部 57 件设 `condition_id=28024`。
- 验证：57/57 挂条件；云端 conditions 加载 1976（含 28024）；无 not valid 报错。
- 生效：`.reload conditions` + `.reload npc_vendor_template`。备份 `npc_vendor_template_bak_505_20260830`。

---

## [机制] 法师闪现 Blink 落点修复 — 2026-08-30 完成（先 navmesh 有路径 / 无路径才碰撞）

> 涉及文件：`src/game/Spells/Spell.cpp`（落点计算）、`src/game/Spells/SpellEffects.cpp`（EffectLeapForward / EffectTeleportUnits 传送处理）。
> 属源码改动，需**重新编译部署 mangosd** 才生效（非 DB 改动，`.reload` 无效）。

### 需求（站长三连约束）
1. **天上（跳起/下落/飞行）放闪现不能被"没有路径"卡住**——空中起点脚下无 navmesh 可行走路径，
   PathFinder 会报 NOPATH / NOT_USING_PATH 导致整个施法被取消、原地不动。
2. **不能穿过 ADT 地面穿模**——落点/路径不得钻进地形里面（山脊/陡坡/悬崖壁）。
3. **不能穿过 WMO 模型**（建筑墙面）。
4. **跳起/原地闪现应像普通闪现一样正常远闪**（顺地形），不能因为 WMO 起伏/坡面卡在原地。

### 关键发现：法师闪现真实走 `SPELL_EFFECT_LEAP`（Effect=29），不是 TELEPORT_UNITS
- 玩家实际用的法师 Blink **1953**（`BLINK_1`）：`Effect1=29(=SPELL_EFFECT_LEAP)`、
  `EffectImplicitTargetB1=55(=TARGET_LOCATION_CASTER_FRONT_LEAP)`。
- 所以 1953 走 **`Spell::EffectLeapForward`**（SpellEffects.cpp），**不是** `EffectTeleportUnits`。
- 之前对 `EffectTeleportUnits`（仅匹配 spell 38203/38643）的所有 PATH-CHECK 改动，**对 1953 完全不生效**
  ——这就是之前反复改却"没效果"的根因。**改闪现必须改 `EffectLeapForward`。**

### 最终设计：先问 navmesh 有无路径，有路径用 navmesh，无路径才碰撞
不再用 flag（IsFlying/IsJumping/IsFalling）或离地高度猜分支，统一流程：

```
Spell.cpp（TARGET_LOCATION_CASTER_FRONT_LEAP）：
  只算"简单直线目标" = prevPos + dist*cos/sin(朝向)，z 保持当前高度（仅水面吸附）。
  不做任何碰撞、不依赖 flag；它只是给 EffectLeapForward 的一个初始目标。

EffectLeapForward（1953 实际走的）：
  读直线目标 (x,y,z) → 跑 PathFinder：
  ├─ 有路径（NORMAL | INCOMPLETE）
  │    → 用 navmesh 落点 getActualEndPosition()（顺地形，闪到远处地面）。
  │    地面 / 跳起 / 下落段(fall=1) 只要 navmesh 命中起点多边形都走这里。
  └─ 无路径（NOPATH | SHORTCUT | NOT_USING_PATH）→ 不 block，做碰撞校正：
       ADT：纯 ADT 高度符号翻转 → 停前一点（不穿 ADT）
       WMO：LOS 判明 - LOS 通过→放行(地形起伏)，LOS 遮挡→GetHitPosition 停墙面
       落点 = 校正后的点。
  最后 NearTeleportTo。
```

- **"有没有路径"由 navmesh 自己回答**，最准确——彻底绕开 flag/高度阈值的不可靠。
- 跳起下落段 `fall=1` 但离地近（起点命中 navmesh）→ 有路径 → navmesh 远闪，不再卡原地。
- 真高空（起点离 navmesh 几十码，如高跳崖/飞行顶）→ 无路径 → 碰撞校正落点，不 block 也不穿地。

### 碰撞校正细节（无路径分支，EffectLeapForward 内）
把 `施法者位置 → 直线目标` 连成直线，每 **2 码**采样，逐点两层检测：
1. **ADT（符号翻转）**：`GetHeightStatic(x,y,z, checkVMap=false)`，纯 ADT 静态地形、无 vmap/WMO、
   无搜索距离限制。`d = 路径z − ADT面z` 相邻两点符号翻转（正↔负）＝直线穿过 ADT 面 → 停**前一个采样点**。
2. **WMO（LOS 门控 + 碰撞）**：先 `IsInLineOfSight`——LOS 通过说明只是可越过的缓坡/起伏 → 放行继续走；
   仅 LOS 被挡（真墙/峭壁）才 `GetHitPosition` 竖直扫掠 → 停在模型表面命中高度。

> ⚠️ WMO 层**必须先过 LOS**，否则 `GetHitPosition` 会把前方地形小幅起伏也判成"挡墙"，
> 导致跳起/原地朝起伏地形闪时第一步(<2码)就停下、看似"原地不动"。

### 踩过的坑（务必记录）
- `G3D::Vector3` **无 distance()**，距离用 `(a-b).magnitude()`；const 初始化会 C2737。
- `TerrainInfo::GetGrid` 是 **private**，不能直接调 `gmap->getHeight`；
  应走 public 的 `TerrainInfo::GetHeightStatic(_,_,_, checkVMap=false)`。
- 判断分支用 navmesh 有无路径，而非 flag：跳起**下落段** `MOVEFLAG_JUMPING=false`、`FALLING=true`，
  无法用 flag 区分"普通跳起"和"真下落"，用 PathFinder 结果判定最准。
- 闪现实测 spell id 可能是 **1953**(BLINK_1 走 Effect_LEAP)，务必确认走 EffectLeapForward 还是
  EffectTeleportUnits，改错函数无效。
- 之前层层堆叠的校正（FINAL-LAND GetHeight 兜底、startAboveADT clamp、LOS 门控移来移去、
  大范围 GetHeightInRange）均已移除，恢复正常版简洁直线目标 + navmesh 判路。

### 验证结果（本地实测，用户确认）
- 原地闪 / 跳起闪：全部 navmesh(0x1 NORMAL / 0x4 INCOMPLETE) → 远闪顺地形，落点 z 随地形起伏。
- 无 `WMO-STOP/ADT-STOP`（无断点）出现——说明真实场景都能 navmesh 到远处，未触发碰撞。
- 真高空（无 navmesh 路径）会进碰撞分支防穿（该场景未在本次日志触发，逻辑保留）。
- 状态：本地编译部署实测通过；**源码已 scp 到云端 `/root/Nmangos-tbc/src/game/Spells/`，
  云端待下次编译部署生效**（同步时未编译）。调试日志已全部移除。

---

## [机制] 法师闪现 Blink：WMO 斜坡穿模修复 + 落点方案重做 — 2026-09-04（navmesh 目标点 + 通用碰撞 + 不钻底）

> 涉及文件：`src/game/Spells/SpellEffects.cpp`（EffectLeapForward）
> 属源码改动，需重新编译部署 mangosd 生效。
> **2026-09-04 定版，取代 2026-08-30 的"直线 LOS 门"方案**——旧方案在斜坡上会误拒
> navmesh 终点，且 WMO 命中后无条件 `-2 + GetHeight 向下重搜` 会钻到模型下方穿模。

### 现象（用户报告）
- 站在 WMO 斜坡上朝坡上闪现：紧挨着的坡面碰撞处理错误，角色穿模（落到斜坡壳下方）。
- 复现点：map=1 (-3727, -4418) 一带 WMO 斜坡（薄 WMO 顶壳浮在 ADT 上约 2 码）。

### 日志证据（临时 [BLINKDBG] 日志已移除）
- 斜坡命中：`WMO-STOP res=(-3729.32,-4420.37,30.24)`（命中 z 就是坡面高度）
- 旧逻辑随后 `res.z -= 2` → `GetHeight` 从坡壳**下方**向下搜到坡下 ADT **26.62**
  → 落点低于坡面 ~3.6 码 = 穿模根因。
- 另：斜坡上 navmesh 给出 INCOMPLETE 终点（坡脊 z≈30.6），但被"起点到终点直线 LOS"
  误判为挡墙丢弃（直线弦在坡脊处切入坡面）→ 只能走直线分支 → 方向/z 都错。

### 根因
1. z 修正无条件 `-2 + GetHeight 向下重搜`：WMO 命中后从坡壳下方搜，只会搜到坡下
   更低层（ADT），从不判断是否已钻到模型下面。
2. navmesh 结果被"直线 LOS"门控：斜坡/坡脊的直线弦必然切入坡面 → navmesh 终点被弃。

### 最终方案
```
navmesh 有真实路径(NORMAL|INCOMPLETE) -> 目标点 = navmesh 终点（z 顺可行走表面）
navmesh 无路径(真高空/水面等)        -> 目标点 = 直线终点
两种目标点都走同一套直线碰撞步进（不穿墙/不穿坡/不穿 WMO）：
  逐 2 码采样：起点 = 玩家实际坐标 +2（跳起时即跳起高度 +2）
              终点 = 目标 +2
    1) ADT：纯 ADT 面与采样线符号翻转 -> 停前一个安全采样点
    2) WMO：LOS 被挡 -> GetHitPosition 表面命中点即停（停在表面）
       （LOS 被挡但拿不到命中点 = WMO-MISS 病态：停上一安全点，不放行穿墙）
最终 z 分三种：
  WMO 表面命中          -> z = 命中高度（不再 -2 / 不再向下重搜，绝不钻底）
  整条直线可通行(NO-STOP)-> z = 直线飞行高度：
                              navmesh 目标 = 可行走表面高度，顺地形落地；
                              直线目标(空中/跳起/水面) = 保持当前高度不掉地，物理自然下落
  ADT 抬升 / WMO-MISS    -> 停上一安全点，从采样线上方下探贴地（只命中表面，不钻壳）
```
- 空中/跳起：采样线起点即玩家实际高度（跳起高度），不拉到 navmesh 地面高度；
  空中闪现不掉到地上（站长要求）。
- 绕墙场景：目标点在墙后但可绕行时，碰撞步进在墙面处停住，不会直线穿墙
  （避免旧"无条件信任 INCOMPLETE"导致的绕墙穿模回归）。
- 全流程不依赖 flag/离地高度猜分支，仅由 PathFinder 有无路径 + 碰撞结果决定。

### 验证
- 本地编译部署实测通过（站长确认 OK，已自行 push + 云端部署 + 重启）。
- 调试日志已全部移除（本记录对应提交为日志移除后的干净版）。

---

## [机制] dynguid 池生物双刷修复 — 2026-09-01（源码改动）

### 现象（用户报告）
- 部分怪在同一出生点**同时出现两只**，行为完全相同（走同一条路径）。例：纳格兰 Northwind Cleft
  guid 151374（Boulderfist Warrior 17136）与 guid 151421（Boulderfist Mage 17137）同点双刷。
- 数据侧核查（本地=云端=原版 TBCDB 全一致）：两者同坐标/同朝向/同 300s 刷新/同一 22 点
  creature_movement 路径，且都在 pool_creature 池 **118**（pool_template max_limit=1，各 50% 几率）——
  **设计上二选一，同时只能有一只**。数据本身无重复。

### 根因（SpawnManager dynguid 分支漏池检查）
- 两个 entry 的 creature_template.ExtraFlags=1048576 = **CREATURE_EXTRA_FLAG_DYNGUID**（动态 guid 生物）。
- ObjectMgr::LoadCreatures 只把非池/非事件 guid 加入 ObjectMgr 网格（IsNotPartOfPoolOrEvent，ObjectMgr.cpp:2374）；
  池成员由池系统管理：PoolManager::Initialize → 池 118 按 max_limit=1 只选一只加入 persistent-state 网格。
- **但 SpawnManager::Initialize（src/game/Maps/SpawnManager.cpp）的 creature 分支把该图所有 dynguid 生物
  无条件 AddCreatureToGrid，没有像下方 GO 分支那样跳过池/事件成员** → 池 118 两只都被加进网格 →
  网格加载时两只都以全新 dynguid 生成（Creature.cpp:1729）→ 同点双刷、走同一路径。
- 上游 mangos-tbc 同款缺陷（两个分支都缺检查）；本 fork 之前已给 GO 分支补过
  if (!data->IsNotPartOfPoolOrEvent()) continue;（SpawnManager.cpp:75），**creature 分支漏补**。

### 修复（本 commit）
- SpawnManager.cpp Initialize() creature 分支：与 GO 分支对齐，先取 data 并加
  if (!data->IsNotPartOfPoolOrEvent()) continue;（池/事件成员交由池/事件系统刷，SpawnManager 不再重复添加）。
- 影响面：本地库 10328 行 dynguid 刷怪中，**153 只属于 guid 池**（池 106-123 Northwind Cleft 系列、
  45103/49301 等）此前全部双刷；事件 dynguid 不受影响（!data.gameEvent 已排除在 dynguid 列表外）。

### 部署与验证
- 需重新编译部署（本地 build_deploy_restart.bat；云端走凌晨 nightly_build_restart.sh 或 manual_deploy.sh）。
- 验证：重启后 Northwind Cleft 该点应只见 1 只（Warrior 或 Mage 随机）；.npc info 查 guid 只剩被选中者。

---

## [机制] dynguid 生物链接组复活不全修复 — 2026-09-01（源码改动）

### 现象（用户报告 + 实测）
- 太阳之井 Sunblade 链接组（如 5800071：Sunblade Cabalist 头目 + 6 小怪）部分死亡后**脱战**，
  RESPAWN_ON_EVADE 只复活了非 dynguid 成员（71/72/97/246），**dynguid 成员（104/119/133）复活不了，
  GM .respawn 也无效**。
- 运行时铁证（tbccharacters.creature_respawn，instance 2）：复活的 4 只无记录（已清零），
  卡住的 3 只 respawntime=死亡+7200（未来）——即"立即复活"路径从未生效。

### 根因（dynguid 复活必须走 SpawnManager，linking 却走原地复活）
- dynguid 生物（CREATURE_EXTRA_FLAG_DYNGUID）死亡时（Creature.cpp:1951-1956）：
  m_respawnTime = time_t::max()（自然复活路径永不触发），复活完全交给 SpawnManager 定时
  （SaveRespawnTime 存的死亡+7200）。
- **Creature.cpp:1753-1760**：dynguid 且持久化复活时间在未来时，LoadFromDB 直接 return false →
  SpawnManager/网格/GM 一切生成路径都失败，直到定时到点。
- **CreatureLinkingMgr 的 EVADE/DIE/RESPAWN 复活动作调 pSlave->Respawn()（原地复活）**——
  只对非 dynguid 有效；dynguid 对象已不在世界/原地复活无效 → 该组 dynguid 成员永不复活。
- 附带缺陷：ProcessSlaveGuidList 在 pSlave 不在世界时**把该 guid 从链接表永久擦除**（dynguid
  对象由 SpawnManager 管理、暂不在世界属正常）→ 链接关系断裂。

### 修复（本 commit，4 处）
1. **Creature::Respawn()**：dynguid 走 GetSpawnManager().RespawnCreature(dbGuid, 0)
   （先清复活时间再让 SpawnManager 立即生成），非 dynguid 保持原地复活。
2. **CreatureLinkingMgr::RespawnLinkedSlave()**（新增）：EVADE/DIE/RESPAWN 三个复活动作统一
   dynguid 走 SpawnManager、非 dynguid 走 Respawn()。
3. **ProcessSlaveGuidList**：pSlave 不在世界时，有效 dynguid 槽位不再擦除，并把 RESPAWN_*
   标志路由到 SpawnManager（非 dynguid 源事件也生效）。
4. **WorldObject::SpawnCreature**：生成前若同 dbGuid 旧对象仍在世界则先移除（防重复）。
- 影响面：所有"非 dynguid 主怪 + dynguid 从怪"的链接组（564/568/580/585 等实例大量存在）脱战复活修复。

### 部署与验证
- 需重新编译部署（本地 build_deploy_restart.bat；云端 manual_deploy.sh 或凌晨 nightly）。
- 验证：太阳之井杀 5800071 组部分小怪 → 脱战 → 6 只应全部复活（含 Vindicator/Dusk&Dawn Priest）。

---

## [机制] ahbot 动态市场价格（商品类/Class 7）— 2026-09-01（源码改动，云端未部署）

### 需求
- 现状：ahbot 买卖价全用静态配置（AuctionHouseBot.Value.* + subclass 覆盖）。对"产出多、用量少"的
  物资，真实市场价低于 ahbot 静态价，但 ahbot 仍按静态价无限收购 → 高价接盘过剩物资。
- 目标：实时监控拍卖行每物品价格，让 ahbot 按市场价动态调整（先只作用于商品类 Class 7；
  现代交易所式价格曲线功能留待后续）。

### 实现（本 commit，本地编译通过）
1. **市场价监控** AuctionHouseBot::UpdateMarketPrices()（每 DynamicRefresh 秒，默认 60s）：
   扫描三个拍卖行的**玩家**上架（排除 ahbot 自己的），每物品×每拍卖行取**单价中位数**（buyout÷堆叠）
   作为市场价；内存缓存 + **持久化到 tbccharacters.ahbot_price**（item, price, auction_house，
   复用旧版未用表，仅价格变化时写库），重启/.ahbot reload 重读。
2. **买卖动态封顶**（仅 ITEM_CLASS_TRADE_GOODS=7）：
   itemWorth = min(静态价, 市场价) → 收购最多按市场价（不再按静态价接盘过剩物资）；
   上架也按市场价（不再挂高于市场的死价）。ahbot_items 手动覆盖值优先级最高。
3. **命令**：.ahbot item <id> 对商品类显示各拍卖行市场价。
4. **配置**（写入运行中的 ahbot.conf，未动 dist，云端未改）：
   AuctionHouseBot.Value.Dynamic = 1、AuctionHouseBot.Value.DynamicRefresh = 60。

### 部署状态
- 本地：代码已编译通过；x64_Debug/ahbot.conf 已加 Dynamic=1。
- 云端：**按用户要求暂未动**（代码未 scp、配置未改、未重载）。待用户确认后再同步部署。


### 做市商升级（本 commit，本地编译通过，云端未部署）
- 明确不模拟 ahbot 持仓（虚拟、无邮箱），只模拟做市商报价行为。
- **双边报价**：bid = mid×(1−spread)、ask = mid×(1+spread)，spread 半宽默认 5%（MarketMaker.Spread），
  上限 20%（SpreadMax）。
- **mid（报价中枢）**：玩家上架单价中位数的 EMA 平滑（Smoothing=50%，首帧用中位数播种），
  持久化到 ahbot_price（数据库为价格源，改库 + .ahbot reload 生效）。
- **价差自适应**：波动大（|中位数−mid|/mid 高）或市场薄（上架数 < ThinListings=3）→ 拉宽价差。
- **买侧**：只收价格 ≤ bid 的挂单（不再按静态价无限接盘）；BuyPerCycle（默认 0=不限）
  每物品每扫描周期买入配额。
- **卖侧**：按 ask 上架（封顶静态价），不挂死价。
- 命令：.ahbot item <id> 显示各拍卖行 mid/bid/ask/spread/上架数。
- 影响范围仍限商品类（Class 7）；ahbot_items 手动覆盖优先级最高。

### 后续规划（未实现）
- 现代交易所式价格曲线：ahbot_price 升级为时间序列（记录历史快照），支持走势/均线/波动判定。




### 猎人自动射击卡死（已修复，commit c908ca5b2，待上云）
- **现象**：平射在"取消后快速重按 / 移动打断后重按 / 云端延迟下单次取消"后卡死：
  图标常亮、按键不再发施法包，只能移动或切目标恢复。
- **根因**（本地+数据包级完整复现）：
  1. 客户端（小黑兔代理 2.53）在取消后短时间内重按平射时，进入 cast→~30-250ms 后自取消 的循环
     （每次 cast 后客户端自动发 CMSG_CANCEL_AUTO_REPEAT + CMSG_CANCEL_CAST）。
  2. 服务器每次"正确地"清掉自动射击槽——但新注册的首箭需要 ~500ms 预备（FirstCast windup），
     取消包总在首箭前到达，箭永远射不出 → 客户端状态机冻结（纯客户端问题，服务器收不到按键包）。
- **修复（风暴盾）**：记录平射槽注册时刻（Unit::m_AutoShotRegisterTime），新注册后 700ms
  首箭窗口内（Unit::IsAutoShotInFirstShotWindow）忽略 CMSG_CANCEL_AUTO_REPEAT 及对应取消施法
  （SpellHandler.cpp 两个 cancel 处理器），让首箭射出、客户端恢复。
- **验证**：本地快速开关 10+ 次 / 单次取消重按 / 移动打断自动恢复 —— 全部正常不再卡。
- **待办**：push c908ca5b2 后在云端无人窗口跑 cloud_mm_deploy.sh 部署，用真实延迟场景复验
  （云端曾出现"单次取消即卡"，风暴盾同样覆盖：延迟取消包晚于重注册到达时会被窗口忽略）。

### ahbot 商品三级分类架构（dev/055(整合版，原057-059)，架构先行：只铺框架不改行为）
- **目标**：商品分三类——0=默认不动(不进做市商book, 仍走原有loot流程供给)；1=市场商品(做市商book+央行流动定价，现状)；2=低级商品(做市商book+单价固定=price列/卖店价，防"无限刷低级材料卖ahbot"印钞)。
- **架构落点**：
  - dev/057 SQL：ahbot_catalog 加 category(默认0) + price(默认0) 列；现有 107 行回填 category=1(保持现状)。
  - 代码：LoadCatalogOverrides 读两新列；GetCatalogEntry 补拷 policy/category/price(顺带修复 policy 此前未拷出的缺陷)；IsCatalogItem 排除 category=0；loot 供给仅跳过 book 成员(category=0 回到 loot 流程)；GetCatalogFixedPrice() + QuoteCatalog/UpdateMarketPrices/买侧 的 category=2 固定价分支(当前无 category=2 行 → 全部惰性不生效)。
  - MM 初始化/买卖不再依赖 Chance.Sell/Buy(可设 0 专注做市商)：Initialize 全量装载；买侧 chanceBuy||(market&&catalog) 进门、非 book 物品仍需 chance 掷点。
- **用法(以后)**：把物品行 category 改为 0/2 + 填 price(SellPrice) → .ahbot reload 即生效；category=1 无需显式(无行默认即市场商品)。category=2 的 supply 充足沿用 transition ×3。

## [任务] 10607「乌鸦之神的低语」预言神殿中文名错译 — 2026-09-16 已修（本地，待推云）

- **现象**：玩家反馈四座预言神殿的 GameObject 中文名不对。
- **定位**：真正的神殿是 GO **184950 / 184967 / 184968 / 184969**（type 10 GOOBER，`data1=10607`=questId），已 spawn 在格里施纳（3784.6/6729.0、3625.7/6541.7、3734.6/6639.5、3575.5/6666.4）。
  `locales_gameobject` 里 **184968、184969 都写成「第一个预言」**，应为「第三个预言」「第四个预言」（184950/184967 原本正确）。
- **修复**：`dev/066_任务10607预言神殿中文名修复.sql`（幂等，只改 locales_gameobject）。
- ⚠️ **顺带纠正一个极易误判的点（别再"修"错）**：`quest_template.10607.ReqCreatureOrGOId1..4 = 22798/22799/22800/22801` 是**正确**的。
  cmangos 规则是「**正数＝生物入口、负数＝-GO 入口**」（`Player.cpp:14456-14469` `CastedCreatureOrGO`：isCreature 时匹配 `>0`，GO 时匹配 `<0`；另有 `Player.cpp:20170` `HasQuestForGO` 用 `-1)*GOId` 判定），
  而这四个 entry 在 `creature_template` 里是 **`[DND]Prophecy 1~4 Quest Credit`**（隐形计数体），spawn 坐标与四座神殿一一对应。
  GO 命名空间里同号的 22798~22801 是 Wooden Chair / High Back Chair（type 7），纯属**撞号**。
  → 所以「走到神殿不互动就自动完成」是设计行为，**不要**把 GO 目标改成负数或改 QuestCredit。
- **生效**：locales 在启动时载入 → 需重启 mangosd（上云后随夜间重启生效）。

## [战术] 拜龙教徒 NPC 21382 停在远程距离却不攻击 — 2026-09-16 已修（本地，待推云）

- **现象**：Wyrmcult Zealot(21382) 战斗中停在 35 码处站桩，不出手（玩家反馈"没有远程攻击却停在远程攻击范围"）。
- **根因**：`creature_ai_scripts` **2138201**（aggro 事件）action1 = **57 `ACTION_T_SET_RANGED_MODE`**，param1=**2**（`RangeModeType TYPE_PROXIMITY`，见 `UnitAI.h:100`）、param2=**35** → `SetRangedMode(true, 35, TYPE_PROXIMITY)`（`UnitAI.cpp:986`）→ 追击停在 35 码。
  该模式还依赖「main spell」，而 `AddMainSpell` **只取第一个**法术（`UnitAI.cpp:972` "only for first"）：21382 法术表(`creature_template_spells` setId=0) 首位是近战技 **32009 Cutdown**，真正远程的 Fireball(20714 / EventAI 用的 9053) 只在 EventAI 的 range 事件（event 9，0~40 码）里 → 站位正确但输出为 0。
- **旁证（运行日志）**：2026-09-16 16:11:30 `Server.log` / `DBErrors.log`：
  `ERROR:EventAI: Creature entry 21492 has ranged mode action but no main spell.`（`CreatureEventAI.cpp:1336` 的守卫：没有 main spell 时该 action **只写日志、什么都不做**；21492 = Wyrmcult Blessed，同营地同类）。
- **修复（站长定案 A：按近战怪处理）**：`dev/067_NPC21382改为近战模式.sql`，把 `action1_param1` 由 2 改为 **0**（TYPE_NONE＝近战模式；参照 2163703 注释里的 "Enable Melee Mode"）。21492 的可选同改留在该 SQL 注释中备用。

## [机制] 试飞任务（10712 / 10711 / 10557）坐骑状态不会被送上试飞平台 — 2026-09-16 已修（本地，待推云）

- **现象**：骑着坐骑与试飞管理员对话选试飞，玩家不会被正确送上试飞平台（玩家反馈）。
- **完整链路（已核实）**：
  1. `gossip_menu_option` menu **8304**（**21461 Rally Zapnabber**，站位 1920.3/5581.3）→ option 0/2/3 分别绑 `dbscripts_on_gossip` **10557 / 10711 / 10712**；
  2. 脚本第一步用命令 15（CAST_SPELL）对玩家施放 **36801 "Cannon Charging (Port)"** —— 它是**传送法术**（落点在 `spell_target_position`：id=36801 → map530 **1920.13 / 5581.9 / 270.426**）＝"送上平台"那一步；
  3. 同时给炮台 NPC 21393/21394 灌 charging aura（36785/36790/36792/36795/36800，0/3/6/9 秒）；
  4. **12 秒后**施放 **Soaring**（Ruuan Weald=**37968** / Razaan's Landing=37910 / Singing Ridge=36812），其数据为 `Effect1=98 KNOCK_BACK`(+misc 100/200/300) + `Effect2=6/aura 105(飞行)` → **"发射"是击退+飞行 aura，不是 taxi 航线**；
  5. C++ 侧只有一处脚本：`src/game/AI/ScriptDevAI/scripts/outland/blades_edge_mountains.cpp` 的 `struct Soaring`（`spell_scripts` 里 36812/37910/37968 → `spell_soaring`），施放时 `RemoveAurasDueToSpell(36801)`，注释写明"避免 root 影响击退"。
- **根因判断**：36801 自带 root，且**坐骑状态同样会压制击退/这类位移** → 骑坐骑时传送/发射不生效。
- **修复**：ScriptDev 新增 `npc_rally_zapnabberAI` + `GossipSelect_npc_rally_zapnabber`（同文件）：
  对话时 `IsMounted() → Unmount()`；遍历 `GetAurasByType(SPELL_AURA_MOD_SHAPESHIFT)` 逐个 `RemoveAurasDueToSpell(aura->GetId(), nullptr, AURA_REMOVE_BY_CANCEL)`（`Aura::GetId()` 在 `SpellAuras.h:119`）；随后 **return false** 交回 `Player::OnGossipSelect()` 继续执行 DB gossip/dbscript（`NPCHandler.cpp:438-439`）。
  配套 `dev/068_试飞任务对话自动下坐骑.sql`：`creature_template.ScriptName = 'npc_rally_zapnabber'`（**必须**，`ScriptDevAIMgr::OnGossipSelect` 按 `GetScriptId()` 取脚本，不绑则钩子不触发）。
- ⚠️ **踩坑记录**：本 fork **没有** `RemoveAurasByType()`（只有 `GetAurasByType()`），别照抄 WotLK/AC 的写法，否则编译报 `error C2039: 不是 "Player" 的成员`。


## [寻路] 本 fork 寻路/地形生成相对上游 cmangos 的全部改动 — 原 dev/寻路系统修改总结_vs_cmangos主分支.md（2026-09-16 整合，标题降一级）


> 对比基准：fork 分叉点 `3e69c84c9`（2026-08-05，上游 master）；对比对象：上游最新 master `6904884e4`（本地 mangos-tbc 仓库）。
> 统计：27 个文件，**+1332 / -97** 行（`git diff 6904884e4..HEAD -- src/game/MotionGenerators src/game/vmap src/game/Maps/GridMap.cpp src/game/Maps/Map.cpp src/game/Movement src/game/Entities/Unit.cpp src/game/Entities/Creature.cpp contrib/mmap dep/recastnavigation`）。
> 整理时间：2026-08-27。历史演变细节见《KNOWN_ISSUES.md》寻路章节（时间线 8-14 ~ 8-27）。
> ⚠️ Unit.cpp/Creature.cpp 内还混有**非寻路改动**（黑兔仇恨协议、圣印舞、死怪攻击防御、辅助呼叫返回值），本文不展开。

---

### 〇、总览：fork 的三个设计取向 vs 上游

| 问题 | 上游 CMaNGOS 行为 | 本 fork 行为 |
|---|---|---|
| vmap 高度查询 | 射线全向，任何面（含垂直墙/天花板背面/悬挑）都算"地面" | 高度查询只认 **60° 内的朝上面**（frontFacesOnly），墙/天花板背面不算地板 |
| 多层地形（地表+洞穴/地堡） | 无限向下搜索，射线穿透洞口命中地下层，浮点微差会把单位拉进地下 | **接近性判定**：vmap 高必须靠近单位 z(≤1.0码) 或 .map 地表(≤3.0码)，否则用 .map 地表；地表上方搜索封顶 |
| 山体/建筑坡度（mmap 生成） | ≥60° 三角形直接清除 → 墙上"空洞"，怪可穿墙 | WMO ≥60° 标 **STEEP 障碍**（保留在 navmesh 里挡路）；ADT 仍 60° 清除（防顶点超限） |
| M2 装饰物 | 按 60° 斜坡判定，柱子/大石可爬 | 按**高度分类**：>1.07码（walkableClimb×0.2667）全障碍；矮模型仅当下方 0.5~4.5 码内有真实地面才可走 |
| 终点处理 | 原样使用请求终点 | 陆地终点一律 `closestPointOnPoly` 吸附 navmesh 表面（防穿模/飘顶） |
| 水中移动 | 游泳状态按出生点静态；水中路径用 GetWaterOrGroundLevel(浅水=贴底) | 游泳状态**动态迟滞判定** + `UNIT_FIELD_FLAGS` 客户端锚定；统一水中路径重写 `[底+0.5, 水面-1.5]` |
| 生成器规则版本 | — | `MMAP_VERSION=8`（曾试 9 定回 8，与云端 mmaps 一致） |

---

### 一、mmap 生成器（contrib/mmap + dep/recastnavigation）——数据侧

> 规则的改动需要**重新生成 mmtile**。本地已全量生成 v8（2764 tile + 72 个 .mmap，云端已部署）。`MoveMapGen` 部署注意：复制到 `x64_Debug/Extractors/MoveMapGen.exe`。

#### 1. 三角形来源标记（TerrainBuilder + MapBuilder）
- `MeshData` 新增 `triSource`（每个三角形 0=ADT / 1=WMO / 2=矮M2 / 3=高M2），随 solidTris 同步生成。
- 按来源分别光栅化：**先 WMO（室内真地板）→ 再 ADT（洞/入口真表面）→ 最后 M2**（矮装饰需下方有实地面，否则 STEEP）。

#### 2. 坡度规则（确定稿，v8）
- **ADT 地形**：保持上游 `rcClearUnwalkableTriangles` 60° 清除（曾试 89° 全可走 → 虚空 tile 顶点超 0xffff → 改回 60°）。
- **WMO 建筑**：`MarkSteepTrianglesAsSteep`——≥60° 标 `NAV_AREA_GROUND_STEEP`（障碍）而非清除；**向下朝的面（天花板底面，n.y<0）也必须 STEEP**（2026-08-24 修，fabsf 会让天花板变可走地板）。
- **M2 装饰**：高模型（> 4×walkableClimb×0.2667 ≈ 1.07码）全 STEEP（柱子/墙/大石不可爬）；矮模型默认待定，经 `HasSpanInWindow`（下方 0.5~4.5 码内有 span）判为可踩地面（箱子/车/桶）或 STEEP（悬空台阶）。
- **移除 WMO 覆盖 ADT 检查**（曾加 cy-15..cy-0.5 窗口判断，误删洞口 ADT → 门口缝隙 → 卡闪避）。
- **移除 `rcMedianFilterWalkableArea`**（中值滤波）。

#### 3. 孤立 polygon 清理（MapBuilder buildTile）
- 对每个 navmesh poly：无内部邻居（neis=0）且无 EXT portal 的 GROUND poly，清掉 GROUND 标志 → 寻路过滤直接跳过。防 `findNearestPoly/getPolyHeight` 报幽灵高度（掉坑/飘顶根源）。
- 注意 neis 解码：`nei = raw & 0x8000 ? 0 : raw - 1`（存储为邻居索引+1，bit15=border）。

#### 4. 侵蚀保留薄墙（RecastArea.cpp `rcErodeWalkableArea`，recast 库改动）
- STEEP（area 10）span 当作**侵蚀边界**（邻居是 STEEP 即 break），且 **STEEP 自身永不侵蚀**——薄墙/薄柱不再被蚀掉消失，保留为障碍。

---

### 二、运行时 vmap 高度模型（防"选错层"）

#### 1. frontFacesOnly（MapTree / ModelInstance / WorldModel）
- 高度查询链路 `getIntersectionTime(..., frontFacesOnly=true)` 只接受**与射线方向夹角 ≤60° 的朝上面**（`n·rayDir <= -cos60` 才命中），墙/天花板背面/悬挑不再被当作地板。
- 其他用途（LOS、相交检测）不受影响（默认 false）。

#### 2. `TerrainInfo::GetHeightStatic` 多层取层修复（GridMap.cpp）
- **[FIX-1] 限制无限搜索**：mapHeight 有效且调用者在地表上方（z2 > mapHeight）时，vmap 兜底搜索距离封顶 `z2 - mapHeight + 2.0f`；在地表下方（洞内怪）保留 10000 穿透找洞底。
- **[FIX-2] 接近性判定**：
  ```
  vmapCloseToZ   = |vmapHeight - z|        <= 1.0f   // 单位贴自己那层的地面（实测差 0.00~0.06）
  vmapCloseToMap = |vmapHeight - mapHeight| <= 3.0f  // 同层差 <1，跨层（表层/地下）差 >20
  两者都不满足 → 用 mapHeight（.map 地表），拒绝远层 vmap
  ```
- 这是 `.go name` / 宠物跟随 / `UpdateAllowedPositionZ` 共用入口，修好后地表单位不再被吸进地下墓穴层。

---

### 三、PathFinder（运行时寻路，+313 行）

#### 1. 无 tile / 无 poly 的链式策略（防"卡闪避"）
- **无 tile**：`calculate` 一律 `BuildShortcut`（上游行为），不再对地面单位标 NOPATH（无 navmesh tile 的地面怪会冻住卡闪避）。
- **INVALID_POLY（起点/终点无 poly）**：游泳快捷路径**要求两端都位于可游水域** + 直线 LOS 可见；否则 NOPATH（防水面怪追岸上/空中目标被直线"抬升出水面"、防浅水直线穿过楼板）。
- **farFromPoly（终点距 poly 表面 >7 码，如玩家在二楼）**：陆地单位 LOS 可见 → `NORMAL|NOT_USING` 直线追（不穿空气）；LOS 被挡 → NOPATH（宁停不穿楼板）；飞行/游泳保持上游 INCOMPLETE。

#### 2. 终点贴面（根因修复：穿模/飘顶）
- 陆地（非飞、非水）终点无条件 `closestPointOnPoly` 吸附到 navmesh 表面（两端都做：起点下方模型面会被拉回，玩家跳坑上方不会再让怪垂直升空）。
- **同 poly**：水中→直接 shortcut（不贴面防拖下海床）；飞行→LOS 校验后 shortcut；陆地→两点必须都在 poly 表面 **1.5 码内**，否则 NOPATH（跨层桥接 poly 直线穿空气被禁），通过后终点吸附到面上。

#### 3. 平滑路径（findSmoothPath）
- iterPos/targetPos 补 `getPolyHeight`（closestPointOnPolyBoundary 不改高度）。
- **ZSnap 兜底已移除**（2026-08-24）：`|z-unitZ|>10 → z=unitZ+0.5` 会把 >10 码下坡压成水平线（怪飞着走，如 58284 z=67.59 地面 47）；信任 navmesh poly 高度。

#### 4. 随机漫步点生成（ComputePathToRandomPoint）
- **深水分支**（CanSwim && IsInSwimmableWater）：目的地水柱校验 `[底+0.5, 水面-0.5]` 内保持当前深度，沿途 4 点采样地形，任何一点高于游深 → NOPATH 重掷（防钻地/浮空）；浅水不再当游泳走（浅水怪之前永远不移动）。
- **陆地分支**：随机点必须落在自己那层的地面上（floorZ 误差 ≤1.0），且到目标直线 **LOS 可见**（防随机点选在树根/岩石/建筑里卡住）。

#### 5. 其他
- `PathFinder::setPathType` 新增（供追击器改写类型）。
- `[PFDBG]` 日志（aura 10909 门控，见第七章）。

---

### 四、追击 / 跟随（TargetedMovementGenerator，+362 行）

#### 1. Chase（追击）
- **下水/上岸状态切换强制重寻路**（`m_lastSwimState`），避免旧陆地路径卡闪避。
- **自身在水中 → 一律直线游向目标**（跳过距离/LOS/z 差/非水检查）：
  - canSwim && !walkInWater：清空路径，直接 start→目标**实际位置**（水下 navmesh=海床，走廊路径会让怪潜水到底够不到目标）；
  - NOPATH/INCOMPLETE 退化 start→end 直游；
  - 直线必须 LOS 可见（魔导师平台 24560 浅水→二楼直线穿楼板 → NOPATH）；
  - 陆地单位**不再走短距直线**（BuildPointPath straightLine 会把终点吸附到坑 poly，z=-65.7 掉坑往返）。
- **RefineWaterPath**（泳线细分）：按 `SMOOTH_PATH_STEP_SIZE` 细分，每点夹在 `[floor+0.5, 水面]`；**纯游泳怪（CanWalk=false）在浅水(深≤1.5)/岸边截断路径**（停深水边缘不上岸）；陆地/WMO 边缘 10 码保护（GetHeight 与 navmesh z 差 >10 不覆盖，防 WMO 边缘穿透到 ADT 深坑）。
- 陆地路径**不再被 RefineWaterPath 重采样**（曾致 WMO 边缘点掉坑 z=-65.7）。
- normalize-z 只对非水生效（水下直线 z 跨度天然 >1 码）。
- `_getLocation` 删除手动楼层吸附（终点由 PathFinder 贴面处理）。

#### 2. Follow（跟随）
- **水中跟随**：canSwim && IsInWater → 直线到主人位置（无论主人在水中还是岸上），type 置 NORMAL。
- 陆地路径点 `GetHeight` floorZ 修正：vmap floor 比 navmesh 低 **2 码以上**视为错层，跳过不拉低；否则贴地。
- **相邻点 z 差 >3 码且 LOS 不通 → 路径非法拦截**（防宠物穿墙/穿洞）。
- Relocation 类型修复：`TypeId()==UNIT` 才 `CreatureRelocation`（防 Player 下转型 UB）。
- 下水/上岸状态切换重寻路（同 Chase）。

---

### 五、水移动系统（游泳状态 + 路径 + 客户端呈现）

#### 1. 动态游泳状态（Unit.cpp `Update`）
- 迟滞式判定：`z < 水面-0.5` → SetSwim(true)；`z > 水面+0.5` → SetSwim(false)；中间带保持原状态；**跳过 WALK_IN_WATER**（螃蟹贴底）。
- `SetSwim` 同步写 **`UNIT_FIELD_FLAGS` 的 `UNIT_FLAG_SWIMMING`(0x8000)**——客户端游泳动画的持久锚定（0x30B 单发 ~2s 衰减、重建对象无效，仅此方案一直有效）。

#### 2. 统一水中路径重写（MoveSplineInit.cpp）
- **GATE：只在单位确实在水中（IsInWater）时才重写路径 z**（曾对所有 spline 生效：GetHeight 穿透 WMO 缝隙到海底 z=-92.4，把陆地怪拖进地下室）。
- walkInWater 或不会游泳 → 贴 `groundZ+0.5`；会游泳 → clamp 到 `[groundZ+0.5, 水面-1.5]`（完全没入水中）；路径点在水面上（岸/船甲板）→ 跳过不拉低。
- 覆盖所有移动类型（chase/follow/wander/waypoint/home）。

#### 3. 其他移动相关（Unit.cpp）
- `UpdateAllowedPositionZ`：**水中单位跳过 z 修正**（防水面/水底弹跳）；陆地 z 拉回上限 **10 码**（防 GetHeight 错层一帧帧拉下深坑）。
- `UpdateSplinePosition`：spline 移动后同步 `m_movementInfo.ChangePosition`（防 movement 包带陈旧出生点位置）。
- `MoveSpline.cpp`：零长度 spline 不再刷 `zero length spline` 错误日志（强制 1ms 原地停留）。

---

### 六、其他运行时改动

#### 1. MoveMap（mmap 内存与按需加载）
- **`TrimMmapMemory()`**：三处卸载路径（tile / .mmap / instance）后 30 秒节流 `_heapmin()`(Win) / `malloc_trim(0)`(Linux)，解决卸载后 RSS 不降。
- **`loadMap` 崩溃修复**：遇到未预加载的 map 改为**自动 `loadMapData`**（而非 `MANGOS_ASSERT`）——修复启动期 `RespawnEmeraldDragons → IsSwimmable → GetHeightStatic → loadMap(530)` 直接 SIGABRT（与 v8 mmap 缺 72 个 .mmap 文件叠加导致）。

#### 2. 网格/内存（Map.cpp，与寻路交互）
- `ForceLoadGrid` 去掉 `setUnloadExplicitLock(true)` 永久锁；`ActiveObjectsNearGrid` 只查玩家+transport（active 怪不再阻止卸载）→ 网格完全懒加载，启动内存 -50%（详见 KNOWN_ISSUES [内存] 章）。
- 附带 UAF 修复（ObjectGridLoader 卸载前 RemoveFromActive）见 KNOWN_ISSUES [宕机根因]。

#### 3. 随机/巡逻地面吸附
- `RandomMovementGenerator::_setLocation`：非飞行/悬浮/水中单位路径每点 `GetHeightInRange` 吸地（b82434357 引入；GetHeightStatic 修复后不再误伤）。
- `WaypointMovementGenerator`：**已移除** GetHeightInRange 吸附（08-24，注释说明信任 navmesh poly 高度，重吸附会把巡逻怪拖进错误层）。

#### 4. 冲锋（MotionMaster::MoveCharge）
- 改为 navmesh 路径（`MoveTo(..., generatePath=true)`）：终点落 navmesh 表面，不再直线穿墙/飘顶（曾试直线冲锋，08-24 移除）。

---

### 七、调试设施：PfDebug.h（新增）

- 统一寻路调试日志：`IsPfDbg(unit)` = 单位且带 **aura 10909（心灵视界）** 才打印，前缀 `[PFDBG]`，sLog.outError 级。
- 覆盖 PathFinder（calculate/FINAL/BuildPolyPath/随机点）、TargetedMovementGenerator（Dispatch/SPLINE）、MoveSplineInit（water gate）等；**保留在代码中**（本地+云端），排查穿模/掉坑时给 GM 目标怪上 10909 即可定点抓日志。
- 云端 Server.log 的 `[PFDBG]` 即此设施产物（须有 aura 10909 才刷）。

---

### 八、Commit 映射（本地 release，倒序）

| Commit | 内容 |
|---|---|
| 3c5fed4c1 | 修复mmap加载失败（loadMap 按需加载） |
| 17884f7dd | 修复空中寻路（INVALID_POLY 两端可游判定） |
| 3e341792a | 修复鱼类上岸（RefineWaterPath 纯游泳怪截断） |
| ec714992c | 修复水下寻路（RefineWaterPath/MoveSplineInit water gate） |
| c93437ad3 | 浅水区怪不移动修复 + PFDBG 加 GPS |
| a8ed20b45 | 添加寻路日志（PFDBG）+ 寻路修复 |
| 1998b2d3c | 更新mmap生成规则（M2 高度/STEEP/侵蚀） |
| 99626db1a | 修复寻路：掉坑/卡闪避/洞口断连 |
| fd57f8f24 | 水下随机行走 + 修复地图退加载 |
| b83f0804e / d64379342 / 290bac9b8 | 水下路径修复（早期迭代） |
| 2be9e7c28 | 修复随机移动路径 |
| dbec01ae2 | 修改mmap卸载（TrimMmapMemory） |
| 8499927c2 | 修复内存泄漏（网格卸载链路，见 KNOWN_ISSUES） |
| 2b3a9839b / 3e3173fd7 | 修复寻路（终点贴面/同 poly 校验/射线 frontFacesOnly） |
| b82434357 | 防止怪物掉到地下（随机/巡逻点 GetHeightInRange） |
| 973ba7ae2 | 修复怪物走空气（→ e3d85ffd9 已 Revert，见 KNOWN_ISSUES） |
| fbe6ca863 | 添加 leash-link（战斗链接） |
| f47c6a05e | 圣印舞（Spell/Unit，非寻路但同文件） |

> 另有一批 **upstream 合并**（f0168395c 等，战斗/拾取/副本/法术/Warden），不属本 fork 原创寻路改动；与上游冲突处已在合并时解决。

---

### 九、已知权衡与遗留（结论）

1. **多层地形穿模（Duskwood 洞穴案）**：GCC vs MSVC 浮点差异导致 findSmoothPath 插值判层不同，本地平滑/云端跳变；已接受现状，拒绝 z 斜率限制（会引入卡闪避/新穿模）。仅多层地形区偶发。
2. **湿地维尔加挖掘场桥**：宠物绕桥下的 vmap 多层未命中问题，待办中（见 KNOWN_ISSUES [地图]）。
3. **PFDBG 日志保留**（aura 10909 门控，无 GM 操作不刷屏），供后续排障；GRIDDBG/HEIGHTDBG 等亦保留但限区域/防刷屏。
4. **mmap v8**：云端已部署（2764 .mmtile + 72 .mmap）；`MMAP_VERSION=8` 与云端一致，改规则必须升版本或手动删旧 tile。
5. 大原则：**服务端逻辑向客户端靠拢**，导航网格（navmesh poly 高度）是移动可走性的唯一权威，vmap/.map 高度只做接近性兜底。


## [资源] 矿点三方对比分析（原始数据：Questie / pfQuest / 本服）— 原 dev/050_矿点三方对比分析.md（2026-09-16 整合）


> 日期：2026-08-29　目的：回答"矿脉太少"的根因，对比三方矿点数据给出完整说明
> 结论先行：**矿少不是数据缺失，是 spawn_group 动态生成机制 + MaxCount=1 导致的**。数据库内容与原版 tbcmangos_orig 逐项一致，未删过矿。

---

### 一、三方数据口径

#### 1. Questie（tbcObjectDB.lua）
坐标点数 = **所有可能生成位置（含备用/潜在点位）**，无刷新时间字段。

| 矿种 | Questie 点数 |
|---|---|
| 铜矿脉 | 2637 |
| 锡矿脉 | 2598 |
| 银矿脉 | 3524 |
| 金矿脉 | ~1000+ |
| 铁矿脉 | ~1000+ |
| 秘银矿脉 | ~1500+ |
| 真银矿脉 | ~1000+ |
| 瑟银矿脉 | ~1000+ |
| 富瑟银矿 | 539 |

#### 2. pfQuest（objects-tbc.lua）
坐标点数 + 第 4 值 = 刷新秒数：普通矿 45s、Ooze 矿 360s。

| 矿种 | pfQuest 点数 | 刷新 |
|---|---|---|
| 铜矿脉 | 2180 | 45s |
| 富瑟银矿 | 539 | 45s |
| 其余矿种 | ~1000+ | 45s |

#### 3. 当前服务器（tbcmangos）
**gameobject 表静态矿实体**（真正常驻、直接可见）：

| 矿种 | gameobject 数量 |
|---|---|
| 铜矿脉 | 1843 |
| 秘银矿脉 | 25 |
| 富瑟银矿 | 9 |
| 铁矿脉 | 6 |
| 锡矿脉 | 5 |
| 金矿脉 | 3 |
| 真银矿脉 | 1 |
| 银矿脉 | **0** |
| 瑟银矿脉 | **0** |

**spawn_group 动态矿组**（265 组，与原版逐项一致）：
- spawn_group_spawn：3149 个占位 guid（gameobject 表中这些 guid 的 id=0，仅作**位置载体**）
- spawn_group_entry：633 条随机矿种（带 Chance 权重，见下）
- 刷新机制：整组空才刷，RespawnOverride 45/90s 后整组重生

---

### 二、为什么实际看到的矿少

#### 1. 高价值矿几乎全靠动态组，静态实体极少
静态实体只有铜矿 1843 个；银/瑟银静态为 0，真银/金/铁/锡静态为个位数。
银、金、真银、秘银、瑟银这些矿 **不存在于 gameobject 静态表**，全部通过 spawn_group 动态随机生成。

#### 2. MaxCount 决定"同时存在的矿数"（核心原因）
spawn_group.MaxCount = 该组同一时间最多存活的实体数。

| MaxCount | 组数 | 占比 |
|---|---|---|
| 1 | 215 | 81.1% |
| 2 | 15 | 5.7% |
| 3 | 2 | 0.8% |
| 4~9 | 5 | 1.9% |
| 10~19 | 23 | 8.7% |
| 22~27 | 5 | 1.9% |
| **合计** | **265** | 100% |

**动态矿同时存在上限 = 721 个**（各组 MaxCount 求和）。
215 个组 MaxCount=1：即使该组有多个位置，同一时间也只有 1 个位置有矿，
被采后必须等整组空 + 45~90s 才在随机位置重生 1 个。

#### 3. Chance 权重进一步压低高价值矿出现率
spawn_group_entry 中每种矿的 Chance（权重，同一组内按权重随机选种）：

| 矿种 | 条目数 | Chance 范围 | Chance 总和 |
|---|---|---|---|
| 锡矿脉 | 52 | 0~90 | 1170 |
| 真银矿脉 | 142 | 5~10 | 765 |
| 金矿脉 | 122 | 5~10 | 695 |
| 银矿脉 | 109 | 5~10 | 675 |
| 铁矿脉 | 52 | 0~80 | 720 |
| 秘银矿脉 | 70 | 0~80 | 630 |
| 富瑟银矿 | 21 | 0~90 | 180 |
| 瑟银矿脉 | 51 | 0~90 | 90 |
| 铜矿脉 | 14 | 0 | 0 |

注意：同一组内通常 3~4 个候选矿种（如 Id=391 组：Ooze 富瑟 Chance 20、金 5、真银 5、秘银 0），
Chance 越低的矿种在同一组被选中的概率越低；加上 MaxCount=1，高价值矿实际出现率被双重压缩。

#### 4. 刷新机制放大"矿少"感受
- 矿被采 → 组内该位置消失 → **整组全空**才调度刷新 → 45~90s 后整组重生（位置随机）
- 重生后若还是 MaxCount=1，仍只出 1 个矿
- 人多时多个位置被采空，地图上长期大片无矿

---

### 三、与原版一致性验证（矿少不是我们改出来的）

| 检查项 | 原版 tbcmangos_orig | 我们 tbcmangos |
|---|---|---|
| 矿脉组数 | 265 | 265 |
| spawn_group_entry 矿条目 | 633 | 633 |
| MaxCount 分布 | 215/15/2/1/1/1/1/1/3/3/2/4/5/2/3/2/1/1/1 | 完全一致 |
| gameobject 静态矿 | 同我们 | 同原版 |
| spawn_group_spawn 矿组 guid | 3149 | 3149 |

→ 数据库层面我们与原版 **100% 一致**，矿少是 CMaNGOS spawn_group 机制的原生设计，非数据缺失。

---

### 四、可选的修复方向（按性价比排序）

#### 方案 A：提高动态组 MaxCount（最直接，SQL 可热加载）
把 215 个 MaxCount=1 的矿脉组改为 2~3：
```sql
UPDATE spawn_group SET MaxCount = 2 WHERE Id IN (...矿脉组...);
```
- 优点：不动位置数据，`.reload` 热加载即生效；同时存在的矿立即可翻倍
- 影响：可能改变"稀有矿稀有"的原版平衡；改前备份

#### 方案 B：提高高价值矿 Chance / 加快刷新
- 把瑟银（90）、富瑟（180）的 Chance 总和调高（如 ×3）
- 或把矿脉组 RespawnOverride 45/90s 调低（如 20~30s），配合 pfQuest 45s 口径更接近
- 已有草稿：`_agent_tmp/mine_fix_pfq.sql`（普通矿 45/90、Ooze 360 对齐 pfQuest）

#### 方案 C：按 Questie 坐标补静态矿点（根治但工作量大）
- Questie 是"所有潜在位置"口径，直接照抄会过量
- 需要：解析 tbcObjectDB.lua → 去重/按地图校验 → 生成 gameobject 静态矿行
- 工作量最大，且会改变世界资源布局，不建议直接全量照搬

#### 建议
先做 **方案 A（MaxCount 1→2）+ 方案 B（Chance 微调）**，热加载观察 1~2 天，
不够再评估方案 C。所有改动以 SQL 存档到 dev/，由站长手动执行/提交。


## [稳定性] 服务器宕机根因：Map::Update 活动对象列表 use-after-free — 2026-08-23 已修复并验证（云端已部署）

> 原记录在仓库根 `SERVER_TODOS.md`，2026-09-16 整合进本手册。

- **现象**：云端 mangosd 每隔 1~13 分钟必崩。
- **根因**：此前"修复内存泄漏（让有活动生物的网格也可卸载）"的改动引入 UAF ——
  `ObjectGridUnloader::Visit` 直接 `delete` 生物却没有调用 `RemoveFromActive`，
  活动列表里残留已释放指针，下一帧 `Map::Update` 的 `objToUpdate` 循环对已释放对象调虚函数崩溃。
- **定位证据**：7b2bcf50a 版本 core dump —— `Map::Update+1096`，崩在虚表调用跳转 `0x4032`。
- **修复**：`ObjectGridLoader.cpp` 在 `delete` 之前先 `RemoveFromActive`（+9 行）。
- **验证**：修复版 7b2bcf50a 在云端 **58+ 分钟零崩溃**（修复前 1~13 分钟必崩），已部署。
- **相关**：同批部署的还有「水中随机移动修复（PathFinder.cpp +33：目的地水柱校验 + 沿途地形采样）」、
  「放弃任务物品清理修复（QuestHandler.cpp：只删本任务需求量 + 跳过 SrcItemId）」；另见本手册 [内存] 与 [水移动] 章节。

## [待办] 尚未落地的改动与待定项 — 2026-09-16（原 SERVER_TODOS.md 整合）

- **水中怪追岸上修复（Chase/Follow 直接线）**：本地已改（不再要求 targetInWater），
  **未提交、未部署云端**（云端二进制仍为 9c3f59674）。部署后需实测"水中怪追岸上目标"不再卡。
- **普通攻击伤害数字延迟**：客户端显示的伤害数字比服务端实际计算晚 —— 待定是否改成延迟伤害计算。
  253 客户端已测，**243 客户端待测**。
- **双手武器平衡**：搁置。分析结论：惩戒骑/武器战在双手下 AP 系数都偏低；
  可选方案 A 标准化系数 3.3→3.4、方案 B 伤害系数 1.03~1.05，**未定案**。
- **登录异常与攻击计时（历史记录）**：b11c9b79d（调整攻击计时）导致"进不了世界"，
  用户重新提交 9c3f59674 解决，云端已部署；其后针对登录异常只加了**观测手段**（realmd 单 IP >5 条 3724 连接的僵尸连接计数写日志，不做自动重启），
  根因是崩溃夜客户端会话错乱，靠临时自愈。
- **反作弊现状**：Movement 检测全部为 Inform（不踢人）；Warden 在云端关闭。详见《功能更新手册》第三部分。


## [任务] 10911「开火！」物品 31807（自然能量炮弹）使用无效：魅惑 aura 被"免疫玩家增益"丢弃 — 2026-09-16 已修（本地，待推云）

- **现象**：玩家对死亡之门邪能火炮使用物品 **31807 Naturalized Ammunition**，只看到"火炮转了一下头"（= `npc_fel_cannon::SpellHit` 里的 `SetFacingToObject`），之后毫无反应：没有控制权、没有动作条。
- **完整链路**：31807 既是任务 10911 的**起始物品**（`quest_template.SrcItemId`）也是**必需物品**（`ReqItemId3` ×1）→ 使用触发法术 **39219**（`Effect1=APPLY_AURA`、`EffectApplyAuraName1=6` = `SPELL_AURA_MOD_CHARM`、目标 = `TARGET_UNIT_SCRIPT_NEAR_CASTER`）→ 经 `spell_script_target 39219 → 22443`（Death's Door Fel Cannon）→ 才是"控制火炮"。
- **根因（实测确认）**：火炮 `creature_template.StaticFlags3 = 2097216 = 0x200040`，含 **`0x200000` = `IMMUNE_TO_PLAYER_BUFFS`**（`CreatureDefines.h:126`）→ `Spell::EffectApplyAura`（`SpellEffects.cpp:3149-3152`）判定"玩家控制的施法者 + 生物目标 + 免疫玩家增益 + 该 aura 为增益"→ **直接 return，aura 根本不创建** → `Aura::HandleModCharm`/`Unit::TakeCharmOf`/`Player::CharmSpellInitialize` 一步都不执行。
  - 为何 39219 被判为"增益"：`IsPositiveAuraEffect`（`SpellMgr.h:1489`）——该法术 AttributesEx4 无 `AURA_IS_BUFF`、Attributes 无 `AURA_IS_DEBUFF`，且目标 38 = `TARGET_UNIT_SCRIPT_NEAR_CASTER`（`SpellTargetDefines.h:62`）不属于负面目标 → 返回 true。
- **定位证据（本地打点，2026-09-16 19:04~19:05）**：
  `[CANNONDBG] 39219 landed on Creature (Entry: 22443 ...): charmer=none hasAura39219=0`，且**没有任何魅惑链路日志**（法术命中回调跑了、aura 没落地）。
- **修复**：`dev/069_任务10911邪能火炮可被魅惑修复.sql`（幂等）：`StaticFlags3 = StaticFlags3 & ~2097152` → 2097216(0x200040) → 64(0x40，保留 `NO_FRIENDLY_AREA_AURAS`)。
  - 副作用：该炮从此可被玩家的增益/治疗 aura 命中（原本"免疫玩家增益"）；它是任务交互对象，可接受。若要保持该语义，可改为代码层放行 charm/possess（`SpellEffects.cpp:3149` 条件里排除 `SPELL_AURA_MOD_CHARM` / `MOD_POSSESS` / `MOD_POSSESS_PET`）。
  - 修复后实测（19:07:30）：`HandleModCharm aura=39219 apply=1` → `TakeCharmOf … hasCharmer=1` → `[CANNONDBG] … charmer=Player Asggd hasAura39219=1` ✅
- **附注（已验证"正常"，勿改）**：火炮两技能 **39221 Artillery on the Warp-Gate / 39222 Anti-Demon Flame Thrower 共享 15 秒 CD** —— `Category=1152`、`CategoryRecoveryTime=15000`，**客户端 `Spell.dbc` 同一份值**（实测 field1=1152 / field24=15000），即暴雪原始设计（要么轰门、要么烧小鬼）。服务端改无效（客户端会继续按自己的 DBC 灰图标、不发施法包），要改只能改客户端 DBC，不建议。

## [机制] 召唤物被吸附到 vmap 地板 → 全局改为"只向上兜底"（不再向下吸）— 2026-09-16 已改（本地，待推云）

- **现象（同一类问题的第 3 起）**：动态生成的单位被引擎**向下吸附**到 vmap 地面，落到可见地板之下：
  1. WMO 平台悬于露天 ADT 之上被吸到远处 ADT 层（见 `Unit.cpp:12597` 原 `[BOUNDED-HEIGHT]` 注释，map530 -1154,1907）；
  2. **急救任务**患者被吸进床里（床是客户端 GO，服务端 vmap 没有它）→ commit `81a1018d04`；
  3. 本次**不稳定邪能小鬼**：脚本点 z=155.07/156.60（门内可见地板），被吸到 vmap 地板 **153.9**（玩家 `.gps` 实测 GroundZ=FloorZ=153.9），于是卡在传送门里。
- **定性（上游 vs 我们）**：`CreatureCreatePos::SelectFinalPoint`（含 `else if (!staticSpawn) cr->UpdateAllowedPositionZ(...)`）与 `Creature::Create` 里的调用点**上游逐字节相同** → "生成时吸附"是 **cmangos 主分支既有设计**；`SetNextCreatureSpawnKeepZ` 才是本 fork 加的（上游无）。差别只在 `Unit::UpdateAllowedPositionZ` 实现：上游无条件吸（`if (z > maxZ) z = maxZ; else if (z < groundZ) z = groundZ;`），本 fork 已收窄（水中豁免 / `GetHeightInRange` 4 码有界 / 落差 ≤10 码护栏）。
- **修法（站长定案"方案 B"）**：`Unit::UpdateAllowedPositionZ` 里**删除向下吸附**，只保留向上兜底：
  `if (z < groundZ && groundZ - z <= 10.0f) z = groundZ;`
  - 语义：脚本/DB 给的 Z 高于地面时**信任它**；低于地面仍被提起（防掉地下/穿地照旧）；10 码护栏照旧（防 GetHeight 回退到错误层导致无限下坠抖动）。
  - 影响面：只影响**动态生成**（`staticSpawn=false`：召唤/宠物/图腾/脚本 spawn）；DB 静态刷点本来就不走吸附。风险：脚本故意生成在半空的怪不再被拉下来（会悬空）。
  - `SetNextCreatureSpawnKeepZ`（一次性钩子）保留，供急救等"必须钉死 Z"的场景使用。

## [机制] 不稳定邪能小鬼（22474）出生成后卡闪避：拴绳半径 30 码 < 门到炮 40~50 码 — 2026-09-16 已修（本地，待推云）

- **现象**：小鬼从传送门出来就"卡在门里、反复卡闪避"。
- **证据（本地日志）**：`[LEASH] EVADE guid=5860258…5860287` 每 3 秒整批刷（临时 guid 段即召唤出来的小鬼）。
- **根因**：`CombatManager.cpp:117-118` —— "距上次续期位置 > **LeashRadius（默认 30 码，`World.cpp:713`）** 且 15 秒（`Pursuit`）未续期" → 强制 EVADE。小鬼在门边生成（北 2188.34/5476.63、南 1981.73/5315.39），而被魅惑的火炮在 **39.7 码（北）/ 49.8 码（南）** 外 → 一出生长距离超限，EVADE 把它拉回出生点（= 传送门），再 AttackStart → 再超限 → 死循环。（打到目标会续期，但它当时动不了。）
- **修复**：`npc_warp_gate::JustSummoned` 里对 22474 加 **`GetCombatManager().SetLeashingDisable(true)`**（与同文件被魅惑火炮自己的做法一致）。
- 相关：小鬼的出生 Z 问题见上一条（vmap 吸附 / `SetNextCreatureSpawnKeepZ`）。

## [机制] 标记"禁止战斗移动"的单位仍会追击：HandleMovementOnAttackStart 未查 IsCombatMovement — 2026-09-16 已改（本地，待推云）

- **触发**：玩家对被魅惑的火炮使用**宠物攻击指令**时，火炮会移动（`PetHandler.cpp:252-254`：`AttackStop() → MotionMaster()->Clear() → AI()->AttackStart(target)`）。
- **根因**：`UnitAI::HandleMovementOnAttackStart`（`UnitAI.cpp:345`）只挡 `UNIT_STAT_CAN_NOT_REACT` / `UNIT_STAT_PROPELLED`，**没有检查 `IsCombatMovement()`**（即 `UNIT_STAT_NO_COMBAT_MOVEMENT`），于是无条件 `MoveChase(...)`。而火炮是 `Scripted_NoMovementAI`（`sc_creature.h:229-237`，构造里 `SetCombatMovement(false)`），本就该站桩。
- **修法**：`if (!m_unit->hasUnitState(UNIT_STAT_CAN_NOT_REACT) && IsCombatMovement())` → 让 `SetCombatMovement(false)` 在攻击启动路径上也生效（同时覆盖 EventAI 的 `NO_COMBAT_MOVEMENT` 动作与所有 `Scripted_NoMovementAI` 脚本）。
- **确认（站长 2026-09-16）**：「宠物攻击指令会让火炮移动」**确为问题**——火炮应当站桩。同批被提到的另一条"自动还击"现象经判定为**小鬼自爆**（`SPELL_UNSTABLE_EXPLOSION` / `SPELL_UNSTABLE_FEL_IMP_TRANSFORM`），与火炮无关，**非 bug**。
- **同类路径核对**：宠物指令的**跟随/停留**分支（`PetHandler.cpp:176-193`）只改 `CharmInfo` 命令状态、不发移动指令；"被魅惑单位跟着玩家跑"是 `PetAI` 的行为，而火炮因 `StaticFlags2` 带 `ACTION_TRIGGERS_WHILE_CHARMED` 会保留自己的脚本 AI（`SetCharmState("")` → `nullptr`，`Unit.cpp:10080-10098` 不换 AI），故不会跟随移动 ✅。
- **未改的同类点（留档）**：`UnitAI::DoStartMovement`（`UnitAI.cpp:818`）同样不查 `IsCombatMovement()`，但只在"逃跑结束重新追击"等少数路径被调用，暂无实际症状，故未动。

## [数据] 离群刷点 guid 65905（Shienor Wing Guard）— 2026-09-16 已删（本地，待推云）

- **来源**：玩家发现"guid 65905 看起来有点奇怪"。它是 creature **18451 Shienor Wing Guard**（map 530），刷点
  `x -1957.77, y 3759.43, z -7.93`，站桩（`spawndist=0, movementtype=0`）。
- **为何异常**：同模板 12 个刷点里，另外 11 个都在 Veil Shienor 主营地一带（x -1600~-1900 / y 3869~4438 / **z 45~53**），
  唯它跑到下营地西南 **60~90 码**外的谷地、矮 53 码，且不参与任何事件/池/路径。
  （补充：那片谷地确有"下营地"人口——20×18449 Talonite + 7×18450 Sorcerer，z ≈ -4.8~13.8——所以地形上不算错乱；
  "不会动"也不异常：12 个 Wing Guard 里 8 个本就是站桩。）
- **定性**：`_tbc-db_ref/Full_DB/FullDB.sql` 与 `Nmangos-tbc-db` 备份里坐标与本库**完全一致** → 上游 tbc-db 继承数据，非本 fork 改动。
- **处理（站长定案：当作冗余刷点删除）**：`dev/070_删除离群刷点65905.sql`（幂等）。
  关联表核对均为 0 行：`creature_movement` / `creature_addon` / `game_event_creature` / `pool_creature` / `creature_spawn_data`；
  SQL 内仍做防御性清理。删除后同族剩 11 个 Wing Guard。
- **生效**：`creature` 表在启动时载入 → 需重启 mangosd 生效（云端随 nightly 重启）。

- **说明（2026-09-17 晚）**：本批 SQL 最终只剩**一个文件** `dev/071_刷新时间整改_整合版.sql`（共 8 节 / 17 条语句，全 entry 口径、幂等）。它先后取代了两批旧文件：① 早先编号的 `dev/071`~`dev/077`（矿脉 / Or'Kalar / 敌对普通怪 3 批 / 22991 / 旗标 / 死登记，均已删除；本文件仍叫 071 属**编号复用**）；② 本轮的 `dev/072`~`dev/074`（组成员与组 override / 点名 entry / 精英统一 900，已并入并删除）。已用云端从库（本地 3307）预演 + 幂等复跑（17 条全部 0 行受影响）；过程记录已并入本章，原 `dev/总结_20260917_刷新时间整改.md` 已删除。

## [数据] 刷新时间普查与统一：敌对普通怪 → 300 秒 — 2026-09-17 已改（本地，待推云）

- **起因**：查"NPC 21419 刷新时间显示 42 秒、实际却要等 3 分 54 秒"时发现本 fork 的刷新被"尸体腐烂计时"拖住；修掉之后暴露真问题：**库里存在大量 15/25/90/150 秒的普通怪刷点**（21419 全部 75 个刷点都是 30–60 秒）。
- **⚠️ 数据血统结论（重要）**：
  - **WoW 客户端不含刷新时间字段**（DBC 里没有）→ `creature.spawntimesecs` 完全由私服 DB 自造，**不存在权威原值**；
  - **pfQuest-tbc 的刷新值不是独立第三方数据**：其官方仓库说明 TBC 数据**取自 CMaNGOS**（与本库同源，只是另一份 2020 年快照）。互证实例：`21419` pfQuest=**40** 与本库改动前的 40/40 一致、`18548` 两边都是 **60**；据此，当日曾按"pfQuest 说 300"改的 **43 entry / 909 刷点已全部回滚**；
  - 表结构 `creature.spawntimesecsmin/max` 的 `COLUMN_DEFAULT = 120`（全库 5,763 个刷点正好 120 秒 ≈ 插入未写值）；GM `.npc add` 会把运行时默认 **25 秒**写进库（`Creature.cpp:1289`）→ 全库 25/25 共 506 条；
  - 同一只怪出现多种值的成因 = **分批录入**（主体刷点 guid 连续成段；后补的零散点各带当时的值，空间上往往各自成片 = 不同"营地"）。
- **普查规模**（世界地图 · rank0 · 有掉落的普通怪）：`300` 占 **60.9%**，其后 275(6.6%)、120(5.4%)、180(4.6%)、360(3.9%)、333(2.3%)、600(2.1%)、345/400/315/500/350(各约 1%)；**`≤60 秒` 仅 108 个刷点 / 26 个 entry**。
- **站长决定（2026-09-17）**：**所有敌对普通怪（含任务物品掉落来源）统一 300 秒**，除非有明确证据（= DB 仓库 `Updates` 里显式设置过刷新时间的 entry/刷点）。理由：①零售常识与主流就是 5 分钟；②改前玩家实际体验（尸体计时耦合）也≈5 分钟；③快刷新对敌对怪是负体验，且尸体只活几秒（来不及捡/剥皮）。
- **改动（本地已执行，共 3 批 + 1 处特例，合计 ≈17,725 刷点）**：
  - `dev/073_敌对普通怪刷新时间统一300秒.sql`（第 1 批）：**13,267 个刷点 / 769 个 entry → 300**；排除活动怪、生物刷怪组、任务发布/交付/商人/训练师 NPC，以及 130 个"有证据"entry + 58 个"有证据"刷点。备份表 `creature_spawntime_bak_20260917_red`；
  - **第 2 批（同一口径的"近 300 补偿档"）**：47 个刷点 → 300。依据 `Updates/0466_CDB-4617_c.2949,2950,2951.sql:208` 的注释 —— "**Adding Dynguid shortens actual respawntime, hence a increase is required to prevent "natural" overspawn**"，即 180/240/275/315/333/345/350/360 这批值是**为补偿 dynguid 缩短实际刷新而人为加过的**，并非原始设计；既然本次代码改动已让"库里的值 = 实际刷新"，补偿前提消失 → 一律回到 300；
  - **第 3 批（含中立/黄名普通怪，站长 2026-09-17 追加确认）**：**4,404 个刷点 → 300**（值档 275×1260 / 180×594 / 360×367 / 450×266 / 120×221 / 90×210 / 345×184 …）。备份表 `creature_spawntime_bak_20260917_all`；
  - **校验**：全部"普通怪"范围内**剩余非 300 = 0**；仍非 300 的只有三类，且均属**正确排除**：① 活动刷点（`game_event_creature`，如 525 癞皮狼仅剩的 2 个点）② 生物刷怪组成员（如 300 Zzarc' Vul 的 3 个点）③ 任务/商人/训练师 NPC 与脚本怪。
  - ⚠️ **过程记录（教训）**：第 2 批首次执行时**漏加"敌对/普通怪"过滤**，误改 16,404 个刷点（含 3,271 个 NPC 商人/任务 NPC、999 个精英、595 个脚本怪、44 个小动物），已**全部回滚**（备份表 `creature_spawntime_bak_20260917_near300`）后按正确口径重做 → 批量改数据前必须先写清 WHERE 口径并 dry-run 核对分类构成。
  - `dev/072_任务怪奥卡拉尔刷新时间修正.sql`：**Or'Kalar（2773）** 5 秒 → 300 秒。它是任务 **[680] The Real Threat** 的任务物品来源（100% 掉 4551 奥卡拉尔之头），有 7 个候选刷点（实测同一时刻只刷 1 只，无需 pool）；vanilla 参照库为 1 点 400 秒，5 秒属手工随意设定。备份表 `creature_spawntime_bak_20260917_orkalar`；
  - `dev/071_矿脉刷新时间改为300秒.sql`：矿脉组 `RespawnOverride` **45/90 → 300/300**（保留 `dev/051` 的 MaxCount 提高）。**`dev/038` 当年"按 pfQuest 矿脉频率 45s"的依据已失效**（同源数据），故折中取 300 秒。
- **保留（有明确证据，未动）**：共 61 个 entry 当前值仍 ≠300，依据来自 DB 仓库 `Updates` 的显式设置，例如：`21419` 30–60（`0492` 注释 "make event be more randomized"）、`19918` 20–45（`0664` CoT 任务怪）、`521 鲁伯斯` 14400–21600 / `462 乌尔图斯` 75600–115200 / `2609 地占师弗林塔格` 75600–115200 等稀有怪（`0465` VDB 稀有度分层）、`2955 平原陆行鸟` 180–240（`0466`）。清单见 `_agent_tmp\evidence_list.tsv`。
- **代码侧（同批收尾）**：**撤销**此前"死亡时把尸体时间压到 0.9×刷新"的改动（它会吞掉模板/脚本显式设置的长尸体，如副本 boss 的 1 小时尸体），保留三条：刷新时间到就清尸体重生（`Creature::Update` CORPSE 分支）、存档不再把尸体时间当刷新时间（`Creature::SaveRespawnTime`）、`.npc info` 尸体倒计时显示修复（`Level3.cpp`）。
- **验证**：目标范围内非 300 残留 = **0**；本地已重启（22:11:52）生效。
- **补记 1：`game_event_creature` 死登记普查（2026-09-17）** —— 表里有 **262 行登记指向不存在的活动**（全部是负数 event，18 个不同值；例：`-12` 只含 `299 幼狼×3 + 525 癞皮狼×2`）。这些登记**永不生效**，属死数据，而且会把普通刷点**误判成"活动刷点"**（本次就因此漏过了癞皮狼那 2 个点）。
  - 处理：`dev/074_清理无效活动登记.sql`（先备份到 `game_event_creature_bak_dead_20260917` 再删除；本地已执行：**262 → 0**）。（该文件后并入 `071` 第 6) 节）
  - ⚠️ **教训：判"活动刷点"必须先确认该 event 在 `game_event` 表里存在且会运行**，不能只看 `game_event_creature` 有行。
- **补记 2：因死登记漏改的 134 个刷点已补齐** —— 含 `525 癞皮狼`（180×2）、`3099/3100 老斑野猪` 180、`3240 雷角蜥蜴` 275、`3035 平原狮` 360、`3255 赤鳞尖啸龙` 275、`3245 暴躁的平原陆行鸟` 275、`9460 加基森卫兵`、`18464 迁跃追猎者` 等 → 已统一 300。⚠️ 这 134 行**未单独建备份表**（疏漏）；改前值可从 `creature_spawntime_bak_20260917_near300`（该表覆盖改前数值档 100–900 的行）恢复。
- **补记 3：`21419 地狱火攻击者`（Infernal Attacker）确定不改，保持 30–60 秒（2026-09-17 站长确认）** ——
  它是本章整条线的起点怪（"显示 42 秒、实际等 3 分 54 秒"就是它），核查后按"**有明确证据**"豁免，保留原值：
  - 现状（本地从库 = 云端）：**75 个刷点，全部 `map 530`（地狱火半岛），`spawntimesecsmin=30` / `max=60`** 无一例外；
    `Rank=0`（普通）· **`LootId=0`（无掉落）** · `ScriptName` 空 · `NpcFlags=0` · `Faction=90`（faction template 90 属敌对，实测 `IsHostileTo` 玩家 = 是）·
    `spawndist=5` + `movementtype=1`（游走）· `game_event_creature` **0 行**（不是事件刷点）· **不属于任何生物刷怪组**（无组 override）。
  - 证据出处：① `Updates/0492_WDB-5334_c.21419.sql:4` —— `UPDATE creature SET spawntimesecsmin = 30, spawntimesecsmax = 60 WHERE id = 21419;`
    注释 **"make event be more randomized (40 40)"**（作者刻意做随机化）；② `Updates/0505_CDB-4671_blasted_lands_stuff.sql:104–178`
    重建这 75 个刷点时**逐行写死 `30, 60`**，与 `21736 蛮锤防御者`/`21417 隐形地狱火施法者`/`21749 影月斥候`（三者均 300 秒）**同批插入** → 是配套设计的快速轮刷进攻方小怪。
  - 因此它同时满足两条豁免（**有明确证据** + **无掉落**），"普通怪一律 300"的整改**不覆盖它**；`071` 的任何 entry 列表里都没有 21419（实测 `<>300` 的 75 行一条都没被命中）。
  - ⚠️ **SQL 教训（重要，以后必踩）：cmangos 的 creature 与 gameobject 共用同一个 guid 域，`spawn_group_spawn` 表不带类型，
    只按 `Guid` 连 `spawn_group` 会误配成 GO 组。** 本次查 21419 时曾因此得到"75 个刷点全在刷怪组里"（组名却是
    "Azuremyst Isle - Copper Vein" 铜矿脉）；正确写法必须带类型过滤：
    `JOIN spawn_group g ON g.Id = s.Id AND g.Type = 0`（0 = 生物组 / 1 = GO 组）。加过滤后 21419 归属于生物组 = **0 行**。
    （同日 071 的最终核查语句里已带 `g.Type = 0`，结论不受影响。）
- **补记 4：云端预演 + 逐行差异核对，抓出并补上 110 行遗漏（2026-09-17 深夜）** ——
  - 云端 `git fetch`（走 `gh-proxy.com` 镜像）+ `reset --hard origin/release` → HEAD `ec241d9bd9`；`DRYRUN=1 bash /root/apply_dev_sql.sh` 确认今晚会按 **066 → 071** 顺序应用（marker 65，072/073/074 已不存在）。
  - **只读条件预演**（把 071 的每条 `UPDATE/DELETE` 自动改写成等价 `SELECT COUNT(*)` 在云端跑，**不写库**）：第 1)~5) 节合计 **17,922**，矿脉 **416**，Or'Kalar(2773) **7**，22991 **75**，假旗标 **35**，死登记 **262**，第 7) 节 **791**，组 override **417**，Zzarc' Vul **3**，第 8) 节精英 **1,123**，15743/15744 **7** —— 与本地口径完全一致。
  - **整表逐行比对**（云端 109,350 行 vs 本地 109,362 行，按 `guid` 对齐 `spawntimesecsmin/max`）：值不同 **19,827 行**，其中 **entry 不在 071 任何列表内的 = 110 行 / 12 个 entry** → **真遗漏**：
    - 原「第 2 批」47 行（`212,730,818,889,892,1251,2949,6846,16964`，值档 120/180/240/300/360，本地当时已改 300，**却从未并入任何 dev SQL**）；
    - 站长点名里不满足批次筛选条件的 3 个（`1756` 22 行 430→300、`21195` 33 行 180→300、`22252` 8 行 180→300，共 63 行）。
    → 已在 071 新增 **第 9) 节**显式列出这 12 个 entry；补后云端**残留缺口 rank0 / rank1 = 0 / 0**（本地复跑 071：18 条语句全 0 行，幂等）。
  - **两个方向的独有 guid 也已解释**：仅云端有 `65905`(18451) = `070` 今晚要删的离群刷点；仅本地有 13 个 = 本地测试手加的点（Kresky 9858、24792×2，以及 10 个普通怪测试刷点），不参与云端。
  - ⚠️ **环境注意**：云端 `creature` / `creature_template` / `game_event_creature` 是 **MyISAM** 表（`spawn_group` 是 InnoDB）→ **不能用"事务 + ROLLBACK"做试跑**，试跑只能用 `SELECT COUNT(*)` 只读核对。
  - ⚠️ **流程教训**：合并 dev SQL 时容易只合并"看得见的文件"，而**早先批次（第 2 批 47 行）从来就没写进任何文件**；这次是靠"目标环境 vs 本地终态"的整表逐行比对才抓出来。以后每次批量改数据，**收尾必须做一次终态逐行比对**，不能只按条数/抽样核对。

#### 整改完整汇总（2026-09-17，原 `dev/总结_20260917_刷新时间整改.md` 并入本章）

#### 四、数据改动（本地已执行）

**统一口径**：世界地图(0/1/530) · rank0 · 非小动物 · **有掉落** · 无 `ScriptName` · 无 NPC 旗标；排除 真实活动刷点、生物刷怪组成员、任务发布/交付/商人/训练师 NPC。
**站长决定**：**普通怪（不限阵营，含任务物品掉落来源）一律 300 秒**，除非有明确证据（DB 仓库里显式设置过刷新时间）。

| # | 内容 | 数量 | dev SQL | 备份表 |
|---|---|---|---|---|
| 1 | 敌对普通怪统一 300（排除有证据的 130 entry + 58 刷点） | **13,267 刷点 / 769 entry** | `dev/073_敌对普通怪刷新时间统一300秒.sql` | `creature_spawntime_bak_20260917_red` |
| 2 | 同口径的"近 300 补偿档" → 300 | 47 刷点 | 见 075 | — |
| 3 | **含中立（黄名）普通怪**统一 300 | **4,404 刷点** | `dev/075_普通怪刷新统一300秒_最终口径.sql` | `creature_spawntime_bak_20260917_all` |
| 4 | 因"活动死登记"漏改的补统一 | **134 刷点** | 075（口径已改为"只排除真实活动"） | （无独立备份，可从 `..._near300` 恢复） |
| 5 | 任务怪 **Or'Kalar（2773）** 5 秒 → 300 | 7 刷点 | `dev/072_任务怪奥卡拉尔刷新时间修正.sql` | `creature_spawntime_bak_20260917_orkalar` |
| 6 | **矿脉**组 `RespawnOverride` 45/90 → **300/300**（保留 `dev/051` 的 MaxCount 提高） | **416 组** | `dev/071_矿脉刷新时间改为300秒.sql` | — |
| 7 | 任务目标生物 **22991**（Skettis 轰炸日常 11008）180 秒 → **10 秒** | 75 刷点 | `dev/077_任务目标生物22991改为10秒.sql` | `creature_spawntime_bak_20260917_trigger` |
| 8 | 清理 **35 个敌对生物的假 QUESTGIVER 旗标** | 35 entry | `dev/076_清理敌对生物的假QUESTGIVER旗标.sql` | （全库 QUESTGIVER 3,813 → 3,778） |
| 9 | 清理 **262 行无效活动登记** | 262 行 | `dev/074_清理无效活动登记.sql` | `game_event_creature_bak_dead_20260917` |

**合计**：普通怪刷新统一 300 秒 ≈ **17,859 个刷点**；范围内剩余非 300 = **0**（验证通过）。

> ⚠️ **过程教训**：第 2 批首次执行时**漏加"敌对/普通怪"过滤**，误改 16,404 个刷点（含 3,271 个 NPC/商人、999 个精英、595 个脚本怪、44 个小动物），已**全部回滚**（备份表 `creature_spawntime_bak_20260917_near300`）后按正确口径重做。**批量改数据前必须先写清 WHERE 口径并 dry-run 核对分类构成。**

#### 五、代码改动清单

- `src/game/Entities/Creature.cpp`：CORPSE 分支（A）、`SaveRespawnTime`（C）、撤销 B（死亡时的尸体压制）
- `src/game/Chat/Level3.cpp`：`.npc info` 尸体倒计时显示修复（D）
- 已本地编译 → 部署 → 重启（`mangosd` 22:11:52 起运行新二进制）

#### 六、验证

- 数据侧：最终口径下"非 300 残留 = 0"；逐批条数与备份行数一致。
- 代码侧：本地已重启新二进制。
- **尚待游戏内抽验**：① 杀一只 dynguid 怪（`.go creature id 21180`）应 ≈300 秒；② 挖一个矿应 5 分钟刷新；③ 尸体不再几十秒消失（恢复为模板/脚本设定值）；④ 22991 应 10 秒刷新。

#### 七、已决定"不做"的（避免以后重复讨论）

| 项 | 结论 | 理由 |
|---|---|---|
| 无掉落（`LootId=0`）的敌对怪（825 刷点 / 54 entry） | **不批量改** | 多为事件波次/触发器（如奎岛 25027/25028/25030/25031/25033、天灾入侵），且有证据的 21419 在内 |
| 真实活动刷点（~7,000 点） | **不动** | 活动期间由活动系统整批刷出，快刷是事件需要 |
| 稀有怪"多点无 pool"（Nimar / Flintdagger / Nazjak） | **不动** | 多点各自超长刷新（5–48 小时）已接近"只刷一个"的体感 |
| 轰炸任务目标统一成一个值 | **不做** | 按类型定值：触发器 10 秒、活体轰炸目标 30–60 秒（如 19398=35 秒）、事件波次不动 |
| 触发器 `23102 Terokkar Trigger`（25 秒） | **不动** | 无任何任务/脚本引用，来历不明 |
| 后续刷新时间调整方式 | **一个一个改，不扫同类** | 站长 2026-09-17 定的工作方式 |

#### 八、经验教训（建议长期遵守）

1. **先核实数据血统再动手**：客户端不含的数据 → 只能来自私服 DB 血统（各家互为副本），第三方插件（pfQuest/Questie）多半同源，**不能当独立证据**。
2. **批量改数据前**：写清 WHERE 口径 → dry-run 看分类构成 → 备份（guid 级）→ 执行 → 复查残留。
3. **判"活动刷点"**：必须确认该 event 在 `game_event` 表里存在且会运行，不能只看 `game_event_creature` 有行。
4. **"有明确证据"的定义**：DB 仓库 `Updates/` 里有显式设置该刷新时间的语句（含注释更好）——这类一律保留、不改。

#### 九、产出文件清单

- **说明（2026-09-17 晚）**：本批 SQL 最终只剩**一个文件** `dev/071_刷新时间整改_整合版.sql`（共 8 节 / 17 条语句，全 entry 口径、幂等）。它先后取代了两批旧文件：① 早先编号的 `dev/071`~`dev/077`（矿脉 / Or'Kalar / 敌对普通怪 3 批 / 22991 / 旗标 / 死登记，均已删除；本文件仍叫 071 属**编号复用**）；② 本轮的 `dev/072`~`dev/074`（组成员与组 override / 点名 entry / 精英统一 900，已并入并删除）。已用云端从库（本地 3307）预演 + 幂等复跑（17 条全部 0 行受影响）；过程记录已并入本章，原 `dev/总结_20260917_刷新时间整改.md` 已删除。

**dev SQL**：`071_刷新时间整改_整合版.sql`（**唯一文件**，8 节 / 17 条语句；原 071–077 与 072–074 均已并入）
**文档**：`KNOWN_ISSUES.md`（新增章节 + 补记 1/2/3）、`README_文档导航.md`（索引行 1576）、`功能更新手册_卡布魔兽.md`（矿脉那一行+章节改为 2026-09-17 定稿）、`HANDOFF_卡布魔兽运维.md` §四（pfQuest 血统 + 教训）
**备份表**（本地库）：`creature_spawntime_bak_20260917_red`(13,267) / `..._all`(4,404) / `..._near300`(16,404) / `..._orkalar`(7) / `..._trigger`(75) / `game_event_creature_bak_dead_20260917`(262)

#### 十、待办（云端）

1. 云端**只读 dry-run** 核对 071 的影响条数（本地/云端 guid 空间不一致，必须按条数确认）；
2. 应用 071（夜间 04:06 自动或维护窗口手动）+ 重启 mangosd；
3. 上线后抽查（`.npc info` / `.go creature`）+ 观察玩家反馈（尤其新手区：幼狼/霜鬃 15 秒 → 300 秒）；
4. **git 提交**：`dev/*.sql`、`KNOWN_ISSUES.md`、`功能更新手册_卡布魔兽.md`、`README_文档导航.md`（提交前确认无云端凭据）；
5. 稳定运行几天后再清理本地备份表与 `_agent_tmp` 临时脚本。
- **追加记录（2026-09-17 晚，站长决定）**：
  - **071 第 7) 节（原 `dev/072_刷怪组成员与组override统一300秒.sql`，已并入 071 并删除）**：**生物组（`spawn_group` Type=0）成员里的普通怪** 62 entry / 614 刷点 → 300；并把所有非 300 的组 `RespawnOverride` 改为 300/300（含 `8001 Silithus Hive'Ashi Drone` 600/600）。另补齐 `300 Zzarc' Vul` 3 个 240/300 的漏网刷点（原条件按 `max` 判断漏了 `min<>300` 的行）。本地已验证：剩余非 300 = 0。
  - ⚠️**已作废**（精英不能设 300；最终按"普通 300 / 精英 900"，见下文"规则定案"）——当时写的 `dev/073_指定entry刷新统一300秒.sql` 把站长**逐个点名**的 17 个 entry 全设成 300（1756 暴风城皇家卫兵、21195 驯养的地狱野猪、22252 龙喉苦工、22253 龙喉晋升者、18856 奥术歼灭者、18886 法兰伦击碎者、6498 魔暴龙、24976 晨锋血骑士、4700 老迈的科多兽、19642、18873、18880、4062、4065、3274、3275、10916）。核查：这些刷点 `in_real_event` 全为 0（**不是**事件刷点）。本地验证：剩余非 300 = 0。
  - **稀有：一律不改** —— rank 4（稀有，291 entry，均 ≈16 小时）与 rank 2（稀有精英，73 entry，均 ≈19 小时）保持现状（含 259200 秒=72 小时的极端值）；rank 3（世界 boss）亦不改。
  - **精英 rank 1：除站长点名的以外不改**（其中 1–10 秒那批如 `Leokk`/`Mogor`/`Stormwind Soldier` 是安其拉开门/事件守卫，不可动）。
  - **术语澄清（重要）**：**事件刷点** = 登记在 `game_event_creature` **且该 event 真实存在于 `game_event` 表**的刷点 —— 平时不出现，活动期间由活动系统整批刷出/移除，其 `spawntimesecs` 只在活动期间被击杀后起作用；统一 300 时一律排除（真实活动约 7,000 点）。
  - 作废项：原待办⑤（"还差一个覆盖第 2/3 批的 dev SQL"）已由 `071_刷新时间整改_整合版.sql` 覆盖。

- **规则定案（2026-09-17 晚，站长确认）**：**普通怪 = 300 秒 / 精英（rank 1）= 900 秒（15 分钟）**，**稀有（rank 2 稀有精英 / rank 4 稀有）与世界 boss（rank 3）一律不改**。
  - 站长逐个点名的 17 个 entry —— rank=0 的 13 个（1756 暴风城皇家卫兵 / 3274 / 3275 / 4062 / 4065 / 4700 老迈的科多兽 / 10916 / 18873 / 18880 / 19642 / 21195 驯养的地狱野猪 / 22252 龙喉苦工 / 24976 晨锋血骑士）→ 300，rank=1 的 4 个（6498 魔暴龙 / 18856 奥术歼灭者 / 18886 法兰伦击碎者 / 22253 龙喉晋升者）→ 900。核查：这 17 个刷点 `in_real_event` 全为 0（**不是**事件刷点）。
  - ⚠️ **纠错（2026-09-17 深夜，云端预演时发现）**：曾判断"这 17 个已全部落在 071 第 1)/7)/8) 节规则内 → 无需单列语句"，**该判断不成立**：精英 4 个确实在 8) 的 224 entry 列表里，普通 10 个也在 1)/7) 里，但 **`1756`（22 点，云端 430）、`21195`（33 点，云端 180）、`22252`（8 点，云端 180）不满足批次筛选条件、从未进入任何列表**（合计 63 行）。已改为**在 071 第 9) 节显式列出**（见补记 4）。教训：**合并/删文件前必须做一次"本地终态 vs 目标环境"的逐行差异核对，不能凭"应该落在规则内"推断。**
  - 原 `073_点名entry刷新统一_普通300_精英900.sql` 已并入 071 并删除，其前身 `073_指定entry刷新统一300秒.sql` 因把精英也设成 300 亦已删除。
  - **071 第 8) 节（原 `dev/074_精英刷新统一900秒.sql`，已并入 071 并删除）**：范围内精英（世界地图 · rank1 · 有掉落 · 无 ScriptName · 无 NPC 旗标 · 非小动物 · 非真实活动 · 非任务/商人/训练师，**含刷怪组成员**）—— 写作**按 entry 的 224 entry 列表 → 900 秒**；当次需改值的行数为 **1,099 刷点 / 212 entry**（原值 600/300/610/1200/1800/430/660/120/180/172800 等）。本地验证：范围内剩余非 900 = 0。
  - ⚠️ **例外 2 个 entry：`15743` / `15744`**（同一 entry 既有天灾入侵**活动刷点** 3600/86400、又有普通刷点 900）→ 无法用 entry 列表区分，故在 071 第 8) 节末尾**单列一条**，按**运行期活动登记**（`game_event_creature` 关联存在的 `game_event`）排除活动刷点，**不硬编码 guid**（本地/云端通用）。这也是合并后 071 里唯一一处子查询，已在文件头注明。
  - 说明：`1756 暴风城皇家卫兵` rank=0 → 按普通怪 300；事件守卫（rank1 但 1–10 秒，如安其拉开门用）因属于真实活动/事件而**排除在外**未动。

- **待办**：①云端按 nightly 应用 **`071_刷新时间整改_整合版.sql`（唯一文件，18 条语句）** —— 云端只读预演已完成、条数已核对（见补记 4），今晚 04:06 自动应用后需**再跑一次残留缺口查询确认 0**；②线上抽查 `.npc info`；③新手区（幼狼/霜鬃等）体感若变化过大，可按备份表按 entry 回滚；④"事件/脚本 NPC 的 5 秒值"（孤儿周、安其拉/太阳井事件兵等）按证据保留未动；⑤（已作废）原"还差一个覆盖第 2/3 批（近 300 档 + 中立怪）的 dev SQL"—— 已由 `071_刷新时间整改_整合版.sql` 覆盖，无需再做。
