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

### 三层对照（2026-09-17 整理；分清"哪一层被验证过"）

> 起因：复查"内存基线从 ~1200MB 降到 ~670MB"的归因时发现手册记错 —— 那下降是**配置**的功劳，不是 mallopt。

| 层 | 问题 | 措施（提交） | 实测收益 | 验证状态 |
|---|---|---|---|---|
| ① 真泄漏 | active 怪 + `ForceLoadGrid` 永久锁 → 网格只增不减 | `8499927c2`（8-20）+ **配置** `Autoload.Active=0` / `mmap.preload=0` / `Instance.UnloadDelay=600000` | 启动内存 **~1180 → ~600MB**、启动网格 **74 → 1-3** | ✅ 已量化 |
| ② 分配器归还策略 | glibc 的 `M_MMAP/M_TRIM_THRESHOLD` 会**动态上调**（128KB → MB 级），涨上去后大块 free 不再归还 OS | `7fb83c8ae`（8-29）：两者钉死 128KB + 启动 `malloc_trim(0)` | **未单独量化**（同两天还在改配置，混在一起） | ⚠️ 原理成立、效果未证 |
| ③ arena 数量 | glibc 默认最多 `8×nproc` 个 arena（本机 nproc=2 → 16），实测长出 **6 个 ~64MB**（≈380MB），碎块不归还 | 2026-09-17：`MALLOC_ARENA_MAX=2`（写进全部 13 个启动脚本） | **本地 A/B 测不出差别**（见下） | ⚠️ 疑似 no-op |
| ④ 内核页粒度 | THP=`always` 时 **522MB 位于 2MB 大页**，大页**不可部分归还**（页内剩一个小对象整块就还不了） | 2026-09-17：THP → `madvise`（systemd 单元 `thp-madvise.service`） | **机制确认生效**（大页→0）；**RSS 效果为噪声级** | ⚠️ 生效但收益不明 |

- **归因更正（重要）**：手册早期写的"mallopt 上线后空载基线 ~1200MB → ~670MB"是**错误归因** —— 那 1200→600MB 实测来自
  ①的配置项 `Autoload.Active=0`（见上表 8-20 数据）。② 的作用是"**防止阈值随运行时间动态上调**"，
  原理上对"跑久了才涨得明显"这个症状是对症的，但没有单独做过 A/B。
- **本机 2026-09-17 实测（改动前基线）**：mangosd RSS 1,188MB / 20h、`AnonHugePages` **522MB（占 44%）**、
  6 个 ~64MB anon arena 段、无 `MALLOC_*` 环境变量；同时 `creatures/gameobjects` 随玩家活动正常增减、
  下线 5 分钟后回落近半 → **对象侧没有泄漏**，剩余增长属于 ②③④（分配器/页层）。
- **验证顺序（分步单变量）**：先测 ③④（2026-09-17 晚随 nightly 生效，配置不动 → 干净 A/B）→
  若仍涨，再回头单独 A/B ②（临时去掉 mallopt 跑一天）→ 仍不行才上 heaptrack 类工具。
- **配套观测**（2026-09-17 起）：`[MEMSTAT]` 每 5 分钟记录 `maps/creatures/pets/gameobjects/dynobjs/players`
  （Linux 另含 `heap_inuse/free/arena`），写入 `/opt/mangos/logs/MemStat.log`；一键体检 `bash /opt/mangos/mem_detail.sh`。

### 本地 Linux（WSL Ubuntu）A/B 实测 —— 2026-09-17 凌晨

**怎么测的**：本地 WSL2(Ubuntu 26.04 / 内核 6.18 / glibc 2.43) 里用 `file://` 从本仓库克隆 release 分支，
`RelWithDebInfo -O2 -g -fno-omit-frame-pointer` 编译（**538MB 带完整调试符号**），数据从 `x64_Debug` 拷入 WSL 内盘，
DB 指向 Windows 上的 MySQL（`wow@%` 用户），用 `screen` 起进程（**必须**：直接 nohup 会因控制台读 stdin EOF 而自杀），
采样 `/proc/pid/smaps_rollup` + `pmap -x` + `MemStat.log`。脚本：`_agent_tmp/wsl/wsl_ab_mem.sh`（A/B）、`wsl_build.sh`、`wsl_prepare_data.sh`。

| 场景 | ③④ 关（ARENA=16, THP=always） | ③④ 开（ARENA=2, THP=madvise） | 结论 |
|---|---|---|---|
| 空闲（8 分钟） | 起 677 → 末 **557MB**；`AnonHugePages` 462~600MB | 起 677 → 末 **508MB**；`AnonHugePages` **0** | ④ 生效；RSS -49MB（略好） |
| 带负载（`Autoload.Active=1`，10.6k 怪，8 分钟）⚠️ **非云端同构，见下** | 起 1,070 → 末 **1,036MB**；大页 **652MB**；~64MB 段 **3**；`heap_arena` 760MB | 起 1,074 → 末 **1,046MB**；大页 **0**；~64MB 段 **3**；`heap_arena` 739MB | ④ 生效；**③ 无差别**；RSS 略差 10MB |

- ⚠️ **方法论更正（站长指出，代码已核实）**：第二组"带负载"用 `Autoload.Active=1` 是**无效对照** ——
  active 怪会给自己**出生网格**挂 `unloadActiveLock`（`Map.cpp:1700 incUnloadActiveLock` / `1735 dec…`），
  而 `GridStates.cpp:59 RemovalState::Update` 要求 **`if (!info.getUnloadLock())` 才允许卸载** →
  **只要 active 怪在活动列表里，那 74 个预加载网格永远不会被回收**。也就是说该组构造的是"网格被钉住"的场景，
  与云端 `Autoload.Active=0`（完全懒加载）**不同构**；其内部对比（③④ 同负载）仍成立，但不能外推到云端。
  以后要测"有负载"，正确做法是 **`Autoload.Active=0` + 真实玩家活动**（本地客户端登录，或直接用云端 3~4 人的日常负载）。
- **③ `MALLOC_ARENA_MAX=2` 很可能是 no-op**：两种配置下 ~64MB arena 段都是 **3 个**、`heap_arena` 几乎相同（760 vs 739MB）
  → 说明 glibc 在该负载下**本来就没长出很多 arena**，限制它没有内存收益，反而强制串行化分配（理论上有轻微吞吐代价）。
  云端那"6 个 ~64MB 段"的成因需要云端实测确认（可能包含主堆 brk 段）。
- **④ THP→madvise 机制确认、收益不明**：`AnonHugePages` 652/600MB → **0** 是干净的生效证据；但 RSS 效果是**噪声级**
  （空闲 -49MB、带负载 +10MB）→ **不能声称它省内存**。
- **两组都没有出现"增长"**（8 分钟内净变化为负，世界加载完后释放）→ 本地**测不出**"增长被治好"，也测不出"变坏"；
  增长需要**真实玩家 + 更长时间**才有意义。
- **溢出结论**：本地 Linux 证明 ③ 大概率无用、④ 只解决"大页不可部分归还"这个理论问题而实测无感 →
  **"内存还在涨"这件事不能指望 ③④ 解决**；若云端数据也无改善，应转向 **② mallopt 单变量 A/B** 或 **bpftrace memleak 在线附着**（零停机）定位真实分配点。

## [本地化] 中文修复统一整合 + 覆盖检测工具（L1 台账）— 2026-09-17（`dev/079`，待推云）

- **问题类**：中文修复散落在多个小文件里（004/011/012/040/063/064/066/072/078），而 8-23~8-25 的
  locale **整包**（`030` 14MB / **`031` 65MB** / `032` / **`033` 20MB** / `033b` 12MB）在它们**之后**执行，
  把人工核对过的中文又改回去了 —— 「赫米特·奈辛瓦里二世」就是这么来的（011 第 24 行本来写对了）。
- **对策（站长定案）**：把中文修复**合并成一个文件、顺序手工排定** → `dev/079_中文locale修复_统一整合版.sql`
  （696 KB / 5,541 行）。段序：004 → 011 → 012 → 040 → 063 → 064 → 066 → 072 → 078 →
  **外部核对修正（72 条，优先级最高）**。文件头写明使用规则：**必须排在所有 locale 整包之后执行**
  （编号 079 最大；以后新增整包编号必须更小，或跑完成包后再补跑本文件一遍）；每段幂等。
  本地已应用 + 复跑验证（结果不变）✓，抽查 715/18180 正确 ✓。
- **检测工具（L1 台账，留在 `_agent_tmp/`）**：
  `locale_ledger.py`（把 9 个 locale 文件的写入按应用顺序重放成台账：**293,911 条写入 / 98,471 个键**）+
  `locale_official_check.py`（拿 tbc.60cj.com 逐条核对）+ `build_079.py`（合成）。
  体检四项（本地实测）：①被写成多个不同值的键 **7,290**；②**小修正写的值被整包改回去 93 条**；
  ③写了但库里不是该值 1 条（说明**覆盖**才是主因）；④中文字段里是纯英文 **6,770 条**。
  清单：`_agent_tmp\locale_conflicts_curated_vs_bulk.tsv`、`locale_english_leftover.tsv`、`locale_official_check.tsv`。
- **93 条外部核对结果**：官方 = 小修正值 **30** / 官方 = 整包值 34（本就无需改）/ 官方 = 都不是 **28** /
  60cj 无中文 20（其中部分用 wowhead zhCN 兜底）→ 共写入 **72** 条修正。
  ⚠️ 教训更新：**小修正文件也未必全对，权威只有外部官方库** —— 例 `11156 Green Skeletal Warhorse`
  官方就是「绿色骷髅战马」（先前我怀疑应为「绿色骸骨军马」是错的）。
  ⚠️ 另外 `zh_ref` 库**不能当权威**（它与整包同源，18180 在里面也是错的）。
- **待办**：`012`（AC 对照 618 KB）尚未逐条外部核对；建议按表分批（creature 名 → item 名 → quest 标题）
  扫"079 之后的值 vs 官方"，出对照表再改。
- **Blizzard 官方 API 可用性实测（2026-09-17，凭据存 `D:\Game\cmangos\_secrets\blizzard_api.json`，仓库外）**：
  - ✅ **正确的命名空间是 `static-classicann-{region}`**（Burning Crusade Classic **Anniversary**，TBC）——
    文档见 `.../world-of-warcraft-classic/guides/namespaces`；`static-classic1x-*` 是 Classic Era、
    `static-tbc-*` / `static-wrath-*` 已废（403）。主机用 `https://{us|eu|kr|tw}.api.blizzard.com`。
  - ✅ **物品名可查**：`/data/wow/item/{id}` —— 不带 `locale` 时一次返回**全部语言**
    （`zh_CN` / `zh_TW` / `en_US` / `ko_KR` …），带 `?locale=zh_CN` 会拍平成字符串。**A 级官方数据**。
  - ❌ **官方 API 的覆盖边界（实测）**：**只有物品**，而且**必须是现役物品** ——
    已被游戏移除的老任务物品一律 **404**（本次 35 条里 22 条如此）；**任务标题**无端点（quest 404）、
    **NPC 名**无端点（creature 404）、**法术** 404、**游戏物体** 无资源。这四类只能人工或退到 C 级。
  - ⚠️ **过滤规则**：官方 `zh_CN` 有可能是**纯英文**（例 23233-23235 那几个开发用 Bryanite 石头返回
    `Red Bryanite of Strength stuff`）→ **必须跳过纯英文**，否则会把英文写进中文字段。
- **本次成果落点**：`079` 第 10 段已拆成 **10a = A 级（Blizzard 官方 API，20 条 / 10 个物品，含 zh_TW）** 与
  **10b = C 级（二手来源，72 条，标注待复核）**；A 级核对还纠正了"两边都错"的例子（如 `30845` 官方是"多彩防护雕文"）。
  另有全量物品扫描脚本 `_agent_tmp/item_full_sweep.py`（26,906 个物品 × 官方 API → `item_full_A.tsv` / `stage_A_full.sql`）。
- **收口（2026-09-17）**：中文 locale 修复**只有一个文件**了 —— `dev/079_中文locale修复_统一整合版.sql`
  （707 KB，**12 段手工排定**：004 → 011 → 012 → 040 → 063 → 064 → 066 → 072 → 10a 官方 A 级 → 10b 二手 C 级 →
  **11 任务标题回退 26 条（原 dev/080）** → **12 中文中点统一全角（原 dev/081，9,816 行）**）。
  `dev/078` / `080` / `081` 已并入并**移出 dev/**（留档 `_agent_tmp/merged_sources/`）。本地已应用 + **幂等复跑 0 错误** ✓；
  抽查：`715 赫米特・奈辛瓦里二世` / `18180 赫米特・奈辛瓦里` ✓、`9853 侵占者古罗克` ✓、`8331 奥蕾尔・金叶` ✓；
  残留"戈隆克" = 0 ✓、残留半角中点 = 0 ✓。
- **新规则（本次定）**：~~**中文人名/地名里的中点一律用全角 `・`(U+30FB)**，半角 `·`(U+00B7) 视为错；~~
  ⚠️ **该规则已于 2026-09-17 晚作废**（站长游戏内实测：客户端字体**没有 U+30FB 字形**，全角点显示成"方块"）：
  **正确写法是半角 `·`(U+00B7)**。回退脚本：`dev/080_中文中点回退为半角点.sql`（9,960 行 / 12 列，
  必须排在 079 之后执行；本地已应用、残留全角 = 0）。核对脚本仍要做全半角归一化，但基准值改成半角 `·`。
- ⚠️ **`mysql source` 打不开含中文的路径**（`Failed to open file ... error: 42`）→ 应用本文件时先
  `Copy-Item` 到 ASCII 路径再喂给 mysql（本次已踩）。

## [本地化] 纳格兰「赫米特·奈辛瓦里」被显示成「赫米特·奈辛瓦里二世」— 2026-09-17 已修（`dev/078`，待推云）


- **现象（站长报告）**：纳格兰奈辛瓦里狩猎队里的 **Hemet Nesingwary(18180)** 中文名是「赫米特·奈辛瓦里**二世**」——
  那是荆棘谷 **Hemet Nesingwary Jr.(715)**（他儿子）的名字，被错误地套到了父亲身上。
- **官方对照（tbc.60cj.com 逐条查）**：`18180 Hemet Nesingwary`（纳格兰，70 级）= **赫米特·奈辛瓦里**；
  `715 Hemet Nesingwary Jr.`（荆棘谷，40 级）= 赫米特·奈辛瓦里二世 ✓（库里这条本来就是对的）。
- **修法**：`dev/078_中文locale修正_纳格兰奈辛瓦里.sql` ——
  `UPDATE locales_creature SET name_loc4 = '赫米特·奈辛瓦里', name_loc5 = '赫米特·奈辛瓦里' WHERE entry = 18180`
  （zhCN 与 zhTW 一起改；台服对这位父亲同样不带"小/二世"）。本地已应用并复核：18180 正确、715 未受影响、**复跑幂等 ✓**。
- **根因（重要，属于一类问题）**：`dev/011_中文locale修正.sql`（2026-08-16，16 KB，158 条手工修正）**第 24 行本来就写了这条修正**，
  但**后写入的整包把它覆盖了** —— 顺序如下（按文件首提时间）：
  `011`（8-16，手工小修正，写对）→ `030_中文locale更新包.sql`（8-23，14 MB，NPC 对话/任务文本）→
  **`031_中文locale整合完整包.sql`（8-23，写入 18180 时用的是错误的"赫米特·奈辛瓦里二世"）** →
  **`033_中文locale其他表_tbc_zh.sql`（20 MB，同样写到了 18180）**。
  也就是"**后写入的整包赢了**"，011 的小修正被吃掉 → 所以这条一直没生效。
  （其余被覆盖的同类修正还有 114 条，见下。）
- **连带发现**：用 dev/011 的 158 条语句逐条比对当前库，**115 条处于"没生效"状态**
  （`locales_creature.name_loc4` 27 条 / `locales_item.name_loc4` 59 条 / `locales_gameobject.name_loc4` 23 条 /
  `locales_quest.Title_loc4` 6 条）。
  ⚠️ **但不要盲目回放 011**：011 自己也有可疑项 —— 例 `11156 Green Skeletal Warhorse`，011 写"绿色骷髅战马"，
  而现值"绿色骸骨军马"更贴官方命名（同族 13331 就是"红色骸骨军马"）。
  → 正确做法：以官方中文库（tbc.60cj.com / wowhead zhCN）**逐条核对后再批量修**，先出对照表给站长过一遍。
- **教训**：**locale 修正必须排在"整包 locale 包"之后执行**（dev 编号大的后跑，别用小号文件改 locale），
  否则会被后一个整包覆盖；改 locale 后需重启 mangosd（或 `.reload`）才生效。



## [任务] 纳格兰元素王座链：任务文本把「古罗克」写成「戈隆克」— 2026-09-17 已修（`dev/072`，待推云）

- **现象（站长报告）**：任务 9853「侵占者戈隆克」——标题/目标写"戈隆克"，但任务物品名却是"古罗克的头颅/古罗克的徽记"，
  同一只怪译名不一致。
- **核查结论**：以**生物/物品名为准**（来自客户端 zhCN 数据）：
  `locales_creature 18182 = 侵占者古罗克`、`18181 = 古罗克的爪牙`、`18208 = 古罗克事件控制者`、`locales_item 24503 = 古罗克的徽记`。
  而**任务文本**写成了"戈隆克"✗ —— 来自早期三批 locale 包（`030_中文locale更新包.sql`、`033_中文locale其他表_tbc_zh.sql`、
  `033b_quest_tbc_zh.sql`）的同名错译，且一直被后续批次沿用。
- **受影响范围（线上实测）**：`locales_quest` 仅 2 个条目 ——
  **9853**（Title/Details/Objectives/OfferRewardText/RequestItemsText **5 列全错**）、**9849**（Objectives + OfferRewardText）。
- **修法**：`dev/072_翻译修正_侵占者古罗克.sql` —— 用 `REPLACE(...)` **限定 `entry IN (9849,9853)`** 替换"戈隆克"→"古罗克"
  （不触碰其它行；幂等，本地从库已验证残留 0）。生效需重启（locales 启动时载入）。
- **同类小瑕疵（未改，待站长定）**：`locales_quest 9821` 的交任务文本里用「"侵入者"古罗克」，
  与生物名「侵占者古罗克」用词不一致（"侵入者" vs "侵占者"）—— 若官方 zhCN 用词确实是"侵入者"则无需改。
- **教训**：翻译类问题要**以生物/物品/技能等基础表为锚**去校验任务文本，反之不行；同一 NPC 在任务链里应全局统一。

## [机制] 客户端 2.5.3：点飞行经常提示"离空运站太远"（ERR_TAXITOOFARAWAY）— 2026-09-17 已修（待推云）

- **现象（站长报告）**：2.5.3 客户端坐飞机时**经常**提示"离空运站太远"，明明站在飞行管理员旁边也飞不了。
- **根因**：`Player::ActivateTaxiPathTo()`（`src/game/Entities/Player.cpp:18381`）在收到客户端的 `CMSG_ACTIVATETAXI(EXPRESS)` 后，
  会拿**服务端 DBC（TaxiNodes.dbc）里该节点的坐标**与玩家坐标做一次校验，超过 `2*INTERACTION_DISTANCE`（≈31.6 码）
  就回 `ERR_TAXITOOFARAWAY`（客户端本地化即"离空运站太远"）。
  但这条路径**此前已经校验过合法性**：`TaxiHandler` 用 `GetNPCIfCanInteractWith(guid, UNIT_NPC_FLAG_FLIGHTMASTER)`
  确认过"玩家确实站在该飞行管理员身边"（内部含 `INTERACTION_DISTANCE` 距离检查），且节点必须已解锁
  （`IsTaximaskNodeKnown`）。于是当**客户端与服务端 DBC 版本不一致**（本站：2.5.3 客户端 / 2.4.3 服务端 DBC）时，
  节点编号或坐标对不上，就会**误判**成"太远"。
- **修法**（`Player.cpp:18382`）：
  1. 通过飞行管理员启动（`npc != nullptr`）时**跳过**该坐标校验（上面的交互校验已足够）；
  2. 节点没有坐标数据（x/y/z 全 0）时不再回 `ERR_TAXIUNSPECIFIEDSERVERERROR`，只记 debug 日志并继续；
  3. **法术/脚本启动的飞行（`npc == nullptr`）仍保留原校验**，用于拦截异常/作弊请求（例如 `SpellEffects` 的
     EffectSendTaxi、`ScriptMgr` 的 sendTaxiPath）；
  4. 校验命中时补一条 `DEBUG_FILTER_LOG(LOG_FILTER_AI_AND_MOVEGENSS, "TAXI: node ... too far, rejected")` 便于以后取证
     （把 `LogFilter_AIAndMovegens = 0` + `LogLevel = 3` 打开即可看到）。
- **副作用/风险**：跳过校验后，**改造过的客户端**理论上可以请求"从任意已解锁节点起飞"（正常客户端永远只发当前节点）；
  代价可接受，且有 `IsTaximaskNodeKnown` + 金钱检查兜底。
- **验证**：需站长在 2.5.3 客户端上复测**之前必报错的那几个飞行管理员**（部署后）；若仍有报错，说明是"节点编号整体错位"，
  那就得对比客户端 MPQ 里的 TaxiNodes.dbc 与服务端 DBC（另一条线）。
- **若站务侧想彻底消除隐患**：让客户端与服务端的 DBC 版本一致（都用 2.4.3 客户端），就没有这类对不上的问题。

## [机制] 刷新时间为 0 的怪：尸体时间被算成 0 → 尸体立刻消失（太阳井 BOSS 无法拾取）— 2026-09-17 已修（待推云）

- **现象（站长报告）**："有些尸体拾取后会立刻消失"。
- **根因**（`src/game/Entities/Creature.cpp:1777`，源自 [RESPAWN-AT-TIME] 时期的改动）：
  ```cpp
  m_respawnDelay = data->GetRandomRespawnTime();     // urand(min,max) → 0/0 时为 0
  if (!isUsingNewSpawningSystem)
      m_corpseDelay = std::min(m_respawnDelay * 9 / 10, m_corpseDelay);   // ← 0×0.9 = 0
  ```
  而 **`spawntimesecs = 0` 的语义是"不自动刷新"**（由脚本/副本管理，依据同文件 1986 行的守卫
  `if (m_respawnDelay && s == JUST_DIED && !GetCreatureGroup())`，以及 `Creature.cpp:1986` 附近逻辑）→
  于是这些怪的**尸体时间被压成 0**，尸体在下一次 `Update` 就被删除（`m_corpseExpirationTime` 到期）。
- **影响范围（云端实测统计）**：**88 个刷点 / 40 个 entry** 刷新为 0；其中**有掉落、玩家真会拾取的**是
  **太阳井（map 580）的 Shadowsword 系列 + 双子 BOSS `25165 Lady Sacrolash` / `25166 Grand Warlock Alythess`**
  （共 22 个刷点）→ 表现为"打死/拾取后尸体秒没"，BOSS 甚至来不及捡。
- **修法**：只在 `m_respawnDelay > 0` 时才做 ×0.9 收紧 → 刷新 0 的怪改用 `Corpse.Decay.*` 配置值
  （普通 300 / 精英 600 / 世界 boss 3600）。已编译通过 ✓，待随 nightly 部署。
- **残留（不修，影响极小）**：刷新 1~9 秒的怪，整数运算 `1×9/10 = 0` 仍会是 0 —— 只有 2 个 entry
  （`552 Protean Horror` 1s ×8、`540 Shattered Hand Heathen` 5s ×5），且两者都是副本脚本反复召唤的怪，无需处理。
- **顺带发现（死配置）**：`Rate.Corpse.Decay.Looted`（conf 里 = 0.0）**只被注册、从未在代码中使用**
  （全仓库仅 `World.h` 枚举 + `World.cpp` 注册两处）→ 调它没有任何效果；要么删掉、要么实现。
- **相关事实（供以后判断"尸体时间"）**：尸体时间 = `min(刷新×0.9, 按 rank 的配置)`；拾取非剥皮怪后
  `ReduceCorpseDecayTimer()` 会把剩余时间压到 `MINIMUM_LOOTING_TIME` = **2 分钟**；可剥皮怪拾取后保留
  （等剥皮），剥完立即消失；`InspectingLoot()` 另有"[RESPAWN-AT-TIME] 战利品窗口不超过刷新时间"的收紧。
  引擎限制：**一个生物只能有一具尸体**（`Creature.cpp:2928` 注释），所以刷新极短的怪，尸体再长也留不住。



## [机制] 哈兰(Halaa)：商人/卫兵刷点本来就没有 + 易主后"走开再回来就没 NPC" — 2026-09-18 已解决（**回归原版事件逻辑** + 补召唤；云端已生效）

- **现象（站长报告）**："哈兰，再次过去还是没有商人 NPC 刷新"；补充说明："第一次占领会正常刷新，再次过去加载的时候不会"。
- **机制**：哈兰是 cmangos 的 **OutdoorPvP** 玩法（`src/game/OutdoorPvP/OutdoorPvPNA.cpp`，开关 `OutdoorPvp.NAEnabled`
  默认开，`World.cpp:745`；`MAX_NA_GUARDS = 15`）。这个系统**自己不生成 NPC** —— 代码注释原文：
  卫兵和商人都是 *"permanent DB spawns"*（守卫死亡位置取自 `creature->GetRespawnCoord()`），系统只按占领方做
  despawn / Respawn。
- **根因（两条）**：
  1. **刷点从来没做过**：`creature` 表里哈兰的 12 个 NPC（`18192` 部落卫兵 / `18256` 联盟卫兵、
     `18816/18817` 研究员、`18821/18822` 军需官、`21474/21483/21484/21485/21487/21488` 商人）**全 0 行**；
     本地库、云端库、上游 `tbcmangos_orig`/`tbcdb_ref`、DB 仓库 `Nmangos-tbc-db`、连 WotLK 库都一样是 0，
     `creature_conditional_spawn` 也是 **0 行** → 镇里既没商人也没卫兵，玩家"去了几次都看不到商人"。
     （核对过当天的备份表 `creature_bak_20260917` 等：也没有 → **不是我们删的，是原本就没做**。）
  2. **"第一次占领有人、重载就没了"**：易主后新占领方的卫兵是 `player->SummonCreature(..., TEMPSPAWN_DEAD_DESPAWN, 0, true)`
     **临时召唤**（`RespawnSoldier`）—— 临时召唤不存盘，**网格一卸载（玩家走开）就消失**；而商人虽然源码按
     "DB 刷点"处理，但库里根本没有商人刷点，所以同样常年不见。
- **修复（最终采用方案 A：两边都预置刷点，同位置成对，易主时切换 —— 不写库）**
  - **数据 `dev/076_补哈兰NPC刷点.sql`（幂等，guid 段 `9000001-9000040`，本地/云端实测空闲）**：
    · 商人 10 个（联盟 `18817/18822/21485/21487/21488`；部落 `18816/18821/21474/21484/21483`），半径 7 码环绕镇中心、
      朝向中心 —— 源码要求商人是"永久 DB 刷点"，opvp 只按占领方 despawn 敌对那 5 个；
    · 卫兵 **15 个岗哨位置 × 双方各一条 = 30 行**（`18256` 与 `18192` **同位置成对**），
      卫兵上限 `MAX_NA_GUARDS = 15`。
  - **代码 `src/game/OutdoorPvP/OutdoorPvPNA.{h,cpp}`**：
    · 新增 `GetGuardTeam()` + `m_teamGuards` / `m_foreignGuards`；
    · `HandleCreatureCreate`：**非占领方**的卫兵刷点直接 `ForcedDespawn()` 并记入 foreign（**不计数**），
      占领方那半记入 team 并照旧计数（保持 `m_aliveGuards` 幂等，避免重载导致计数漂移）；
    · `ProcessCaptureEvent`：易主时把 new owner（foreign）的卫兵 `Respawn()` 回来、把旧占领方的 `ForcedDespawn()`，
      再互换列表、清空旧的重生队列 → **两半都是永久 DB 刷点，网格卸载/重启都不丢**
      （这正是"第一次占领正常、走开再回来就没 NPC"的修法：以前新占领方的卫兵是临时召唤，不存盘）；
    · 初始归属 `TEAM_NONE` → **HORDE**（`TEAM_NONE` 时 despawn 逻辑不生效，会让两阵营 NPC 同时站在镇上），
      世界状态与墓地归属同步；
    · ⚠️ opvp 占领方**本来就不持久化**（cmangos 上游行为）→ 重启后归属回到部落，属已知行为。
  - **曾评估并放弃的备选方案 B**：卫兵不预置，改由服务端创建时立刻 `SaveToDB()`（`GenerateStaticCreatureLowGuid`
    + `Create` + `SaveToDB` + `LoadFromDB`），易主时删旧行建新行 —— 好处是库里始终只有当前占领方 15 行；
    缺点是运行时写库（guid 分配/删行/bootstrp 位置表在代码里），且 `creature` 表随游戏演化、本地与云端会各自长出
    不同行，和"用 dev SQL 管数据"的习惯冲突。**站长最终选 A**；B 的代码已全部撤回（`git grep` 无残留，编译通过）。
- **本地验证**：编译通过（`build1` → `mangosd.exe`，仅 `OutdoorPvPNA.cpp` 重编 + 链接）；
  `076` 应用后 `creature` 新增 **40 行**（15 联盟卫兵 + 15 部落卫兵 + 10 商人），**复跑幂等 ✓**。
- ⚠️ **坐标是初版估值**：以镇内现有锚点 `Halaa Banner(182210) = (-1572.6, 7945.3, -22.5)`、
  `Nagrand Spawn Timer(18264) = (-1568.5, 7941.9, -22.4)`、`Nagrand Spawn Trigger(18263) ×5`、
  墓地 `Spirit Healer(6491) = (-1667.3, 7948.4)` 为参照，绕镇中心排布。
  **站长上线看过之后用 `.go xyz` 报坐标，我出 `dev/077` 覆盖 9000001-9000040 段即可校正。**
- **待办**：push（`dev/076` + `OutdoorPvPNA.h/.cpp`）→ 云端 `git pull` → nightly 应用 **072 → 073 → 075 → 076** →
  重启后核对：哈兰有 10 个常驻商人（按占领方只显示 5 个）、15 名卫兵、地图上"守卫剩余"= 15，
  玩家走开再回来 NPC 仍在。

### ⚠️ 后续改判（2026-09-18 03:02）—— 上面的"方案 A"已整条回退，**勿再照它执行**

- 站长反馈：**"重启后哈兰直接归部落了"** + **"NPC 刷新位置不对"** + **"哈兰应该按原来的事件逻辑来"**
  → 改用 **方案 C：回归上游原版**（自制常驻刷点方案作废）。
- **代码（提交 `25cb6c31e 修复哈兰`）**：`m_zoneOwner = TEAM_NONE`（**中立起步**，不再"重启回部落"）；
  占领时仍由原版 `dbscripts_on_event` **11503（部落）/ 11504（联盟）** 在**原版真实坐标**召唤商人/卫兵；
  只保留 `d540af8b7` 的空队列宕机保护（7 行），其余自制逻辑（`m_teamGuards`/`GetGuardTeam`/预置刷点切换）全部撤回。
- **本次唯一的新代码 = 修掉原版毛病"走开再回来 NPC 消失"**：`OutdoorPvPNA::RespawnFactionNpcs(go)`
  —— 仅当"记下的 NPC 一个都不在图里"时才重跑原版脚本 11503/11504（幂等；不动归属、不动坐标、不动触发条件）。
  调用点在 `OutdoorPvPNA.cpp:238`（捕获事件后）。
- **数据**：`dev/082` 删除 `dev/076` 插的 40 行估值坐标刷点（guid `9000001-9000040`）；`dev/076` 已改成纯注释留档（作废）。
- **云端已生效（2026-09-18）**：`OutdoorPvPNA.cpp` 02:56 同步 → 二进制 `/opt/mangos/bin/mangosd` **03:12** 编译（含改动，
  源码比二进制早 16 分钟）→ SQL marker = **082**；实测云端库 `preset_spawns(9000001-9000040) = 0`、
  `dbscripts_on_event 11503/11504 = 40 行`、哈兰 NPC 常驻刷点 = 0（原版设计就是靠事件脚本召唤，无常驻刷点）。本地库同状态。
- **残留（属上游已知行为，不是 bug）**：opvp 归属不持久化 → **重启后回到中立**；中立期间镇上本来就没有常驻 NPC，
  只有有人占领时才由脚本召唤当方阵营的商人/卫兵。

### ✅ 最终方案（2026-09-19）—— 改成**静态 DB 刷点**，"临时召唤"那一套整体删除

- **为什么再改**：`dbscripts_on_event` 11503/11504 召唤出来的是**【临时召唤】（动态 guid、不落库）**，而 opvp 这套
  代码从头到尾都假设镇里的 NPC 是**永久 DB 刷点**（卫兵战死靠 `GetRespawnCoord()` 记位、`DespawnVendors()` 按 guid 处理）。
  临时召唤只要网格卸载（玩家走开 2 分钟）就整批消失，而脚本只在占领那一刻跑过一次 → 无论怎么"补召唤"都是在跟机制对抗。
  另外实测：`Map::ScriptsStart(SCRIPT_TYPE_EVENT, 11504, 旗帜GO, 旗帜GO, …)` 调用不报错、但 20 行
  `TEMP_SPAWN_CREATURE` **一条都不生效**（`[HALAA] script 11504 produced no NPCs`），这条路本身也不可靠。
- **数据 `dev/093_哈兰NPC静态刷点_原版真实坐标.sql`（幂等，guid 段 `9000001-9000040`）**：
  坐标**逐值取自** 11503/11504 里 `command=10` 的那 40 行原版数据（脚本生成，不手抄、不估算 —— 当初否掉旧方案
  就是因为坐标是估的）：15 部落卫兵(18192) + 15 联盟卫兵(18256)（同位置成对）+ 双方各 5 名商人/研究员/军需官
  （18816/18821/21474/21483/21484 与 18817/18822/21485/21487/21488）。
  **`spawntimesecs = 2592000`（30 天）= 核心不自己复活**。
- **代码（`OutdoorPvPNA.cpp/.h`）**：
  · `HandleCreatureCreate`：商人与卫兵统一按 `m_zoneOwner` 过滤 —— **中立时全部隐藏**、非占领方 `ForcedDespawn()`
    并记进 `m_foreignVendors`/`m_foreignGuards`、占领方计入（卫兵用 `m_aliveGuards` 幂等去重；静态 guid 跨网格
    重载稳定，这个去重才真正有效）；
  · `ProcessCaptureEvent`：易主时旧占领方的卫兵藏掉、新占领方的放回来（商人与卫兵现在对称）；
  · **删除"临时召唤"那一套**：`Update()`、`RespawnSoldier()`、死亡位置队列 `m_deadSoldiers`、复活计时器
    `m_soldiersRespawnTimer`、`HalaaSoldiersSpawns` 结构全部删除；
  · **战死的卫兵不再补回来**（站长 2026-09-19 明确要求）：卫兵是永久 DB 刷点，谁死谁就没了，小镇会被慢慢打空 →
    可被占领，这才是原版攻城玩法的意图；顺带也就不再有"网格卸载丢卫兵 / 网格重载多卫兵 / 计数器与实际人数对不上"。
- **云端**：SQL 走 nightly（marker 082 → 093 自动应用），代码已 scp 到 `/root/Nmangos-tbc`（md5 与本地一致）。
- **本地验证**：`dev/093` 应用后 40 行刷点齐全（15+15+5+5），编译通过、本地服重启无报错；
  待站长在游戏内确认：中立=空镇 → 点旗帜占领 → 当方 15 卫兵 + 5 商人 → 走开 2 分钟回来 NPC 仍在。




## [数据] 精英(rank1) 刷新时间统一 **600 秒（10 分钟）** — 2026-09-17 定案并已改（`dev/075`，待推云）

- **起因**：站长问 "18411 entry 刷新时间是多少？" —— 核查发现**本地与云端不一致**：
  `18411 Durn the Hungerer`（Son of Gruul，rank1 精英，1 个刷点 guid 65801）**本地 = 900/900，云端 = 600/1500**。
- **根因**：071 的定案原本是"普通怪 300 / 精英 900"，但**"精英 → 900"那一段在合并成 071 时丢了** ——
  现在的 071（本地工作区 / `git HEAD` / 云端三处一致）只有 **57 行 / 15 条 UPDATE**，没有精英段，
  只在文件头留着"精英 224 entry → 900"这句说明。本地之所以是 900，是因为早先**单独跑过**旧的
  `dev/074_精英刷新统一900秒.sql`（那个文件后来"并入 071 并删除"，**并入时没带进去**）；
  **云端从未执行过任何精英统一语句**。
- **站长重新定案（2026-09-17）**：随机区间没意义 → **精英(rank1) 一律统一 600 秒（10 分钟）**，
  不再保留 600/1500 这类随机窗口（原定 900 作废）。
- **实现（`dev/075_精英刷新统一600秒.sql`，规则式、幂等）**：`UPDATE creature JOIN creature_template`，
  范围 = ① `Rank = 1` ② 世界地图 `map IN (0,1,530)` ③ 有掉落（`LootId/PickpocketLootId/SkinningLootId` 任一非 0）
  ④ 无 `ScriptName` ⑤ `NpcFlags = 0` ⑥ `CreatureType <> 8`（非小动物）
  ⑦ 排除**真实活动刷点**（该 guid 登记在 `game_event_creature` 且对应 `game_event` 存在；按 guid 排除，
  同时覆盖 15743/15744 那种"同一 entry 既有活动刷点又有普通刷点"的情况）。含刷怪组成员。
  **稀有（rank2/rank4）与世界 boss（rank3）不动。**
- **云端只读预演（应用前实测）**：范围内共 1,236 刷点 / 233 entry，其中
  `=600` 已有 401/75，**需要改的 835 刷点 / 157 entry**：
  · 原值 >600 或区间（**会变快**）448 刷点 / 58 entry（最大 172800 秒）；
  · 原值 max<600（**会变慢**，多数是 071 之前被当普通怪改成 300 的精英）387 刷点 / 100 entry
  （含 22253 Dragonmaw Ascendant 25 秒 ×12、17592 Razormaw 30 秒、448 Hogger 180 秒等）。
- **本地验证（3306 库）**：执行后范围内"非 600"残留 = **0**，`18411` = 600/600，稀有/boss 未动（1,177 行 0 改动），**复跑幂等 ✓**。
- **知识备查（随机区间的含义）**：`creature.spawntimesecsmin/max` 是**区间**，核心在怪**死亡那一刻**
  （`Creature::SetDeathState(JUST_DIED)`，`Creature.cpp:1967`）用 `urand(min,max)`（`Creature.h:315`）
  抽一个数当本次刷新时间 → 600/1500 = 每次随机 10–25 分钟（均值 17.5 分钟）。
  原版给宽区间是"反蹲守/反脚本"设计；它同时会带动尸体时间（`尸体 = min(刷新×0.9, 按 rank 的配置)`，
  `Creature.cpp:1774-1781`）。**统一成 600 后：比原均值更快、且完全可预测。**
  另注：`spawntimesecs = 0` 表示"不自动刷新"（脚本/副本管），与本次无关（该语义已由 [CORPSE-FIX] 处理）。
- **待办**：站长 push 后 → 云端 nightly（marker 071 < 075，会按 072 → 073 → 075 顺序应用）→
  重启后复核"范围内非 600 残留 = 0"，并抽查几个精英（18411 / 448 Hogger / 22253）。



## [任务] 战备 90100–90109（60%）+ 驰骋外域 90200–90209（100%）：坐骑奖励改多选一、战备改名 — 2026-09-17 已改（`dev/073` 单文件，待推云）

- **原状（两条线各只给一匹固定坐骑）**：
  - 「战备」`90100`~`90109`：十个任务各绑**一个种族**（`RequiredRaces` = 1/2/4/8/16/32/64/128/512/1024），
    奖励**唯一一种**本族 **60% 档**坐骑（`RewItemId1`：2411 / 5872 / 8632 / 8595 / 29744 / 5665 / 13331 / 15277 / 8588 / 29221）
    + 初级骑术 `RewSpell 33388` / `RewSpellCast 33389`；任务名却写成"战备：**迅捷**XX"。
  - 「驰骋外域」`90200`~`90209`（需等级 60）：各奖励**唯一一匹**本族 **100% 史诗档**坐骑
    + 中级骑术 `RewSpell 33391` / `RewSpellCast 33392`；任务文本本来就写"领取你的**史诗**坐骑"。
  - 两条线都由**所有骑术训练师**提供，玩家只能看到与自身种族匹配的那一个 → **都没有选择余地**。
- **需求（站长）**：改成"按该族坐骑商人在售的坐骑**多选一**"（有几个颜色就给几个选项）；
  战备任务名去掉"迅捷"。**100% 档那条线也一样改成多选一**。
- **实现（`dev/073_任务坐骑奖励改为多选一.sql`，一个文件覆盖两条线，全 entry 口径、幂等）**：
  ① 清 `RewItemId1/RewItemCount1`，写 `RewChoiceItemId1..N` + `RewChoiceItemCount1..N = 1`；
  ② 战备十条任务标题去掉"迅捷"。核服务端支持每位任务最多 **6** 个可选奖励
  （`QUEST_REWARD_CHOICES_COUNT`，`GossipDef.cpp:396/498` 下发给客户端，`Player.cpp:13174` 发放）。
  **选项口径 = 该族坐骑商人在售的该档库存**（`npc_vendor` ∪ `npc_vendor_template`；逐族见下表）。
  每个任务**原本那一匹仍在选项里**，不会少拿；骑术奖励字段不变。
  | 任务 | 种族 | 战备（60% 档，`RewSpell 33388`） | 驰骋外域（100% 档，`RewSpell 33391`） |
  |---|---|---|---|
  | …00 | 人类 | **四选一**：2411 黑马 / 2414 花斑马 / 5655 栗色马 / 5656 棕马 | 18776 迅捷褐色马 / 18777 迅捷棕马 / 18778 迅捷白马 |
  | …01 | 矮人 | 5872 棕山羊 / 5864 灰山羊 / 5873 白山羊 | 18785 迅捷白山羊 / 18786 迅捷棕山羊 / 18787 迅捷灰山羊 |
  | …02 | 暗夜精灵 | 8632 斑点霜刃豹 / 8631 条纹霜刃豹 / 8629 条纹夜刃豹 | 18766 迅捷霜刃豹 / 18767 迅捷雾刃豹 / 18902 迅捷雷刃豹 |
  | …03 | 侏儒 | **四选一**：8595 蓝 / 13321 绿 / 8563 红 / 13322 未涂装 机械陆行鸟 | 18772 迅捷绿色 / 18773 迅捷白色 / 18774 迅捷黄色 机械陆行鸟 |
  | …04 | 德莱尼 | 29744 灰 / 28481 棕 / 29743 紫 雷象 | 29745 重型蓝色 / 29746 重型绿色 / 29747 重型紫色 雷象 |
  | …05 | 兽人 | 5665 恐狼 / 5668 棕狼 / 1132 冬狼 | 18796 迅捷棕狼 / 18797 迅捷森林狼 / 18798 迅捷灰狼 |
  | …06 | 亡灵 | 13331 红 / 13332 蓝 / 13333 棕 骷髅马 | **两选一**：13334 绿色骸骨军马 / 18791 紫色骷髅战马 |
  | …07 | 牛头人 | **两选一**：15277 灰科多 / 15290 棕科多 | 18793 大型白色 / 18794 大型棕色 / 18795 大型灰色 科多兽 |
  | …08 | 巨魔 | 8588 翡翠 / 8591 青绿 / 8592 紫罗兰 迅猛龙 | 18788 迅捷蓝色 / 18789 迅捷绿色 / 18790 迅捷橙色 迅猛龙 |
  | …09 | 血精灵 | **四选一**：29221 黑 / 29220 蓝 / 28927 红 / 29222 紫 陆行鸟 | 28936 迅捷粉色 / 29223 迅捷绿色 / 29224 迅捷紫色 陆行鸟 |
- **顺手修的一处明错**：`90209`（血精灵·驰骋外域）原本奖励 `28927 红色陆行鸟` —— 那是 **60% 档**
  （`spell 34795` = 速度 +60%），与"史诗坐骑 + 中级骑术 33391"的定位矛盾（文本也写"史诗坐骑"）
  → 已改成三匹史诗陆行鸟（28936 / 29223 / 29224）。
- **任务新名**：战备：战马 / 山羊 / 霜刃豹 / 机械陆行鸟 / 雷象 / 战狼 / 骷髅马 / 科多兽 / 迅猛龙 / 陆行鸟。
  正文里的"你必须有匹快马"是比喻，未改。
- ⚠️ **纠错记录（重要，避免以后再踩）**：曾误判"绿色科多兽 `15292` 是 60% 档、RequiredLevel 被写错成 60"，
  把它的 `RequiredLevel` 改成 30 —— **错**。证据：`spell 18991`（绿色科多兽）= **速度提高 100%**，
  而 18989 灰色科多兽 / 18990 棕色科多兽 = **速度提高 60%**；`15292` 在官方 TBC 数据库里标注为**史诗**、
  ilvl 与需等级都是 60。073 里已带回滚语句（`RequiredLevel = 30 → 60`）。
  教训：**判断某个物品是哪一档坐骑，要看它 spell 的速度百分比，不能只看名字/名字里的颜色。**
- **本地验证（3306 库）**：战备 10 条 = 4/3/3/4/3/3/3/**2**/3/4 个选项、残留"迅捷" = 0、`RewItemId1` 全 0；
  驰骋外域 10 条 = 3/3/3/3/3/3/**2**/3/3/3 个选项；**每一项都过了"该族能骑"校验**
  （`AllowableRace & RequiredRaces ≠ 0`）；**复跑幂等 ✓**。
  档次也逐件验过法术速度：60% 档那 31 件 = **+60%**，史诗那 29 件 = **+100%**（`34795 红色陆行鸟` = +60% ✓ 印证上述明错）。
  生效需**重启 mangosd**（任务模板启动时载入）→ 走 nightly；客户端无需补丁（奖励由服务端下发）。
- **编号说明**：`dev/072`（古罗克翻译）与 `dev/073`（本文件）是**编号复用** —— 旧的 `dev/072`~`dev/074`
  属"刷新时间整改"那批，已并入 `dev/071` 并删除；云端 marker 现为 **071**，nightly 会按 072 → 073 顺序应用。
- **文件合并说明**：本条最初写成两个文件（`dev/073_战备任务坐骑改为三选一.sql`、
  `dev/074_驰骋外域任务坐骑改为多选一.sql`），站长要求"放到一个 sql 里"→ 已合并为
  **`dev/073_任务坐骑奖励改为多选一.sql`**（含战备 + 驰骋外域 + 15292 纠错 + 校验），那两个文件已删除；本批 dev SQL 最终只有 **072、073 两个文件**。



## [数据] 各族 60% 档坐骑（坐骑商人库存）核对：牛头人只有 2 种 —— 2026-09-17（结论已修正；当时的"补马商"文件已删除）

- **起因**：站长问"60% 科多兽什么情况，每个种族应该都有三种，是坐骑商人卖的"。
- **口径（含一次重要纠错）**：商人库存必须看 **两张表** —— 商人的**直挂行** `npc_vendor`
  **加上**它引用的**模板** `npc_vendor_template`（`creature_template.VendorTemplateId`；核心在
  `ObjectMgr.cpp:9703 LoadVendors("npc_vendor_template", true)` 合并加载）。判定档次看 spell 速度，不看名字。
  ⚠️ **我第一版只查了 `npc_vendor`，于是误判"人类马商缺 3 匹、两个马商是空货架"** —— 实际上人类 4 个马商
  都挂 **`VendorTemplateId = 17`**，而模板 17 里正好是
  `2414 花斑马 / 5655 栗色马 / 5656 棕马 / 18776·18777·18778 三匹迅捷`；所以线上
  **384 Katie Hunter / 1460 Unger Statforth = 直挂黑马 1 件 + 模板 6 件 = 7 件**、
  **2357 Merideth Carlson / 4885 Gregor MacVince = 6 件**（与原版一致地不卖黑马）→ **一切正常，没缺**。
  站长在游戏里核对后指出"看起来没有缺失"，我随即用**云端库只读查询**复核（`npc_vendor` ∪ `npc_vendor_template`）→
  确认无误。因此 `dev/074_补全人类马商缺失的坐骑.sql` **已删除**，本地测试库里被它误插的 24 行**已回滚**；
  **云端一行未动**（本任务对云端只做过只读查询，没有推送、没有应用任何 SQL）。
- **核对结果（`npc_vendor` ∪ `npc_vendor_template`；`tbcmangos` / `tbcmangos_orig` / `tbcdb_ref` 一致）**：
  | 种族 | 商人（entry） | 60% 档库存 | 官方 TBC | 差异 |
  |---|---|---|---|---|
  | 人类 | Katie Hunter 384 / Unger Statforth 1460 | 4：2411 黑马 / 2414 花斑马 / 5655 栗色马 / 5656 棕马（直挂 1 + 模板 17 三件） | 同 | — |
  | 人类 | Merideth Carlson 2357 / Gregor MacVince 4885 | 3：2414 / 5655 / 5656（全来自模板 17，不卖黑马） | 同（不卖黑马） | — |
  | 矮人 | Veron Amberstill 1261 | 3：5864 / 5872 / 5873 | 同 | — |
  | 暗夜精灵 | Lelanai 4730 | 3：8629 / 8631 / 8632 | 同 | — |
  | 侏儒 | Milli Featherwhistle 7955 | 4：8563 / 8595 / 13321 / 13322 | 同 | — |
  | 德莱尼 | Torallius 17584 | 3：28481 / 29743 / 29744 | 同 | — |
  | 兽人 | Ogunaro Wolfrunner 3362 | 3：1132 / 5665 / 5668 | 同 | — |
  | 亡灵 | Zachariah Post 4731 | 3：13331 / 13332 / 13333 | 同 | — |
  | **牛头人** | Harb Clawhoof 3685 | **2**：15277 灰 / 15290 棕 | **也是 2**（另卖 3 匹史诗"大型"科多） | **原版就只有两种** |
  | 巨魔 | Zjolnir 7952 | 3：8588 / 8591 / 8592 | 同 | — |
  | 血精灵 | Winaestra 16264 | 4：28927 / 29220 / 29221 / 29222 | 同 | — |
- **牛头人为什么没有第三种颜色（结论）**：TBC 客户端数据里，60% 档科多兽法术只有
  `18989 灰色科多兽`（+60%）和 `18990 棕色科多兽`（+60%）两个；"绿色科多兽"用的是 `18991`（+100%，史诗）。
  也就是说 **60% 档的绿科多在原版里根本不存在**，想造一个必须新做**60% 速度的绿科多召唤法术**，
  而法术在客户端 `Spell.dbc` 里 → **需要客户端补丁**，服务端数据改不出来。
  （`18793/18794/18795` 是"大型白/棕/灰科多"史诗档，也不是第三种颜色。）
- **教训（写进流程）**：说"某商人缺货 / 空货架"之前，必须把 `npc_vendor` 与 `npc_vendor_template`
  （按 `VendorTemplateId`）**合并**后再下结论 —— 只看前者会得到"空货架"这种假象；
  上游 `tbcmangos_orig` / `tbcdb_ref` 的 `npc_vendor` 里没有这些行，也不是缺陷（货在模板里）。
  同理，判断任何"库里有/没有"的结论，先确认自己查的是**全部来源**（直挂表 + 模板表 + 关联字段）。
- **多源交叉验证（2026-09-17，站长要求"实测一下"）**：科多兽商人 3685 的 60% 档库存，**6 个独立来源全为"2 匹"**——
  上游 `tbcmangos_orig`/`tbcdb_ref`；原版 1.12 `classicmangos_ref`（灰/棕 + 3 史诗）；
  [tbc.60cj.com](https://tbc.60cj.com/npc/3685/sell)；[tbc.cavernoftime.com](https://tbc.cavernoftime.com/npc=3685)（Gray/Brown + 3 Great）；
  tbcdb.rising-gods.de（Grauer/Brauner + 3 Great）；[wowhead TBC Classic](https://www.wowhead.com/tbc/npc=3685)
  （评论："The level 40 (60% speed) mounts … The level 60 (100% speed) mounts …"）。
- **"每档三种"印象的来源（已查清）**：那是 **WotLK** 的货架 —— 本地 `wotlkmangos` 库里 3685 卖
  灰/棕/**白**（`46100 White Kodo`）+ 3 史诗 = **每档三种**；而 `46100` 及其召唤法术是 WotLK 才加的，
  TBC 客户端里没有（我们 TBC 库里也查不到 46100）→ **TBC 服务端用不了**。
  另外 wowhead 老玩家评论指出：**绿科多/青科多是 1.4 补丁之前的史诗坐骑**，后来被"大型白/棕/灰科多"取代；
  数据库里 `quest 7662 新科多兽-青色` / `7663 新科多兽-绿色` 的奖励正是**三匹史诗科多三选一**，
  这也解释了"一套三种"的记忆 —— 但那是**史诗档**，不是 60% 档。
- **60% 档"一套三种"的种族确实存在**：矮人 / 暗夜精灵 / 德莱尼 / 兽人 / 亡灵 / 巨魔 各 3 种，
  人类 / 侏儒 / 血精灵 各 4 种；**只有牛头人是 2 种**（这就是原版的形状，见上表）。
- **档位复核（逐件验证）**：把 073 奖励里用到的 29 件坐骑的召唤法术逐条查了速度 —— **全部 = 速度提高 60%**
  （`580 棕狼 / 470 黑马 / 6648 栗色马 / 458 棕马 / 6653 暗灰狼 / 6654 暗棕狼 / 6777 灰山羊 / 6899 棕山羊 /
  6898 白山羊 / 10873 红机械陆行鸟 / 8395 绿迅猛龙 / 10796 青迅猛龙 / 10799 紫迅猛龙 / 10969 蓝机械陆行鸟 /
  10793 条纹夜刃豹 / 8394 条纹霜刃豹 / 10789 斑点霜刃豹 / 17453 绿机械陆行鸟 / 17462-17464 骷髅马 /
  18989 灰科多 / 18990 棕科多 / 34406 棕雷象 / 34795 红陆行鸟 / 35020 蓝陆行鸟 / 35022 黑陆行鸟 /
  35710 灰雷象 / 35711 紫雷象`）；补的史诗马与史诗科多（23227-23229 / 23247-23249）均为 **100%** ✓。
- **可当场实测的坐标（含模板后的应然货架，与实际一致 ✓）**：
  `384 Katie Hunter`（东部王国 -9455.4 / -1385.3，艾尔文森林东谷伐木场）与
  `1460 Unger Statforth`（东部王国 -3645.8 / -744.1，湿地米奈希尔港）→ **7 件**（黑马/花斑/栗色/棕 + 3 匹迅捷）；
  `2357 Merideth Carlson`（东部王国 -783.6 / -603.3，希尔斯布莱德南海镇）与
  `4885 Gregor MacVince`（卡利姆多 -3835.7 / -4397.7，尘泥沼泽塞拉摩）→ **6 件**（不卖黑马）；
  `3685 Harb Clawhoof 科多兽商人`（卡利姆多 -2279.8 / -392.1，莫高雷血蹄村）→ 5 件（灰科多、棕科多 + 3 匹大型）。
- **关于"标价 50 / 95"（2026-09-17，站长决定：以数据库为准，不改）**：站长在别处看到这些马标价
  50（60% 档）与 95（100% 档），与本库/2.4.3 原版（`BuyPrice` 10 金 / 100 金，物品等级 30 / 60，
  需骑术 75 / 150）不一致。已逐库核对：`tbcmangos`(本库) = `tbcdb_ref` = `classicmangos_ref` = Cavern of Time
  TBC 库，均为 10 金 / 100 金；WotLK 库反而是 1 金 / 10 金。**站长指示按数据库走 → 价格与物品等级一律不动**，
  本次 073 也不涉及价格字段。以后再遇到"某处标价不同"，先确认那个来源是哪个版本/哪个服，不据此改数。



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

> ✅ **状态：已解决**（2026-08-18 ~ 08-30 先后落地，本地已实测；本节完整保留排查过程）。
> **一句话结论**：客户端判定怪物游泳认的是 `UNIT_FIELD_FLAGS` 的 **`UNIT_FLAG_SWIMMING(0x8000)` 这个持久字段**，
> 用**动态 SetFlag**（Unit::Update 迟滞判据 + SetSwim 同步写字段）即稳定游泳；
> `SMSG_SPLINE_MOVE_START_SWIM(0x30B)` 只是**开场动画提示**，会 ~2 秒衰减、周期重发会抖，
> 因此方案里**不再依赖它**。下文"各种方法都失败"一节是**历史记录（被否决的方案）**，不代表当前状态——
> 只看到那张失败表就判断"此问题未解决"属于误读。

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

### 历史记录：为什么"投递游泳状态"的各种方法都失败（均已被下方方案取代，**非当前状态**）

| 方法 | 结果 |
|---|---|
| SMSG_SPLINE_MOVE_START_SWIM (0x30B) 单发 | 有效但 ~2 秒后客户端自己衰减回走路 |
| 0x30B 周期重发（1s/500ms） | 保持游泳但**抖**（每次重发动画状态机重置） |
| CREATE_OBJECT2 重建（对已存在单位） | 不应用，无效 |
| destroy + create（强制重建） | 短暂游泳后仍回走路（客户端不重新锚定） |
| monster move 带状态 | **SMSG_MONSTER_MOVE 协议不带 movement flags**（查实），无此通道 |
| UPDATETYPE_MOVEMENT | 4 次实验全失败（位置错乱/怪消失），放弃 |

**结论（问题已解决，勿读成未解决）**：客户端游泳 = `UNIT_FIELD_FLAGS` 的 `UNIT_FLAG_SWIMMING` 锚定，
`0x30B` 只是临时动画提示。**动态 SetFlag 是唯一持久方案，且已在 2026-08 落地并实测通过**
（见上文"完整方案"组件 1/2，以及本节 08-23 水中随机移动、08-25 游泳怪上岸卡住两次修复）。
上表只说明"为什么不能靠投递动画包来解决"，不是"没有解法"。

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
- ⚠️ **2026-09-17 补漏：当初"一刀切"没有排除"可交易"的任务物品**（`bonding = 0`，无绑定，可送人/卖店/邮寄）→
  这些物品也变成"每人一份"，等于凭空多刷。典型：**荆棘谷的青山 第 1~27 页**（SellPrice 375 铜）、
  Rethban Ore、Okra、Hops、Captain Sander's Treasure Map 等采集类任务物品。
  云端实测：class=12 共 3,865 个，其中 `bonding=0` **542 个**（全部被加了 MULTI_DROP），
  另有 11 个是**上游原版就带** MULTI_DROP 的（E'ko 系列 `12430-12436`、能量水晶 `11184-11188`，
  不可卖店、暴雪刻意设计）→ **保留**。
  修法：`dev/077_任务物品多重拾取_排除可交易.sql` —— `Flags & ~2048 WHERE class=12 AND bonding=0`
  且排除那 11 个（云端将改 **531** 行）。核对口径：**"可交易"= `item_template.bonding = 0`**
  （`bonding=1` 拾取绑定 576 个、`bonding=4` 任务物品 2747 个都不可交易，保持"每人一份"）。
  本地已应用并复核：可交易里只剩那 11 个带 MULTI_DROP、`bonding=1/4` 仍 100% 带、复跑幂等 ✓；
  生效同样需重启 mangosd + 推送。

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

> 状态：**服务器侧结论不变（生物 spawn z 本来就贴地，服务器坐标没错）**；
> **客户端侧的重力/悬停表现 2026-09-19 已修** —— 见本文件「[核心] 生物重力 flag：飞行怪被客户端重力拉回地面」：
> 现在按"生物实际是否在空中"给 create 块与每条移动路径补 `MOVEFLAG_LEVITATING`，大风鹏（17129）/野生雀鹰（22979）
> 等实测不再被客户端重力拉回地面；本机实测通过。

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

## [机制] 试飞任务（10557 / 10711 / 10712）骑乘或变形时不会被传上试飞平台 — 2026-09-21 已修（本地实测通过，待推云）

- **现象**：**骑着坐骑**（或德鲁伊飞行变身等形态）跟 21461 Rally Zapnabber 对话选试飞，人不会被传上平台、也不会被弹射；未骑乘/未变形时一切正常。
- **完整链路（已核实）**：
  1. `gossip_menu` entry **8304**（21461 Rally Zapnabber，站位 1920.31/5581.30/263.98）→ `gossip_menu_option.action_script_id` = 10557 / 10711 / 10712 → `dbscripts_on_gossip` 三条链；
  2. delay 0：**36801 "Cannon Charging (Port)"**（传送法术，落点在 `spell_target_position`：map530 **1920.13/5581.9/270.426**）＝"送上平台"那一步；同时由 **buddy** NPC 灌充能光环：21394 Cannon Channel Target(半径 30) 施 36785，21393 Cannon Channeler 施 36795；
  3. delay 3000/6000/9000：21394 施 36790/36792/36800；delay 12000：先命令 14 清掉这些光环，再由 21930 / 21413 / 21944（Gnome Cannon Shooter，**搜索半径 200**）施放 **Soaring**（10557→37910 / 10711→36812 / 10712→37968，`datalong2=1` 触发）；
  4. Soaring = `Effect1=98 KNOCK_BACK`(misc 100/200/300) + `Effect2=aura 105(飞行)` → **"发射"是击退 + 飞行光环，不是 taxi 航线**（C++ 侧 `struct Soaring` 施放时 `RemoveAurasDueToSpell(36801)` 去 root）。
- **真因（代码级，不是"坐骑压住击退"那种推测）**：36801 那行的 `data_flags = 6` = `REVERSE_DIRECTION(2) | SOURCE_TARGETS_SELF(4)`
  ⇒ 先反转、再"源指向自身"（`ScriptMgr.cpp:1626-1630`）⇒ **是玩家自己给自己施放 36801**；
  而 `spell_template` 里 36801 的 `Attributes = 536871168 (0x20000400)` **没有 bit24 `SPELL_ATTR_ALLOW_WHILE_MOUNTED`**，`datalong2 = 0` 又表示**非触发**
  ⇒ `Spell::CheckCast()` 的骑乘分支（`Spell.cpp:5338-5345`）直接返回 **`SPELL_FAILED_NOT_MOUNTED`**，36801 连 `cast()` 都进不去（挂在 `OnCast` 上的下马是死代码）。
  骑乘时 36785 / 36795 / 36801 全部被拒，只剩 triggered 的 Soaring 生效 ⇒ 人从原地被弹飞或完全没反应；变形（`IsInDisallowedMountForm()`）同理。
- **修复（唯一改动）**：`src/game/AI/ScriptDevAI/scripts/outland/blades_edge_mountains.cpp` 新增 `GossipHello_npc_rally_zapnabber`，注册为 **`pGossipHello`**，照抄飞行管理员起飞前检查（`Player.cpp:18323-18343`）：
  ```cpp
  pPlayer->RemoveSpellsCausingAura(SPELL_AURA_MOUNTED);                       // 真下马（光环一起删，移速恢复）
  if (pPlayer->IsInDisallowedMountForm())
      pPlayer->RemoveSpellsCausingAura(SPELL_AURA_MOD_SHAPESHIFT);            // 变形/德鲁伊飞行变身
  return false;                                                               // 交回数据库菜单 8304 / DB 链
  ```
  `pGossipHello` 在**菜单准备阶段**触发（`NPCHandler.cpp:401`：返回 false = 照旧下发 DB 菜单 8304），所以下马正好发生在 DB 链施放 36801 **之前**；DB / 法术 / SQL 一行未改（`dev/068` 的 `creature_template.ScriptName='npc_rally_zapnabber'` 仍然必须存在，钩子按 ScriptId 取）。
- **本地验证（2026-09-21 17:10 部署的 x64_Debug）**：骑乘对话 → 立即下马且移速正常 → 点选项 → 被传上平台（实测坐标 1922.09/5581.96/269.22，与 36801 落点吻合）→ 充能 12 秒 → 弹射完成。
- **回滚**：还原 `blades_edge_mountains.cpp` 两处（函数 + `AddSC_blades_edge_mountains` 里的注册），SQL/DB 无需回滚。
- ⚠️ **绝不能注册 `pGossipSelect`**（09-16/09-20 两次踩坑）：`ScriptDevAIMgr::OnGossipSelect()` 在调 handler **之前**就 `ClearMenus()`（`ScriptDevAIMgr.cpp:208`），而 `NPCHandler.cpp:438` 只有 handler 返回 false 才继续调 `Player::OnGossipSelect()`（DB 链入口）；此时菜单已空 ⇒ `Player.cpp:12520` 第一个 guard 直接 return ⇒ **整条试飞链永不执行（骑不骑乘都一样）**。
- ⚠️ **别用 `Unit::Unmount()` 给玩家下马**：它只清显示与 `UNIT_FLAG_MOUNT`，**不移除 `SPELL_AURA_MOUNTED`**（表现为"下了马但移速还在"）；本仓库通用写法是 `RemoveSpellsCausingAura(SPELL_AURA_MOUNTED)`（`.dismount`、战场、飞行管理员等 12 处）。
- ⚠️ **法术脚本的绑定在 `spell_scripts` 表**（`SELECT Id, ScriptName`），`spell_template` 没有 `ScriptName` 列；表里有行但 C++ 没注册同名脚本 = 悬空绑定、不会有任何效果（本地库曾残留撤销掉的 dev/098 写的 `36801 → spell_cannon_charging_port`，已删除；云端从来没有这行）。


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
⚠️ **来源更正（2026-09-22，站长指正）**：pfQuest 的 TBC 数据**取自 CMaNGOS**（与本库同源，只是另一份快照），
**不是独立第三方、更不是官服数据**；Questie 的来源则**不可考**。见 6.4「证据等级」表 —— 本节数值只作"同源快照对照"，勿当官服事实。

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

- **规则定案（2026-09-17 晚，站长确认）**：**普通怪 = 300 秒**，**稀有（rank 2 稀有精英 / rank 4 稀有）与世界 boss（rank 3）一律不改**。
  ⚠️ **精英（rank 1）已由 900 改为 600 秒（10 分钟）**（同日稍后站长重新定案："随机区间没意义，统一 10 分钟"，见本文件
  `## [数据] 精英(rank1) 刷新时间统一 600 秒` 一章与 `dev/075`）——下面凡写"精英 900"的地方均已作废。
  - 站长逐个点名的 17 个 entry —— rank=0 的 13 个（1756 暴风城皇家卫兵 / 3274 / 3275 / 4062 / 4065 / 4700 老迈的科多兽 / 10916 / 18873 / 18880 / 19642 / 21195 驯养的地狱野猪 / 22252 龙喉苦工 / 24976 晨锋血骑士）→ 300，rank=1 的 4 个（6498 魔暴龙 / 18856 奥术歼灭者 / 18886 法兰伦击碎者 / 22253 龙喉晋升者）→ 900。核查：这 17 个刷点 `in_real_event` 全为 0（**不是**事件刷点）。
  - ⚠️ **纠错（2026-09-17 深夜，云端预演时发现）**：曾判断"这 17 个已全部落在 071 第 1)/7)/8) 节规则内 → 无需单列语句"，**该判断不成立**：精英 4 个确实在 8) 的 224 entry 列表里，普通 10 个也在 1)/7) 里，但 **`1756`（22 点，云端 430）、`21195`（33 点，云端 180）、`22252`（8 点，云端 180）不满足批次筛选条件、从未进入任何列表**（合计 63 行）。已改为**在 071 第 9) 节显式列出**（见补记 4）。教训：**合并/删文件前必须做一次"本地终态 vs 目标环境"的逐行差异核对，不能凭"应该落在规则内"推断。**
  - 原 `073_点名entry刷新统一_普通300_精英900.sql` 已并入 071 并删除，其前身 `073_指定entry刷新统一300秒.sql` 因把精英也设成 300 亦已删除。
  - **071 第 8) 节（原 `dev/074_精英刷新统一900秒.sql`，已并入 071 并删除）**：范围内精英（世界地图 · rank1 · 有掉落 · 无 ScriptName · 无 NPC 旗标 · 非小动物 · 非真实活动 · 非任务/商人/训练师，**含刷怪组成员**）—— 写作**按 entry 的 224 entry 列表 → 900 秒**；当次需改值的行数为 **1,099 刷点 / 212 entry**（原值 600/300/610/1200/1800/430/660/120/180/172800 等）。本地验证：范围内剩余非 900 = 0。
  - ⚠️ **例外 2 个 entry：`15743` / `15744`**（同一 entry 既有天灾入侵**活动刷点** 3600/86400、又有普通刷点 900）→ 无法用 entry 列表区分，故在 071 第 8) 节末尾**单列一条**，按**运行期活动登记**（`game_event_creature` 关联存在的 `game_event`）排除活动刷点，**不硬编码 guid**（本地/云端通用）。这也是合并后 071 里唯一一处子查询，已在文件头注明。
  - 说明：`1756 暴风城皇家卫兵` rank=0 → 按普通怪 300；事件守卫（rank1 但 1–10 秒，如安其拉开门用）因属于真实活动/事件而**排除在外**未动。

- **待办**：①云端按 nightly 应用 **`071_刷新时间整改_整合版.sql`（唯一文件，18 条语句）** —— 云端只读预演已完成、条数已核对（见补记 4），今晚 04:06 自动应用后需**再跑一次残留缺口查询确认 0**；②线上抽查 `.npc info`；③新手区（幼狼/霜鬃等）体感若变化过大，可按备份表按 entry 回滚；④"事件/脚本 NPC 的 5 秒值"（孤儿周、安其拉/太阳井事件兵等）按证据保留未动；⑤（已作废）原"还差一个覆盖第 2/3 批（近 300 档 + 中立怪）的 dev SQL"—— 已由 `071_刷新时间整改_整合版.sql` 覆盖，无需再做。

---

## [修复] 副本里尸体"点一下就消失 / 拾取不了"（2026-09-17，**真因已更正**）

**症状（站长报）**：副本里打怪后，一打开拾取窗口（点尸体）尸体立刻消失、捡不到东西；副本外的怪正常。副本怪刷新时间本身是 2 小时，与此无关。

**真因（代码，09-16 引入）**：commit `6b4fd8eb1`（"修改刷新时间"）在 `Creature::InspectingLoot()` 里加了"尸体不能超过刷新时间"：

```cpp
if (m_respawnTime > time(nullptr))
{
    TimePoint respawnTimePoint = TimePoint(std::chrono::seconds(m_respawnTime));  // ← 整数溢出点
    if (m_corpseExpirationTime > respawnTimePoint)
        m_corpseExpirationTime = respawnTimePoint;
}
```

`InspectingLoot()` 由 `Loot::ShowContentTo()` 在**玩家打开拾取窗口时**调用。而"新刷新系统"的生物（`WorldObject::IsUsingNewSpawningSystem()` = `GetDbGuid() != GetGUIDLow()`，即**刷怪组成员 / dynguid**）在死亡时会把 `m_respawnTime` 设成 `std::numeric_limits<time_t>::max()`（`Creature::SetDeathState`：刷新交给 SpawnManager 管）。把 max() 转成 `TimePoint`（纳秒计数）会**整数溢出**，得到一个落在过去的垃圾时间点 → `m_corpseExpirationTime` 被改到过去 → 下一个 tick `IsCorpseExpired()` 为真 → `RemoveCorpse()`。玩家视角就是"一点尸体就没了、拾取不到"。

**为什么只有副本必现**：副本杂兵基本都在刷怪组里（本地库 `spawn_group_spawn` 共 28,279 个成员，覆盖地狱火城墙/奥金顿/幽暗沼泽/生态船/暗影迷宫等），静态世界刷点则是 `m_respawnTime = 现在 + 刷新`，是正常时间戳、不会溢出。

**修复**：只对"真实的、一年以内的刷新时间戳"做收紧，`max()` 这类哨兵值跳过。

```cpp
if (m_respawnTime > time(nullptr) && m_respawnTime - time(nullptr) < 366LL * 24 * 3600)
```

**影响面**：只改 `InspectingLoot()` 这一个收紧分支。刷新时间（含副本 2 小时）仍由 SpawnManager 按原值管理，尸体照常保留 `Corpse.Decay.*`（普通 300 / 精英 600 秒）供拾取。

**排查教训（重要）**：
- 第一轮误判根因为"`spawntimesecs = 0`（全库 88 个刷点）→ 尸体时间 = 刷新×0.9 = 0"，据此加的守卫（`Creature::Update` 的 CORPSE/DEAD 分支 + `[CORPSE-DBG]` 诊断日志 + `Loot::IsBeingLooted()`）**对本次症状无效**，已按站长要求**全部回滚**（回滚后 `src` 下只剩 `Creature.cpp` 一处改动；附带好处：不再改头文件，增量编译只重编这一个文件，云端也不会再出现"动头文件引发几百个文件全量重编"）。
- 关键线索是**本地日志里 `[CORPSE-DBG]` 一条都没有** → 尸体不是走"刷新规则 / Respawn / 强制消失"，而是走 `IsCorpseExpired()`。**凡排查"提前删尸体"，必须覆盖 `IsCorpseExpired()` 这条路径**（当时的诊断函数特意跳过了"已到期"的情况，正好漏掉了真凶）。
- 其它排查过但**不是**病因的项：`creature_template.CorpseDecay`（与上游零差异）、`creature_addon` 的召唤物 `corpseDespawnTime`、`Rate.Corpse.Decay.Looted = 0.0`（本 fork 已不使用该配置）、`spawn_group` 覆盖值（我们改过的 417 个组全是旧世界矿脉组，副本组与上游一致，副本 2 小时刷新未被改动）。

**次级问题（真实但影响面小，2026-09-17 未单独处理）**：`Creature::LoadFromDB` 的 `m_corpseDelay = std::min(m_respawnDelay * 9 / 10, m_corpseDelay)` 对 **`spawntimesecs = 0`** 的刷点会算出尸体时间 0。这类刷点全库共 88 个（map 580 太阳井 Shadowsword 杂兵与双子 BOSS、map 509 安其拉 Ossirian 水晶触发、map 530 外域无尽虚空幽魂等），**上游 `tbcmangos_orig` 同样为 0**，属原版数据。commit `9eb768fd7` 在新代码里加了 `&& m_respawnDelay` 守卫。

**部署与回滚记录**：
- 2026-09-17 21:48–21:51：上线 md5 `e80e2e40…`（基于含 09-16 溢出 bug 的树 + `9eb768fd7`），停机 2 分 15 秒。
- 2026-09-17 22:12–22:13：站长要求回滚 → **git 树与二进制一起退回 `07281ebe4`（Sep 7 13:44 编译的版本）**，云端已稳定；该版本不含 09-16 的溢出代码，因此**没有此 bug**。
- 溢出修复目前只在**本地**（本地树 `b46f74d52` + `Creature.cpp` 一处改动），本地服务 22:27 已重启待站长实测。

---

## [本地化] 中文中点：全角 ・ 改回半角 ·（2026-09-17 晚，站长游戏内实测）

- **现象（站长报）**：游戏里 NPC / 物品 / 任务名中间的那个点显示成**方块**（豆腐块）。
- **原因**：`079` 第 12 段（原 `dev/081`）按当时定下的规则，把半角 `·`(U+00B7) 统一成了全角 `・`(U+30FB)。
  但**客户端字体没有 U+30FB 的字形**（U+30FB 是日文片假名中点，中文客户端字体通常不收录）→ 缺字渲染成方块。
  数据库内容本身没错，问题在"选了客户端渲染不了的码位"。
- **定案**：中文中点一律使用**半角 `·`(U+00B7)**；079 第 12 段的"全角 ・"规则**作废**（已在 079 文件内加警告注释）。
- **修复**：新增 `dev/080_中文中点回退为半角点.sql`（幂等；自动枚举覆盖全部 `locales_*` 的 40 个 `_loc4` 列）。
  实际改动 **9,960 行 / 12 列**：`locales_creature.name` 2,474、`locales_npc_text.Text0_0` 2,771 + `Text0_1` 1,544、
  `locales_quest.Objectives` 1,914 / `Details` 815 / `Title` 137 / `OfferRewardText` 115 / `RequestItemsText` 50 / `EndText` 33、
  `locales_item.name` 56、`locales_gameobject.name` 34、`locales_page_text.Text` 17。
  **必须排在 079 之后执行**（编号顺序天然保证）；本地已应用，残留全角 = **0**。
- **生效方式**：locale 数据在 mangosd 启动时载入 → 应用后需重启（本地已重启待实测）。
- **教训**：字符（尤其是标点）的选择**不能只看参考资料里是哪个码位，必须以客户端字体能否渲染为准** ——
  U+00B7 属 Latin-1，几乎所有字体都有；U+30FB 属日文标点，中文客户端常缺字形。
  以后遇到"某个标点/生僻字符显示成方块"，先怀疑字形缺失，再看数据。

---

## [修复] 登录握手：mangosd 掉线后再上线"卡在读取角色列表"（2026-09-18）

- **站长报告**："mangosd下线导致的掉线，再次上线就会卡在读取角色"；这也是之前反复出现的
  "上线时卡在角色选择界面、每次重启 realmd 就好了"的同一个问题。
- **现场证据（云端，03:02 重启后）**：
  | 观测 | 数据 |
  |---|---|
  | 世界认证**每次都成功** | `authentification failed` / `unknown account` / `version mismatch` 全为 **0** |
  | 客户端在**反复重试** | 同一账号 4 次世界认证：03:02:46 → 03:03:08 → 03:03:19 → 03:03:21 |
  | 最后进去了 | 03:04:05 `Login Character`（从掉线到进去约 80 秒）|
  → **卡点在"世界认证成功之后、角色列表下发之前"**：认证没问题，是握手后半段没走完。
- **根因（`src/game/Server/WorldSocket.cpp` 的【重连分支】，523-556 行）**：
  掉线后客户端自动重连走的正是这条分支，而它里面有**两处"什么都不回、也不关连接"的静默失败**：
  1. `if (!session->RequestNewSocket(self.get())) return;` —— 会话上已有一个待处理 socket 时被拒，
     直接 return（**连日志都没有**）；
  2. `if (!anticheat->ReadAddonInfo(...)) { sLog.outBasic("... bad addon info. Kicking."); return; }` ——
     addon 校验失败同样静默 return，而且日志是 `outBasic`（默认日志级别下看不到）。
  两者都会让客户端**收不到任何响应、连接也不断** → 就卡在"读取角色列表"干等，
  十几秒后自己超时重试 ✓ 与观测到的重试节奏完全吻合。
- **修法（最小、且不再静默）**：
  - 两处都改成 **`outError` 日志 + 回 `SMSG_AUTH_RESPONSE(AUTH_FAILED)` + `Close()`** →
    客户端立刻失败并重新登录，不再干等；
  - 新建世界会话、以及 `WorldSession::Update()` 发送 `AUTH_RESPONSE` 时各加一条 `[AUTH]` 日志
    （**站长要求长期保留到线上，方便下次定位**）。
  - 注：`LogFileLevel = 0` 的语义是 `0 = Minimum`（Server.log 里能看到 `[AUTH]`/`ADDON:` 这类 basic 行），
    为稳妥起见关键路径一律用 `outError` 或 `outBasic`。
- **本地验证**（03:07 部署本地 → 只重启 mangosd、realmd 保持不动，精确复现"mangosd 下线导致掉线"）：
  ```
  03:08:46 [AUTH] new world session created: account='NYMPH' (id 6) from 127.0.0.1
  03:08:46 [AUTH] sending AUTH_RESPONSE(ok/queued) to account id 6 (state=CREATED, socket=open, inQueue=0)
  03:08:46 WARDEN: Account - 6 get opcode 01 ...（客户端当场恢复）
  ```
- **上线**：03:12 云端编译部署（只重编 `WorldSocket.cpp` + `WorldSession.cpp`）。

## [运维] 教训：常驻进程会继承 `flock` 锁，导致锁永不释放（2026-09-18）

- **现象**：`flock -n /var/lock/nightly_build.lock` 一直失败（rc=1），
  `fuser -v` 显示 **锁被 `realmd` 持有**（`/proc/<pid>/fd/3 -> /run/lock/nightly_build.lock`）。
- **根因**：util-linux 的 `flock <file> <cmd>` 用的是 **fd3**，且会随 exec 传给子进程；
  而 nightly 是**在 `flock` 里**运行的，它调用的 `realmd_restart_verify.sh` 用
  `nohup ./realmd ... &` 启动 realmd —— realmd 属于**常驻进程**，于是 fd3 一直开着，
  **锁永不释放**。后果很严重：crontab 里的 `flock -w 5400 /root/nightly_build_restart.sh`
  会空等 90 分钟然后**直接跳过整轮**（编译、部署、dev SQL 全都不做），且不留明显报错。
- **修法**：启动常驻进程前显式关闭继承 fd：
  ```bash
  nohup setsid bash -c "exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-; exec ./realmd -c $BINDIR/realmd.conf" > /tmp/realmd_run.log 2>&1 &
  ```
  同样处理 nightly 里两处 `screen -dmSL mangosd ... bash -c 'cd ... && exec 3>&- ...; MALLOC_ARENA_MAX=2 exec ./mangosd ...'`。
  备份：`realmd_restart_verify.sh.bak_lockfd_20260918_0312` / `nightly_build_restart.sh.bak_lockfd_20260918_0312`。
- **验证**：重启 realmd（用修好的脚本）后，`flock -n` **立刻可以拿到锁**，
  且 realmd 常驻运行期间锁保持空闲 ✓。
- ⚠️ **通用教训**：**任何在 `flock` 段内启动的常驻进程，都必须关闭继承的锁 fd**；
  否则锁泄漏、后续所有依赖该锁的定时任务静默失效。

---

## [经济] AHBot：分解套利整改 + 收购熔断 + 报价每日限额（2026-09-18）

**起点（站长观察）**：存在一个套利空间 —— **收购拍卖行的装备 → 分解 → 卖附魔材料**。

### 1. 价格发现机制的真实形状（先搞清楚再动手）

- 机制：`AuctionHouseBot::UpdateMarketPrices()` 每个刷新周期（`MarketMaker` / `Value.DynamicRefresh = 60s`）扫全盘，
  对每个物品算：全盘最低单价中位数、挂单深度、**玩家挂单件数与最低要价**、bot 自己的挂单；
  然后按"**自己的买卖流水**"做长周期结算（`FlowSettleHours`）移动报价锚：
  `flow_bought`（bot 从玩家手里买进）≫ `flow_sold`（玩家从 bot 买走）→ 报价下跌 `FlowMoveDownPct`；
  反向 → 上涨 `FlowMoveUpPct`；需要 `flow_total ≥ FlowMinUnits` 且一边 ≥ `FlowRatio%` 才动。
- ⚠️ **致命限制（本次实测确认）**：`ahbot_market_state.price_ref > 0` 的行是**操作员钉价行**，
  代码在钉价分支直接 `continue` → **整套价格发现对它们完全旁路**。云端共 **134 行**是这种状态，
  包含全部附魔材料、源生、绝大多数材料。
- 站长实测案例：卖出 1,218 个大块棱光碎片 → `flow_bought = 1218`、`spent = 11,394 金`
  **流水记下来了，但报价仍然是 10.80 金没动**（因为它是钉价行）。
- 结构性问题：拍卖行 **bot 挂单 146,987 条 / 372,079 件（115.9 万金），玩家只有 3 条** →
  玩家挂单信号≈0，"发现"只能靠流水驱动。
- bot 累计 **花掉 14,826 金 / 买进 1,469 件、收入 2,921 金 → 净投放 11,905 金**进经济（旧配置 `BuyPerCycle = 0` = 无限收购）。

### 2. 套利量化（`/root/de_arbitrage.py`，云端实测）

- bot 在卖的可分解装备 **3,452 种**，其中 **2,847 种（82%）的分解期望价值 > 售价**；
- 最高 +841%：`15931 奥术之星` 售价 1.01 金 / 分解值 9.52 金；蓝装挂单最低 **0.04 金**、紫装最低 **3.40 金**，
  而分解产物 `22449 大块棱光碎片` 10.80 金 / `22450 虚空水晶` 25.00 金。

### 3. 落地改动

**（a）材料价按分解期望重定** —— `dev/084_附魔材料价按分解期望重定.sql`
- 方法：约束「装备售价 P_i ≥ Σ(分解产出 x_ij × 材料价 p_j) ÷ relax」，从当前价迭代收缩（`/root/de_final2.py`）；
- 站长定案：**以方案1（压材料价）为主 + 材料价适当留高** → `relax = 1.5`（允许最多 50% 分解利润）
  + **地板 = 原价 15% 或卖店价**（避免低级材料被压成 0）；
- 30 种材料新价（金）：虚空水晶 25.00→**14.29**、大块棱光碎片 10.80→**2.73**、强效位面精华 6.00→**2.66**、
  强效不灭精华 6.00→**0.96**、连结水晶 4.00→**1.66**、小块棱光碎片 3.60→**1.32**、奥法之尘 1.20→**0.47** …；
- 效果：可套利装备 **2,847 → 约 700 件**，其中 >50% 利润的**只剩 4 件**；
- 备份表 `ahbot_market_state_bak_20260918_ench`（一条 UPDATE 可回滚）。

**（b）收购熔断（两道闸）** —— 站长定案："按 50 人在线，每天释放硬限制 5000 金以内；
在线时间不均匀，以周期为单位不合适；同时每周期也要有限制，防止一上来就吃完；每周期限制 100 金，
一个物品被抬到 100 金一组说明供给很有限，不应继续收购；真有人找到漏洞，那也算他的奖励。"
- **日闸（主闸）**：`MarketMaker.MaxGoldPerDay = 50000000`（5000 金/24h），
  **跨重启连续**（`ahbot_daily_budget` 表，`dev/086`；否则每晚重启会把预算重置成漏洞）；
- **周期闸**：`MarketMaker.MaxGoldPerCycle = 1000000`（100 金/周期）—— 纯硬闸，
  **单件价格超过周期预算就永远不买**（价格掉不下来就不收）；
- 保留原有的**每项件数闸** `BuyPerCycle = 2 件/项/周期`；
- 触发时打 `error` 级日志（`[AHBOT] BUY BREAKER TRIPPED (daily) / (per-cycle)`），日志串一律 ASCII
  （MSVC 按 GBK 解析，中文字符串会**偶发**吃掉引号导致 `error C2001`）。

**（c）报价每日上下移动限额** —— 站长要求"报价一天上下移动限额 10%"
- `MarketMaker.MaxDailyMovePct = 10`；新增字段 `ahbot_market_state.day_price / day_start`（`dev/085`）
  持久化 24h 窗口基准；落库前把新报价夹在「基准 ±10%」内，窗口满 24h 用当前报价重设基准；
- 为什么需要：结算窗口调成 6h 后，一天最多结算 4 次 × 下跌 5% ≈ 单日最多跌 18.5%，超过 10% 的要求。

**（d）装备价与地板：不动** —— 站长定："装备地板就是卖店价，这是为了买装备更便宜"
（所以**没有**给装备加"分解价值地板"；那是另一条路，会让装备涨价）。

**（e）AHBot 调参**（`/opt/mangos/etc/ahbot.conf`，备份 `.bak_tune_20260918_1749` / `.bak_breaker2_20260918_1808`）
| 项 | 原值 → 新值 |
|---|---|
| `Chance.Sell` / `Chance.Buy` | 25 / 25 → **15 / 15** |
| `Loot.Creature.Rare` | 20,20,5,8 → **8,8,2,3** |
| `Loot.Creature.RareElite` | 20,20,5,8 → **5,5,1,2** |
| `Loot.Disenchant` | 5,6,20,20 → **3,4,10,15** |
| `FlowSettleHours` / `FlowMinUnits` / `FlowRatio` / `FlowMoveUpPct` | 24h / 20 / 150% / 1% → **6h / 8 / 120% / 3%** |
| `BuyPerCycle` | 0（无限）→ **2 件/项/周期** |

### 4. 观测与测试工具（云端）

| 工具 | 用途 |
|---|---|
| `bash /opt/mangos/ahbot_watch.sh` | 市场面板：流水/钉价行/收购强度/挂单来源/配置值 |
| `python3 /root/de_arbitrage.py` | 套利分析：3,452 种可分解装备逐个对比售价 vs 分解值 |
| `python3 /root/de_relax.py` | 材料价方案扫描（relax 1.0/1.25/1.5/2.0 四档对比） |
| `python3 /root/de_final2.py` | 最终方案（`FLOOR=0/15/30 RELAX=1.5` 可调），并打印可直接用的 SQL 片段 |
| `UPDATE ahbot_daily_budget SET gold_spent = 0` | 手动放开当日预算 |

**测试价格发现的方子**：小号挂一批低于 bot 报价的物品 → bot 吃单 → 面板第【1】节 `flow_bought` 上升 →
过 `FlowSettleHours` 后报价按 `FlowMoveDownPct` 下移（且受每日 10% 上限约束）；
反向（买光 bot 的货）→ `flow_sold` 上升 → 报价上移。

### 5. ⚠️ 另一处本地/云端不一致（务必知道）

本地库的 `ahbot_market_state` 价格与云端**不同**（例：大块棱光碎片 本地 3.60 金 / 云端 10.80 金），
且本地流水几乎全为 0 → **本地测 AHBot 行为不能代表线上**。本次已把本地 `ahbot.conf` 与云端全部对齐
（备份 `ahbot.conf.bak_sync_20260918_1801`），材料价也已用同一份 dev SQL 应用到本地。

---

## [任务] 10961《觉醒之戒》：沼泽花不炸飞玩家 —— 已修 + 玩家实测通过（2026-09-19）

### 1. 设计链路（数据都在，没缺）

| 环节 | 数据 | 说明 |
|---|---|---|
| 花本体 | 地物 **185497**（chest，loot 22011 → 任务物品 31950）/ **185500**（goober，questId 10961） | 由 **spawn_group 29999「Zangarmarsh - Bogblossom (185497,185500)」MaxCount=123** 动态刷，247 个刷点（`spawn_group_spawn`）；所以游戏里看得到花（刷点是 guid 级，模板由组决定；那些刷点的 `gameobject.id` 存的是 0，模板由组的 entry 决定） |
| 联动陷阱 | goober 185500 的 `linkedTrapId = 185499`；chest 185497 的 `linkedTrapId = 185502`（无害版） | 185499 是 trap，`charges=1` |
| 花粉法术 | **39558**：Effect1/2 = APPLY_AURA，Effect3 = 28(SUMMON) misc = **23104** | 召唤 Bogblossom Bunny |
| 击飞 | Bunny **23104** 的 EventAI `id=2310401`：EVENT_T_SPAWNED(11) → ACTION_T_CAST 施放 **40532** | Effect=98 KNOCK_BACK，misc 300 / basepoints 274 |

### 2. 两个断点（缺一不可，所以之前完全没反应）

1. **联动陷阱从没被"用"过**：`GameObject::TriggerLinkedGameObject()`（GameObject.cpp:1287）只在**已存在**、同 entry、**半径 0.5 码内**的陷阱地物上调用 `Use()`；而 185499 全库没有任何实例（`gameobject` 0 行、也不在 29999 组里，上游 tbcdb_ref / FullDB 同样如此）→ 搜索永远失败 → 花粉根本不会施放。
   （`linkedTrapId` 在代码里只有 ObjectMgr 的校验用到，运行时就这一个触发点；trap 的 `diameter=0` 也意味着不会靠走近触发。）
2. **兔子那条 EventAI 打不到人**：`creature_ai_scripts.id=2310401` 的 `action1_param2 = 15`，在 EventAI 目标枚举里 **15 = `TARGET_T_NONE`（无目标）** → 40532 以 nullptr 为目标施放，而 `Spell::EffectKnockBack()` 第一行 `if (!unitTarget) return;` 直接返回。
   → 即便把断点①修好（花粉施放、兔子召唤出来），玩家依然不会被弹。这条 AI 数据本身有问题。

### 3. 修法（数据 dev/091 + 核心兜底）

- **数据 `dev/091_任务10961沼泽花击飞修复.sql`**：陷阱 185499 的法术 `data3` 由 39558（花粉）改成 **40532（击飞）** —— 绕开出问题的"花粉→兔子→AI"链。
  **明确不改**：宝箱版 185497（掉任务物品 31950 的那朵）的联动陷阱保持 **185502「无害版」**（无 spell）—— 站长确认"**宝箱版不会击飞是对的**"，所以只有 goober 版（185500）那朵会弹人。
- **核心 `src/game/Entities/GameObject.cpp` → `TriggerLinkedGameObject()` 兜底**：找不到已放置的联动陷阱时，按模板把它的法术打在使用者身上（以花为 original caster），这样陷阱没被摆进世界也能生效：

```cpp
    if (trapGO)
        trapGO->Use(target);
    else if (trapInfo->trap.spellId)
        const_cast<GameObject*>(this)->CastSpell(target, target, trapInfo->trap.spellId,
                                                 TRIGGERED_OLD_TRIGGERED, nullptr, nullptr, GetObjectGuid());
```

影响面严格限于"联动陷阱缺失"这一种情况（以前是静默无操作）→ 零回归风险，顺带修好其它"陷阱没摆出来"的联动地物。

### 4. 验证

- 本地 build1 已 Release 编译 + 部署，站长进游戏实测：**现在有击飞** ✓；
- 当时埋的临时诊断日志（已删除）留下了证据：
  ```
  [GOTRAP]  go 185497 used by Player ... -> linked trap 185499 (spell 40532) placed=1
  [KNOCKBACK] spell 40532 caster Player ... target Player ... misc 300 dmg 27.5
  ```
- 源码（GameObject.cpp / SpellEffects.cpp）与 `dev/091` 均已同步到云端 `/root/Nmangos-tbc`，夜间 04:06 自动编译+重启生效。

---

## [经济] AHBot 开放紫装（史诗）上架 + 去掉材料钉价 —— 2026-09-19

### 1. 生效的配置文件（容易搞错）

`_AUCTIONHOUSEBOT_CONFIG = SYSCONFDIR "ahbot.conf"`，`SYSCONFDIR = "../etc/"`，mangosd 的 cwd 是 `/opt/mangos/bin`
→ **云端真正读的是 `/opt/mangos/etc/ahbot.conf`**（启动日志打印 `AHBot using configuration file ../etc/ahbot.conf`）。
`/opt/mangos/bin/ahbot.conf` 是 9 月 2 号的**废弃副本**（里面 `Value.Epic = 160,160`，没人读），别被它误导。

### 2. `Value.Epic` 的作用与本次取值

- `Value.<品质>` 是 17 个数 = class 0..16 的百分比；`GetItemValue()==0` 的物品直接不上架（代码 441 行）。
- 本次值：`AuctionHouseBot.Value.Epic = 0,0,25,0,25,0,...`（只放武器 class2 / 护甲 class4，各 25%，与 Rare 同档；
  宝石 / 配方 class9 / 杂货保持 0，日后再单独议）。
- 报价 = `CalculateBuyoutPrice()` × 25% = `BuyPrice`（或 `SellPrice×5`）× 0.25。
  实测候选 141 件（41 武器 + 100 护甲），**没有一件低于 1 金**（最低约 45 金，最高巫术之刃 5412 金）→ 无低价陷阱。
- **`BuyPrice=0 && SellPrice=0` 的紫装不会上架**（代码 491 行 `if (buyoutPrice == 0 || !item) continue;`），
  共 10 件（能量枯竭的锁甲手套/布质护腕、暗影之眼、成年蓝龙肌腱、涡轮加速飞行控制器、弗洛尔的屠龙技术纲要、
  比斯巨兽的完美毛皮、深渊节杖、迅捷魔法/飞行扫帚）→ **不需要额外地板价**。
- 60346 那 9 件 ilvl115 紫装是 **BoP（bonding=1）→ 依然不上架**（我们给的 ×5 掉率只对玩家生效）。
- 供给仍来自「模拟打怪掉落」：141 件里约 85 件覆盖 118~670 只怪（60345 世界掉落组、经典世界掉落、MC/BWL 的 T1 腰带护腕等）
  会真正出现；18 件只有团本小怪那 15 只怪；约 38 件覆盖 0~1 只怪（灵魂卫士/救赎灵魂/束缚灵魂/影钢/野性卫士/寒冰卫士/
  泰罗克/3072x 那批，来源是牌子/任务/世界 boss）基本永远不出现 —— 按站长决定不加禁售行。

### 3. 材料钉价去掉（`dev/090`）

`ahbot_market_state` 里 125 条 book 行只有 2 条是"钉死"的（`price > 0` = 操作员定价，代码 750 行跳过全部发现）：
22449 大块棱光碎片 10.80 金、22450 虚空水晶 25.00 金；其余 123 条 `price = 0` 早已走价格发现
（`price_ref` 只是 bot 自己持久化的上次收盘价/锚，**不是钉价**）。
`dev/090` 把这两行的 `price` 清 0（**不删行**——删行会让物品退出 book，而 class7 品质3/4 在 Value 矩阵里是 0，
bot 会彻底不上架这两种材料）。本地 A/B 验证过：去钉价后价格不再被覆盖回去，锚价稳在 2.73 / 14.29 金。

### 4. 精华「强效 / 次级」套利修复（`dev/095`）

- **站长报的问题**：强效<X>精华 与 次级<X>精华 之间存在套利空间，因为 **1 强效 = 3 次级**。
- **量化**（云端 `ahbot_market_state` 实测 2026-09-19）：6 对里**强效全部低于 3 × 次级** ——
  魔法 478 / 897（1.60×）、星界 **675 / 2229（0.91×，强效比 1 个次级还便宜）**、秘法 5007 / 7311（2.05×）、
  虚空 7061 / 18708（1.10×）、永恒 9855 / 28533（1.01×）、位面 26575 / 52977（1.50×）。
  → 「买强效 → 拆成 3 个次级 → 卖给 bot」白拿差价；星界、永恒那两对几乎是无风险 3 倍收益。
- **依据**：游戏自身 `BuyPrice` 已把汇率定死成 3:1（800/2400、3000/9000、10000/30000、20000/60000、
  40000/120000、40000/120000）；而 `staticPrice = BuyPrice × 物品价值%`，同一对品质/分类相同
  → **staticPrice 天然也是 3:1**，所以把 `price_ref` 设成 3× 不会被启动时的
  `[PriceFloor=5%, PriceCeil=300%]` clamp 打歪。
- **做法**：只把【强效】一侧的 `price_ref` 重定为「当前次级 × 3」= 897 / 2229 / 7311 / 18708 / 28533 / 52977
  （**写死值** —— 按 P0，云端库只跑静态、幂等、秒级的写操作，不做计算/判断）。
  **不动次级**（它是这一对的锚，`084` 已按分解期望定过）；**不写 `price` 列钉价**
  （`090` 已定案：材料价应当交给价格发现）。
- **验证**：本地应用后 6 对 ratio 全部 = 3.00；**复跑输出逐字节一致**（幂等）；
  校验 2（`g.price_ref < l.price_ref * 3`）返回 **0 行**；备份表 `ahbot_market_state_bak_20260919_essence` 已存改前值。
- **生效**：`price_ref` 由 `AuctionHouseBot` 在 mangosd 启动时载入 → 随夜间重启生效
  （云端 marker 当时为 093，夜间会先跑 `094` 再跑 `095`）。
- ⚠️ **价格发现仍会漂移**：`price_ref` 只是启动锚（实测同一 item 本地/云端能差几十~几百铜）。
  若日后 ratio 又被拉开，说明发现逻辑把它推回去了 —— 那就不是数据问题，需要再议
  （加跨物品约束，或对这两列改用 `price` 钉价）。
- ⚠️ **物品名在库里是英文**：`item_template.name` 是 `Lesser/Greater ... Essence`，
  中文只存在于客户端 DBC —— 所以**用中文名查库永远查不到**，排查时要用英文名
  （本次一开始用 `LIKE '%精华%'` 白查了一轮）。

### 5. 装备挂牌过多 → 下调普通生物掉落模拟的抽样源（`ahbot.conf`，2026-09-19）

- **站长诉求**：「ahbot 的装备太多了」，要求把 AHBot 对生物掉落的 loot 频率降一些。
- **先量现状**（云端 `tbccharacters.auction` 实测，共 **30,677** 条挂牌）：
  材料 class7 11,777 / **护甲 class4 7,269** / 消耗品 2,699 / 任务 2,318 / 配方 2,220 /
  宝石 1,897 / **武器 class2 1,335** → **装备合计 8,604 条 = 28%**（2,916 种）。
- **关键发现（以后别再摸错地方）**：`ahbot_market_state` 的 book 只有 **125 项，且全部是 class 7 材料**；
  **装备 100% 在 book 之外**（in_book 仅 2,338 条，outside_book 28,339 条）。
  → 材料走 `QuoteCatalog`（市场做市），**装备走 `ahbot.conf` 的 `AuctionHouseBot.Loot.*` 掉落模拟路径**
  （`AuctionHouseBot.cpp` 377 行注释写明：loot-table supply 只负责 catalog 之外的物品）。
  所以「装备太多」**只能调 `Loot.*`，改 `ahbot_market_state` 没用**。
- **参数语义**（`ahbot.conf` 自带注释）：
  `AuctionHouseBot.Loot.<source>[.<rank>] = <minSources>,<maxSources>,<minLootings>,<maxLootings>`
  —— 前两个决定**抽多少个掉落源**（≈物品多样性/数量），后两个决定**每个源刷几次**（≈堆叠份数）。
- **改动（两轮，最终为站长定值）**：`/opt/mangos/etc/ahbot.conf`（**真正生效的那份**，见本章第 1 节）

  | 参数 | 原值 | 第一轮 | **最终** |
  |---|---|---|---|
  | `Loot.Creature.Normal` | 100, 100, 5, 8 | 50, 50, 5, 8 | **25, 25, 3, 5** |
  | `Loot.Creature.Rare` | 8, 8, 2, 3 | — | **3, 5, 1, 3** |
  | `Loot.Creature.RareElite` | 5, 5, 1, 2 | — | **3, 5, 1, 3** |

  备份：`/root/ahbot.conf.bak_20260919_lootfreq`（原值）、`…_lootfreq2`（第一轮之后的值）。
  ⚠️ `cloud_mm_deploy.sh` 只**备份**该文件、不覆盖它，nightly 完全不碰配置 → 改动不会被冲掉。
- **预估效果**（掷骰量 ≈ 源数 × 刷取次数中值）：Normal **650 → 100（−85%）**、Rare 20 → 8、
  RareElite 7.5 → 8；**生物掉落总量 677 → 116（约 −83%）**。
  三组都是「源数」与「刷取」一起降，所以**种类和份数同时减少**。
- **为什么重点在 Normal**：`Elite` / `WorldBoss` 本来就是 `0,0,0,0`（关着），
  且 Normal 一组的掷骰量比 Rare / RareElite 高一个量级 —— 普通怪是装备的绝对主来源。
- **继续调**：嫌少就把 `25, 25, 3, 5` 往发行版默认（`30, 35, 8, 12`）抬；
  只想减「同一物品的份数」而不动种类，就单独调后两个数。

### 6. 紫装价值 25%→50%、虚空水晶按新价重定（`dev/096`）+ 幽灵商人 bug —— 2026-09-19

- **起因**：站长查「自然愤怒法杖（31334）」挂 **66 金**、比同批紫装高一大截（且已售出），顺藤追出两件事。
- **① 幽灵商人 bug（真 bug，尚未修）**：AHBot 判定「商店货」用的是
  `FillUintVectorFromQuery("SELECT item FROM npc_vendor")`（代码 126 行）—— **只扫 `npc_vendor`，
  不校验这个商人有没有刷点**；而 `GetItemValue()`（1862 行）对商店货直接 `return 100`，
  于是这些物品的静态价被算成 **BuyPrice 的 100%**。
  - 实例：31334 在 `npc_vendor`（NPC **26309「武器商人」**，卖 150 件货），但 26309
    **在 `creature` 表里 0 刷点** → 玩家永远见不到它 → bot 却按商店价定 **67.17 金**
    （观测挂单 66 金 = 含 `Value.Variance=5` 的 ±5% 浮动）。
    同批紫装不在商店里，只按 class 价值 25% 算 → 只有 6~16 金。
  - **波及面**：788 个商人 NPC 里 **27 个没有刷点** → 影响 **1,179 件物品**，其中
    **704 件紫装**被按商店价定价（比正常 class 价高 2.5~4 倍）。
  - 修法（待站长定）：`SELECT item FROM npc_vendor` 加「商人必须有刷点」的过滤，
    或清掉那 27 个幽灵商人的 `npc_vendor` 记录。
- **② 紫装价值 25% → 50%**（站长定值）：`/opt/mangos/etc/ahbot.conf`
  `AuctionHouseBot.Value.Epic = 0,0,50,0,50,…`（**武器 class2 与 护甲 class4 都是 50**）。
  备份 `/root/ahbot.conf.bak_20260919_epicarmor`（先改的护甲）、`…_epic50`（最终）；
  原始值 `0,0,25,0,25,…` 仍保留在 `/root/ahbot.conf.bak_20260919_lootfreq`。
  效果：来源紫装挂单价全线翻倍（31339 Lola's Eve 6.09→12.05、31331 13.29→26.58、31336 55.20→108.24）。
- **③ 虚空水晶按新价重定（`dev/096`）**：**14.29 → 11.45 金**（`price_ref` 114500）。
  - 产出关系（已核实）：`disenchant_loot_template` 的 **DE id 66/67（ilvl 95+ 紫装）→ 22450 × 1~2，100%**，
    均值 **1.5 个/件**；DE id 65 出的是 20725 连结水晶，与本项无关。
  - **装备挂单价 = 静态价 ±5%**（非 book 物品走 `ValueWithVariance`）→ **下限可算，不会乱飘**。
  - **锚点怎么选的（关键，别用错）**：候选里最便宜的几件**根本供不上** ——
    34029 Tiny Voodoo Mask（静态 1.80 金）只挂在参考组 36152，**仅 1 只怪**引用；
    34837 The 2 Ring（2.26 金）在参考组 10000、**0 只怪**引用，且其商人 NPC 26300 也是幽灵商人；
    21863 / 32655 / 34622 / 35693~35703（2.40~5.17 金）**完全没有掉落来源**。
    真正稳定供给的是 **参考组 60345（670 只怪引用）**，组内最便宜 = **31339 Lola's Eve 12.05 金**。
  - 计算：P_min = 12.05 × 0.95 = **11.45 金**；沿用 `084` 的 relax=1.5 → `V ≤ P_min` → **V = 11.45 金**
    （分解期望 17.18 金 ÷ 11.45 = **1.50 倍 = +50%**，正好卡在允许边界；
    改前是 21.43 ÷ 6.09 = **3.52 倍 = +252%**）。
- **教训**：
  1. **查「库里有没有」必须先确认列名与库名**：本次 `itemcount`（实际是 `item_count`）、
     `creature_template` 里不存在的 `map` 列、以及忘带库名，三次都被 `2>/dev/null` 静默吞成空结果，
     白查三轮。**查询出错必须让 stderr 可见。**
  2. **价格锚点必须落在「真能被供给」的物品上**：只看数值最小会把锚定到永远刷不出来的东西，
     结论就全错。
  3. 物品中文名不在 `item_template.name`（那是英文），在 **`locales_item`**
     （`name_loc4`=简中、`name_loc2`=法、`name_loc3`=德、`name_loc5`=繁中、`name_loc8`=俄 …）
     —— 要核对中文名就查这里。

### 7. 修掉「幽灵商人」定价 bug：商店货判定加刷点过滤 —— 2026-09-19

- **改动**：`AuctionHouseBot::Initialize()` 里

  ```cpp
  // 改前
  FillUintVectorFromQuery("SELECT item FROM npc_vendor", tmpVector);
  // 改后
  FillUintVectorFromQuery("SELECT item FROM npc_vendor WHERE entry IN (SELECT id FROM creature)", tmpVector);
  ```

  （`creature.id` 有 `idx_id` 索引，子查询很快；写法与 gameobject 那条早就在用的刷点过滤一致。）
- **效果（云端实测）**：
  - 商店货物品表 **3,646 → 2,603 件**
  - **1,043 件彻底失去商店货身份**（其中 **677 件是紫装装备**）；另有 **136 件**因为还有别的正常商人卖，仍保留身份
  - 这些紫装从「按 BuyPrice 的 100% 定价」回落到 class 价值定价，例如
    `30911 Scepter of Purification` **101.53 → 50.76 金**、`30902 Cataclysm's Edge` 97.87 → 48.93 金、
    `31334 自然愤怒法杖` 67.17 → 33.59 金
- **口径说明**：该过滤是**严格子集** —— 只要还有**一个有刷点**的商人卖它，物品就仍算商店货。
  所以「被幽灵商人卖过的物品数 1,179」≠「彻底失去身份的物品数 1,043」，两个数**别混用**。
- **生效**：随夜间编译重启。⚠️ 改这个文件必须保留 **CRLF**（见下条）。

### 8. ⚠️ 连踩三个工具坑：行尾 CRLF/LF、「中文注释 + MSVC/CP936」、假的 `grep -c $'\r'`

- **现象**：给 `AuctionHouseBot.cpp` 加了几行**纯 ASCII** 注释后，本地编译报
  `error C2447: "{": 缺少函数标题`，报错位置在第 1286 行 —— 离改动点几百行远，非常迷惑。
- **真因**：该文件是 **CRLF**，我误判成 LF，把它整体 `\r\n → \n` 转换了一遍，
  于是触发了 **MSVC 按 CP936 读 UTF-8 中文注释时的「行吞并」陷阱**：
  注释行末尾的 UTF-8 字节被当成 GBK 首字节，把换行也吃掉 → **下一行代码被注释掉**。
  把行尾改回 CRLF，立刻编译通过。
- **教训 1：不要假定行尾。** 云端源码树是**混合**的 —— `AuthSocket.cpp` / `Map.cpp` 是 **LF**，
  `AuctionHouseBot.cpp` 是 **CRLF**。同步前先看**该文件自己**的行尾、按原样同步。
  GCC 两种都能编，**但本地 MSVC 遇到「UTF-8 中文注释 + LF」会炸**。
- **教训 2：`grep -c $'\r'` 经 ssh 传过去根本不可靠。** PowerShell 会把 `$'\r'` 原样传给 bash，
  bash 不解释它，grep 于是在找字面量 `$\r` → **永远返回 0**，看起来"全是 LF"。
  **这正是我把 CRLF 误判成 LF 的直接原因。** 要查行尾就用 Python 数字节
  （`b.count(b'\r\n')` vs `b.count(b'\n')`），别用 grep。
- **教训 3：PowerShell 里 `git show ... > file` 写出的是 UTF-16LE**（文件大小正好翻倍：
  205,448 ≈ 2 × 102,724），不能拿来做源码对比。要用 `git show` + Python 捕获 `bytes`。
- **教训 4**：`python -c` 里的反引号/引号会被 PowerShell 吃掉（本次 `SyntaxError: unterminated string literal`），
  复杂脚本一律**写成 .py 文件再跑**。

### 9. 修掉「向上改价后竞拍价掉队」：一口价涨了、起始价没跟着 —— 2026-09-20

- **现象**（站长报）：拍卖行的**紫装只改了一口价，没改竞拍价** —— 一口价本该与竞拍价接近。
- **量化**（云端实测，按品质 × 创建时间分档看 `startbid / buyoutprice`）：

  | 创建时间 | 品质 | 条数 | 起始价/一口价 |
  |---|---|---|---|
  | 改价前（09-19 14:55 ~ 09-20 02:01） | **紫** | 195 + 143 | **48.9% / 49.2%** ❌ |
  | 改价后（09-20 02:45 ~ 02:51） | **紫** | 1 + 3 | **97.0%** ✅ |
  | 改价前 | 蓝 | 6,727 | 97.2% ✅ |
  | 改价后 | 蓝 | 118 | 97.5% ✅ |

  明细佐证：`31322 The Hammer of Destiny` 起始价 **15.80** / 一口价 **31.31**，
  而 15.80 正是**改前的静态价**（BuyPrice 62.61 × 25%），31.31 是改后的（× 50%）。
- **定位**：**创建路径本来就是对的** —— 5 处 `AddAuction`（500 / 522 / 1468 / 1500 / 1534 行）
  全都是 `bid = buyout × urand(Bid.Min, Bid.Max)%`（线上 95~100%）。
  出问题的只有 `UpdateMarketPrices()` 里对**已挂单的单子就地改价**那段：

  ```cpp
  // 改前（1065-1066 行）
  if (auction->startbid > newBuyout)
      auction->startbid = newBuyout;      // 只在【新一口价更小】时才往下夹
  ```

  **向上改价时旧的起始价原样留着**。紫装价值 25%→50% 正是一次翻倍式上涨，
  于是被改过价的旧单，起始价停在新一口价的一半。
- **不是"改价"本身的锅**：任何 **≥1% 的向上改价**都会复现
  （触发条件 `priceMoved = |newPrice-oldPrice|*100/oldPrice >= RepriceThreshold(=1)`，
  且该段对**所有有挂单且 state.price 非 0 的物品**都跑，不限 book 成员）。
  做市商的价格发现本来就会推价（`MaxDailyMovePct = 10`）→ **这是潜在 bug，本次只是被暴露出来。**
- **改动**（`AuctionHouseBot.cpp` `UpdateMarketPrices()`）：把起始价拉回
  `[Bid.Min%, Bid.Max%] × 新一口价` 区间内：

  ```cpp
  uint32 bidLo = (uint32)((uint64)newBuyout * m_auctionBidMin / 100);
  uint32 bidHi = (uint32)((uint64)newBuyout * m_auctionBidMax / 100);
  if (auction->startbid < bidLo || auction->startbid > bidHi)
  {
      uint32 target = (bidLo >= bidHi) ? bidHi : urand(bidLo, bidHi);
      if (auction->bid && target > auction->bid)
          target = auction->bid;      // 已有出价时不得倒挂
      auction->startbid = target;
  }
  ```

  设计点：① **只在超出区间时才动** —— 健康单子零抖动，且已有的 338 条坏单会在下一次改价时**自动归位**；
  ② 区间取自 `Bid.Min/Bid.Max`，与创建路径**同源**；③ 保留 `起始价 ≤ 当前出价` 的不变式（倒挂会让客户端报错）。
- **顺带堵掉的漏洞**：起始价只有一口价一半时，玩家出个最低价、无人竞争就能**到期半价拿走紫装**。
- **见效方式**：今后任何向上改价都同步归位（**不再复发**）；现有 338 条（195 武器 + 143 护甲）
  **最多 12 小时**内随挂单到期、按创建路径重挂而自然清空（`Time.Min/Max = 12`）。
  随 09-20 04:06 nightly 编译上线（判据实测：1 条编译命令，含 `AuctionHouseBot.cpp`）。

## [掉落] 至尊二戒（The 2 Ring, 34837）掉率 0.1% → 0.5% + 钓鱼宝藏袋链路 —— 2026-09-20

### 1. 它到底怎么获得（实测，链路全通）

```
NPC 25580 Old Man Barlo（沙塔斯，map 530，1 个刷点）
  → 5 个钓鱼日常：11665 奖 35348 / 11666・11667・11668・11669 奖 34863
  → 每次完成奖 1 个「钓鱼宝藏袋 Bag of Fishing Treasures」
  → 开袋走 item_loot_template → 参考组 10000（26 件）
  → 组内 groupid=2 竞争组里，至尊二戒几率 0.1%
```

⚠️ **教训：查"这东西能不能拿到"不能只查掉落表。** 本次先只查了
`creature/gameobject/fishing/skinning/item_loot/reference` 六张表，结论"哪都不出"，
**漏了任务奖励这条**（`quest_template.RewItemId1` —— 而且该表的奖励列**不含 "Reward" 字样**，
用 `LIKE '%Reward%'` 只会查到 `OfferRewardText/Emote` 那几列，容易误判成"没有奖励列"）。
以后再问"某物品从哪来"，**任务奖励（`RewItemId*` / `RewChoiceItemId*`）、商店（`npc_vendor` ∪ `npc_vendor_template`）、
法术产出（`spell_template.EffectItemType*`）三处必须一起查。**

### 2. 为什么玩家/AH 都看不到它

- 一天一次日常 × 一次一个袋子 × **0.1%** → 期望约 **1/1000 天**，基本等于不存在。
- AHBot 也永远上不了架：bot 的开袋候选池有额外门槛（`AuctionHouseBot.cpp` 111-115 行）——
  **容器本身必须能从 creature / gameobject / fishing / skinning 掉出来**，而钓鱼宝藏袋
  是任务奖励、任何掉落表里都没有 → 进不了池（池子共 45 个容器，它不在其中）。
  → 所以「至尊二戒不在 AHBot 上架列表里」是**两道门都关着**，不是单一原因。

### 3. 参考组 10000 的完整档位（中文名已核对）

| 档 | 物品 | 几率 |
|---|---|---|
| 通用 | 锐利的鱼钩 75% / 水上行走药剂 25% | groupid 1 |
| 实用件 | 食谱·拉姆瑟船长特酿 4% / 暗影珍珠 3% / **真银渔线 2%** | groupid 2 |
| 收藏件 | 酒杯·婚戒·义眼·银雕像·古代硬币·水手日志·银手铐·贵族眼镜·秘银剃须刀 各 1.5% | groupid 2 |
| 收藏件（更稀） | 海洋之眼·饱经风霜的渔帽·饱经风霜的日记 各 1% | groupid 2 |
| **至尊二戒** | **0.1%** ← 改动前，组内垫底 10~40 倍 | groupid 2 |

（`真银渔线 Spun Truesilver Fishing Line`：class 0 subclass 6 = 消耗品·**物品强化**，
需要**钓鱼 300**，是给鱼竿加钓鱼技能的渔线；全服同类只有它和 19971 高强度恒金渔线。）

### 4. 改动（`dev/097`）

`reference_loot_template`（`entry=10000, item=34837`）的 `ChanceOrQuestChance`：
**0.1 → 0.5**（提高 5 倍）。

- 只动这一行 —— 组内另 25 件、5 个任务、袋子本身都不碰。
- 0.5 仍低于"收藏档"的 1%，保住"至尊"的定位（站长的档位选择）。
- 附带代价：groupid=2 是"最多出一件"的竞争组，它提概率会让同组其他件理论上各少一点
  （合计约 0.4 个百分点），量级可忽略。
- ⚠️ 该列是 **float**：0.5 可被二进制精确表示（不像 0.1 会存成 0.10000000149），
  本次无浮点误差；**但以后用小数阈值比较这一列务必加容差**（见本章第 6 节/前面的教训）。
- 生效：掉落模板在 mangosd 启动时载入 → **需重启**（随夜间重启）。

### 5. 想再提产的话，三个旋钮（本次只用第 1 个）

| 旋钮 | 位置 | 影响面 |
|---|---|---|
| ① 组内几率（本次用） | `reference_loot_template(10000, 34837).ChanceOrQuestChance` | 只影响这一件 |
| ② 一次日常给几个袋子 | `quest_template.RewItemCount1`（5 个任务，现值 1） | 袋内**所有** 26 件一起变多 |
| ③ 给袋子加掉落来源 | 加进 `fishing_loot_template` | 可反复钓、摆脱日常限制；但 25 件杂物一起灌市场，**且会激活 AHBot 的开袋路径**（那时就要处理它的定价/套利） |

⚠️ 走 ③ 之前务必先读本章第 6 节：袋子一旦"能从掉落表掉出"，就同时满足了 AHBot 开袋池的门槛，
至尊二戒会被按静态价（BuyPrice 4.52 金 × 50% = **2.26 金**）挂上拍卖行，
而它拆解期望是 **17.18 金** → 7.6 倍套利。真要开 ③ 就得配 `category=2` 钉价。

## [掉落] 能量枯竭套装（能量枯竭的徽章 32672）掉率核查 + 小怪比率提升 —— 2026-09-19

### 1. 物品定位与用途（先搞清楚它是什么）

| 项 | 值 |
|---|---|
| 中文名 | 能量枯竭的徽章 |
| entry | **32672**（Depleted Badge，class 15 Junk / Quality 3 / ilvl 115 / SellPrice 0） |
| 同系列 | 32670~32679 共 10 件：双手斧 / 钉锤 / 徽章 / 匕首 / 剑 / 锁甲手套 / 布质护腕 / 披风 / 戒指 / 法杖 |
| 唯一用途 | 用它施放 **埃匹希斯水晶灌注**（spell 40744，需 **50 个埃匹希斯碎片 32569**）→ 得到 **32658 坚守徽章**（BoE、ilvl 115、拆解 ID 52 → 大块棱光碎片 99.5% / 虚空水晶 0.5%） |

→ 所以它是「刀锋山奥格瑞拉/巴什伊尔圈」的一条**大块棱光碎片产线**（碎片堆叠上限 250，掉落见下），
  与 `081` 的「超稀有掉落」无关，也和 AHBot 材料价有联动（一充能 = 一枚大块棱光碎片）。

### 2. 掉落来源（本地库 / 云端库 / 上级参考库 FullDB 三方完全一致）

| 来源 | 外层引用几率 | 实际出「徽章」 |
|---|---|---|
| 参考组 **41301**（Blade's Edge Mountains - Depleted Items，组内 10 件等概率取 1）挂在 33 只怪上 | 精英/boss **20%** ×12 只<br>普通小怪 **0.25%** ×21 只 | **2%**<br>**0.025%（1/4000）** |
| 沙图尔 23230（Shartuul's Transporter 事件 boss）组内掉落（10 件等概率，另有 2 枚戒指各 10%） | 组内 | **8%** |
| 埃匹希斯碎片 32569（充能材料，同圈掉落） | 精英 100%×2~3、小怪 35% | — |

- 33 只怪中，**只有 4 只精英有静态刷点**：Rivendark / Furywing / Insidion / Obsidia（各 1 只，刀锋山面龙）；
  Braxxus、Mo'arg Incinerator、Zarcsin、Bash'ir's Harbinger、Bash'ir、The Grand Collector、Apexis Guardian、Galvanoth、沙图尔
  **creature 表 0 刷点**（靠事件召唤）→ **玩家实际唯一可刷的就是那 21 只小怪**。
- 其中 `22182 闪电黄蜂`、`23386 甘尔葛分析者` 连刷点都是 0，改掉率对它们无意义。

### 3. 为什么 `081_超稀有掉落提升.sql` 没覆盖到（站长问的「之前改过掉率没覆盖这个吗」）

**没覆盖，被阈值挡掉了**：081 的 A 组条件是「41301 等紫装组里 `ChanceOrQuestChance <= 0.1%` 的行」，
而本组实际值是 **0.25%（小怪）/ 20%（精英）**，全部高于阈值 → 云端实测 `rows_le_0p1 = 0`，**一行都没命中**（空跑）。

**更关键的一条机制（以前一直踩坑）**：
组内那 10 选 1 是 `LootGroup::Roll()` 的等概率抽取，该函数**根本没有 rate 参数**，
所以 `Rate.Drop.Item.Rare = 5` / `Epic = 3` 这类配置**对这系列物品从未生效过**；
唯一能被倍率影响的是外层引用行，而外层吃的是 `Rate.Drop.Item.Referenced`（=1，081 特意保持 1）。
即：想让这系列变多变少，**只能改数据表的 `ChanceOrQuestChance`**。

### 4. 本次改动：`dev/087_掉落比例提升_能量枯竭+暗月卡牌+全紫装.sql` 的 A 段

- 倍率口径按站长要求「与之前改动同比例」：081 A 组最后一级 `(0.01%, 0.1%] → 0.5%` 即 **×5**；
  本组 0.25% 沿用 ×5 → **1.25%**。
- 只动 `mincountOrRef = -41301` 且恰为 `0.25` 的 **21 行小怪**；精英 20% 那 12 行、沙图尔 23230 组内**不动**。
- 效果：整套 0.25% → **1.25%**；单件（含徽章）0.025% → **0.125%（1/4000 → 1/800）**。
- 幂等：结果 1.25 > 0.25，重跑 `WHERE` 匹配 0 行（本地连跑两次已验证：21 行 @1.25、0 行残留 @0.25、12 行 @20 不变）。
- 本地已应用并重启验证（mangosd 18:45 起来，掉落表加载无新增报错）；
  云端已放入 `/root/Nmangos-tbc/dev/`，随夜间 `apply_dev_sql.sh` 与 083~086 一起应用 + 重启后生效。
- 若日后觉得还不够「看得见」，下一档是 ×25（→ 6.25%，单件 0.625%）；反之回调只需把 1.25 改回 0.25。

---

## [掉落] 覆盖判据改为「AHBot 供得上吗」：暗月卡牌 088 + 全紫装组 089 —— 2026-09-19

### 1. 判据（站长定案）

不要只看掉率高低，要看 **AHBot 供不供得上**：AHBot 有货的（蓝绿装备、背包、材料）不用动掉落；
AHBot 结构性上不了架的，才用掉落补。实测（云端角色库 bot 挂牌）：

| 品质 | bot 挂牌条数 | 覆盖种数 |
|---|---|---|
| q1 普通 | 44,744 | 498 |
| q2 优秀 | 80,847 | 3,468 |
| q3 稀有 | 10,099 | 393 |
| **q4 史诗** | 1,818 | **只有 2 种物品** |

→ 蓝绿稀有装备 AHBot 供得上；**紫装基本供不上**；卡牌是**配置硬过滤**（见下）。

### 2. 卡牌上不了架的真实原因（与掉率无关，站长要求不动 ahbot 规则，仅记录）

`AuctionHouseBot.cpp:441` `if (GetItemValue(prototype) == 0) continue;`，
而 `ahbot.conf` 里 `Value.Rare` 的第 13 个数（class 12 = 任务物品）为 **0**
（class 12 仅 Normal 品质开了 = 100）→ 卡牌（class 12、品质 3）永远进不了货架。
同一张表里 class 15（杂物）品质 3 也是 0 → 能量枯竭系列同理。
即使把该值打开，bot 货源是「模拟打怪掉落」（`AddLootToItemMap` 对 creature loot 跑 `Process`），
1/12,000 级的命中在每周期几百次掷骰里基本不会出现，所以仍然只能靠掉落补。

### 3. `dev/087_...` 的 B 段：暗月卡牌

- 范围：参考组 49001/49002/49003/49004（祝福/风暴/报复/愚人/野兽/督军/元素/入口 的 2~8），
  外层 0.05 → 0.25、0.1 → 0.5（×5，与 087 同口径）；30 行 + 1,869 行。
- 效果：单张卡 0.00625~0.0083% → **0.031~0.042%（约 1/2,400~1/3,200）**。
- 太乙（Ace）不在其中：TBC 四张大乙在组 49000（挂在 1~2% 的精英/boss 上），经典四大乙是直接掉落（2~15%）。

### 4. `dev/087_...` 的 C 段：全紫装组

- 范围：**所有「全紫装」参考组**（组内物品品质全为 4）中外层几率 ≤1% 的行 —— 实测 53 组 / 2,386 行
  （603xx 系列 47 组 2,304 行，含站长点名的 **60346**；36xxx 系列 6 组 82 行）。
- ×5：0.1→0.5、0.15→0.75、0.25→1.25、0.8→4、1→5（60346 从 0.45/0.8 变 2.25/4）。
- 明确**不动**：30012（经典蓝装）、600xx–602xx / 61xxx 世界掉落蓝绿（AHBot 有货）、
  6044x 背包（bot 每种有 28~161 条）、506xx 卷轴（商店货）。

### 5. ⚠️ 两条写掉落 SQL 必须避开的坑

1. **FLOAT 比较**：`ChanceOrQuestChance` 是 FLOAT，0.1 存进去是 `0.100000001490116`，
   与字面量 0.1（DOUBLE）比较判为「大于」→ `= 0.1` / `<= 0.1` 会**静默漏行**。
   081 的 A 组就吃了这个亏（60345 的 22 行 0.1 一行没抬）。**改用** `ROUND(x,4)` 或宽区间。
2. **×5 的幂等陷阱**：0.1→0.5、0.15→0.75 之后**仍落在 `<=1` 区间内**，
   若只写 `WHERE chance <= 1` 且倍率是 ×5，第二次执行会**再乘一次**
   （本地实测：0.1 连跑两次变成 2.5）。089 用 `AND ROUND(x,4) NOT IN (0.5,0.75)` 兜住，
   两跑结果一致；代价是原本恰为 0.5% 的 1 行不再被抬。

### 6. 状态

**已合并为一份 SQL**：`dev/087_掉落比例提升_能量枯竭+暗月卡牌+全紫装.sql`（A 能量枯竭 / B 暗月卡牌 / C 全紫装组；
原 087/088/089 三份文件已删除，避免同一件事散在多份文件里）。
本地做了一次**从原始状态跑整份文件**的验证：先把三方改动还原成原值（21@0.25 / 30@0.05 / 1,869@0.1），
再跑合并文件 → A 21@1.25 且 12 行 20% 不动、B 30@0.25 + 1,869@0.5、C 无残留 + 1,983@1.25 + 60346 40 行全部符合预期；
连跑第二次结果完全一致（幂等）。
云端 `/root/Nmangos-tbc/dev/` 已只留这一份，干跑队列 `083 → 087`，随夜间一起应用 + 重启生效。

---

## [核心] 生物重力 flag：飞行怪被客户端重力拉回地面

### 现象

- 有些飞行怪（大风鹏、雀鹰、狮鹫骑士、龙骑士等）在客户端里 **从空中掉到地面**：
  服务器坐标没变、只是表现不对，静止悬空的怪尤其明显（2026-09-18 站长报告）。

### 成因

- 客户端对一个 unit 的重力只看 create 块里的 `MOVEFLAG_LEVITATING (0x400)`：
  没有它，客户端就按重力把模型往下拉，一直拉到地形上，直到服务器发下一个移动包。
- 本端只在 `Creature::Create` 里按 **模板** `InhabitType & INHABIT_AIR` 设这个 flag，
  而 DB 里大量飞行怪的 InhabitType 是 地面(1)/地面+水(3)：

  | entry | 名字 | InhabitType | 刷点高于地面 |
  |---|---|---|---|
  | 20237 | 荣耀堡狮鹫骑士 | 3 | +489 |
  | 21719 | 龙喉龙骑士 | 1 | +31 |
  | 25236 | 脱缰的龙鹰 | 1 | +42 |
  | 17129 | 大风鹏 | 1 | +5.6 |
  | 22979 | 野生雀鹰 | 3 | +17.7 |

- 还有一类更隐蔽：**刷点在地面、靠运动路径飞到天上**的巡逻怪 —— 20502 日蚀龙鹰（35 个刷点全部贴地，
  最大 +0.4）、21721 被奴役的虚空之翼雏龙、15649 野性龙鹰雏鸟、4012/4107 翼龙。
  模板和刷点都看不出它会飞，**只有运动路径能看出来**。
- 因此只改"加载时"不够，必须同时按"运动情况"判断 —— 这正是 `Creature.cpp:456` 那行老 TODO
  （"movement flags should be computed automatically at each movement"）说的事。

### 改动（提交 `e550a28da`）

- `Creature::IsAirbornePosition(x, y, z)`：先用高度图（`GetHeightStatic(..., false)`）廉价预筛，
  可疑点再用 vmap 确认真实地板（含 WMO）；**水面也算地板** → 船甲板、游泳者不会被误判成空中。
- `Creature::Create()` 末尾：刷点悬空（且模板/脚本没给 flag）→ `SetLevitate(true)`，让 create 块带上 flag。
- `MoveSplineInit::Launch()`：新增 `[FLY-FLAG]`，与已有 `[SWIM-FLAG]` 对称 —— 路径终点在空中就补 flag
  （spline 同时按飞行插值、播飞行动画），终点回到地面就撤销；**只撤销核心自己设的**
  （`Creature::IsAirborneFlagAutomatic()`），脚本/模板设的（夜之魇、卡雷苟斯等）不碰。
- 阈值 **4yd**：取 2yd 时，16945 Mo'arg Engineer(+2.7)、17131 Talbuk Thorngrazer(+3.6) 这两个
  **贴地刷点**（本来靠客户端重力落到地面道具上）也被标成空中 → 会浮空，故抬高阈值。

### 验证

- 本地重启后日志（临时 `[GRAVFLAG]`，验完已降级为 `DEBUG_LOG`）命中 6 个悬空刷点：
  18842 Garadar Credit Marker +4.1、17129 大风鹏 +5.6、17131 Talbuk Thorngrazer +3.6（阈值 4 后不再命中）、
  16945 Mo'arg Engineer +2.7（同前）、19212 Fel Cannon: Hate Target +4.9、22979 野生雀鹰 +17.7。
- 站长本地实测：飞行怪正常悬停，地面怪走路姿势正常。

### 状态

提交 `e550a28da`，已 push + 同步云端 `/root/Nmangos-tbc`，随夜间编译生效。

---

## [核心] Unit::GetSpellRank 少乘 5：生物按等级缩放的法术弱了 5 倍

### 现象

- 刀锋山 **雷神饿狼(5781) 胁迫低吼**：描述 -32 敏捷，实际只降约 6 —— "降低的属性和描述不符"（2026-09-18）。

### 排查

- `spell_template` 5781：Effect 6(APPLY_AURA) + Aura 29(MOD_STAT)，带 **per-level 缩放**
  （`EffectRealPointsPerLevel` / `baseDice`）。
- `WorldObject::CalculateSpellEffectValue()` 里 `level = GetSpellRank(spell) / 5`，再
  `basePoints += level * EffectRealPointsPerLevel`；`Spell::CheckPower` 的 manaCostPerlevel 同样除以 5。
- `Player::GetSpellRank()` 返回 `GetSkillValue()`（= 等级 * 5），封顶写成 `maxLevel * 5`；
  **只有 `Unit::GetSpellRank()` 返回裸 `GetLevel()`** → 生物的 per-level 缩放只有 1/5。
  （上游 `ac1267cc2` 给调用方加了 `/5`，却没同步改 `Unit::GetSpellRank`；
  `2aae6842a` 那条线动的是 CLS 伤害缩放，不是这里。）

### 改动

- `Unit::GetSpellRank()`：`GetLevel()` → `GetLevel() * 5`（封顶 `maxLevel * 5` 不变）。
- 影响面：全库 1,693 个带 per-level 缩放的 spell（648 个伤害类、1,045 个光环类）；玩家侧不受影响。

### 验证

- 本地实测 5781 数值与描述一致（STR -22 / AGI -32），玩家技能数值不变。

### 状态

提交 `b1577d224`（站长本人提交），已 push + 同步云端，随夜间编译生效。

---

## [技术] CLS 曲线对比：本端 / cmangos WotLK / TrinityCore / AzerothCore

> 2026-09-18 站长提问"这个 cls 曲线在别的端是怎么样的"的完整答案（含数值），
> 以后不用再重新查。数据来源：本端 `tbcmangos`、本地 cmangos WotLK 库 `wotlkmangos`、
> `trinitycore_ref\sql\old\3.3.5a\TDB52_to_TDB53_updates\world\2013_12_2*_world_creature_classlevelstats.sql`、
> AzerothCore master 源码（`CreatureData.h` / `Creature.cpp` / `ObjectMgr.cpp`，2026-09-18 拉取）。

### 1. 表结构 / 取值方式

| 核心 | 表 | 每个 (level,class) 的伤害从哪来 |
|---|---|---|
| **本端** cmangos TBC | `creature_template_classlevelstats`；固定列 Class/Level/BaseMana/AP/RAP/BaseArmor/五维 + **每组扩张三列 `(BaseHealthExp{i}, BaseDamageExp{i}, BaseDamageExp{i}OLD)`**，`MAX_EXPANSION = 1` → 只有经典(0)/TBC(1) | 直接查表：按 `creature_template.Expansion` 选组，取 `BaseDamage` |
| cmangos WotLK | 同名同布局，多一组 Exp2（`MAX_EXPANSION = 2`） | 同上 |
| TC 3.3.5a / AC 3.3.5a | `creature_classlevelstats(level, class, basehp0/1/2, basemana, basearmor, attackpower, rangedattackpower, damage_base, damage_exp1, damage_exp2, Str/Agi/Sta/Int/Spi)`；后 5 列是 **2013-12-28 TDB52→53 才 ALTER 加的**（3.2.2a 时代只有 `exp, class, level, basehp, basemana`） | `CreatureBaseStats::BaseDamage[MAX_EXPANSIONS]`，`GenerateBaseDamage(info) = BaseDamage[info->expansion]`；然后 `weaponBaseMinDamage = basedamage; weaponBaseMaxDamage = basedamage * 1.5`（AC `Creature.cpp:1555-1570`） |
| TC master（11.x） | `creature_classlevelstats` 只剩 `level, class, basemana, attackpower, rangedattackpower, comment` —— **没有生命/伤害曲线** | `sDB2Manager.EvaluateExpectedStat(CreatureHealth / CreatureAutoAttackDps / CreatureArmor, level, expansion, contentTuning, class)` × `HealthModifier/DamageModifier`（宠物再 × `GetHealthMod(classification)`）；曲线交给客户端 DB2 |

### 2. 关键结论：TC/AC 的三列 = 本端的 `...OLD` 列（同一份暴雪数据）

逐值对得上（class 1 战士 / class 8 法师，举例）：

| 数据点 | 本端 | TC/AC |
|---|---|---|
| class 1 lvl 55 `damage_base` | BaseDamageExp0OLD = **30.7177** | **30.7177** |
| class 1 lvl 60 `damage_base` | BaseDamageExp0OLD = 33.9625 | 33.6577 |
| class 1 lvl 70 `damage_exp1` | BaseDamageExp1OLD = 104.527 | 104.3456 |
| class 1 lvl 80 `damage_exp2` | (WotLK) Exp2OLD = **164.924** | **164.9240** |
| class 8 lvl 70 `damage_exp1` / `exp2` | 88.3402 / (WotLK) 114.496 | 87.7526 / 114.4956 |

而本端**实际生效**的是另一列（非 OLD）：`Creature::SelectLevel` 里 `cinfo->DamageMultiplier >= 0` 就走
`BaseDamage`，`BaseDamageOLD` 只在 `Object.cpp:3198`（法术按 CLS 缩放那条比较）里被读，基本是死数据。

### 3. 数值差（本端激活列 ÷ TC/AC 同列）

| class | lvl 60 | lvl 65 | lvl 70 | (WotLK lvl 80) |
|---|---|---|---|---|
| 1 战士 | 66.84 / 56.49 = **1.18×** | 132.17 / 80.42 = **1.64×** | 261.32 / 104.35 = **2.50×** | 412.31 / 164.92 = **2.50×** |
| 2 圣骑 | 1.18× | 1.64× | 261.32 / 96.74 = **2.70×** | 2.50× |
| 4 盗贼 | 1.18× | 1.64× | 104.53 / 104.35 = **1.00×** | 1.00× |
| 8 法师 | 1.21× | 1.80× | 241.72 / 87.75 = **2.75×** | 2.51× |

即：**TBC 段 61-70 级的曲线是条指数曲线**（战士 60→70：66.84 → 76.61 → 87.80 → … → 261.32，约 ×1.146/级），
而 OLD/TC/AC 那条是近似线性（53.48 → 104.53）。盗贼（class 4）两列完全相同，所以盗贼怪不受影响。

### 4. 换算成每击伤害（示例）

以 `23344 Corlok the Vet`（70 级 · class 1 · 普通 · DamageMultiplier 0.969 · DamageVariance 0.4 ·
攻速 2.0s · CLS AP 304；不含护甲/减伤）：

| | 计算 | 每击（min..max） |
|---|---|---|
| 本端（现生效） | `261.316 × (1∓0.2) × 0.969` + `AP/14×2.0` | **≈ 245..346**（均值 ≈295） |
| AC / TC 3.3.5a 同参数 | `104.3456 × (1.0 … 1.5) × 0.969` + 同上 AP 项 | **≈ 143..194**（均值 ≈169） |

→ 同参数下**本端约为 AC/TC 的 1.75 倍**（战士类）。若想要与 AC/TC 对齐，改法很简单：把生效列换成 OLD 列
（`Creature.cpp:1447/1449` 的 `cCLS->BaseDamage` → `cCLS->BaseDamageOLD`），一行级别；但注意那是 cmangos
"老模型"的数值，是否更接近 TBC 零售体感需要站长定夺（本端的非 OLD 列更像是按嗅探到的每击伤害直接落库）。

### 5. 附带发现

- `Creature::SelectLevel` 里 `modifiedMainMinDmg / modifiedMainMaxDmg` 两个局部变量算了但没用（`DamageMultiplier`
  实际是在 `StatSystem.cpp:900-901` 乘到武器伤害上的），属历史残留，不是 bug。
- AC 的 `creature_template.DamageModifier` 在 `ObjectMgr.cpp:1216` 已乘上 `_GetDamageMod(rank)`；
  本端对应 `DamageMultiplier × _GetDamageMod(rank)`（`Creature.cpp:1419`）→ 两边都有这一层，不影响上面的比值比较。
- AC 也有和本次「生物重力 flag」同类的机制（`ac_Creature.cpp:60-63`：wandering 生物按位移距离刷新
  swim/fly/hover 移动 flag，`Map::CreatureRelocation()` 里立即刷新）。

---

## [运维] 云端 CPU 打满：一条遗留的临时表分析查询跑了 1h54m — 2026-09-19 已处置

> ### 铁律（站长 P0）
> **不能在云端数据库做逻辑查询，只能在本地做。**
> 云端库只跑「静态、幂等、秒级」的写操作（改数据用**写死值**，不做计算/判断）；
> 分析型查询（关联子查询、临时表、聚合统计、按条件推导）**一律在本地库（3306）跑**。

### 现象

- 站长反馈"云端 CPU 还是很高"（当时在线玩家 3 人）。`uptime` load **6.0~7.0**，而机器**只有 2 vCPU**；
  `vmstat` 显示 `us 65% / id 28%`。

### 定位

- ⚠️ **判断"谁在吃 CPU"不能用 `ps -eo pcpu`**：那是**进程生存期均值**——当时它显示 mangosd 21%、mysqld 12%，
  完全看不出问题（mysqld 已跑 18.5 小时，瞬时 88% 被平均成 12%）。
  正确姿势：`top -b -n 2 -d 1` 取**第 2 个采样**看瞬时值 + `SHOW FULL PROCESSLIST` 看正在跑的语句。
- 瞬时采样：**mysqld 88.1%**（2 vCPU 里的整整一个核）+ mangosd 35.6%。
- PROCESSLIST 一眼看到真凶：连接 1818，`Time=6858`（**1 小时 54 分**）、`State=executing`：
  `CREATE TEMPORARY TABLE cls AS SELECT x.entry, x.ItemLevel, x.class,
   (SELECT COUNT(DISTINCT c.id) FROM creature c WHERE c.id IN (… creature_loot_template … UNION … reference_loot_template …))
   FROM it141 x`
  —— 当天为 CLS / 掉落覆盖分析在云端跑、跑完没人管的那条**相关子查询**（每一行都去扫 ~20 万行掉落表）。
- `performance_schema.events_statements_summary_by_digest` 在本实例是空的（未启用）→ "按总耗时排序找慢 SQL"
  这条路在云端走不通，**PROCESSLIST 是唯一可靠入口**。

### 处置

- `KILL 1818`（该语句只写临时表，**没有任何永久数据改动**）→ 即时采样 mysqld **88.1% → 4.0%**、
  CPU idle **31% → 74%**。
- load average 是 1/5/15 分钟均值，会滞后十几分钟（7.0 → 4.15 是 2 分钟后的值），**别被它误导**。
- ⚠️ PROCESSLIST 里 Sleep 状态的 `tbcmangos / tbccharacters / tbcrealmd / tbclogs` 连接是 mangosd
  与平台自己的连接池，**不要 KILL**（会白掉线一次）。

### 教训

1. **分析型/逻辑查询只能在本地库跑**，绝不留在云端；云端只跑静态幂等 SQL（对应既定规则：云端 SQL 用静态 update
   而不是逻辑判断）。本次一条查询就把 2 vCPU 的一整个核占满近两小时，全程影响在线玩家。
2. 云端排查 CPU 的固定套路：`uptime` → `top -b -n 2 -d 1`（第二个采样）→ `SHOW FULL PROCESSLIST`
   （找 `Time` 大且 `Command=Query` 的行）。**不要用 `ps` 的 `%CPU` 下结论。**

### 残留风险

- 机器 **2 vCPU / 1.87 GB RAM**：mangosd RES 1.1 GB（61%）、swap 已用 ~250 MB，资源本就紧张
  （另见 `[内存]` 章，以及 P0 的"严禁在运行时段在 2GB 机器上编译"）。

## [稳定性][安全] realmd 登录包堆溢出：认证前可远程触发的崩溃 — 2026-09-19

> **这是长期"realmd 隔两三天自己崩一次"的根因**，也是本端第一个被确认的**远程可利用**内存安全问题。

### 现象

- `/opt/mangos/bin/realmd` 约每 2~3 天自发崩溃一次（5 周内被 watchdog 拉起约 14 次）。
- 09-19 当天更明显：12:38 SIGABRT、13:34 SIGSEGV，间隔不到 1 小时。
- 此前一直是"没有现场"：core 存不下来（cron/watchdog 下 `RLIMIT_CORE=0`），日志也定位不到。

### 定位（靠 core，不靠猜）

把 `ulimit -c unlimited` 补到 realmd 启动路径后，09-19 两次崩溃的 core 首次被完整保存，
`coredumpctl info` 拿到**带符号的回溯**：

| 时间 | 信号 | 关键帧 |
|---|---|---|
| 12:38 | SIGABRT | `AuthSocket::_HandleLogonChallenge` 的 lambda → `std::make_shared<ByteBuffer>` → `malloc_consolidate` → `malloc_printerr` = **glibc 当场检出堆损坏** |
| 13:34 | SIGSEGV | `AsyncListener<AuthSocket>::startAccept` → `SRP6::SRP6` → `BN_new` → **段错误发生在 malloc 内部**（空闲链表被写坏） |

两次都在认证路径、都是"堆被写坏"，且第二例是**上一次连接写坏堆、下一次连接 malloc 时踩雷** ——
这正是"崩溃时间看起来随机"的原因。

### 成因

`src/realmd/AuthSocket.cpp` 的 `_HandleLogonChallenge()`：

```cpp
uint16 remaining = header->size;              // 客户端给的 uint16，最大 65535
if ((remaining < sizeof(sAuthLogonChallengeBody) - AUTH_LOGON_MAX_NAME)) return;   // 只有下界！
std::shared_ptr<sAuthLogonChallengeBody> body = std::make_shared<sAuthLogonChallengeBody>();  // 47 字节
self->Read((char*)body.get(), remaining, ...);  // 把 remaining 字节读进 47 字节的堆对象
```

**缺上界检查** → 客户端只要把登录包里的 `size` 写成 > 47，就能让 realmd 往 47 字节的堆对象里
写入最多 65535 字节。`_HandleReconnectChallenge()` 是**同一个 bug**（下界 37，同样无上界）。

- 合法客户端最大只发 `30 + userName_len(≤16) = 46` 字节，所以**正常玩家永远不会触发**，只有畸形/扫描/构造包会。
- 3724 是公网端口（本机日志里本来就有端口扫描与 SSH 暴力破解记录），触发来源现实存在。
- ⚠️ 危害不止"崩溃"：这是**认证前、写入长度可控的堆溢出**，具备被利用做远程代码执行的条件。

### 改动

`src/realmd/AuthSocket.cpp` 两个 handler 各加上界检查 + ERROR 级日志 + 主动断连：

```cpp
if (remaining > sizeof(sAuthLogonChallengeBody))
{
    sLog.outError("[AuthChallenge] Rejecting oversized body (%u bytes) from %s",
                  uint32(remaining), self->GetRemoteAddress().c_str());
    self->Close();
    return;
}
```

### 验证（本地实测，非推断）

⚠️ **前置坑**：本地 `x64_Debug\realmd.exe` 是**陈旧二进制**（8-21，2.79 MB；当前源码编出来只有 686 KB），
因为 `build_deploy_restart.bat` 只编 mangosd、**从不重编 realmd**。第一轮 PoC 打旧二进制打不崩，
差点误判成"漏洞不存在"。**结论：任何 realmd 改动都必须先 `cmake --build build1 --target realmd` 再测。**

- 复现（修复前，用当前源码新编的 realmd）：发一个 `size=2000` 的登录挑战包 → **realmd 当场死亡**；
  对照 `size=46`（合法最大）正常应答。
- 修复后回归 `_agent_tmp\verify_realmd_fix.py`：**8/8 通过** —— 46/47 正常应答；48/2000/65535 以及
  reconnect 包的 2000/65535 一律被丢弃、realmd 存活；攻击之后再发合法包仍能正常应答。

### 顺带审计（这两处是安全的，不要误改）

- `_HandleLogonProof` 的 PIN 分支：`*pinCount > 16` 有检查，`vector` 按 `*pinCount + 1` 分配 → 安全。
- `_HandleLogonProof` 的包长由服务端 `getSize()` 决定，客户端不可控 → 安全。

### 教训

1. **凡是"客户端声明的长度"都必须同时校验上界**。本端 `Read(buf, len)` 是裸
   `boost::asio::async_read`，不会校验缓冲区大小 —— 只要 `len` 来自网络就必须自己卡住。
2. **core 是这类问题唯一的可靠证据**，`ulimit -c unlimited` 必须覆盖**所有**启动路径。
   realmd 的三条路径（watchdog / realmd_restart_verify / golive）早就有，**只有 nightly 漏了** ——
   09-19 17:45 mangosd 的 SIGABRT 因此没留下 core，`Server.log` 又被新进程截断，现场全丢。
3. **部署脚本必须同时安装 realmd**：`nightly_build_restart.sh` 自始至终只 `cp` mangosd，
   `/opt/mangos/bin/realmd` 一直停在 8-13 的旧二进制 → **realmd 的任何修复都上不了线**。已补 3.3 节。
4. 崩溃"看起来随机"时，优先怀疑**堆被上一次请求写坏、下一次分配才踩雷**，而不是当次请求。

### 状态

- 2026-09-19：本地修复 + 回归通过；云端脚本已补 realmd 安装步骤与 core 开关；待 nightly 编译上线。

## [经济] 放宽价格天花板 + 取消静态价地板（`ahbot.conf` + 代码）—— 2026-09-20

### 1. 站长判断

`ahbot_market_state` 的价格上下限都建立在 **`staticPrice = BuyPrice × Value.<品质>[class]%`** 上，
而那几个 `Value.*` 百分比是**人为随意设的**，不能代表"正常区间"。所以
**`PriceCeil = 300`（300% × 静态价）太低、挡住了正常上涨，应当取消。**

### 2. ⚠️ 陷阱：`PriceCeil = 0` 不是"取消"，方向正好相反

```cpp
uint32 ceil = staticPrice * std::max<uint32>(100, m_mmPriceCeil) / 100;
//                          ^^^^^^^^^^^^^^^^^^^^^ 语义是"天花板最低也得是静态价的 100%"
```

所以填 `0` 会让天花板从 300% **压到 100%（比默认还紧 3 倍）** —— 一个会**静默办错事**的坑。
以后想"取消"某个百分比类开关，先看它是 `max(100, x)` 还是 `min(100, x)`。

### 3. 改动

**代码**（`AuctionHouseBot.cpp`，两处：启动钳制 / 运行钳制）—— 让 `0` 真表示"无上限"：

```cpp
uint32 hi   = (staticPrice && m_mmPriceCeil)
                  ? (uint32)((uint64)staticPrice * std::max<uint32>(100, m_mmPriceCeil) / 100) : 0;
uint32 ceil = (staticPrice && m_mmPriceCeil)
                  ? (uint32)((uint64)staticPrice * std::max<uint32>(100, m_mmPriceCeil) / 100) : 0;
```

下游本来就是 `if (hi && …)` / `if (ceil && …)` → **0 天然等于"不钳制"**，所以只要让配置为 0 时算出 0 即可。

**配置**（`/opt/mangos/etc/ahbot.conf`，备份 `/root/ahbot.conf.bak_20260920_ceilfloor`）：

| 项 | 原 | 现 | 说明 |
|---|---|---|---|
| `MarketMaker.PriceCeil` | 300 | **10000** | 站长选"B + 宽兜底"：100 × 静态价，实际等于取消，但留一道"明显离谱"的闸 |
| `MarketMaker.PriceFloor` | 5 | **0** | 取消"5% × 静态价"那段地板 |

**地板不需要改代码**：它用的是 `std::min<uint32>(100, m_mmPriceFloor)`，**填 0 会真的算出 0**，
之后由下面这条硬道理接管（保留）：

```cpp
if (proto->SellPrice > floor) floor = proto->SellPrice;   // 防"拍卖行买了卖给商人"稳赚
```

### 4. ⚠️ 两个必须知道的后遗症

**① 天花板放宽后，"只涨不跌"的棘轮失去兜底。**
降价必须有真实卖压（代码注释原话："卖不动不是降价的理由"），所以会出现：
一波单向买入把价推高 → 之后既没人买也没人卖 → 流水归零 → **价格可能永久卡在高位**。
另有一条"慢速拉高再回卖给 bot"的路径（先把报价养高、再卖回），
封顶它的是 `BuyPerCycle = 2`（每周期每件只收 2 单位）与 `MaxGoldPerDay = 5000 金` 熔断。

**② 取消静态地板后，29 件附魔材料【完全没有下限】。**
125 个 book 材料里 **96 件有卖店价**（源生系列 4 金、魔莲花 1 金…）→ 仍受卖店价保护；
但 **29 件 `SellPrice = 0`**，而且正好是最重要的那批：
虚空水晶 22450、强效位面精华 22446、强效不灭精华 16203、大块棱光碎片 22449、
强效虚空精华 11175、次级位面精华 22447、连结水晶 20725、奥法之尘 22445 …
→ 它们**没有任何下限**，理论上可一路衰减（单步 −5%、每天最多 −10%，所以衰减是慢的）。
这正是 `dev/084` 当年设地板的理由（"取消地板会让强效星界精华/大块微光碎片/灵魂之尘 掉到 0.01~0 金，属畸形值"）。
**要保险就把 `PriceFloor` 设回 `1`（1% 静态价）—— 纯配置，不用编译。**

### 5. 生效

- **配置**：mangosd 启动时读取 → 随重启生效
- **代码**：需编译 → 已同步云端源码树（md5 `2d9fa6b4…`，与本地逐字节一致），
  **随 09-21 04:06 nightly** 编译上线（判据实测：1 条编译命令，含 `AuctionHouseBot.cpp`）

## [经济] 结算周期放宽到每天 + 数量门槛提高 + 加结算日志 —— 2026-09-20

### 1. 站长的判断链

1. 静态价是人为随意设的，不该当"正常区间"上界 → **已放宽天花板**（见上一节）
2. 放宽天花板后，"只涨不跌"的棘轮失去兜底 → 需要补偿控制
3. 补偿办法：**过滤掉小额成交量**（提高数量门槛）+ **放宽结算周期到每天**（少动、动得有意义）
4. 买卖限额已有：买入侧有 `BuyPerCycle = 2`（每周期每件）+ `MaxGoldPerCycle` / `MaxGoldPerDay` 熔断；
   卖出侧由挂单量（`MaxItemUnits = 200` / `QuoteExposurePct` / 阶梯）自然约束

### 2. 改动

**配置**（`/opt/mangos/etc/ahbot.conf`，备份 `ahbot.conf.bak_20260920_settle`）：

| 项 | 原 | **现** | 上游默认 |
|---|---|---|---|
| `MarketMaker.FlowSettleHours` | 6 | **24** | 24 |
| `MarketMaker.FlowMinUnits` | 8 | **20** | 20 |

（`FlowRatio = 120`、`FlowMoveUpPct = 3`、`FlowMoveDownPct = 5` 未动；上游默认分别是 150 / 1 / 5。）

> 也就是说：**这两项回到了上游默认值**。当初被调成 6h/8 是为了在小服务器上"能触发"，
> 现在为了稳定性又调回去 —— 但因为我们同时加了日志，这次是**有数据可依据的**，不再是拍脑袋。

**代码**（`AuctionHouseBot.cpp`，+17 行，仅结算块）：**加结算日志**，每次结算且有流水时写一行：

```
[AHBOT] SETTLE item=%u house=%u bought=%u sold=%u total=%u gate=%u old=%u new=%u result=%s
```
`result` 取值：`up` / `down` / `balanced`（量够但不够单边） / `under-gate`（量不够）。
用 `sLog.outError`（ERROR 级必然输出，与既有 `[AHBOT]` 日志一致）→ 进 `Server.log`。

### 3. 效果量化

| | 改前（6h / 8） | **改后（24h / 20）** |
|---|---|---|
| 每天结算次数 | **最多 4 次** | **1 次** |
| 单次触发所需流水 | 该 6h 窗口 ≥8 单位 | 该 24h 窗口 ≥20 单位 |
| **每日最大涨幅** | 10%（4×3%，被日闸截断） | **3%** |
| **每日最大跌幅** | 10%（4×5%，被日闸截断） | **5%** |

→ **上涨速度从"最多 10%/天"降到"最多 3%/天"** —— 这正好补上了刚被放宽的天花板。
把价格翻一倍现在需要**持续约 24 天、每天买走 ≥20 单位**，那条"养高再回卖"的路径基本被封死。

### 4. ⚠️ 一个必须知道的行为（日志会暴露它）

结算时**无论量够不够，流水计数器都会被清零**：

```cpp
state.flowBought = 0;  state.flowSold = 0;   // 无条件清零
```

所以**低于门槛的流水是"被丢弃"，不是"累积到下期"**。
含义：某件货如果每天都只有 5 单位流水，它**永远不会调价**（价格冻结）——
这符合"过滤小额成交量"的意图，但要清楚这是**冻结**而不是"慢慢攒够再动"。
`result=under-gate` 的日志行会告诉我们有多少货处在这种状态，之后可以据此决定要不要改成"累积"。

### 5. 生效

- 配置：mangosd 启动时读取 → 随重启生效
- 代码：已同步云端源码树（md5 `6adc26e4…`，与本地逐字节一致）→ **随 09-21 04:06 nightly** 编译上线

## [经济] AHBot 回收侧：`BuyPerCycle = 2` 让所有整组挂单卖不掉（纯配置已修）—— 2026-09-21

### 1. 现象（站长实测）

> 「我在拍卖行的挂单一直没 bot 买入。」

线上实查（`tbccharacters`）：玩家挂单共 **6 条（全是站长的）**，`item_count` = 20 / 10 / 20 / 20 / 20 / 10，
**全部 `> 2`**；单价全部落在 bot 的回收区间内（Silk Cloth 300 vs 291–324、Runecloth 800 vs 768–856、
Netherweave 1300 vs 1303–1454、Ancient Lichen 2688 vs 3024–3374），物品也都确实在做市商 book 里（`category=1`）。
⇒ **不是价格问题**。另外线上 `ahbot_market_state.flow_bought` 全部为 0（没有新的回收流水）。

### 2. 根因：配额数的是「单位」，而买断是「整单成交」

```cpp
if (mmBuyState && m_mmBuyPerCycle)
{
    if (mmBuyState->buyoutsThisCycle + item->GetCount() > m_mmBuyPerCycle)
        continue;                                  // 整单跳过
    mmBuyState->buyoutsThisCycle += item->GetCount();
}
```

- `MarketMaker.BuyPerCycle` 的语义是 **每周期（≈`Value.DynamicRefresh`=60 秒）每件最多吸收多少「单位」**，
  **不是"单数"** —— 以前的口径容易被读成"每周期最多 2 单"，**这是误判点**。
- 因为**买断是整单成交**（拍卖行无法只买一条挂单的一部分），判据会**整单跳过**：
  堆叠数大于该配额的挂单 **永远** 不会被回收 —— 不是"只买 2 个"，而是"一条都不买"。
- 于是 `BuyPerCycle = 2` 在人人挂整组（10/20 个）的服务器上 ⇒ **回收功能整体静默失效**：
  没有任何报错，只在数据上表现为 `flow_bought` 恒为 0（历史 `spent > 0` 的记录都来自 1~2 个的小单）。

### 3. 修法：**纯配置**（不改代码）

`/opt/mangos/etc/ahbot.conf`（备份 `/root/ahbot.conf.bak_20260921_buypercycle`；该文件 LF、无 BOM）：

| 键 | 原 | 现 | 说明 |
|---|---|---|---|
| `MarketMaker.BuyPerCycle` | 2 | **20** | 每周期每件最多吸收 20 单位 ⇒ 20 个/组的满组能成交（成交一次即用满当周期配额，下一条等下一个 60 秒周期）|

> **曾经**想把它拆成"每周期单位配额 + 单笔堆叠上限（新增 `BuyMaxStack`）"两个键并已写好代码；
> **站长定：没必要** —— 这个配置本来就是"最多买多少个（单位）"，把值调到 ≥ 玩家常见堆叠大小即可，
> 拆键等于凭空多一个机制。**该代码改动已整条撤回**（未推送，工作区已还原）。
> 两道金币闸不变：`MaxGoldPerCycle = 100 金/周期`、`MaxGoldPerDay = 5000 金/24h`。

### 4. 生效与验收

- 线上 conf 已改；⛔ **没有为它单独重启**：查的时候线上有 **3 名玩家**，
  站长定规「**有玩家在线时禁止重启服务器**」（已写进 handoff 的 P0）。
- 生效路径：夜间维护窗口（阿里云 04:00 关机 / 04:05 开机 → 04:06 nightly）。**即使不需要编译**，
  nightly 也会走"mangosd 未运行则拉起"这一步把服务起回来 ⇒ **配置随这次启动读取生效**。
- 验收：重启后 `ahbot_market_state.flow_bought` / `spent` 开始增长；站长那 6 条挂单被逐条买走。

### 5. 教训

1. **数量/百分比类配额必须先问"单位是什么"**：`BuyPerCycle` 数的是**单位**，而判据与"整单成交"耦合
   ⇒ 值必须 ≥ 玩家常见堆叠大小，否则是完全静默的失效（"配额 2" ≠ "每周期买 2 单"）。
2. 这类失效**没有任何日志**，只能靠观测量发现（`flow_bought = 0` + 玩家挂单堆积）——
   以后调这类参数，先定一个"可观测的验收指标"。
3. 对称地看：卖侧的挂单是按**满组**打的（`QuoteCatalog` 用 `maxstack` 打包），回收侧却按"单位"限额 ——
   两侧的计量单位不一致，就是这次踩坑的土壤。

## [经济] AHBot 结算机制优化（反养价 + 摊平价格）+ 拍卖行成交日志 —— 2026-09-21

### 1. 动机（站长定案）

- 上一节关掉探针后，剩下的可套利路径是"**养价**"：每天买 ≥20 单位 → 锚价 +3%/天 → 出货时挂 106% 锚价 →
  在 5000 金/天的日闸内稳赚小额。要压掉它 ⇒ **提高门槛与单边要求 + 把价格变动摊平 + 按买家去重**。
- 静态价上下限（`PriceFloor/PriceCeil`）**无意义**：最初的价格是随手设的，不能当"正常区间"；
  改成"**以当前价格为准 + 每小时/每天的变动上限**"来约束。

### 2. 配置（`/opt/mangos/etc/ahbot.conf`，备份 `ahbot.conf.bak_20260921_mech`）

| 键 | 原 | 现 | 含义 |
|---|---|---|---|
| `FlowMinUnits` | 20 | **100** | 单次结算的证据门槛（单位数）|
| `FlowRatio` | 120 | **300** | 单边比要求（3:1）|
| `FlowSettleHours` | 24 | **1** | 结算窗口 = 1 小时 |
| `FlowMoveUpPct` / `FlowMoveDownPct` | 3 / 5 | **1 / 1** | 每次结算最多 1% ⇒ **每小时 ≤1%** |
| `MaxDailyMovePct` | 10 | 10（不变）| **每天 ≤±10%**（`day_price/day_start` 持久化）|
| `PriceFloor` / `PriceCeil` | 0 / 10000 | **0 / 0** | 关闭静态价钳制（0 = 不钳制）|

### 3. 代码（`AuctionHouseBot.cpp/.h`、`AuctionHouseMgr.cpp`、`ahbot.conf.dist.in`）

1. **涨价按买家去重**（反养价核心）：新增 `soldBuyers[8] / soldBuyerCount`，每次"玩家买走我们挂单"记录买家低 guid
   （`AuctionHouseMgr` 的 `DeductInventory(...)` 增加 `buyerGuid` 参数）；结算时**涨价要求 `soldBuyerCount >= 2`**，
   否则 `result=up-blocked-1buyer`（写进结算日志）。**降价不设该限制** —— 单个玩家大量砸货是真实的供给过剩信号，
   且"跌得比涨得快"是该机制有意的保护（宁可低也不要虚高）。
2. **方差对称化**：`ValueWithVariance` 原式 `urand(0, 2V+1) − V` 值域是 `[−V, +V+1]`（上沿多 1%），
   改为 `[−V, +V]`。影响：回收上限由 106% 变回 105%（`V=5`），堵掉"挂上限必被吃"的尾巴。
3. **结算时钟持久化**：`lastSettleTime` 原来只在内存 ⇒ **每次重启都会"提前结算一次"**、24h 时钟被重置；
   现持久化到 `ahbot_market_state.last_settle_time`（读入 + 结算时写回）。
4. **拍卖行成交日志**（经济追踪）：在**唯一成交结算点** `AuctionEntry::AuctionBidWinning()` 写
   ① `tbccharacters.auction_history` 一行（`time/house/item_template/item_count/unit_price/total_price/seller_guid/buyer_guid/seller_is_bot/buyer_is_bot`）；
   ② 一条 ERROR 级 `[AHTRADE] …` 日志（必进 `Server.log`，见第十三章）。
   ⚠️ **落盘**：DB 行刻意写在成交事务（`BeginTransaction`）**之外** ⇒ 自己独立提交、不被后续回滚带走；
   再加日志文件一份 ⇒ 两道保险（站长要求）。

### 4. 生效

- **dev SQL**：`dev/099_ahbot机制优化与成交日志.sql`（**全静态**：只有 `CREATE TABLE IF NOT EXISTS auction_history`；
  显式库名 `tbccharacters`，因为 `apply_dev_sql.sh` 的默认库是 `tbcmangos`）。
  - ⚠️ **2026-09-22 改造**：原版本用 `SET @exist := (SELECT COUNT(*) FROM information_schema.COLUMNS …)` +
    `PREPARE/EXECUTE` 守卫 `ADD COLUMN`（MySQL 不支持 `ADD COLUMN IF NOT EXISTS`），属"逻辑查询"。
    按站长定规「**SQL 里不用逻辑查询、一律静态写死值**」已改掉：新增列 **`last_settle_time` 于 2026-09-22
    用静态 `ALTER TABLE` 在本地库与云端库直接建好**（云端实测 `SHOW COLUMNS` 返回
    `last_settle_time int unsigned NO '' 0`），文件里只留建表语句；那句 ALTER 写进文件注释备"全新库重建"。
    这样重跑不会撞 1060 Duplicate column 卡住 marker 队列，队列里也不再有任何查询/判断。
- 云端源码树已手工同步（cpp 按云端 CRLF、其余 LF；备份 `/root/_srcbak_*_20260921_2*`）；
  nightly dry-run 实测：`would apply 099` + 需编译 `AuctionHouseMgr.cpp.o`、`AuctionHouseBot.cpp.o` ⇒ **今晚 04:06 生效**。
- ⛔ **本次没有重启**（当时线上有玩家；站长定规：有玩家在线禁止重启）。

### 5. 取舍与待观察

- `FlowMinUnits = 100` 是**每 1 小时窗口**的门槛 ⇒ 冷门商品可能长期不动价（这正是"证据驱动"的代价）。
  观察 `[AHBOT] SETTLE … result=under-gate` 的占比再调；若觉得太死，可把 `FlowSettleHours` 设回 24（门槛变"每天 100 单位"），
  但那样"每次 1%"就变成"每天 1%"——两者必须一起改。
- 重启后的第一个窗口：买家集合是内存态（DB 只持久化流水）⇒ 该窗口不会因去重而涨价（保守方向，会自愈）。
- `BuyDepth` 仍是 **0**（回收 = 100% 锚价，做市商没有价差）—— 站长尚未定；若要恢复价差设 5~10。
- 成交日志量级：预计每天数百~数千行，`auction_history` 无清理策略，长期需留意（后续可加按天归档）。

### 6. 探针单（`MarketMaker.ProbeUnits`）2026-09-22 关闭（站长要求）

- **机制**：做市商会按参考价的 85%/75%/65%/55%/45% 五档各挂一小单（`ProbeUnits` 件）试探需求 ——
  下单 `AuctionHouseBot.cpp:510-536`；扫价时"单价 < 参考价 95%"的自家挂单被归入 probe 档 `:1124-1163`；
  重定价时"探针单跟随新价重锚到它那一档" `:1058`。**默认是关的**（`ahbot.conf.dist.in` = 0），
  但云端 2026-09-04 部署做市商时被设成 **5**、后来是 **1** ⇒ 探针一直在挂。
- **处理（2026-09-22）**：云端 `/opt/mangos/etc/ahbot.conf:230` 的 `ProbeUnits` **1 → 0**（备份 `ahbot.conf.bak_probeoff_*`），
  随即 `screen -S mangosd -X stuff ".ahbot reload\r"` 热重载，日志确认
  `All config are reloaded from ahbot configuration file.` —— **没重启、没动服**（`.ahbot reload` → `ReloadAllConfig()`，`Chat/Level3.cpp:88`）。
  ⚠️ 云端 mangosd 实际读的是 **`/opt/mangos/etc/ahbot.conf`**（启动日志 `AHBot using configuration file ../etc/ahbot.conf`，cwd=`/opt/mangos/bin`，
  编译期 `SYSCONFDIR` 决定，见 `src/shared/SystemConfig.h:79`）；`/opt/mangos/bin/ahbot.conf` 是 2026-09-02 的旧拷贝（仍写着 5），**别拿它当 live**。
- **存量探针单**：关闭那一刻线上还挂着 **481 条**（单价≈参考价 85%/88% 的 bot 挂单，多数是 1 件铜币货，如 2835 劣质石头 8c→7c；
  88% 是 85% 在小额价上的四舍五入产物）。它们已在服务器内存里，**直接删 DB 行不会让它在游戏里消失**（要等重启才重建）
  ⇒ 正确做法是等它们**卖掉或到期**（做市商挂单时长 12–48h）自然消失；关闭后不会再新增。

---

## [任务] 9397《捉小鸟》：雌性卡利鸟是 10% 骰子（**不是 bug**）—— 2026-09-22 排查

### 1. 站长反馈

> 「检查任务 9397，我一直刷不出雌性卡利鸟。」

### 2. 任务链路（全部查实，非推断）

| 环节 | 数据/代码 |
|---|---|
| 任务 | 9397 `Birds of a Feather`（中文《捉小鸟》，62 级，地狱火半岛），接/交任务人 **16790 Falconer Drenna Riverwind**（猎鹰岗哨） |
| 目标 | 收集 **23486 Caged Female Kaliri Hatchling**（`ReqItemId1`） |
| **鸟笼从哪来** | `quest_template.SrcItemId = 23485, SrcItemCount = 1` ⇒ **接任务时系统直接发给你空鸟笼**（`Player.cpp:14095 StoreNewItem`），不是掉落/购买 |
| 鸟巢 | **181582 Kaliri Nest**（GOOBER type 10、lock 43、`data10 = 29395`），**13 个静态刷点**（map 530，坐标约 x −983…−1333 / y 4040…4264 = **Den of Haal'esh**），`spawntimesecs = 181`（3 分钟），**不在池/刷怪组/事件里** ⇒ 巢本身没问题 |
| 用巢发生什么 | 施放 **29395 Break Kaliri Egg**（Effect1 = 77 SCRIPT_EFFECT，**硬编码**在 `SpellEffects.cpp:6010-6025`） |
| **随机结果** | `urand(0,99)`：**0–9 → 17034 雌性卡利鸟幼崽（10%）**；10–59 → 17035 卡利鸟女族长（**50%**，63 级真怪）；60–99 → 17039 雄性卡利鸟幼崽（40%） |
| 召唤位置/寿命 | `SummonCreature(id, 0,0,0,0, …)` —— 0,0,0 走"**跟随召唤者**"分支（`Object.cpp:2138-2141`）⇒ 就刷在巢边；**只存在 120 秒**（`TEMPSPAWN_TIMED_OOC_OR_DEAD_DESPAWN, 120s`），脱战/死亡即消失 |
| 抓鸟 | 用 **空鸟笼 23485**（法术 **29435**：`Effect1=3 DUMMY` + `Effect2=24 CREATE_ITEM → 23486`，隐式目标 **38 = TARGET_UNIT_SCRIPT_NEAR_CASTER** ⇒ **站在幼鸟旁边用**）⇒ 鸟被 `ForcedDespawn()`、物品到手 |
| 交任务 | `dbscripts_on_quest_end(9397)`：在猎鹰岗哨召唤 **17262 Captive Female Kaliri** 20 秒 + 表情（演出，无关功能） |

### 3. 结论：为什么"一直刷不出"

**这是 10% 概率，不是坏了**。平均要开 ~10 个巢才出 1 只雌鸟；而且 **50% 会出"卡利鸟女族长"**（63 级会打你）——
很可能就是"以为刷出来了、结果不是它"。按 13 个巢、每个 181 秒刷新算：
- 一轮全开：出雌鸟概率 = 1 − 0.9¹³ ≈ **75%**；两轮 ≈ **94%**。
- 要点：**召唤物只有 120 秒** ⇒ 出了立刻用鸟笼收（站旁边按就行，不用精确选中目标）；别跟女族长纠缠。

### 4. 概率的出处与"别的端是多少"（三方核对）

| 端 / 分支 | 29395「Break Kaliri Egg」的实现 | 概率 |
|---|---|---|
| **本端** Nmangos-tbc（`SpellEffects.cpp:6013-6020`） | 有 | 雌 **10%** / 女族长 50% / 雄 40% |
| `mangos-tbc-heitu-master`、`Nmangos-tbc-master3`（本地两套别的 TBC fork） | 同一段代码（:6402 起） | **完全相同的 10/50/40** |
| **上游 cmangos master**（2026-09-22 用 curl 拉最新 `SpellEffects.cpp` 核对） | 同一段代码 | **完全相同的 10/50/40** |
| AzerothCore / TrinityCore（WotLK 系） | **核心没有这段实现**（AC 库里巢的 `data10=29395` 字段仍在，但代码无处理；TC master 的 29395 是别的法术） | 无值可比 |
| 幼鸟等级（顺带核对） | 本端与 AC 的 `creature_template` 一致：雌 62 / 女族长 63 / 雄 61 | — |

- `git blame`：这段判定来自 **上游 cmangos 提交 `de44790b05`（2012-01-24，作者 Xfurry）** ⇒ mangos 作者当年的**估计值**，
  所有 mangos 系 fork 原样继承；**没有"别的端的更权威数字"可抄**（AC/TC 不实现该任务法术）。
- 站长 2026-09-22 追问"概率太小"，核对完以上三方后**定案：保持 10% 不改**（承认上游设计；改它需改代码+编译+重启）。

### 5. 10% 之下的刷法（给玩家/GM 的实际口径）

| 雌鸟概率 | 一轮 13 个巢出 ≥1 只 | 每轮期望只数 |
|---|---|---|
| **10%（现行）** | **74.6%** | 1.3 |
| 20% | 94.5% | 2.6 |
| 30% | 98.8% | 3.9 |

- **每轮 13 个巢**（guid 160049-160061，map 530，坐标集中在 Den of Haal'esh）：
  x ≈ −1153/4264、−1099/4253、−1138/4242、−983/4231、−1168/4215、−1140/4212、−1103/4211、
  −1115/4185、−1076/4177、−1109/4176、−1200/4117、−1332/4062、−1325/4041；**每个采后 181 秒（3 分钟）回**。
- ⚠️ **三个常见"刷不出"的真正原因**：
  1. **把幼鸟打死了**（幼鸟是生物 17034）—— 正确做法是**对幼鸟使用「空鸟笼」**（物品 23485，接任务时系统直接发），
     吃了它才拿到 23486；打死只掉普通掉落，任务物品拿不到。
  2. **超过 120 秒**：召唤出的幼鸟只存在 120 秒（脱战/死亡即消失），出了**立刻**用鸟笼收。
  3. **只开了一两个巢**：单巢 10%、13 巢一轮 74.6%；一轮没出就再来一轮（3 分钟后巢全回来）。
- 鸟笼不会消耗（法术 29435 只做 `CREATE_ITEM 23486` + 让目标消失），不用反复找笼子；交任务时系统会收回。

---


> 站长定案：**以后遇到「DB 里有、游戏里看不到/`.gobject nearspawned` 没有」这类问题，先考虑 dynGuid 这个原因。**
> 本章把机制、判据、排查命令、以及本次（任务 9345 刺叶）的完整证据一次性写清。

### 1. 症状签名（满足即先查这里）

| 观测 | 结果 |
|---|---|
| `.gobject near 60`（读 DB，Level2.cpp:1228） | **有**（行、坐标、模板全对） |
| `.gobject nearspawned 60`（读世界，Level2.cpp:1324） | **没有** |
| `Server.log` | **没有任何** `invalid displayId` / `not loaded` 之类的报错 |
| 换个客户端 / 换台机器 | 一样看不到（排除客户端渲染/模型缺失） |

⚠️ **`.gobject nearspawned` 的默认半径只有 10 码**（`ExtractOptFloat(&args, distance, 10.0f)`），
比较时必须两边都写同一个半径，否则"没有"是假阴性。

### 2. 为什么"DB 有 = 场上必须有"是错的：加载期就被分流了

`ObjectMgr::LoadGameObjects()`（`Globals/ObjectMgr.cpp:2426`）逐行判定一条刷点是不是 **dynGuid**：

```
ObjectMgr.cpp:2460-2488   ① gameobject.id == 0 且该 guid 在 gameobject_spawn_entry 里被标 dynguided
                          ② gameobject_template.ExtraFlags & GAMEOBJECT_EXTRA_FLAG_DYNGUID (0x2)
ObjectMgr.cpp:2589-2599   dynGuid 且非事件 ⇒ 只记进 m_dynguidGameobjectDbGuids[mapid]，
                          否则（else if）才 AddGameobjectToGrid() —— 这一支才是"网格加载时刷出来"
```

也就是说：**被判为 dynGuid 的刷点，从一开始就不进网格表**，普通网格加载永远不会生成它。
另有两条只在运行时才生效的 dynGuid 判据（`Entities/GameObject.cpp:922-930`）：

```
GameObject.cpp:923  map->IsDynguidForced()                 // Map.cpp:3065 —— 只有 533 Naxxramas / 543 Hellfire Ramparts
GameObject.cpp:928  goinfo.ExtraFlags & 0x2  ||  groupEntry // ← 刷怪组（spawn_group_spawn）成员走这条
GameObject.cpp:932  if (dynguid || newGuid == 0) newGuid = map->GenerateLocalLowGuid(HIGHGUID_GAMEOBJECT);
                    // ⇒ 运行时 guid ≠ DB guid，这就是站长说的「动态 guid」；
                    //    DB guid 仍是唯一句柄（所有 GM 命令都用它）
ObjectGridLoader.cpp:123-138  网格加载时 newGuid 默认 = DB guid，只有 IsEventGuid() 为真才置 0
```

### 3. dynGuid 的刷点由 SpawnManager 接管，**当下可能并不存在**

`SpawnManager::Initialize()`（`Maps/SpawnManager.cpp:72-90`，开图时执行一次）：

```
复活时间 < now  ⇒ MapPersistentState::AddGameobjectToGrid()   // 补进网格，随网格加载出现
复活时间 ≥ now  ⇒ AddGameObject(dbGuid)                        // 只排进 m_spawns 待生成队列 ⇒ 场上没有
```

⇒ **"DB 行在、场上没有"在这里是合法状态**：要么它排着队没到点，要么它属于某个"限量组"而没被选中。

### 4. 本次案例：任务 9345《Preparing the Salve》的刺叶

- 任务 9345（等级 61，地狱火半岛）要求 **12 × 23205（Hellfire Spineleaf）**；
  GO **181372 Hellfire Spineleaf**（type 3 宝箱、lock 259、loot 18233）每株只出 **1 个**（`gameobject_loot_template` 18233→23205，`-100`，maxcount 1）
  ⇒ 需要**采 12 株**。
- 刷点：`gameobject` 里 **98 个**（guid 181100-181197，map 530），坐标/模板/spawnMask/复活时间全部正常。
- **真因**：这 98 个点**全部属于刷怪组 `spawn_group` 21390「Hellfire Spineleaf」**
  （`spawn_group_spawn`：`Id=21390, SlotId=-1, Chance=0`；组定义 `Type=1`(GO)、**`MaxCount=15`**）。
  - 组成员 ⇒ `GameObject.cpp:910/928` 判为 dynGuid ⇒ 运行时动态 guid；
  - `SpawnGroup::Spawn()`（`Maps/SpawnGroup.cpp:157`、MaxCount 检查在 **175**、`std::shuffle` 在 **326**、截断在 **357**）
    ⇒ 在 98 个候选点里**随机挑 15 个**生成；采掉一株后由 `SpawnManager::RespawnGameObject()`
    （`SpawnManager.cpp:164`，写 `gameobject_respawn`）重排，**下次换哪几个点是不确定的**。
- ⇒ **站在任意一个固定点上，大概率一株都看不到**（全场同时最多 15 株，且位置每次重抽），
  这正是"`.gobject near` 有 98 个、`nearspawned` 一个没有、怎么换客户端都看不见"的全部原因。
- 反证（系统本身在正常工作）：查的时候 `gameobject_respawn` 里有 **5 条**刺叶记录
  （181107/181108/181145/181150/181151，时间 00:28~00:33，均为"+600 秒"）—— 说明近期确实有玩家**采到了**。
- 与参照库一致：`tbcdb_ref` 里 **同一个组 21390、同样 MaxCount=15、同样 98 个成员** ⇒ **不是本次改坏的数据，是该库的设计**。

### 5. 逐一排除掉的其它原因（本次都验过，别重复劳动）

| 假设 | 实测 |
|---|---|
| 模板 displayId 不在 DBC | ❌ 无 `invalid displayId` 日志；`ObjectMgr.cpp:2480` 一失败就会打日志 |
| 坐标埋地下 / 网格层级问题 | ❌ 98 个点与地形高度差 ≤0.1 码，与可见的魔草/梦叶草同级 |
| 池（pool_gameobject / pool_gameobject_template） | ❌ 0 行（注意：**入口级**池是按 `gameobject.id` 关联的，只查 guid 会漏） |
| 游戏事件（game_event_gameobject） | ❌ guid 181100-181197 一条都没有 |
| 持久化复活时间未到 | ❌ `gameobject_respawn` 里那 5 条都已是过去时间，其余 93 个根本没有记录 |
| `gameobject_spawn_entry` 标了 dynguided | ❌ 0 行（这条只对 `gameobject.id = 0` 的行生效） |
| 本地/云端源码不一致 | ❌ 云端 `/root/Nmangos-tbc` 与本地判据代码逐行一致 |

### 6. 「这任务不是太难做了吗」——站长定案：**取消节流，GO 刷点一律全刷（= AZ 口径，`dev/101`）**

**先搞清这不是孤例**：本库的世界库把**所有采集点都做成了「分区/分组 + 并发上限」**
（魔草 600 个点全在组里、梦叶草 439 个、铜矿 Barrens 36/160、瘟疫花 EPL 50/201……），
所以「解散刷怪组、退回 98 个静态刷点」**是偏离本库整体设计的做法，不推荐**。

**真正的异常是比例**：本库草药/矿脉组的并发上限普遍是成员数的 **20~33%**，而刺叶是 **15%**：

| 组 | 上限 / 成员 | 比例 |
|---|---|---|
| Felweed - Hellfire Peninsula - SE (21460) | 13 / 56 | 23% |
| Fel Iron Deposit - HFP - SW (21554) | 13 / 50 | 26% |
| Dreaming Glory - Hellfire - Fissure East (21493) | 3 / 12 | 25% |
| Copper Vein - Barrens (10565) | 36 / 160 | 23% |
| Plaguebloom - Eastern Plaguelands (10776) | 50 / 201 | 25% |
| **Hellfire Spineleaf (21390)** | **15 / 98** | **15%** ← 地狱火半岛采集组里最低档 |

再叠加「任务要 12 株、每株只出 1 个、位置每轮随机重抽」，实际体验就是"满地图找 12 株"。

**另一件事：`MaxCount = 15` 是上游原始设计，不是本端改坏的**。三方核对完全一致：

| 数据源 | 刺叶刷点 | 组 | 上限 |
|---|---|---|---|
| TBC-DB 社区全库 `_tbc-db_ref\Full_DB\FullDB.sql` | 98 个（map 530） | `(21390,'Hellfire Spineleaf',1,15,…)` | 15 |
| 同上 `spawn_group_spawn` 成员 | 98 个，guid **181100-181197**（与本库逐一对上） | — | — |
| `tbcdb_ref` / `tbcmangos_orig` / `wotlkmangos`（cmangos 官方 WotLK 库） | 98 | 21390 | 15 |
| AzerothCore 参照 `ac_cmp` | **无刷点数据**（只有 `gameobject_template` 模板/本地化）；AC 是 WotLK 端、节点分布用 `pool_*`，没有本端这套 spawn_group/dynGuid 机制 | — | — |
| TrinityCore 参照 `trinitycore_ref` | 本地只有代码 + updates + 10.x 本地化串，**没有 world 数据 dump**；TC 采集点同样走池系统（`pool_template`/`pool_gameobject`），没有本端这套 spawn_group/dynGuid 机制 | — | — |

任务 9345 的原文本身也写着「Spineleaf grows in and around the **Valley of Bones** to the north…
Gather 12 Hellfire Spineleaf plants」—— 上游是按"**一小片区域里 15 株**"设计的。

#### 6.1 定案前的普查：这套上限到底有多"随意"

- **规模**：GO 型刷怪组 **1,514 个 / 22,857 个刷点**，上限合计 **5,734（≈25%）**
  ⇒ 库里两万多个采集点，场上同刻只有五千多个。分类：草药 731 组 / 13,275 点、矿脉 543 组 / 6,902 点、
  其他（宝箱/任务物/鱼群/蛋）240 组 / 2,680 点。
- **比例没有任何公式**：<15% 247 组｜15-25% 270｜**25-35% 452**｜35-50% 23｜50-70% 42｜≥70% 47。
- **上游自己承认是补偿值**：cmangos `Updates/0466` 注释 —— 加 dynguid 会缩短实际刷新时间，
  故需调大刷点值以防"自然过量刷新"。⇒ 这些数字是**针对模拟器副作用的经验补偿，不是零售数据**。
- **AZ 对照（已实测）**：同一批 181372 的点 AZ 有 70 个（本端 98 的子集）**全部常驻、无任何上限**。
- **已经 ≥50% 的 190 组（982 点）构成**（查过，避免误伤）：**正好 50% 的 135 组 / 632 点**（不受影响）；
  真超 50% 的 55 组 / 350 点 = **钓鱼 49 组 / 419 点** + **副本物件 15 组 / 107 点**
  （Karazhan Sealed Tome、Deadmines Box of Assorted Parts、Old Hillsbrad 箱/水晶…）
  + 少数外域草药矿脉（Netherstorm `Ethereal Technology` 30→23=77%、`Etherlithium Matrix` 29→21=72%…）
  + 一个手误遗留 `Copper Vein - Hillsbrad Foothills`（3 个刷点、上限却写 8 = 267%）。
- ⚠️ **坑：`FLOOR(成员数×50%)` 会把"只有 1 个刷点"的 18 个组算成 0，而 `MaxCount = 0` 是"一个都不刷"**
  （`Maps/SpawnGroup.cpp:175` 的 `>=` 判定）⇒ 副本矿点/任务箱（IoQD 系列、Shattered Halls、Old Hillsbrad…）会直接消失。
  **本方案（上限 = 成员数）天然绕开这个坑**（1 个成员 ⇒ 上限 1）。

#### 6.2 改动（`dev/101_刷点上限放开_GO组全刷.sql`，**全静态**）

```sql
-- 每条都是写死的字面量：无 JOIN / 无子查询 / 无聚合 / 无计算（站长定规：云端只跑静态幂等写，改数据写死值）
UPDATE `spawn_group` SET `MaxCount` = 98 WHERE `Id` = 21390 AND `MaxCount` <> 98;
UPDATE `spawn_group` SET `MaxCount` = 13 WHERE `Id` = 21032 AND `MaxCount` <> 13;
... （共 1,514 条，逐组写死"成员数"）
```

- ⛔ **为什么不做成 `UPDATE … JOIN (SELECT COUNT(*))`**：那是逻辑查询（云端还要现算一遍）。
  数值已在**本地**算好，云端只做字面量赋值。
- ✅ **写法：按目标值分组**（2026-09-22 站长要求"一大堆 `WHERE Id=` 不能写到一起吗"后改的）：
  同一个 `MaxCount` 的所有 Id 用一条 `IN (…)` 写完 ⇒ **1,514 条压成 110 条**（110 个不同目标值），
  文件 **120 KB → 18 KB**；回滚文件同法 **1,536 → 36 条**（12 KB）。
  例（刺叶与另一组同为 98，合并成一条）：
  ```sql
  UPDATE `spawn_group` SET `MaxCount` = 98 WHERE `Id` IN (10547,21390) AND `MaxCount` <> 98;
  ```
  本地三步实测：回滚 0.084s、应用 **0.16s**、复跑 0 行变更（幂等）、`MaxCount<成员数` 的组 0。
  （不用"一条巨型 CASE"：单条 100 KB+ 语句、全有全无、出错难定位；分组版既短又可逐条核对。）
- ✅ **已于 2026-09-22 02:07 在云端应用并重启生效**（marker 097 → 099 → 101；当时 0 人在线，站长授权）。
  **实测效果（world 库口径）**：GO 组上限合计 **5,734 → 22,857**（+17,123，×3.99）——
  矿脉 1,631 → **5,976**（×3.66）｜草药/植物 3,203 → **12,917**（×4.03）｜其他（宝箱/任务物/鱼群/蛋/副本）900 → **3,964**（×4.40）；刺叶 15 → **98**。
  ⚠️ 口径说明：这是"**同刻可存在点数**"上限；实际场上数量还受刷新 CD（采集后 600s / 组覆盖 300s）与玩家采集影响。
  其中 **6,154 个成员是 `gameobject.id = 0` 的占位点**（运行时按 `gameobject_spawn_entry` 的权重抽矿种）⇒
  "点位全开"**不会**让稀有矿变多，稀有度仍由权重与点位数量决定。
- **回滚**：`~~dev/rollback/101_回滚_刷点上限还原.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`（同样是全静态、写死**改前**值：刺叶 15、21032 → 2 …，共 1,536 条）。
  ⚠️ 放在 `dev/rollback/` 子目录 —— `apply_dev_sql.sh` 只扫 `dev/[0-9][0-9][0-9]_*.sql`（**不递归**），**不会被自动执行**（干跑实测仍只列 099 → 101）。
- **只改 `MaxCount`**（设为该组成员数 = 全刷）；组成员、模板、刷新时间、组的世界状态/旗标**一律不动**，代码不改。
  ⚠️ 口径说明：`spawn_group.Type = 1` 共 **1,536 组**，其中 **22 组没有任何 `spawn_group_spawn` 成员（空组）**，
  它们的 `MaxCount` 保持原值（空组本来就刷不出东西、无影响）。
  因此按"全部 Type=1"统计上限合计是 **5,790 → 22,913**，而按"有成员的 1,514 组"统计是 **5,734 → 22,857**，两个口径都对。
- **生物组（`Type = 0`，1,648 组）一律不动**：生物组成员本来就由网格加载（`ObjectMgr.cpp` 生物分支是两个独立 `if`），
  上限限制的是组管理器；乱动会把 `MaxCount = 1` 的稀有精英变成"全刷"，也会踩 dynguid 双刷的老坑（见 1449 章）。
- 本地实测（2026-09-22，走"静态回滚 → 静态应用 → 复跑"三步）：改前 **5,734**（刺叶 15、与成员数不符的组 1,494）
  → 改后 **22,857**（刺叶 98/98、不符的组 **0**）；生物组分布不变（1,340 组仍是 0）；**复跑 0 行变更（幂等）**。

#### 6.3 ⚠️ 「全刷」不等于「秒刷」：`MaxCount` 与刷新 CD 是两个独立旋钮

站长 2026-09-22 追问"全刷会不会所有东西秒刷"——**不会**。`MaxCount` 只决定**同刻存在几个**，
一个物件被采掉后**必须等它自己的 CD 到点才回来**：

| 环节 | 代码位置 | 行为 |
|---|---|---|
| 采掉物件时定 CD | `Entities/GameObject.cpp:702-705` | `m_respawnDelay = gameobject.spawntimesecsmin~max 的随机值`；**组设了 `RespawnOverrideMin/Max` 就用组的值覆盖** |
| 落定回来时间 | `GameObject.cpp:711` | `m_respawnTime = now + m_respawnDelay` |
| CD 未到不许刷 | `Maps/SpawnGroup.cpp:291-307` | 候选里"复活时间 > now"的点**被剔除**；只有 `ignoreRespawntime`（GM `.respawn` / 脚本强制）才无视 CD |
| 组级冷却 | `SpawnGroup.cpp:78-83` | 仅**整组清空**时给一次冷却（非副本）；全刷下几百成员不可能同时空 ⇒ 实际不触发 |

**本库实际 CD**（2026-09-22 实测）：采集点（刺叶/魔草/梦叶草/地脉草/虚空花/梦魇藤/铜矿）**600 秒**；
**416 个组带 `RespawnOverride = 300 秒`**（`dev/038` 矿脉刷新加速那批：成员自身 600、组覆盖 300 ⇒ 矿 5 分钟回来，
如 `Iron Deposit - Arathi Highlands`）；无覆盖的组走成员自身的 600。全库其它值参照：
600×20,745、180×18,821、120×4,742、900×4,572、7200×2,252、`-1`（永不自动刷）×1,401、86400×1,196。

**体感差异（这才是全刷真正的变化）**：

| | 改前（有上限） | 改后（全刷） |
|---|---|---|
| 采掉一个点 | 组里空出名额 ⇒ **立刻随机换另一个点**刷出（节点像"会瞬移/乱冒"） | 名额已满 ⇒ **采一个少一个**，只能等它自己 CD（采集点 600s） |
| 区域总览 | 恒定 N 个、位置一直变 | **开局遍地**、越采越稀、按 CD 陆续回满 |

⇒ 想让采集"更快回"必须改另一个旋钮（`gameobject.spawntimesecs` 或组 `RespawnOverride`），经济影响远大于本改动。

**判定频率与"补位是随机抽签"（站长 2026-09-22 追问的细节）**：

- `Map::Update` **每 tick** 调 `m_spawnManager.Update()`（`Map.cpp:729`）→ 组 `Spawn(false,false)`；
  而 `MapUpdateInterval` 默认 **100 ms**（`World.cpp:511`，下限 `MIN_MAP_UPDATE_DELAY`）⇒ 所有"补位/回刷"的延迟都是**亚秒级**。
- **改前（有上限）是"名额驱动"**：某点 CD 走完但名额满 ⇒ 它只是重新进入抽签池，**不会顶掉别人**；
  只要有**任意一个活着点被采**（哪怕不是它）就空出名额 ⇒ 下一 tick 补一个，但补的**是随机的**：
  `SpawnGroup.cpp:326` 把"所有 CD 已到期的成员"`std::shuffle` 后取前 k 个（k = 空位数）
  ⇒ 那个刚到期、被挡住的点**中签概率 = 1 / 候选数**，不保证轮到它（这就是玩家觉得"矿/草会乱冒、会跑"的根源）。
  候选全在 CD 中时一个都不刷；`MaxCount == 1` 的组另有 rare-mob 保护（`SpawnGroup.cpp:298-299`：任一成员在 CD ⇒ 整个 `Spawn()` return，**不换点顶替**）。
- **改后（全刷）是"CD 驱动"**：名额永远有空 ⇒ **CD 一到就地刷回原刷点**，位置固定。

**玩家可见症状：「同一个点采完马上又刷出来一个」——这是"替位（substitution）"，不是该点 CD 提前结束**（2026-09-22 站长实测提问）：

- 机制：采掉一个点 ⇒ 组里立刻空出一个名额 ⇒ 下一 tick（≤100ms）在"**CD 已到期的成员**"里 `shuffle` 抽一个补上（见上面 291-357 那段）。
  被采的那个 guid **确实在冷却**（`tbccharacters.gameobject_respawn` 里能看到 `now+600`/`now+300`），回不来的是别人顶上。
- 为什么"看着像原地"：很多组是**小簇组**（如 `Badlands - Iron Deposit | Silver Vein | Gold Vein (1) Ore 004` 只有 4 个点挤在一小片、
  `The Deadmines - Copper Vein (1) Ore 000` 4 个点）⇒ 新点就刷在旁边几码；偶发也会**抽中同一坐标**（但那是**另一个 guid**，概率 1/候选数）。
- **实测方法**：采掉后立刻查 `SELECT guid, respawntime, FROM_UNIXTIME(respawntime) FROM tbccharacters.gameobject_respawn ORDER BY respawntime DESC LIMIT 5;`
  （期望该 guid = 现在+600/300），再用 `.gobject nearspawned 60` 看多出来的是哪个 guid（多半是几码外的另一个组成员）。
- **全刷（dev/101）后此现象消失**：上限=成员数 ⇒ 采掉一个后场上已是 N−1，而唯一"CD 已到期却不在场"的成员就是它自己（正在冷却）
  ⇒ **候选池为空、不补位**，变成"采掉就空着，等自己的 CD 到点原位刷回"。

#### 6.4 「官服是怎么样的」—— ⚠️ 只能给证据等级，**不能给结论**

站长 2026-09-22 追问后又纠正：**pfQuest 不是官服数据，Questie 来源也不明** ⇒ 本端**没有任何一手官服数据**。
所以下面只列"每个来源能不能代表官服"，**不要**再写"官服是这样的"：

| 来源 | 它是什么 | 能不能当官服证据 |
|---|---|---|
| **pfQuest** `objects-tbc.lua` | 点数 + 第 4 值刷新秒数（普通矿 45s、Ooze 360s） | ❌ **其官方仓库自述 TBC 数据取自 CMaNGOS** ⇒ 与本库**同源**，是"另一份快照"而非独立第三方（本文件 2063 行早记过） |
| **Questie** `tbcObjectDB.lua` | 众包坐标库（铜 2637、锡 2598、银 3524、富瑟银 539…），**无刷新时间字段** | ❓ **来源不可考**（站长：可能是官服数据，也可能是别处凑的）⇒ 不能单独作为官服依据 |
| TBC-DB / cmangos / 本库 `tbcmangos` | 同一条血统的社区库；**`spawn_group + MaxCount` 这套并发上限是 mangos 系自己加的机制** | ❌ 机制不是零售的 |
| **AzerothCore** `acore_world`（已导入本地） | 另一支血统：同一点**70 个刷点、无上限、无池**（`gameobject` 表连 `spawnGroupId`/`poolId` 列都没有） | ❌ 它和本库(98 点)点位数就不同 ⇒ 两边都是**众包近似**，谁都不是"官服原样" |

**能确定 / 不能确定**：

- ✅ **能确定（本端实测）**：`spawn_group` 的并发上限是 **mangos/cmangos 血统的机制**（AZ/TC 的 world 库里没有这些草药组，
  连列都没有）；本端改前"98 个点只开 15 个、采一个立刻随机换点"的行为，**是这套机制的产物，不是零售行为**。
- ✅ **能确定（语义等价）**：全刷后的语义 = "**所有点位都可能存在 + 采掉后各自 CD 回原位**"，
  与"无上限的库（AZ）"一致。
- ❓ **不能确定**：官服的真实并发数、真实刷新秒数。暴雪从未公布，插件数据要么同源（pfQuest）、要么来源不明（Questie）。
  因此 6.3 里"官服 CD 更快（45s 级）"这类说法**只能当作"某个同源库的数值"，不能当官服事实**。
- 生效：**需重启**（`LoadGameObjects` / `SpawnManager::Initialize` 在启动/开图时跑；
  之后 `SpawnGroup::Update()` 每 tick 会把组填到上限）。云端干跑 `would apply 099 → 101`，随夜间 04:06 生效。
- 预期：同刻存在的采集点/物件 **5,734 → 22,857**（+17,123 个常驻 GameObject，内存估算 **+10~17 MB**）；
  采集产出≈4 倍，草药/矿石市场供给↑、AHBot 回收支出↑（日闸 100 金/周期、5000 金/24h 不变）。
- 遗留观察：① 重启后首图打开会一次性生成 2 万多个物件（内存峰值留意 `mem_monitor.sh`）；
  ② 灵翼蛋/血之英雄/副本宝箱等"稀有轮换"物件也变成全刷（站长已确认接受该口径）。
- ⚠️ **`MaxCount = 0` 不是"无限"，是"一个都不刷"**：`SpawnGroup.cpp:175` 是 `if (m_objects.size() >= m_entry.MaxCount) return;`
  ⇒ 0 会让 `0 >= 0` 恒真。（注：库里确实存在一批 `MaxCount = 0` 的**生物**组（Netherstorm 28011/28014…），
  按这段代码它们应当刷不出东西 —— 与本任务无关，仅记录待查。）
- ⚠️ **改完必须重启**（`LoadGameObjects` 只在 mangosd 启动时跑、`SpawnManager::Initialize` 只在开图时跑），
  且**有玩家在线时禁止重启**（P0）⇒ 走夜间维护窗口（04:00 关机 / 04:05 开机 / 04:06 nightly 应用 dev SQL 并启动）。

### 6b. 别的核心怎么实现的（AZ / TC 对照，2026-09-22 查）

**核心差异：AZ/TC 的 `spawn_group` 与本端（cmangos）的 `spawn_group` 是"同名不同物"。**

| | 本端 cmangos | AzerothCore / TrinityCore |
|---|---|---|
| 表 | `spawn_group(Id, Name, Type, **MaxCount**, WorldState, WorldStateExpression, Flags, StringId, RespawnOverrideMin/Max)` + `spawn_group_spawn(Id, Guid, SlotId, Chance)` | `spawn_group_template(groupId, name, mapId, flags)` + 刷点的 `spawnGroupId` 列（AC `SpawnData.h`：`SpawnGroupTemplateData { groupId, name, mapId, flags }`） |
| 语义 | **限量池**：一组刷点里**同时最多 `MaxCount` 个**存在，随机挑、采后重排；组成员还是 dynGuid（运行时动态 guid） | **开关组**：`SPAWNGROUP_FLAG_SYSTEM / COMPATIBILITY_MODE / MANUAL_SPAWN / DYNAMIC_SPAWN_RATE / ESCORTQUESTNPC` ⇒ 只管"这组**生不生效**"（副本 boss 状态联动 `instance_spawn_groups`、护送任务、手动 `SpawnGroupSpawn/Despawn`），**没有"同时存在几个"这种上限** |
| 采集点数量控制 | 刷怪组上限（本端刺叶即 15/98） | **没有这个维度**；只有**池系统** `pool_template`/`pool_gameobject`（一组点里按权重只出其中一部分），草药/矿脉一般不进池 |
| 结论 | 库里有 98 个点、场上最多 15 个 | **`gameobject` 表里有多少行，就同时存在多少株**（采掉后按各自 `spawntimesecs` 刷新） |

- 证据：AC 源码 `azerothcore_ref\src\server\game\Maps\SpawnData.h`（`SpawnGroupTemplateData` 只有 groupId/name/mapId/flags）
  与 `Map.cpp:2596-2720`（`IsSpawnGroupActive` / `SpawnGroupSpawn` / `SpawnGroupDespawn`）；
  TC 侧 `trinitycore_ref\sql\base\dev\world_database.sql` 里是 `instance_spawn_groups`（boss 状态→刷怪组）。
  参考：[AzerothCore wiki `spawn_group`](https://www.azerothcore.org/wiki/spawn_group)、
  [`spawn_group_template`](https://www.azerothcore.org/wiki/spawn_group_template)。
- ⇒ **cmangos 的 spawn_group 数据（含 MaxCount）搬到 AZ 上没有任何作用**（列不匹配、语义不同）。
- ✅ **已实测（2026-09-22）**：把 AC 的 world 库导进了本地 MySQL（库名 **`acore_world`**）。
  官方没有单文件发布 —— 正确路径是主仓库 `azerothcore/azerothcore-wotlk` 的
  `data/sql/base/db_world/*.sql`（309 个文件 297 MB，内含完整刷点内容）+ 按日期顺序
  `data/sql/updates/db_world/*.sql`（867 个）。本次用 `git sparse-checkout set data/sql` 只取这两个目录，
  脚本见 `_agent_tmp/import_acore_world.sh`（base 8 个 locale 文件 + 43 个 update 因**客户端字符集/重复主键**失败，
  与刷点无关；重跑需加 `--default-character-set=utf8mb4` 并按 base 里的 `updates` 表跳过已应用项）。
  **实测结果**：`gameobject` 共 **96,628** 行；**181372 = 70 行**（全部 map 530）；`pool_gameobject` 中 **0 行**；
  `spawn_group` 全表 **54 行**、`spawn_group_template` **7 行**（全是 Sanctum of the Stars / Altar of Sha'tar 等
  脚本开关组，flag=4 `MANUAL_SPAWN`，**无任何草药组**）；`gameobject` 表**没有 `spawnGroupId`/`poolId` 列**。
  ⇒ **AZ 上 70 个点全部同时存在**（采后各自按 `spawntimesecs` 刷新），不存在本端"库里有 98、场上只有 15"的现象。
- **逐点比对（本端 98 vs AZ 70）**：AC 的 70 个点**是本端 98 个点的真子集** —— 70/70 在 2 码内一一对上，
  AZ **无独有点**，本端多出 **28** 个点；两边 z 范围一致（−36.4 ~ 94.9）。同组对照：Felweed 本端 633 / AZ 426。
  即：**AZ 的点更少，但同刻可采数量是 70 : 15（约 4.7 倍）**。

- **与 `dev/051`（2026-08-29"矿脉组 MaxCount 1→2"）的关系**（站长 2026-09-22 专门追问过）：
  051 是针对**同一根因**（spawn_group 机制 + `MaxCount` 太小 ⇒ 矿少）的第一次修复，把 215 个含矿 entry 的组 1→2；
  线上实测（改前）：该范围 265 组里 **230 组仍是 `MaxCount = 2`**、上限合计 **936 / 成员 3,149**；
  全库 `MaxCount = 2` 的 GO 组 **517 组 / 3,129 个成员**（含灵翼蛋、Ragveil 泵站等）。
  → 本脚本把它们一律抬到成员数（该范围 936 → **3,149**），**是 051 的延续与终极版，不是回退**；
  站长确认"矿脉一并全刷，不保留 `MaxCount = 2` 的档位"（不再单独排除任何组）。
- **回滚**：`~~dev/rollback/101_回滚_刷点上限还原.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`（**全静态**，写死改前值 1,536 条；见 6.2）。
  ⚠️ 早先版本曾用"建快照表 `spawn_group_bak_maxcount_20260922` + JOIN 还原"的写法，因站长定规
  「**SQL 里不用逻辑查询、一律写死值**」已改掉（云端从未执行过那版，本地那张表已删）。
- **本地与云端的一致性**：本地库已应用（`MaxCount` 全为成员数；静态回滚文件在手）；
  云端在夜间 04:06 应用（干跑 `would apply 099 → 101`）。两者最终一致。

### 7. 附：一条顺手发现的代码笔误（只记录，不改）

`GameEvents/GameEventMgr.cpp:880`：事件 GO 注册成了 **`AddEventGuid(goDbGuid, HIGHGUID_UNIT)`**
（同函数的移除用 `RemoveEventGuid(goDbGuid, HIGHGUID_GAMEOBJECT)`，981 行才是 creature 的正确写法）。
后果：事件 GO 的 dbGuid 进的是**生物**的事件 guid 集合（`IsEventGuid(go, GAMEOBJECT)` 恒 false），
网格加载时不会给它动态 guid；而移除时从 GO 集合删、删了个不存在的东西 ⇒ **生物集合里会残留**。
生物与 GO 的 dbGuid 是两个独立编号空间（都从 1 开始）⇒ 理论上存在"编号撞车"的隐患。
本次与刺叶无关，仅记录待观察。

---

## [机制] Tap 规则补齐：NPC 伤害 >50% 抢走拾取权 —— 2026-09-22（源码改动，本地编译通过）

> ✅ **站长本地验收通过（2026-09-22）**：NPC 伤害 >50% 抢走拾取权的场景实测符合预期。

### 现状核查（改前）

| 零售 Tap 规则 | 本端实现 |
|---|---|
| 首击归属 | ✅ `Unit.cpp` 伤害路径：`!HasLootRecipient()` 时 `SetLootRecipient(dealer)`；`Creature::SetLootRecipient` 用 `GetBeneficiaryPlayer()` ⇒ 宠物算主人、**纯 NPC 不设归属** |
| 副本内按组共享 | ✅ `m_lootGroupRecipientId` + `IsTappedBy`（代码里留着 cmangos 的 TODO "group situation need more work"） |
| 无 Tap（世界 boss） | ✅ `CreatureStaticFlags3::CAN_BE_MULTITAPPED` 直接跳过归属 |
| **NPC >50% 抢拾取权** | ❌ **未实现**：`m_damageByOthers` 只喂给 `Unit::GetModifierXpBasedOnDamageReceived`（**削经验**，≥100% 归零），**与拾取权无关** |

### 改动（4 文件，已编译通过）

- `Unit.h`：加 `uint32 m_damageByNpcs = 0` / `bool m_tapStolenByNpc = false` + `GetDamageDoneByNpcs()` / `IsTapStolenByNpc()` / `SetTapStolenByNpc()`（头文件改动是必要的，否则无法区分"NPC 伤害"与"他人玩家伤害"）。
- `Unit.cpp` 伤害路径：**非玩家单位**（`TYPEID_UNIT` 且无受益玩家 ⇒ 守卫/友方 NPC 及其宠物）伤害累加，**> 目标最大生命 50%** ⇒ `SetTapStolenByNpc()` + `SetLootRecipient(nullptr)`；
  首击赋值处加 `!IsTapStolenByNpc()` 判断。
- `Creature.cpp::SetLootRecipient`：`IsTapStolenByNpc()` 时直接 return ⇒ **被 NPC 抢走后玩家再也抢不回来**（`SetLootRecipient(nullptr)` 仍可用）。
- 宠物/图腾有受益玩家 ⇒ 算玩家侧、不计入。⚠️ **副本内同样生效**（零售如此）：副本里友方护送 NPC 打掉 >50% 时本队会失去该怪拾取权。
- **生效与验收**：本地 Release 编译通过；4 个文件已同步云端源码树（md5 一致、原件备份 `/root/_srcbak_tap_manaforge_20260922/`），
  随 **04:06 nightly** 编译上线（同步时线上 3 人，未人工重启）。
  验收：① 让友方卫兵/护送 NPC 打掉某怪 >50% ⇒ 你和其他玩家都**不能再拾取**（该怪拾取权作废）；
  ② 宠物独自打 >50% 不影响归属（宠物算玩家侧）；③ 普通抢怪（玩家先手）行为不变。

## [任务] 关闭法力熔炉（10299/10321/10322/10323）：失败路径无人触发，躲角落等 2 分钟必成 —— 2026-09-22（源码改动，本地编译通过）

- **站长实测**："打到钥匙后关闭法力熔炉，然后找个没人角落等 2 分钟就完成了，完全不用管修复的工程师。"
- **机制**（`AI/ScriptDevAI/scripts/outland/netherstorm.cpp`，`npc_manaforge_control_consoleAI`）：用 Access Crystal 开启控制台 → 阶段 1/2/3/4 = **60+30+20+10 = 120 秒**（正是"2 分钟"）→ 阶段 5 `EMOTE_COMPLETE` + `KilledMonsterCredit`；
  期间每 20~30 秒刷 **Sunfury 技术员(20218)** 沿路径走向控制台施放 `Interrupt Shutdown`(35016/35176) = 抢修。
- **根因**：失败逻辑 `DoFailEvent()`（`FailQuest` + EMOTE_ABORT + 复位）**只由 `ReceiveAIEvent(AI_EVENT_CUSTOM_A)` 触发，而全代码库无人发送该事件** ⇒ 技术员纯装饰。
  ✅ 已拉**上游 cmangos master 同一文件**对比：同样如此 ⇒ **上游实现缺口，不是本 fork 改坏的**。
- **改动（5 处补发事件）**：`SummonedMovementInform` 里技术员到达控制台施放抢修法术的 3 处（B'naar/Coruu/Duro）+ Ara 的 `SPELL_INTERRUPT_2` 那处 +
  `npc_manaforge_spawnAI::EnterEvadeMode` 的 `fDistance < 20` 分支（技术员脱战后跑回控制台抢修）⇒ 触发既有 `DoFailEvent()`，
  玩家必须**阻止工程师**才能完成。
- **生效**：本地 Release 编译通过（无 error）；4 个文件已同步云端源码树（md5 与本地一致、保持云端 CRLF 行尾；
  原件备份 `/root/_srcbak_tap_manaforge_20260922/`），nightly 判据 `NEEDS_BUILD=1` ⇒ **随 04:06 nightly 自动编译 + 安装 + 重启**
  （同步时线上有 3 名玩家，按 P0 不人工重启）。
- **验收（重启后）**：接"关闭法力熔炉"→ 故意不打技术员 → 等到技术员走到控制台施放抢修 ⇒ **任务应失败**（EMOTE_ABORT + 任务失败提示）；
  在控制台附近清掉技术员则正常完成。

### 追加修正（同日，站长实测反馈后）：补上"抢修引导"，别让玩家没反应过来就失败

- **站长反馈**："他跑过来，但是距离很远就开始说台词，然后失败了，没反应过来"；并问"是不是应该先判断一次进入战斗"。
- **为什么是"很远"就说台词**：不是补错了位置 —— 上游本来就把"抢修点"设在**离控制台 15~20 码的路点**（`m_afBanaarTechCoords` WP1:2 等；
  `EnterEvadeMode` 里也是走到 `fDistance - 15` 处），技术员在那里对控制台施放 `Interrupt Shutdown`。
  查 AZ 端 SmartAI（`acore_world.smart_scripts` 20218 → 定时脚本 `2021806`）**也是"到达路点 1 就施放 35016"** ⇒ 远端判定是设计如此。
- **改法（站长 2026-09-22 定案，最终版）** —— 关键结论：**这个抢修本来就是"引导法术"，时长不该由我们硬编码**：
  站长从 wowhead 查到 `Interrupt Shutdown` 是"**20 码范围 / 12 秒施法时间**"，回头核对官方数据**完全吻合**：
  | 官方数据字段 | 值 | 含义 |
  |---|---|---|
  | `ChannelInterruptFlags` | **15367（非 0）** | 这是**引导**法术（不是瞬发） |
  | `DurationIndex` | 29 → `SpellDuration.dbc` = **12000 ms** | **引导 12 秒**（wowhead 的"12 秒 施法时间"） |
  | `RangeIndex` | 3 → `SpellRange.dbc` = **20.0 码** | 正好对应上游路点离控制台的 15~20 码 |
  | `CastingTimeIndex` | 1 = 0 ms | 引导类法术的"施法时间"字段是 0，真正的时长在 Duration 里 |
  ⇒ 改成：
  1. **让技术员真的引导**：`DoCastSpellIfCan(控制台, SPELL_INTERRUPT_1/2)`（非 triggered）⇒ 客户端会显示**引导条**，也能被脚踢/击杀打断；
     引导跑完 = 停机被打断。（原来是 `TRIGGERED_OLD_TRIGGERED` 瞬发，玩家看不到任何提示。）
  2. **时长不硬编码**：窗口 = `GetSpellDuration(spellInfo)`（自由函数，`SpellMgr.h:62`）⇒ 直接从法术数据取 **12 秒**；
     连"数据缺失时的兜底值"也写 **12000**（站长：兜底也该是 12 秒，不许自己拍数）。
  3. **战斗中不抢修，且一旦脱战从头重新引导**（站长原话："这任务不应该那么难"）：战斗中直接 `InterruptNonMeleeSpells` 掐掉引导，
     并把剩余时间重置为满窗口；脱战后重起一次引导。
  4. **抢修成功后只中止事件，不判任务失败**（站长选 B，对齐 AZ）：`DoFailEvent()` 改名 `DoAbortEvent()`，
     只做 `DoScriptText(EMOTE_ABORT)` + `ResetControlConsoleAndDespawn()`（清召唤物、解 GO 的 IN_USE、控制台消失）⇒ 玩家**立刻能再点控制台重来**；
     原 SD2 的"对全队 `FailQuest`"那段已删（注释里留了恢复指引）。
  ⛔ **不许自己加东西**（站长 2026-09-22 明确要求）：中途我自己加的两样已全部撤掉 ——
     ①"抢修时播 `EMOTE_STATE_WORK` 修理表情"（引导本身就带引导条，不需要额外表情）；②"被拉离控制台 > 40 码算打断"这条护栏（战斗中不抢修已覆盖）。
  实现：`npc_manaforge_spawnAI` 增加 `m_bRepairing` / `m_uiRepairTimer` / `m_uiRepairTime` / `m_uiChannelRetryTimer`
  + `StartRepair()` / `StopRepair()` / `CastRepairChannel()` / `GetRepairChannelTime()` / `DoRepair()`，挂进**该类原有的 `UpdateAI`**
  （⚠️ 该结构体本来就有 `UpdateAI`，别再写第二个，否则 C2535 "已经定义"）；控制台脚本 4 个抵达点统一改为 `StartRepair()`。
- **其他端对照**：AZ 端技术员抢修成功后**只中止事件**（控制台 `On Data Set 7 7 → Despawn`），
  全库**没有任何 `FAIL_QUEST` 针对 10299/10321/10322/10323/10329/10330/10338/10365** ⇒ AZ **不判任务失败**，玩家可直接重来 —— 站长据此选了 B。
  ⚠️ 但 AZ 自己把这段写成"到达路点 → **1000 ms** 后瞬发施放"，**既不是官方数据的 12 秒引导，也没有引导条** ⇒ AZ 数据不能当官服口径用（站长指出）。
- **站长本地验收（2026-09-22，`x64_Debug` 用新二进制实测）**：**大方向通过** —— 引导条、被打断、"只中止不判失败"都对。
  站长唯一提出疑点的是"**只是靠近它，它也会中断引导来打我**"，核对后确认**这是上游数据本来的设计**，站长决定**保留不改**：
  - `creature_ai_scripts 2021801`：技术员 On Spawn → `SET_REACT_STATE(1)` = **防御型**（不主动仇恨）；
  - `creature_ai_scripts 2021802`：**On Aggro → `INTERRUPT_SPELL(3)`（CURRENT_CHANNELED_SPELL）= 一进战斗就掐掉自己的引导** —— 即"挨打中断抢修"是数据作者的原意；
  - 所以现象是：防御型会**帮附近挨打的同伴** ⇒ 你在法力熔炉里跟别的日怒怪交手时，技术员会加入战斗 ⇒ 引导中断（不是"靠近"触发的）。
  - 站长结论：**"我打他中断是对的"**，这条保留；代码里的"战斗中掐引导"与 DB 行效果重复但方向一致，一并保留。
- ⛔ **云端同步纪律（站长 2026-09-22 指令）**：**未经他确认、本地没测过的东西一律不许同步云端**；本条与钓鱼那条在收到指令前已被我推云（`NEEDS_BUILD=1`），
  且**云端 `netherstorm.cpp` 上还留着我后来被否掉的两处**（`EMOTE_STATE_WORK` 修理表情、8 秒兜底值）——
  是否把"站长实测过的那版（无表情 / 兜底 12 秒 / 无 40 码护栏）"推上去覆盖它，等站长一句话，**不自行处理**。

## [数据] 魔铁宝箱 181798 掉落"断线"：`data1` 指向自己 ⇒ 接回 `9933` —— 2026-09-22（`dev/102`，本地验证通过）

> ✅ **站长本地验收通过（2026-09-22）**：开箱掉落档位正确（必出食物 + 草药/锭 + 绿装 + 武器）。

- **站长判断**："魔铁宝箱出的是 35 级物品……每个等级的宝箱应该出的东西越来越好才对。"
- **按物品等级审计全部 158 个宝箱类模板**（参数：lootid 展开参考组后的物品 ilvl / RequiredLevel）：

  | 宝箱 | lootid | 物品数 | ilvl 中位 | 需求等级中位 | 判定 |
  |---|---|---|---|---|---|
  | Bound/Solid Adamantite Chest | 21261/21280/21281 | 86-172 | **114-120** | 68-70 | ✓ 外域高档 |
  | Heavy Fel Iron / Adamantite Bound / Felsteel | 22342/22984 | 232 | **108** | 66 | ✓（参考组 61000/60446/50604/42005） |
  | Solid/Bound Fel Iron Chest | 21260/21278/21279 | 200 | **96** | 62 | ✓（参考组 50604/42002/42001） |
  | **Fel Iron Chest（181798）** | 181798 | 436 | **57** | **52** | ❌ **旧世界档**（= 断线后的降级表，见下"根因"） |
- 181798 明细：**6 行 ilvl<40**（Silk Cloth / Iron Ore / Mana Potion / Heavy Hide / Greater Healing Potion / Bolt of Silk Cloth）、
  **71 行 ilvl 40-59**（Mageweave / Mithril Ore / Dreamfoil / Golden Sansam / 各种附魔与裁缝图纸…）、仅 13 行 ilvl 60-79；
  它用的 6 个参考组（60008/60198/60274/60334/60445/60446）也都是 **ilvl 51~65** 档。
- **三方一致**（本库 = `tbcmangos_orig` = `tbcdb_ref`）⇒ **上游 DB 的历史遗留错误**，不是我们改的。
- ~~修法（待批，纯静态数据）：把 181798 换成同级结构（参照 `22342` 或 `22984`）~~ ← **已被下面的"根因/修法"取代**：不需要重写表，把线接回 `9933` 即可（低档行是当年抄表抄坏的产物）。
- 次要可疑（待复核）：`184716 Coilskar Chest`（中位 70、23% 低档）、`187892/188124 Ice Chest`（含 ilvl 1 行）。

### 根因（站长判断成立）：不是"表写错"，是**线接错了**

站长原话："既然这个箱子写错了，应该有一个原本给它准备的掉落表没写过去，只要找到这个 id 把线连上就行。" —— 核实结果：

- 本库 / `tbcmangos_orig` / `tbcdb_ref`：181798 的 `gameobject_template.data1 = 181798`（**自引用**），表内容是把 9933 拍平出来的独立百分比 + 64 条 0.01% 死行；
- ✅ **`wotlkmangos`（cmangos 官方 WotLK 库）：同一个 GO 181798 接的是 `9933`**；
- ✅ `9933` 在我们库里**存在且完整**（497 行，被 `153454 Solid Chest` 使用）：组 4 = 6 种食物（**必出一件、1/6 等概率**）、组 2 = 梦叶草/黄金参/山鼠草/真银锭（必出一件）、组 1 = 307 件绿装池、组 3 = 48 件武器池、组 0 = 131 条独立概率行；
- 🔑 **铁证**：181798 那 64 条 0.01% 死行的物品（Recipe: Limited Invulnerability Potion、Formula: Enchant Gloves - Riding Skill、Plans: Thorium Armor…）**正是 9933 组 0 里 0.5% 的同一批** ⇒ 当年是"把 9933 抄成 181798 并把概率写坏（0.5% → 0.01%）"。
- 全库扫描（本库 vs `wotlkmangos` 的 `type=3` 容器 `data1` 差异）：除 181798 外只剩 `153462 Large Solid Chest`（本库 0、wotlk 接 9934），
  但**本库 `gameobject` 表里 153462/153463/153464 一个刷点都没有**（wotlk 里也只有 153463 刷 3 个）⇒ **零影响，不动**。
  其余差异（Ancient Gem Vein 22046 vs 26862、Ice Chest 23324 vs 187892、Brightly Colored Egg…）都是 **WotLK 专属 lootid、本库不存在** ⇒ 属资料片差异而非断线。
- 已排除的疑似（**误报，不记入待修**）：`184716 Coilskar Chest` 的 `data1 = 21717`，**与 wotlk 完全一致**（表也在，13 行）⇒ 低档内容是上游数据，不是断线；`187892/188124 Ice Chest` 在 wotlk 里就是自引用 `187892`。

### 修法（`dev/102_FelIron宝箱掉落接线_181798指向9933.sql`）

```sql
UPDATE `gameobject_template` SET `data1` = 9933 WHERE `entry` = 181798 AND `data1` = 181798;
```

- 一行、全静态、幂等（带 `AND data1 = 181798`）；回滚 `~~dev/rollback/102_回滚_FelIron宝箱接线还原.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`。
- 本地验证：改前 `181798→181798` → 应用后 `181798→9933` → 复跑无变化 → 回滚回 `181798` → 再接线 `9933` ✓。
- 生效：`gameobject_template` / 掉落表在 mangosd 启动时载入 ⇒ **需重启**（云端干跑 `would apply 102`，随 04:06 nightly 应用并重启生效）。
- 效果：魔铁宝箱变成"**必出一件食物 + 一件草药/锭 + 一件绿装 + 一件武器 + 独立概率的药水/布/稀有图纸**"，与站长给的清单吻合。

## [机制] 「某单位死亡 → 周围单位脱战/逃跑/变友善/消失」设计全量普查 —— 2026-09-22（分析，未改）

起因：站长报 17058「伊利达雷工头」死亡后，附近的德莱尼苦工应当**脱战并变友善**；站长要求"我们有很多类似的设计，检查所有的这些"。

### 一、这套机制怎么运作（先立判据）

除了脚本（ScriptDevAI）直接写逻辑，DB 里有一条**通用的"广播—接收"链路**：

1. **抛出方**：死者的 `creature_ai_scripts` 里 `event_type = 6 (EVENT_T_DEATH)`，动作 `ACTION_T_THROW_AI_EVENT = 45`，参数 = `(事件号, 半径, 目标)`；
   `CreatureEventAI::JustDied()`（`CreatureEventAI.cpp:1528`）→ `ProcessAction` case 45（同文件 `1178`）→ `SendAIEventAround(事件号, target, 0, 半径)`。
2. **事件号取值**（`AIDefines.h:22`）：`0=JUST_DIED、1=CRITICAL_HEALTH、2=LOST_HEALTH、5/6/8/9/10/11=CUSTOM_EVENTAI_A/B/C/D/E/F`。
   ⚠️ **事件号是全局槽位，不是私有通道**：`半径` 才是隔离手段；离线判定"谁会被影响"必须**按生成点距离算**，不能只看 `event_param2`（`event_param2 = 0` 表示"任意发送者"）。
3. **接收方**：`event_type = 30 (EVENT_T_RECEIVE_AI_EVENT)`，`event_param1 = 事件号`，`event_param2 = 发送者 entry`（0 = 任意）；
   `CreatureEventAI::ReceiveAIEvent()`（`CreatureEventAI.cpp:1599`）只做两件事：匹配事件号 + 匹配发送者 entry。
4. **常用"脱战类"动作**：`24 EVADE`（`param1=1` 只停战 `CombatStopWithPets`、`0` 走完整 `EnterEvadeMode`）、`25 FLEE`（`DoFlee()` → `SetInPanic`，**恐慌乱跑但仍在战斗**）、`2 SET_FACTION`、
   `36 UPDATE_TEMPLATE`（`UpdateEntry` 会 `setFaction(新模板的 Faction)` ⇒ **换模板 = 换阵营 + 换模型/等级**）、`41 FORCE_DESPAWN(延迟ms)`、`14 THREAT_ALL%(-100)` 清仇恨。
5. **相位（phase）闸门**（关键坑）：`event_inverse_phase_mask` 是**反掩码**，`mask & (1<<当前相位)` 为真 ⇒ 跳过（`CreatureEventAI.cpp:300`）。
   例：`mask=3` = 相位 0、1 都不跑 ⇒ **只有相位 ≥2 才跑**；`mask=5` = 相位 0、2 不跑 ⇒ 相位 1 跑。
   相位在**死亡时**被清 0（`JustDied` 末尾 `m_Phase = 0`），`Reset()`（闪避/回巢）**不清相位**。

### 二、普查结果（本地全量 19,373 行 `creature_ai_scripts`）

- **死亡触发（event_type=6）且带 THROW 的行：14 条**。按"死者生成点 ↔ 接收方生成点"最短距离与半径对照：

  | 死者 | 名称 | 事件/半径 | 接收方（半径内） | 接收方动作 | 判定 |
  |---|---|---|---|---|---|
  | 17058 | Illidari Taskmaster | 6 / 15 | Dreghood Geomancer d=0.9、Dreghood Brute d=1.9 | `FLEE + EMOTE0 + SET_PHASE 2` →（相位≥2 的通用计时器行）`UPDATE_TEMPLATE→Fleeing Dreghood + THREAT-100% + 9 秒后 FORCE_DESPAWN` | ✅ 设计完整（详见下） |
  | 17959 | Coilfang Slavehandler | 6 / 25 | Wastewalker Slave d=8.9、Wastewalker Worker d=5.3 | `EVADE(0) + RELAY_SCRIPT(5470001) + THREAT_ALL%(-100)`（相位 1） | ✅ **本服"解放奴隶"标准范式** |
  | 22963 | Bonechewer Worker | 5 / 50 | Bonechewer Taskmaster d=1.7、Dragonmaw Wyrmcaller d=20.2 | `CAST(40845)+TEXT_NEW+SET_PHASE 2` / `TEXT_NEW` | ✅ |
  | 15937 | Mmmrrrggglll | 5 / 225 | Grimscale Murloc/Oracle/Forager/Seer（5~51 码） | `CAST(26661)`（小鱼人逃散） | ✅ |
  | 7156 / 9462 / 12380 | Deadwood Den Watcher / Chieftain Bloodmaw / Unliving Resident | 0 / 25、25、20 | Deadwood Avenger d=5.7/8.3、Unliving Caretaker d=9.7 | `CAST(8599 狂暴) + TEXT(1151)` | ✅ |
  | 18322 | Sethekk Ravenguard | 5 / 20 | Sethekk Ravenguard d=0.0（自身） | `CAST(34970)` | ✅ |
  | 20138 | Culuthas | 6 / 25 | Image of Socrethar d=19.8 | `SET_PHASE 2` | ✅ |
  | 15449 / 15620 / 25948 | Hive'Zora Abomination / Hive'Regal Hunter-Killer / Doomfire Shard | 9、8、0 / 200、200、100 | 铁炉堡旅/卡巴尔教徒等（**但死者自身在本库没有刷点**） | 各族脱战/消失 | ⚠️ 死者是召唤物（AQ/太阳井），脚本本身没错，只是**场上永不出现** |
  | 9257 | Scarshield Warlock | 5 / 40 | 接收方 `9707 Scarshield Portal`（**召唤物，无静态刷点**） | `FORCE_DESPAWN` | ⚠️ 无法离线判定（召唤物） |
  | 17678 | Sironas | 5 / 10 | 接收方在 **cpp**（`bloodmyst_isle.cpp:198`），DB 内无 | — | ⚠️ 属脚本侧 |

- **接收方动作含"脱战/消失/变友善"的行：26 条**（含非死亡触发）。除上表外还有：
  1779905 Dreghood Slave（`EVADE+RELAY 5450002+清仇恨`，由 17805 CC 时的事件 7 触发）、1544105/1544205 铁炉堡旅（`FORCE_DESPAWN 20s`）、
  2066625 刀刃山宝珠触发器、2150307 日怒术士 `SET_FACTION(1826)`、495103/495201 塞拉摩练习假人（`EVADE`）、277501 刺脊掠夺者、2360204 叛逃煽动者 等。
  其中标注"DB 内没有对应抛出行"的，是**由 ScriptDevAI/核心抛事件**（如 `AI_EVENT_GOT_CCED`、`AI_EVENT_JUST_DIED` 由 `CreatureEventAI.cpp:1534` 自动广播），不是断链。

### 三、结构性问题扫描（全库）

| 检查项 | 结果 |
|---|---|
| 接收行所在模板 `AIName` 不是 `EventAI`（脚本永不执行） | **0 条**（加载器 `CreatureEventAIMgr.cpp:1114` 会报错，云端 `EventAIErrors.log` 也无此类行） |
| 接收行模板/guid 不存在 | 仅 `5550xxx` 一族 guid 脚本（历史遗留，云端加载日志同样报 `have missing dbguid`，**脚本本身是死的**，与本主题无关） |
| THROW 行引用的 entry/spell 不存在 | **0 条** |
| **相位不可达**（`mask` 要求的相位永远到不了 ⇒ 死行） | 全库 **150 行**（如 Perry Gatner 的"Phase 3"若干行、Race Master Kronkrider 441903/441904）；**本主题的链条 0 行**（自写工具 `_agent_tmp/eai_phase_reach.py` + `death_flee_audit.py`） |

### 四、17058 这条到底怎么回事（结论：设计是完整的、且是上游原样）

- 链路（云端库与本地库逐字段一致，`tbcmangos_orig`/`tbcdb_ref` 也一致 ⇒ **不是我们改坏的**）：
  `1705802`（死亡）`CAST 29460 + THROW(6, 半径15)` → `1693701/1693802`（接收）`FLEE + EMOTE0 + SET_PHASE 2`
  → `1693702/1693803`（`mask=3`，即相位 ≥2 的通用计时器）`UPDATE_TEMPLATE→20157/19477 + THREAT_ALL%(-100) + FORCE_DESPAWN(9000)`。
- **几何上必定触发**：17 个工头刷点，每个都有苦工在 **10 码内**（最近距离 0.9~9.2 码），半径 15 足够。
- **阵营上确实变友善**：`Fleeing Dreghood Geomancer/Warrior`（20157/19477）模板 Faction = **774**；查本地 2.4.3 `FactionTemplate.dbc`：**`774` 的 `enemyMask = 0x0`（对玩家无敌意）**，`friendMask=0x2`，即**友善**。（AZ 端同一 NPC 用 `35`，也是友善档；两者都可用。）
- **与"解放奴隶"范式的唯一差别**：17058 用的是 `FLEE`（恐慌乱跑，**仍在战斗中**），而不是 Coilfang 那套 `EVADE + 清仇恨`；"脱战"实际由**下一秒的换模板行**完成。
  ⇒ 因此如果你在游戏里看到"苦工没有立刻脱战/仍在打我"，属于**动作选型差异**而非断链。
- AZ 对照：`acore_world.smart_scripts` 里 17058 死亡脚本是 `UPDATE_TEMPLATE 19477 + SET_FACTION 15 + SET_EMOTE_STATE + EVADE + 随机移动 + 10 秒消失`（意图相同），但其 `target_type = 9`（= 随机敌对**玩家**）明显是脏数据 ⇒ **AZ 的那份不能照抄**。

### 五、站长 2026-09-22 游戏内实测反馈 → 真因找到：**工头在巡逻，15 码半径大半时候够不着**

站长原话："没有变友善，只是脱战一次，我还是能打他。"⇒ 补查发现两个此前没看的点：

1. **只有 16937/16938 会被这条广播命中**：本库 `event_param1 = 6` 且 `event_param2 ∈ {0, 17058}` 的接收行共 46 条，
   逐一按生成点比对，**半径 15/25/30/40/60/100 都只有这 2 行落在范围内** ⇒ 提半径**没有副作用**。
2. **17 个工头里有 2 个在巡逻**（`creature_movement` 有路径：guid **59461** 8 点、**59464** 9 点；其余 15 个是静止刷点，
   苦工全部静止）——巡逻圈到最近苦工的距离**最远 34.2 / 34.4 码**：
   | 半径 | 59461 命中巡逻点 | 59464 命中巡逻点 |
   |---|---|---|
   | 15（原值） | **2 / 8** | **3 / 9** |
   | 25 | 5 / 8 | 6 / 9 |
   | **40** | **8 / 8** | **9 / 9** |
   ⇒ **在巡逻圈外侧击杀工头 = 附近苦工完全没反应**，这正是"时灵时不灵 / 没变友善"的来源；
   而"脱战一次"是玩家把苦工拉出拴绳后的常规归位。
3. 另：每个工头只"约束"自己那 **1~3 个**苦工（37 个苦工里 34 个能被某个工头覆盖），营地其余苦工本来就不该响应 —— 设计如此。

### 六、落地（**一份**静态 SQL 覆盖家族全部改动，已本地验证 + 已推云端，随夜间窗口生效）

> ⚠️ 2026-09-22 站长要求"同类 SQL 整合到一起"：原先拆成 `dev/103`（17058 动作）+ `dev/104`（17058 半径）+ `dev/106`（17805 补链）
> 三份，现已**合并为一份 `dev/103_工头与奴隶主死亡解放奴隶.sql`**（三项工作同属"工头/奴隶主死亡 → 奴隶脱战变友善"），
> 旧的 103/104/106 三份及其回滚件已从本地与云端删除；队列因此变成 **102 → 103 → 105**。

| 文件 | 覆盖内容 | 本地验证 |
|---|---|---|
| `dev/103_工头与奴隶主死亡解放奴隶.sql` | ① 17058 接收动作：`25 FLEE(0)` → `24 EVADE(0)`、`5 EMOTE(0)` → `2 SET_FACTION(35)`（`action3 22 SET_PHASE(2)` 不变）；② 17058 死亡广播半径 15 → **40**；③ 17805 新增死亡抛事件 6 / 半径 30；④ 17805 新增仇恨抛事件 5 / 半径 30；⑤ 17799 新增接收行：`EVADE(0)` + `SET_FACTION(35)` + `RELAY(5450002)` | 应用=成品态（对已修库 0 行变更）、全量回滚可回上游原样（25/0+5/0+22/2、半径 15、三行消失）、再应用恢复 ✔ |

- 效果：击杀工头/奴隶主 → 40 码内（含巡逻全圈）的奴隶**立刻脱战 + 立刻变友善**（不再依赖"下一秒换模板"），
  随后原有链路仍跑（换 `Fleeing Dreghood` 模板 + 清仇恨 + 9 秒后消失）。
- 回滚：`~~dev/rollback/103_回滚_工头与奴隶主解放奴隶.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`（一次还原全部五项）。
- ⚠️ 教训：**"事件广播半径"必须对照"刷点的移动方式"验算** —— 静止刷点用生成点距离就够，
  巡逻怪必须用**整条路径**逐点验算，否则会漏掉"最远处永远够不着"这一类失败。

## [机制] EventAI「相位不可达」死行普查 —— 2026-09-22（全库 19,373 行 → 47 行）

> ✅ **站长定案（2026-09-22）**："看起来无所谓"，随 nightly 直接上线（未单独验收）。

站长要求把上一条普查里发现的"相位死行"扫一遍。方法：写了个离线可达性工具
`_agent_tmp/eai_phase_reach.py`（数据源 `_agent_tmp/ai_all.tsv` = 全量 `creature_ai_scripts`，报告 `eai_phase_reach.md`）：

- **判据**：`event_inverse_phase_mask` 是**反掩码**，`mask & (1 << 当前相位)` 为真就跳过（`CreatureEventAI.cpp:300`）；
  `m_Phase` 初值 0（`CreatureEventAI.h` / 构造函数），**只在死亡时归零**（`JustDied` 末尾），`Reset()` 不清相位。
  于是从相位 0 出发做 BFS（`SET_PHASE 22` / `INC_PHASE 23` / `RANDOM_PHASE 30` / `RANDOM_PHASE_RANGE 31` 都算转移），
  任何"要求的相位永远到不了"的行就是**死行**。⚠️ 两个坑：① `MAX_PHASE = 32`（`CreatureEventAI.h:34`），
  掩码是 32 位，别按 16 相位猜；② 反掩码里 `65535 = 0xFFFF` 只屏蔽相位 0-15，**不是"永远屏蔽"**。
- **同一 guid 的 `-guid` 脚本与该 guid 的 entry 脚本是同一个 AI 实例**，必须合并后再算相位（合并前 150 行、合并后 47 行）。

**结果（47 行，3 个真问题 + 1 批历史残留）**：

| entry | 名称 | 行数 | 症状 | 三个库是否一致 |
|---|---|---|---|---|
| **19228** | **Perry Gatner**（说笑话的 NPC，map 530 有 1 个刷点） | **40** | 出生行 `1922801` 是 `RANDOM_PHASE(1, 2, 1)` ⇒ 相位只可能是 **1 或 2**；但"Phase 3"那一整套段子（`1922882~19228121`，掩码 7 = 只在相位 ≥3 跑）**永远不播** | ✅ 本库 = `tbcmangos_orig` = `wotlkmangos` **完全一致**（上游数据 bug，不是我们改的） |
| **18875** | **Zaxxis Raider**（虚空风暴） | 2 | `1887501`（掩码 5 = 相位 1/3…跑，设相位 2）与 `1887502`（掩码 3 = 相位 ≥2 跑，设相位 1）**互相等对方先跑**，而初始相位是 0 ⇒ 两条都永不执行，表情循环完全没生效 | ✅ 三库一致（上游） |
| **4419** | **Race Master Kronkrider**（赛车场播报员） | 2 | `441903/441904`（掩码 3 = 需相位 ≥2）永远不跑；**而且**发送者 `4251 Goblin Racer` / `4252 Gnome Racer` **在本库没有刷点、其 EventAI 也从没抛过事件 5/6** ⇒ 即使修掩码也不会响 | ✅ 三库一致（上游） |
| 16424 / 16425 / guid -5320412 | Spectral Sentry / Phantom Guardsman | 3 | 历史残留的**按 guid 脚本**：这些 guid 只留了 OOC 行，没有对应的接收行（相位 1 由**别的 guid** 的行设置）⇒ 不影响场内表现 | — |

**可选修法（都是一行静态 SQL）**：

| 方案 | SQL 要点 | 效果 | 状态 |
|---|---|---|---|
| Perry Gatner | `1922801` 的 `action1_param3` 由 `1` 改成 `3`（即 `RANDOM_PHASE(1,2,3)`） | 三套段子各 1/3 概率播出，40 行死行全部复活 | ✅ **已改（`dev/105`）** |
| Zaxxis Raider | `1887502` 的 `event_inverse_phase_mask` 由 `3` 改成 `2`（允许在相位 0 起跑） | 表情循环 `相位0→2→1→2…` 正常运转 | ✅ **已改（`dev/105`）** |
| Kronkrider | 不修（发送侧根本没抛事件）或改掩码 `3→1` 只做数据整洁 | 场上无差别 | ⏸ 不改 |

- **`dev/105_修两处相位死行.sql`**（+ 回滚 `~~dev/rollback/105_回滚_两处相位死行还原.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`）：站长 2026-09-22 定案修前两项。
  本地验证：`1922801` p3 `1→3`、`1887502` 掩码 `3→2`；复跑 0 行；回滚可还原；再应用成功；
  **复算后全库死行 47 → 5**（残留：Kronkrider 2 行 + 16424/16425/-5320412 三个 guid 残留行，均已判定为无影响）。
- 复用手法：以后凡"某段 EventAI 行为在游戏里从来不出现"，**先用相位可达性工具扫一遍**（比在游戏里试快得多）。
  工具运行：`python _agent_tmp/eai_phase_reach.py`（依赖 `pos_all.tsv` 做 guid→entry 归一）。

## [机制] 「工头死亡 → 解放奴隶」家族全量普查（站长："类似的工头死亡还有很多 npc"）—— 2026-09-22

> ✅ **站长本地验收通过（2026-09-22）**：赞加沼泽 17058（40 码内苦工立刻脱战 + 绿名）、蒸汽地窟 17805（死亡后奴隶脱战 + 变友善）均符合预期。

方法（工具 `_agent_tmp/slaver_census.py`，报告 `slaver_census.md`）：
按名字取「奴隶主/工头型」（taskmaster / slaver / slavedriver / slavemaster / slavehandler / enslaver / slavener / overseer / slave master，共 70 个 entry）
× 「奴隶/苦工型」（slave / drudge / peon / worker / captive / wrekt / dreghood / enslaved / prisoner / laborer / miner，共 205 个），
**按生成点距离 ≤60 码同图配对** ⇒ **26 组"工头 × 附近奴隶"**；再对每组查三样证据：
① 工头有没有"抛事件"行（EventAI `ACTION_T_THROW_AI_EVENT=45`）或 dbscripts 的 `SCRIPT_COMMAND_SEND_AI_EVENT=35`；
② 奴隶有没有对应接收行；③ **AZ 端（`acore_world.smart_scripts`）同 NPC 有没有"解放"脚本**（只有 AZ 有，才算零售行为，才值得我们补）。

### 结论：TBC 里"打死工头 → 解放奴隶"只有 3 处，我们已全部覆盖

| 工头 | 场景 | 我们库的状态 | AZ 端证据 |
|---|---|---|---|
| **17058 Illidari Taskmaster** | 赞加沼泽 | ✅ 完整（死亡抛事件 6，半径 15→**40**；奴隶 EVADE + 变友善）—— `dev/103` | 死亡脚本 = 换 Fleeing Dreghood 模板 + 改阵营 + 逃脱 |
| **17959 Coilfang Slavehandler** | 盘牙水库·**奴隶围栏**（map 547 = CoilfangDraenei） | ✅ 完整（仇恨抛事件 5 → 奴隶改阵营 16；死亡抛事件 6 → 奴隶 EVADE + 中继 + 清仇恨） | On Aggro → Set Data 2 2；On Death → Set Data 1 1（解放） |
| **17805 Coilfang Slavemaster** | 盘牙水库·**蒸汽地窟**（map 545 = CoilfangPumping，站长 2026-09-22 点名"这里也有一个类似事件"） | ❌ **断链**（17799 奴隶监听事件 5/7，但 17805 从不抛事件、也没有 dbscripts）⇒ 打死它奴隶照旧打你 | **On Just Died → Set Data 2 2（"Free Stored Slaves"）**；On Aggro → "Assist me slaves!" ⇒ 本题成立 |

- **`dev/103_工头与奴隶主死亡解放奴隶.sql`**（一份文件覆盖上表 17058 + 17805 的全部改动；回滚 `~~dev/rollback/103_回滚_工头与奴隶主解放奴隶.sql~~（2026-09-22 删：验收通过的 SQL 不留回滚件）`）：
  站长 2026-09-22 定案，并按要求把同类改动**合并成一份**（原 103/104/106 三份已删）。文件内含五项：
  ① 17058 接收动作 `FLEE+EMOTE` → `EVADE+SET_FACTION(35)`；② 17058 死亡广播半径 15 → 40；
  ③ `1780511` = 17805 死亡时抛事件 6 / 半径 30；
  ④ `1780512` = 17805 仇恨时抛事件 5 / 半径 30（对齐 AZ 的 "Assist me slaves!"，让原本永远跑不到的 `1779903` 复活）；
  ⑤ `1779907` = 17799 收到"事件 6 / 来自 17805" → `EVADE(0)` + `SET_FACTION(35)` + `RELAY(5450002 逃跑喊话)`，
     掩码 0（原事件 7 那两条是掩码 1 = 只在相位 ≥1，死亡瞬间可能还在相位 0）。
  本地验证：应用（对已修库 0 行变更）→ 全量回滚回上游原样 → 再应用恢复 ✔。

### 其余 23 组为什么**不动**

1. **"奴隶来帮忙"型（不是解放）**：赞加沼泽的纳迦 `18086 Darkcrest Taskmaster / 18089 Bloodscale Slavedriver / 19946 Darkcrest Slaver / 20088 Bloodscale Overseer`
   在**仇恨**时抛事件 5（半径 25），附近 `18122 Dreghood Drudge / 18123 Wrekt Slave` 的反应是 `ATTACK_START`（打攻击工头的人）——
   即"奴隶是帮凶"。AZ 端同 NPC 也没有死亡解放脚本 ⇒ **不是 bug，是设计**。
2. **完全没有任何设计（19 组）**：`79 Narg the Taskmaster`＋科博矿工、`634/4417 Defias`＋矿工、`2977/6606 Venture Co.`＋劳工、
   `5844 Dark Iron Slaver / 8283 Slave Master Blackheart / 14621 Overseer Maltorius`＋黑铁工人/被奴役考古学家、
   `8889 Anvilrage Overseer`（黑石深渊）、`11605/11677`＋冰矿苦工（奥特兰克山谷）、`19397 Mo'arg Overseer`＋甘纳尔苦工、
   `19426 Peon Overseer`、`21808 Illidari Overseer`＋灰舌工人、`23028 Bonechewer Taskmaster`＋碎手苦工（黑庙）、
   `23140/23291`＋龙喉苦工（虚空风暴矿洞）、`23309 Murkblood Overseer`＋穆尔血矿工。
   **AZ 端逐一核对：这些 NPC 只有战斗技能/对话脚本，没有任何"解放"逻辑** ⇒ 都是普通怪，**不要凭空发明**。
   （判断口诀：先看别端有没有同一行为，有才补；没有就是设计如此。）

## [机制] 钓鱼"技能等级不够"：硬编码区域表漏收录 ⇒ 整个区域下不了钩（悲伤沼泽·芦苇海滩实测）—— 2026-09-22（源码改动，本地编译通过）

### 现象与实测数据

站长在**悲伤沼泽 · 芦苇海滩**（钓鱼 225，做「纳特·帕格的钓鱼大师」要钓 Misty Reed Mahi Mahi）**下不了钩**，
客户端提示**"技能等级不够"**。`.gps` 现场：

```
Map:0(东部王国) Zone:8(悲伤沼泽) Area:300(芦苇海滩)
X: -11018.43  Y: -4164.31  Z: -0.395
GroundZ: -0.396755 FloorZ: -0.396755 Have height data (Map: 1 VMap: 1)
Liquid level: 0.000000, ground: -0.396755, type flags 8, status: 4
```
⇒ 地面/水位/液体**完全正常**（水面 0.0 比地面高 0.4 码，status 4 = 站在浅水里）⇒ **不是地形/液体数据问题**。

### 根因（源码里的一个兜底值）

`Spell.cpp` 钓鱼目标分支 `TARGET_LOCATION_CASTER_FISHING_SPOT`（本地 `Spell.cpp:2042` 起）在算完抛钩点后，
用一张**硬编码的「区域 → 钓鱼最低技能」表**当施法门槛：

```cpp
uint32 minimumRequiredSkill = 500; // catch setting for missing cases so its noticable   // ← Spell.cpp:2079
switch (mapId) { case 0: switch (zone) { case 1: case 12: ... case 41: case 139: ... } }
...
if (fishingSkill < minimumRequiredSkill)
    result = SPELL_FAILED_LOW_CASTLEVEL;      // ← 客户端显示"技能等级不够"
```
- **zone 8（悲伤沼泽）不在这张表里** ⇒ 落到兜底 **500** ⇒ 225 < 500 ⇒ 直接拒绝施法 ⇒ **该区域任何技能都下不了钩**。
- 同类的经典区域漏收录还有 `46 燃烧平原(330)`、`36(130)`、`796(130)` 等；经典副本 map 未列出的也一律 500。
  ⚠️ 外域 map 530 **有 `default: 305`**（`Spell.cpp:2223`）⇒ TBC 区域不受这个坑影响，受影响的只有 map 0/1 与未列出的副本 map。

### 修法（`Spell.cpp`）

硬编码表**未收录**（仍为兜底 500）时，回退查 DB 表 `skill_fishing_base_level` —— 与 `GameObject.cpp:1781` 钓鱼掉落**同一张表**：

```cpp
if (minimumRequiredSkill >= 500)
{
    int32 baseSkill = sObjectMgr.GetFishingBaseSkillLevel(area);   // 先子区域
    if (baseSkill <= 0)
        baseSkill = sObjectMgr.GetFishingBaseSkillLevel(zone);     // 再 zone
    minimumRequiredSkill = (baseSkill > 0) ? uint32(baseSkill) : 0u;  // 都查不到就不再拦（原为 500 卡死）
}
```
- 表里已收录的区域**行为完全不变**（只有兜底 500 那一支走新逻辑）⇒ 外域与经典已收录区域零回归。
- 站长现场按新逻辑：area 300 查不到 → zone 8 = **130** → 225 ≥ 130 ⇒ **可以下钩**。
- ✅ **站长本地实测通过（2026-09-22）**：`x64_Debug` 用新二进制 + `.setskill 356 225` + 钓鱼竿，在芦苇海滩**正常抛竿**（原话"可以钓了"）⇒ 不回滚，随 nightly 上线。
- 生效：本地 Release 编译通过；云端源码树保持该修复（md5 `bc831e271148dcec7d765321940e47b5` 与本地一致、保持 CRLF；
  原件备份 `/root/_srcbak_fishing_20260922/` = 修复前版本，如需回滚直接覆盖回去），`NEEDS_BUILD=1` ⇒ 随 04:06 nightly 编译生效。
- ⚠️ 教训：客户端"**技能等级不够**"= 服务端 `SPELL_FAILED_LOW_CASTLEVEL` —— **先找服务端的技能门槛表**，
  别先怀疑水位/地形；`.gps` 的 `Liquid level` 正常就能一眼排除液体问题。

---

## [机制] GameObject「重生时间」被误设成 NODESPAWN：门/按钮/goober 不按 DB 时间重生（上游 e0999474b）—— 2026-09-22（源码改动，本地编译通过）

### 现象
- 部分 GameObject（门/按钮/goober）**不按 DB 里的重生时间走**：被脚本移除/实例重置/用掉后，要么当拍就回来，要么再也不回来。典型受害者是任务/节日物件（战槌监狱门、Fel Cannonball Stack、虚空龙蛋、仲夏彩带柱…）。

### 定位/根因（`GameObject.cpp:947` 修复前的写法）
```cpp
if (!GetGOInfo()->GetDespawnPossibility() && !GetGOInfo()->IsDespawnAtAction() && data->spawntimesecsmin >= 0)
{
    SetFlag(GAMEOBJECT_FLAGS, GO_FLAG_NODESPAWN);
    m_spawnedByDefault = true;
    m_respawnDelay = 0;          // ← DB 的 spawntimesecs 被整条丢弃
    m_respawnTime  = 0;
}
```
- `GetDespawnPossibility()`（`GameObject.h:444`）只有 **DOOR / BUTTON / GOOBER / FLAGSTAND / FLAGDROP** 会按 `noDamageImmune` 返回 false，其余类型恒 true；再叠加 `IsDespawnAtAction()`（CHEST/GOOBER 看 `consumable`）⇒ 命中面就是「`noDamageImmune = 0` 的门/按钮，以及 `consumable = 0` 的 goober」。
- `m_respawnDelay = 0` 还连带把 `IsSpawned()`（`GameObject.h:796`）**恒定为 true**：
  `return m_respawnDelay == 0 || (m_respawnTime > 0 && !m_spawnedByDefault) || (m_respawnTime == 0 && m_spawnedByDefault);`
  ⇒ 这些 GO 永远"处于已刷出状态"，同时 `GO_FLAG_NODESPAWN` 也发给客户端；而 `GO_JUST_DEACTIVATED` 分支里 `if (!m_respawnDelay) return;`（`GameObject.cpp:688`）**根本不排重生**。

### 全库受影响面（本地 `tbcmangos` 实测）
| 类型 | 命中模板 | 命中刷点 | 其中重生时间非 0 |
|---|---|---|---|
| 0 DOOR | 547 | 556 | 548 |
| 1 BUTTON | 214 | 187 | 171 |
| 10 GOOBER | 616 | 1,253 | 1,247 |

合计 **1,972 个刷点**此前被硬当成"永不 despawn"。典型条目：`182484~182503 Warmaul Prison`（纳格兰战槌监狱门，181 秒）、`185861 Fel Cannonball Stack`（正是上游同一处 TODO 注释点名的对象）、`184867 Nether Drake Egg`（181 秒）、`181605 Ribbon Pole`、`180763/180764 Firecrackers`、`182106 Tower Banner`（900 秒）、`181148 Mummified Troll Remains`（60~120 秒）、`186287 Blackhoof Cage`（900 秒）。

### 修复
- 采用上游提交 **e0999474b**（`src/game/Entities/GameObject.cpp`，+12/−22）：删掉该分支，**所有 `spawntimesecsmin >= 0` 的 GO 一律走 DB 的 `spawntimesecsmin/max`**；只有 `spawntimesecsmin < 0`（DB 约定 = 反重生时间）才走 `m_spawnedByDefault = false` 分支。
- 本地对 `e0999474b` 全 3 个 hunk clean apply（GameObject.cpp 命中在 944 行，offset −11）。

### 验证
- 本地 Release 编译通过（新 `x64_Debug\mangosd.exe` md5 `BDFC221C12A182D1A76A5A74A3BF2E8D`），本地测试服已换新二进制，启动 11 秒无新增报错。
- **站长游戏内验收用例（最干净的一条）**：纳格兰 **战槌监狱门 182484~182503**（type 0 DOOR，`data3 = 0`，`spawntimesecs = 181`）——
  它的 go-use 脚本是 `dbscripts_on_go_template_use 182484`：`command 8`（kill credit）→ 3 秒后 `command 18 SCRIPT_COMMAND_DESPAWN_SELF`。
  修复前：`m_respawnDelay = 0` ⇒ despawn 之后不会排重生；修复后：门消失后应在 **181 秒**回来。

### 残留风险
- 门/按钮的**自动关闭**走 `autoCloseTime`（`UseDoorOrButton` → `GameObject.cpp:1391`，`Update` GO_ACTIVATED 分支 `:529`），与本改动无关，不受影响。
- 我们 fork 在 `Use()` 里保留了「非消耗型箱子/goober 用掉后不 despawn」的早退（`GameObject.cpp:653/685`，上游同款语义）⇒ **"用掉后留在原地可再点"的那类 goober 行为不变**；本次变的是"需要消失、并按 DB 时间重生"的那部分。
- 受影响的门/按钮共 743 个刷点，量不小；若站长实测发现某扇门/按钮"该一直开着却关了"或反之，请回报具体 entry + 坐标，可单独把这一个 entry 的 `spawntimesecs` 调整或回滚本提交。

---

## [机制] 34700「过敏反应」只应对玩家控制单位生效（上游 46d9a78d7）—— 2026-09-22（源码改动 + `dev/107`）

### 现象/根因
- 植物园 **Laj（17980）**给自己叠 `34697 Allergic Reaction`（自身 buff），再由 34697 触发 **`34700`** 传染给附近单位。
- 我们库里 `34700`（`spell_template`：`AttributesEx = 2048`、`EffectApplyAuraName1 = 14`、`EffectApplyAuraName2 = 3`）**没有挂任何 SpellScript**：`spell_scripts` 查不到 `34700` 这一行 ⇒ 传染目标不做过滤，连**非玩家控制单位**（Laj 自己的召唤物等）也能吃到，官服只对玩家侧生效。

### 修复（两半，必须一起上线）
1. 代码：`src/game/AI/ScriptDevAI/scripts/outland/tempest_keep/botanica/boss_laj.cpp` 新增
   ```cpp
   // 34700 - Allergic Reaction
   struct AllergicReaction : public SpellScript
   {
       bool OnCheckTarget(const Spell* spell, Unit* target, SpellEffectIndex /*eff*/) const override
       { return target->IsPlayerControlled(); }   // 玩家控制单位才允许被传染
   };
   ```
   并在 `AddSC_boss_laj()` 里 `RegisterSpellScript<AllergicReaction>("spell_allergic_reaction");`
2. 数据：`dev/107_34700过敏反应只作用于玩家单位.sql`
   ```sql
   DELETE FROM `spell_scripts` WHERE `Id` = 34700;
   INSERT INTO `spell_scripts` (`Id`, `ScriptName`) VALUES (34700, 'spell_allergic_reaction');
   ```
   ⚠ 顺序：**代码先于数据**，否则启动日志会报 `Spell 34700 has script spell_allergic_reaction in spell_scripts but script does not exist. Skipping.`（不致命，该行会被跳过）。两者同一夜间窗口上线即可。

### 验证
- 本地 Release 编译通过、启动无 "script does not exist" 报错（对照：库里另一条老问题 `53719 spell_seal_of_martyr_self_damage` 仍在报缺脚本，属既有问题，不在本次范围）。
- 待站长验收：植物园打 Laj，34700 只应压在玩家/玩家宠物身上，不应传到 Laj 的召唤物。

---

## [数据] 上游 spell 数据修正：脱战保留（32578 / 39153）+ 术士 T5 四件套叠层 —— 2026-09-22（`dev/106`）

### 背景
上游 `sql/base/dbc/cmangos_fixes/Spell.sql` 自我们 merge-base（`3e69c84c9`, 2026-08-05）以来有大量增量，**不能整文件覆盖**（会带回一堆无关改动）。逐条核对后，只有下面 3 处对我们是真实的"库内取值不对"，整理成 `dev/106`（全静态、带旧值判据、幂等）。

### 逐条
| 项 | 我们库内现状 | 官方/上游目标值 | 判定 |
|---|---|---|---|
| `32578` Gor'drek's Ointment | `AttributesServerSide = 0` | `\|= 0x04`（`SPELL_ATTR_SS_IGNORE_EVADE`，`SpellMgr.h:498`） | **缺失，已补** |
| `39153` Darkfury | `AttributesServerSide = 0` | `\|= 0x04` | **缺失，已补**（见下方 id 说明） |
| `37401/37402` 术士 T5 四件套服务端光环 | `Attributes = 192`、`AttributesEx5 = 0` | `Attributes = 128`、`AttributesEx5 = 0x20000000` | **缺失，已补** |
| `12579` Winter's Chill | `AttributesEx = 2048` | `\|= 0x800` | 早已满足（`dev/031` 已合） |
| `15167` Windsor's Frenzy / `32912` Windfury / `29363` / `31386` / `32008` / `32732` / `37248` / `38471` / `43119` / `43120` / `43457` | `AttributesServerSide = 4` | 同上 | 早已满足（`dev/031` 已合） |

- **`0x20000000` = `SPELL_ATTR_EX5_AURA_UNIQUE_PER_CASTER`**（`SpellDefines.h:239`，核心在 `Unit.cpp:5370` / `SpellStacking.cpp:420` 读它）⇒ 同一施法者只保留一层，修"T5 四件套无限叠层"；`Attributes 0xC0 → 0x80` 是去掉 `SPELL_ATTR_PASSIVE`、保留 `DO_NOT_DISPLAY`（上游 `921115e06`，与 `140802b54` 是同一处两笔，文件里合并成终态一次写死）。

### ⚠ 上游 id 笔误（`39152` vs `39153`）
上游 `c54fbea31` 提交信息与语句写的是 **`39152`**，但：
- `39152` 在 **我们库和上游库的 `spell_template` 里都不存在**（查无此行）；
- 库里唯一叫 `Darkfury` 的法术是 **`39153`**（`Attributes = 65536`，`EffectApplyAuraName1 = 22`）；
- 唯一使用者也正是"会脱战"的那类对象：**creature 21315 Ruul the Darkener（虚空风暴）**，由 `creature_ai_scripts 2131505`（`action1_type = 11 CAST_SPELL`, `action1_param1 = 39153`，注释 "Ruul the Darkener - Cast Darkfury"）在战斗中施放。

⇒ 按上游**意图**（该 buff 不应在脱战时被移除）把标记打在真正存在的 `39153` 上；若站长认为应严格照抄上游（打在不存在的 `39152` 上＝空操作），删掉 `dev/106` 的第 ② 条即可。

### 生效/回滚
- `dev/106_上游spell数据修正_脱战保留与术士T5.sql`（`spell_template` 在 mangosd 启动时载入 ⇒ **需重启**）；回滚件 `dev/rollback/106_回滚_上游spell数据修正.sql`。
- 已在本地库连续执行两次：第二次 0 行变更（幂等）。云端待站长验收后随夜间窗口应用。

---

## [机制] 战斗日志协议补全：`SMSG_ATTACKERSTATEUPDATE`（上游 0d2ebc3ee）—— 2026-09-22（源码改动，本地编译通过）

### 改了什么（`Unit.h` / `Unit.cpp` / `Spell.cpp`，+121/−43）
1. `CalcDamageInfo`：`blocked_amount → blockedAmount`，新增 `meleeSpellId`（下次挥击法术 id）、`attackerState`；`HitInfo` 位名整理（`HITINFO_BLOOD_SPURT = 0x2000` 等）。
2. **下次挥击类法术**（`SPELL_ATTR_ON_NEXT_SWING` / `_NO_DAMAGE`，如英勇打击、重殴、猛禽一击）现在也会发一条 `SMSG_ATTACKERSTATEUPDATE`，并把法术 id 带进包（客户端战斗日志因此能正确显示这一击）。
3. **血花喷溅**改为"重击才算"：`cleanDamage > target->GetHealth() * 25 / 100` 时置 `HITINFO_BLOOD_SPURT`（`Unit::CalculateMeleeDamage` 末尾）。
4. `SendAttackStateUpdate` 从 `CalcDamageInfo*` 改成 `CalcDamageInfo const&`（顺带 codestyle）。

### 验证
- 本地 Release 编译通过、本地测试服启动正常。
- 待站长验收：打怪时战斗日志里**英勇打击/重殴**这类"下次挥击"技能应出现挥击条目；血花只在大额伤害时出现。

### 残留风险（上游自身的小瑕疵，未改，先记录）
- `Spell.cpp::_handle_immediate_phase()` 里新增的 `CalcDamageInfo dmgInfo;` **未整体清零**，只逐字段赋值了 `subDamage[0]`；而 `SendAttackStateUpdate` 是按 `m_weaponDamageInfo.weapon[attackType].lines`（可 >1，多段伤害武器）循环发包的 ⇒ 多段武器偶发可能带上未初始化字段。上游 HEAD 至今也是这个写法（已确认），故本次**保持与上游逐字节一致**；若游戏内真出现战斗日志乱码，再把 `CalcDamageInfo dmgInfo;` 改成 `CalcDamageInfo dmgInfo{};` 即可。

---

## [机制] 制造专业「分支技能（专精）」可被囤任务/脚本白拿：学习入口不校验专业 —— 2026-09-22（源码改动，本地编译通过）

### 现象（站长 2026-09-22 报告 + 实测）
- 站长原话：「制造专业的分支技能，最后奖励没有验证专业是否存在，导致可以存下多个专业技能来获得多个专业」；
- **实测复现**：**完成任务后照样拿到了「防具锻造」**（即：接任务时专业还在，交付前把专业退掉，交付仍然给专精技能）。
- 也就是说：**防具锻造/武器锻造/龙鳞制皮/魔焰裁缝/地精工程… 这些"专业技能"可以靠攒任务一次拿好几个**。

### 全库普查：专精/专业技能到底能从哪些路径拿到（这才是关键）
`RewSpell/RewSpellCast` 经一跳（`SPELL_EFFECT_LEARN_SPELL`）指向 `SPELL_EFFECT_TRADE_SKILL` 的任务：

| 专业 | 任务 | 奖励法术 | 任务专业要求 | 发放路径 |
|---|---|---|---|---|
| 制皮 | 5141/5144/5143（联盟）、5145/5146/5148（部落） | 10657/10659/10661 | 165 ≥ 225 | 任务奖励（核心） |
| 裁缝 | 10831/10832/10833 | 26799/26796/26800 | 197 ≥ 325 | 任务奖励（核心） |
| 炼金 | 10897/10899/10902 | 28676/28674/28678 | 171 ≥ 325 | 任务奖励（核心） |
| 工程 | 3639/3641/3643 | 20221/20220 | 202 ≥ 200 | 任务奖励（核心） |
| 烹饪/急救 | 6610 / 6622·6624 | 18261 / 10847 | 185≥225 / 129≥225 | 任务奖励（核心） |

**脚本路径（15 条，全部靠"点 gossip / 交任务"直接给专精，核心原本完全不校验）**：
- `dbscripts_on_quest_end`：`5283 → 9790 防具锻造`、`5284 → 9789 武器锻造`（← **站长实测走的就是这条**）
- `dbscripts_on_gossip`（NPC 的"请让我成为…"选项，cast 学专精包装）：
  `318201 防具锻造`(Myolor Sunderfury 11145 / Krathok Moltenfist 11176)、`318202 武器锻造`、`608901 斧专精`(Kilram 11192)、`609001 锤专精`(Lilith the Lithe 11191)、`609101 剑专精`(Seril Scourgebane 11193)、`705801 侏儒工程`/`705802 地精工程`、`853001 月布`(Nasmara Moonsong 22208)/`853101 魔焰`(Gidge Spellweaver 22213)/`853201 暗影`(Andrion Darkspinner 22212)、`757101 药剂大师`(Lauranna Thar'well 17909)/`854001 药剂大师`(Lorokeem 19052)/`854201 转化大师`(Zarevhi 22427)

### 根因（三条链）
1. **交付阶段无校验**：`Player::RewardQuest` 拿到 `RewSpellCast ?: RewSpell` 后无条件 `CastSpell`；任务的专业要求只在**接任务**时校验（`Player::CanTakeQuest`，`Player.cpp:13016`）。脚本路径更彻底——`dbscripts_on_quest_end` / `dbscripts_on_gossip` 的 `command 15 CAST_SPELL` 完全不经过任务要求。
2. **学习入口不校验**：`Player::learnSpell`（所有学习路径的唯一收口：任务奖励 / 任务脚本 / gossip 脚本 / `spell_learn_spell` / 训练师 / `.learn`）原本对"专精法术"没有任何专业校验。
3. **专精法术本身不带专业信息、收益只看"在不在书里"**：专精法术都是 `Effect1 = 47 SPELL_EFFECT_TRADE_SKILL` 且 `EffectMiscValue1/2/3 = 0`（基础专业技能法术才带技能 id，如 2018 锻造→164）；核心 `Spell::EffectTradeSkill`（`SpellEffects.cpp:4787-4794`）是**空实现**；而制造加成判定 `canCreateExtraItems()`（`Skills/SkillExtraItems.cpp:134`）**只查 `HasSpell(专精法术)`**。所以只要法术进了法术书就一直生效。

### 数据侧原本有的防线（本次核实，之前误判过，特此更正）
库里 **gossip 的"学专精"选项其实是有复合条件的**（type `-1` 的条件组，子条件里正是此前被误判为"悬空"的 169/170/10999/11000/922-924 等）：
- `20492`：`NOT(已学 9788 或 9787) AND 锻造 ≥ 225 AND (5283/5284 或 5301/5302 已奖励)` ⇒ 防具/武器锻造只能选一个
- `20479`：`NOT(已学 17039/17040/17041) AND 等级 ≥ 50 AND 锻造 ≥ 250 AND 已学 9787(武器锻造)` ⇒ 剑/斧/锤大师需要武器锻造且三者互斥
- `11004`：`NOT(已学 20219 或 20222) AND 已奖励 3639/3641/3643 AND 工程 ≥ 200`
- `937`：`已奖励 10831/10832/10833 AND 裁缝 ≥ 350 AND NOT(已学三系之一)`
- `262`：`NOT(已学三系之一) AND 已奖励 10897/10899/10902 AND 炼金 ≥ 350 AND 等级 ≥ 68`

⇒ **gossip 路径本身是严的；漏的是"任务奖励"和"任务脚本"这两条核心路径**（以及"退掉专业后再交付/再点"这个时间差——条件只在点击那一刻算，任务却是先接后退专业）。

### 修复（两层，`src/game/Entities/Player.cpp`）
1. **学习入口兜底（主修，覆盖全部路径）**：`Player::learnSpell` 开头新增静态辅助 `GetSpecializationProfessionSkill(spellId)`：
   - 判定"是不是专精法术"= 有 `SPELL_EFFECT_TRADE_SKILL` 且 `EffectMiscValue*` 全为 0，且 `spell_chain.first` 指向别的法术（如 9788 → 2018）；
   - 父专业技能 = `spell_chain.first` 那个基础法术的 `EffectMiscValue2`（9788 → 2018 → 164）；
   - 若玩家该技能为 0 ⇒ **拒绝学习** + `sLog.outError("... tries to learn profession specialization spell %u without profession skill %u.")`。
   - 离线核对：Effect 47 且 misc 全 0 的法术只有 18 个——16 个真专精 + `2656 Smelting`、`2842 Poisons`（这两个没有 `spell_chain` 行 ⇒ 函数返回 0，**不受影响**，贼的毒药任务照旧）。
2. **任务交付校验（第一层，先前已提交）**：`Player::RewardQuest` 里奖励法术若给制造专业技能（`GrantsProfessionTradeSkill`）而玩家已不满足本任务的 `RequiredSkill` ⇒ 跳过奖励法术并记日志（物品/金钱/声望照给）。

### 验证
- 本地 Release 编译通过（`x64_Debug\mangosd.exe` md5 `9EFAD45204DDD4E3D24D8698D760D4AD`），本地测试服已换新二进制并正常启动（8086 监听）。
- **站长验收步骤**：
  1. `.setskill 164 0`（清掉锻造）→ `.learn 9788`（防具锻造）⇒ **学不到**，日志出现 `tries to learn profession specialization spell 9788 without profession skill 164`；
  2. `.setskill 164 300` → `.learn 9788` ⇒ 正常学到；
  3. 重跑你原来的复现（接分支任务→退专业→交付）⇒ 应该拿不到专精了。
- ⚠️ **踩坑记录**：`Player.cpp` 是 UTF-8 无 BOM 而 MSVC 按 GBK 读，第一版中文注释里一个字节把 `*/` 吃掉了，报出一串假语法错误（C2059/C2143，位置还在几百行之后）。**这个文件的新增注释一律写 ASCII 英文**。

### 待办/残留风险
- **同族重复专精（站长 2026-09-22 确认无需再加）**：gossip 路径由复合条件（`20492`/`20479`/`11004`/`937`/`262`）锁着"同族只能一个分支"，任务路径由 `ExclusiveGroup` 锁着；站长实测同族第二个专精没复现出问题，故核心层不再加"已有同族另一分支就拒绝"的判定。
- **二级分支的前置没查**：`.learn 17039`（剑专精）目前只要求"有锻造"，不要求"有武器锻造"（官服要求武器锻造）。gossip 条件 `20479` 已含 `已学 9787`，所以正常玩法没洞；如需核心也兜住，可加 `spell_chain.prev_spell` 判定。
- ⚠ **更正（先前"锻造部落侧少给"是误判，站长实测没复现）**：锻造专精的真正发放口是 **NPC gossip**——联盟 **Myolor Sunderfury(11145, menu 3182, 铁炉堡)**、部落 **Krathok Moltenfist(11176, menu 3187, 奥格瑞玛)**，选项条件 `20492` = `NOT(已学 9788 或 9787) AND 锻造 >= 225 AND (5283/5284 已奖励 OR 5301/5302 已奖励)` ⇒ **部落靠 5301/5302 已奖励 + 这个 gossip 拿专精，根本不缺**。
  而 `dbscripts_on_quest_end 5283 -> 9790 / 5284 -> 9789` 会**额外**直接给专精、且**没有互斥条件** ⇒ 联盟侧两条路都能拿，脚本那条更松（站长复现"交付后仍拿到防具锻造"走的正是它，本次已由学习入口兜住）。若要更干净，可删掉这两条脚本、改用 `quest_template.RewSpellCast`（自动走核心两层校验）。

---

## [数据] 全库「负事件号」刷怪标注整批缺失 ⇒ 奎岛推进阶段后旧敌对 NPC 不再消失 —— 2026-09-23（`dev/108`，本地验证通过）

### 现象（站长 2026-09-23 报告）
- 「现在奎岛开了新的阶段之后，旧的敌对 NPC 不会停止刷新」——黎明刃部队（Dawnblade Blood Knight/Summoner/Marksman）、虚空怪（Irespeaker / Abyssal Flamewalker / Unleashed Hellion）等在阶段推进后仍持续存在。

### 机制：`game_event_creature.event` 允许【负数】（这是本次的关键）
负数行 = **「该刷点存在到事件 N 开始为止」**，是 cmangos 用来做"阶段推进时整批清场"的原生手段：

| 调用 | 效果 |
|---|---|
| `GameEventMgr::ApplyNewEvent(N)`（事件 N 启动） | `GameEventSpawn(N)`（生成正数标注的刷点）+ **`GameEventUnspawn(-N)`（移除负数标注的刷点）** |
| `UnapplyEvent(N)`（事件 N 结束） | `GameEventUnspawn(N)` + `GameEventSpawn(-N)` |

- 载入与索引：`GameEventMgr.cpp:245-290`，`m_gameEventCreatureGuids.resize(m_gameEvents.size() * 2 - 1)`，索引 `m_gameEvents.size() + event_id - 1`，合法性只查 `IsValidEvent(std::abs(event_id))` ⇒ 负数与正数共用同一套事件号空间。
- 奎岛的阶段推进正是靠这套：`WorldState::StartSunsReachPhase()`（`WorldState.cpp:2487`）在阶段 2/3/4 分别 `StartEvent(303 / 306·307 / 310)`，从而触发 `-303 / -307 / -310` 的整批清理。

### 根因：整类数据丢失（不是核心逻辑问题）
- 本库 `game_event_creature` 里 **负数行 0 条**；参考库 `tbcmangos_orig` / `tbcdb_ref` 各 **262 条**。
- 逐行比对（`guid` + `event` 维度）：本库相对参考库 **只少这 262 行、多 0 行**（6819 vs 7081）；262 个 guid **全部**存在于本库 `creature` 表（无悬空），PK 冲突 0。
- 同时比对 `game_event_gameobject` / `game_event_creature_data` / `game_event_mail` / `game_event_quest` / `game_event` 五张表：与参考库**完全一致** ⇒ 只有 `game_event_creature` 这一张表整类丢失，不是零散人为删改。
- 交叉验证：奎岛那 112 行与 **`wotlkmangos`** 的同名行逐行一致（差异 0/0），确认是上游原生数据而非参考库的孤例。

### 修复：`dev/108_奎岛阶段清理_恢复负事件刷怪标注.sql`
- 262 行**逐字取自 `tbcmangos_orig`**（上游数据，非自创）；**全静态**（无 JOIN/子查询/聚合/计算，只有写死字面量）；`INSERT IGNORE` ⇒ 幂等。
- 分组（文件内按事件分段并注释受影响生物）：
  - **一、奎岛 112 行**：`-302`:13、`-303`:19、`-307`:29、`-310`:51（覆盖 Dawnblade Blood Knight/Summoner/Marksman、Irespeaker、Abyssal Flamewalker、Unleashed Hellion，以及几个会被后续阶段替换掉的破碎残阳哨点）
  - 二、同批丢失的其它事件 150 行：`-123` 安其拉第 4 阶段 96、`-27` 夜晚 14、`-26` 啤酒节 14、`-76`~`-84` 暗月马戏团搭建/开张 18、`-12` 万圣节 5、`-100` 暴风前夕 3
- 回滚：`dev/rollback/108_回滚_恢复负事件刷怪标注.sql`（`DELETE FROM game_event_creature WHERE event < 0;` —— 修补前该表负数行为 0，等价还原）。

### 验证（本地，含核心侧实证）
1. 本地库连续执行两次：`262 → 262`（幂等，无报错）。
2. 临时诊断（`GameEventUnspawn()` 内打印负数事件的清理条数与前 6 个 guid），把本地 `world_state` 的奎岛 `phase` 由 0 改成 **2（ARMORY）** 后重启，日志实测：
```
GameEvent 303 "Suns Reach Reclamation Phase 2 Permanent" started.
GameEvent 306 "Suns Reach Reclamation Phase 3 Only" started.
GameEvent 307 "Suns Reach Reclamation Phase 3 Permanent" started.
GAMEEVENT-DIAG: unspawn event -303 -> 19 creatures (map 530), first guids: 5300086,5300087,5300293,...
GAMEEVENT-DIAG: unspawn event -307 -> 29 creatures (map 530), first guids: 5300365,5300460,5300461,...
```
   ⇒ 阶段推进时**实际移除了 48 个刷点**（全在 map 530 奎岛）。修复前这些行不存在 ⇒ 同样的阶段推进移除 **0 个**。
3. 临时诊断代码**已回退**（`git diff src/game/GameEvents/GameEventMgr.cpp` 为空），并重新编译。
4. 待站长验收：本地测试服奎岛阶段已置为 3（ARMORY），进岛看**日境圣所/军械库一带的黎明刃是否已消失**；看完想回阶段一执行
   `UPDATE tbccharacters.world_state SET Data='0 0 0 0 0 0 0 0 0 0 0 0 3 0 0 0' WHERE Id=20;` 再重启即可。

### 生效/回滚
- `game_event_creature` 在 mangosd 启动时载入 ⇒ **需重启**；负数行是在"对应事件被 Apply 的那一刻"执行清理，而奎岛事件由 `WorldState::StartSunsReachPhase()` 在启动时重放 ⇒ 重启即生效。
- 云端随夜间窗口应用；验收通过后再删回滚件（本仓惯例：验收通过的 SQL 不留回滚件）。

### 关联发现（同一次排查的副产品，尚未处理）
- **`game_event_creature_data.vendor_id` 是第二张"借货表"**：`Creature::GetVendorTemplateItems()`（`Creature.cpp:2737`）会用它覆盖 `creature_template.VendorTemplateId`。奎岛铁匠 **25046 Smith Hauthaa** 的 `VendorTemplateId = 0`（所以只查商品表永远查不到），但 `game_event_creature_data(guid 5300787, event 309 铁砧)` 把她的商店指向 **template 505**（57 件 P5 徽章装备，`condition_id` 全为 28024）。全库共 11 条这类覆盖（竞技场赛季军需官、Shaani、Hauthaa）。这条机制与本次修复无关，但它解释了"她自己表里没货却在卖"。
- **真正未过滤的奎岛徽章货在 Kayri(26089)**：`template 554` 有 45 行以公正徽章结算（`ExtendedCost 1015 = 25 徽章` 15 行、`2347 = 40 徽章` 30 行），`condition_id` 全为 0，未按 `dev/054` 的"装等 ≥128 → 28023"上锁。

### 运维教训
- cmangos 的 `game_event_creature` 有**负数事件号**这一整类语义（阶段清场专用），**只比对正数行会漏掉整个机制**；今后做事件/刷点类数据比对，必须显式带上 `event < 0` 维度。
- 参考库（`tbcmangos_orig` / `tbcdb_ref` / `wotlkmangos`）在"整类数据是否丢失"这类判断上是可靠标尺：先做 `guid`+`event` 双向差集，再谈修改。

---

## [数据] 任务目标「1 号槽留空」导致 Questie 整体错位一行 —— 2026-09-23（已定位并备好配方，**站长决定暂不改**）

### 现象（站长报告）
- 日常 **11532《亡者伤痕的骚扰》/ 11533《空袭必须继续》** 在 Questie 里三条击杀目标整体错位：
  显示 `已消灭深渊霸主 0/2`、`已消灭艾瑞达巫师 2/3`、`已消灭天怒执行者 3/12`。
- 站长自诊断："Questie 认为的槽是 123，而不是 234，所以会错位" —— **判断正确**。

### 根因
- 这两条任务的生物/GO 目标占 **2/3/4 号槽**，1 号槽为空：

| 槽位 | 任务侧字段 | 值 |
|---|---|---|
| 生物槽 1 | `ReqCreatureOrGOId1` | **0（空）** |
| 生物槽 2 | `ReqCreatureOrGOId2 / Count2` | 25031 Pit Overlord（深渊霸主） / 2 |
| 生物槽 3 | 3 / Count3 | 25033 Eredar Sorcerer（艾瑞达巫师） / 3 |
| 生物槽 4 | 4 / Count4 | 25030 Wrath Enforcer（天怒执行者） / 12 |
| 物品槽 1 | `ReqItemId1` | 34475 Arcane Charges / 1 |

- 服务端全程按**原始槽号**配对且自洽：`Player::KilledMonsterCredit`（`Player.cpp:14473` 起）按槽号累加、`SendQuestUpdateAddCreatureOrGo(..., j, ...)` 带槽号下发、`character_queststatus.mobcount1..4` 也按槽号存；
  验证：云端 `Everbloom(guid 21)` / `Spicymode(guid 23)` 的 11533 都是 `mobcount=(0,2,3,12)`、`rewarded=1`（跑完的日常，计数留在 2/3/4 号槽）——**服务端没有错**。
- 客户端同样按槽号配对，所以**原生任务日志显示正常**；错位只发生在**假定目标必然占 1..N 连续槽**的插件（Questie）上：它把"压缩后的目标文字"与"按原始槽号取的计数"错配 ⇒ 整体错一行。

### 数据形态核查（不是我们改坏的）
- 该"1 号槽留空"形态在参考库里一样存在：`tbcmangos_orig` 37 条、`tbcdb_ref` 37 条、`wotlkmangos` 43 条、`acore_world`(WotLK) 47 条。
- 全库 37 条的三种形状：`0X00` 28 条（单目标放 2 号槽）、`0XX0` 5 条、`0XXX` 4 条（含 11532/11533/891/905）。

### 决定：暂不改（站长 2026-09-23）
- 2026-09-23 曾按"把目标压实到 1..N 连续槽"生成并本地验证过 `dev/109`（30 条 UPDATE + 1 条角色侧迁移，本地实测：空洞 37 → 7、幂等、重启无报错），站长随后决定 **先不改** ⇒ 本地库已回滚到原形态（空洞 37 条）、`dev/109` 与回滚件已删除，**未上云端**。

### 将来若要改：现成配方（可直接照做）
1. **可安全压实的 30 条**（目标槽自洽，`ReqSpellCast1..4` 与 `ReqSourceId1..4` 全为 0）：
   - 多目标 8 条：`358, 891, 5242, 9594, 10765, 10774, 11532, 11533`
   - 单目标 22 条：`573, 6681, 8995, 9165, 9437, 9683, 10182, 10299, 10321, 10322, 10323, 10329, 10330, 10338, 10365, 10427, 10564, 10598, 10742, 10791, 10806, 11093`
   - 做法：把非空的 (id,count) 按原顺序搬到 1..n 槽，高位清零；`WHERE` 里写死改前四个槽的值 ⇒ 幂等。
2. **7 条暂不动**（`905, 2459, 2994, 10446, 10447, 10855, 11129`）：它们同时带 `ReqSpellCastN` / `ReqSourceIdN`，这些字段**按同一槽号**与生物/GO 目标配对（校验见 `ObjectMgr.cpp:4993` 起、消耗见 `Player.cpp:14767`），挪槽必须四个数组一起挪，需单独核对（例：905 的 `ReqSpellCast2/3/4 = 5316` + `ReqSourceId1 = 5165`，当前就已不自洽）。
3. **角色侧迁移**：动手前处于"进行中"的角色，其计数留在旧槽位（`character_queststatus.mobcountN`），必须同批挪槽，否则进度显示为 0 —— 写死 `guid + quest + 改前计数` 进 `WHERE` 即可幂等（时任云端快照只有 `guid 23 / quest 11093 = (0,3,0,0)` 一条需要迁移）。
4. **生效**：`quest_template` 在 mangosd 启动时载入 ⇒ 需重启。

### 运维教训
- 显示类问题的第一步是**分清"服务端存的对不对"**：直接查 `character_queststatus.mobcount1..4`（按槽号存）就能把责任划清，不必先改数据。
- 插件的隐含假设（"目标一定占 1..N 连续槽"）不等于服务端/客户端约定；**照插件假设去改数据 = 迁就插件**，改与不改都要站长拍板。

---

## [机制] 斯克提斯「鸦爪战士呼救」：卡利鸟只跟着主人跑、不打玩家 —— 2026-09-23（`dev/110`，数据修正，**站长已验收 + 已上云端**）

### 现象（站长报告）
- 斯克提斯鸦爪战士（21650）挨打后把旁边**黄名**小卡里鸟（21804）叫来，但卡利鸟**不攻击玩家**，只跟着鸦爪战士跑；鸦爪战士死后它飞回原位。

### 根因：上游 EventAI 脚本"目标写错"+"中立生物结构上打不了玩家"
| 层 | 事实 |
|---|---|
| ① 呼救方 | `creature_ai_scripts 2165001`（鸦爪战士·进战斗）第 3 动作 = 45 抛 AI 事件：EventType=**5**(`AI_EVENT_CUSTOM_EVENTAI_A`)、Radius=25、**Target=0(TARGET_T_SELF)** ⇒ 事件携带的 invoker 是**鸦爪战士自己** |
| ② 响应方 | `2180402`（卡利鸟·收到发送者 21650 的事件 5）= 55 攻击目标，参数=**10(`TARGET_T_EVENT_SENDER`)** ⇒ 它去攻击**事件发送者=鸦爪战士**（自己的友军）⇒ 打不动，只剩"跟着跑"；主人一死目标消失 ⇒ 飞回家。注释写的是 *"Attack Invoker"*，作者本意确实是打玩家，**参数写错** |
| ③ 硬约束 | 卡利鸟阵营 **1869（中立/黄名）**，而 `Unit::CanAttack` 要求 `IsEnemy(unit) || unit->IsEnemy(this)`（`Relations.cpp:437`）⇒ **中立生物根本无法攻击玩家**，所以只修 ② 的目标只会换个跟随对象 |

- 三库核对：`2165001`/`2180402` 在**我们库、`tbcdb_ref`、`wotlkmangos` 逐字段一致**（上游 TBC-DB 数据）；阵营 1869 在 orig/ref/wotlk/acore 四库也都是 1869。
- 原版线索：客户端法术 **`37520 Skettis Kaliri`（效果 56 SUMMON → 21804）** 存在，但在我们/ref/wotlk/acore 四库**都没有任何使用点** ⇒ 不是"缺数据"，是 TBC-DB 当年用"抛 AI 事件"自造的替代方案写歪了。

### 修复（站长 2026-09-23 决定：**让呼喊改阵营 + 修目标链**，即 `dev/110`）
1. `2165001`：`action3_param3` 0 → **1(`TARGET_T_HOSTILE`)** ⇒ 事件的 invoker = 鸦爪战士当前仇恨目标（把它打进战斗的玩家）。
2. `2180402`：
   - `action1` = **2(`ACTION_T_SET_FACTION`)**，factionId=**1862**（与鸦爪战士同阵营 ⇒ 对玩家敌对、也能被玩家反击），factionFlags=**2(`TEMPFACTION_RESTORE_COMBAT_STOP`** ⇒ 战斗结束自动还原成 1869 黄名，无需额外脚本，见 `Creature.h:593`）；
   - `action2` = **55(`ACTION_T_ATTACK_START`)**，目标=**6(`TARGET_T_ACTION_INVOKER`)** ⇒ 打事件 invoker = 玩家；
   - 动作按 1→2→3 顺序执行（`CreatureEventAI.cpp:657`）⇒ 先切阵营，攻击判定才通得过。
- `AI_EVENT_CUSTOM_EVENTAI_A(5)` 的定义本身就写明 *Invoker = TARGET_T_ACTION_INVOKER*（`AIDefines.h:30`），抛事件时用 `TARGET_T_HOSTILE` 填 invoker 正是它的标准用法。

### 验证（本地）
- `dev/110` 本地应用 + 复跑一次：改后 `2165001` = (…,45,5,…,**1**)、`2180402` = (2,**1862**,2,55,**6**,0)，复跑 0 行变更（幂等）。
- 本地测试服重启后 EventAI 载入 **19,350 条脚本、0 报错**（无 "nonexistent FactionId 1862"，说明 1862 在客户端 FactionTemplate 里有效），启动 10 秒。
- **站长已验收**（本地测试服，斯克提斯）：打一只旁边有黄名卡利鸟的鸦爪战士 ⇒ 卡利鸟**变红冲过来打你**；战斗结束后**变回黄名并飞回原位** ⇒ 2026-09-23 通过。
- 云端已上线数据：`dev/110` 已推送并执行（`/root/.dev_sql_applied` = **110**），云端两行实测为 `2165001 = (…,45,5,…,1)`、`2180402 = (2,1862,2,55,6,0,0,0)`；**生效需等一次重启**（每日 03:00 `/etc/cron.d/mangos_restart` 或 04:06 夜间窗口）。回滚件按惯例在验收通过后已删除（改动内容见本节，可随时重写）。

### 生效 / 回滚
- `creature_ai_scripts` 启动载入 ⇒ **需重启**。
- ⚠️ 本改动**偏离上游数据**（上游三库都是坏脚本），属站长 2026-09-23 明确批准的修正；若上游日后自行修好，可删掉 `dev/110` 文件。

---

## [机制] 飞行路线「会走不同路径」的机制排查 —— 2026-09-23（纯分析，**未改任何东西**）

站长问题：*"检查是否有机制导致了飞行路线有不同的路径。"* 结论：**有 4 条，且都不在数据库数据上（数据库侧只有 `taxi_shortcuts` 一张表参与）**。

### 0. 航线数据来源与选路唯一性
- 航线几何**全部来自 DBC**：`TaxiPath.dbc`(514 行=514 条航线) + `TaxiPathNode.dbc`(13462 个导航点) + `TaxiNodes.dbc`；服务端**没有** `taxi_path*` 数据表，DB 侧唯一影响飞行的是 `taxi_shortcuts`（235 行，本地与云端一致，启动日志 `>> Loaded 235 taxi shortcuts`）。
- `(起点,终点)` → 航线由 `sTaxiPathSetBySource` 决定（`DBCStores.cpp:536-539` 用 DBC 逐行填 map）。实测 514 行里 **`(from,to)` 组合无一条重复** ⇒ 服务端选路**没有歧义**，"同一对起终点飞两条路"在服务端不可能发生。

### M1 中转接缝裁剪 `Tracker::Trim`（**唯一会改变几何形状的机制**）
- `Tracker::AddRoute` 每加一段就裁一次前一段的接缝：`Taxi.cpp:161-163` → `Trim(m_routes[count-2], m_routes[count-1])`；`Trim` 本体 `Taxi.cpp:381-452`：把前一段的**落点**与后一段的**起点**各裁掉若干导航点，让坐骑"切角"而不是飞进中转点再折返。
- 三级行为：
  1. `taxi_shortcuts` 里 `pathid` 的 `landing` 与 `takeoff` **都非零** ⇒ 用原版预定义接缝裁剪（`Taxi.cpp:409-414`，数据来自 `ObjectMgr::LoadTaxiShortcuts` / `GetTaxiShortcut`，`ObjectMgr.cpp:6775-6803`）。
  2. 数据缺或只写一半 ⇒ **运行时兜底启发式**（`Taxi.cpp:416-450`）：两个游标从上一段尾部、下一段头部**锁步**向里推，找到第一对"离中转节点 2D 距离都 > 48 码"的点当作新接缝。代码注释自己写明：*"Retail uses serverside pre-definied junction points… We have a fallback custom automatic runtime trimmer. The result will not match retail and can be visually unpleasing at times."*
  3. 兜底也失败（两段不同地图、地图 id 变化、走到头）⇒ **完全不裁** ⇒ 坐骑飞到中转点再从原路飞出去，肉眼就是"折返绕远"。
- 覆盖率实测（本地库 `taxi_shortcuts` × `TaxiPath.dbc`）：514 条航线中 **takeoff/landing 都非零只有 101 条**，只写一半 **67+67 条**，**完全没行 279 条**。按"真实的 A→B→C 中转组合"枚举，**2670 种里只有 926 种（34.7%）两边数据齐全** ⇒ **约 2/3 的中转衔接走的是 48 码兜底算法**。
- 分大陆：外域 **119/158（75%）**、东部王国 **86/142（61%）**、**卡利莫多只有 30/210（14%）** ⇒ 卡利莫多的多段航线基本全靠兜底。奎岛（节点 **213 破碎残阳基地**）相关 7 条航线**都有数据且方向配套**（入岛航线给 takeoff、出岛给 landing）：781/782 银月城、786/787 祖阿曼、796/797 圣光之愿、807 铁炉堡 ⇒ 奎岛不会因为缺数据而绕远。
- 兜底算法两个**确定性**缺陷（正是"同一条路看着不一样"的来源）：① 两游标**锁步**推进（`++i1, ++i2`），配对的是"第 k 个尾点 ↔ 第 k 个头点"，不是几何最近点对 ⇒ 接缝位置随**两段各自的点数**变化；同一路口、不同航段组合会裁在不同位置。② 只比 **2D 距离、忽略高度与地形** ⇒ 切角线可能穿山穿建筑。
- `taxi_shortcuts` 数据本身无异常：无一条被 `std::min(…, nodeEnd-1)` 夹断（值最大 17，航线点数都够），注释显示来源为"视频核对 / 近似"。

### M2 中转站由**客户端**决定，服务端从不重新规划
- 客户端把**整条节点链**发上来：`CMSG_ACTIVATETAXI`（2 点，`TaxiHandler.cpp:194-221`）或 `CMSG_ACTIVATETAXIEXPRESS`（N 点，`TaxiHandler.cpp:141-179`）；服务端只逐段查 `GetTaxiPath` 后依次飞（`Player.cpp:18509` → `AddRoutes`）。
- ⇒ "同一目的地走哪几个中转站"取决于该玩家**当前已解锁飞行点掩码**（`m_taxi`）：解锁进度不同的两个玩家，或同一玩家后来解锁了新点，客户端给出的中转链就不同 ⇒ **同一句"去奎岛"能飞出不同路线**。这是客户端行为，不是服务端 bug；`AllFlightPaths`（本服/云端均为 0）会把这个差异放大。

### M3 客户端 / 服务端 DBC 不一致 —— 本次实测**排除**（标准客户端一致）
- 用 mpyq 按补丁优先级解析三份本地 2.4.3.8606 客户端（`D:\Game\70\2.4.3`、`守护者（LV核心）客户端`、`卡布奇诺TBC纯净客户端`）的 `TaxiPath.dbc` / `TaxiPathNode.dbc` / `TaxiNodes.dbc`，md5 **与本服（`x64_Debug\dbc`）/云端（`/opt/mangos/data/dbc`）逐字节一致**（`ca64ada0…` / `d43ffb83…` / `11a46c1b…`）⇒ 正常客户端**不会**出现"地图上画的线 ≠ 实际飞的线"。
- 但客户端**自身两个语言补丁互相打架**（`patch-zhCN.MPQ` vs `patch-zhCN-2.MPQ`）：
  - `TaxiPathNode`：**412 号航线**差 **5 个点（补了 idx 18-22）+ idx 11-17 相差最大 885 码**；526 号航线差 3 点（10~39 码）；411 号 idx3 差 7.7 码；
  - `TaxiNodes`：**82/83**（银月城/塔奎林）坐骑外观 id 不同（3574 vs 19917），**209/210/211/212/213**（太阳井日常/破碎残阳基地节点）flag 由 `0xFF00FE` 变 `0xFF01FE`。
  - ⇒ 若玩家用**自制或改过 DBC / 带额外补丁的客户端**（例如本机 `守护者（LV核心）客户端` 里那个 mpyq 都读不了的加密 `patch-zhCN-Z.MPQ`），预览与实际就可能真的对不上。**官方纯净客户端不存在这个问题。**
- ⚠️ 顺带修正本文档 432 行那节的归因：把"点飞行常提示离空运站太远(ERR_TAXITOOFARAWAY)"说成"客户端 2.5.3 + 服务端 2.4.3 DBC 差异"，**本次核对不支持**（三份客户端 taxi DBC 与服务端逐字节相同）。更可能的真因是那段坐标校验把**平方距离**与 `(2*INTERACTION_DISTANCE)^3` 比较（`Player.cpp:18474-18488`，维度写错，等效容差≈**31.6 码**；上游同样写法）⇒ 节点坐标离飞行管理员稍远就误判。该节结论（"NPC 发起的飞行放行"）仍然有效，只是**理由要改**。

### M4 断线/重登会丢掉后半段航线（配置决定）
- `LongFlightPathsPersistence = 0`（本地与云端 `mangosd.conf` 均是 0）：`Tracker::Save()` 只保存 **1 条** pathid（`Taxi.cpp:56`），`Load()` 读回来只飞第一段 ⇒ 多段航线中途掉线/重登，**飞完第一段就停下**、剩余航段被丢弃 ⇒ 与"平时那条路线"不一致。

### M5 缺腿静默截断（少见）
- `Tracker::AddRoutes`（`Taxi.cpp:191-205`）逐段添加，坏段（该段起点节点**该阵营没有坐骑外观** `GetTaxiMountDisplayId`、或 `(from,to)` 组合不存在）直接 `break`，但只要**已加成一段**就返回 true ⇒ 请求 3 段可能只飞 1-2 段就落地下马，表现为"路线不对/没飞到目的地"。

### 追加（同日）：站长补充症状「有时候 taxi 走直线穿模」——**实测定位：兜底接缝算法把接缝画到山体里**
方法与判据：用本服地形高度图（`x64_Debug/maps/%03u%02u%02u.map`，地形 float V9 129×129/格，与 `GridMap::getHeightFromFloat` 同源）沿每条直线段每 4~10 码采样，比较「该点 Z」与「该点地形高度」。

| 对照 | 段数 | 地形高出直线 >2 码 | >20 码 | 最大穿透 |
|---|---|---|---|---|
| **基线：原版 DBC 相邻航点**（暴雪自己的数据） | 12,804 | **5.27%** | **4.88%** | 349 码 |
| 接缝直线 · 有 `taxi_shortcuts` 数据（data 模式） | 471 | 0.8% | 0.8% | **69 码** |
| 接缝直线 · **兜底算法**（fallback 模式） | 759 | 7.1% | **8.3%** | **346 码** |

- 更严格的判据（地形高出该点 >5 码 **且** 该点离两条航线的原版航点都 >60 码 ⇒ 既在地下、又不在原版航线附近，也就是"既穿地又不在 WMO 内部通道里"）：命中 **53 个真实中转**（fallback 48 / data 5），其中穿透 >100 码 34 个、>200 码 16 个。
- **top 全部集中在铁炉堡（node 6，山洞城）**：穿透 194~345 码、直线段 373~1555 码，例如 `path 312 -> path 438` 穿 345 码 / 直线 667 码、`path 13(暴风城→铁炉堡) -> path 314(铁炉堡→丹巴达尔)` 穿 266 码 / 直线 1400 码、`path 402 -> path 314` 穿 265 码 / 直线 1555 码；其次是 **卡加斯（node 21，荒芜之地峡谷）** 125~128 码、**守望堡（node 45）** 126 码。
- 原因：兜底那套「两个游标锁步推进、找第一对离枢纽 >48 码的点」在铁炉堡必然踩坑——进出铁炉堡的航线是沿**环形山的两侧**走的，第一个满足 48 码条件的点对正好是**跨过整座山**的一对，于是服务器让坐骑**直接从山体里穿过去**（客户端只是沿服务端给的直线段播放，没有地形跟随）。`taxi_shortcuts` 里那些"视频核对"出来的值反而是好的（最大仅 69 码），**问题出在没有数据的 61% 中转上**。
- 离线模拟两种修法（782 个兜底中转，同一判据）：
  | 方案 | 穿透 >20 码的中转 | 最深穿透 | 直线段中位/最大 |
  |---|---|---|---|
  | 现状（锁步） | 60 (7.7%) | 281 码 | 193 / 2669 码 |
  | 兜底改「按直线段长度从小到大找第一条不穿地的」 | **0** | **0** | 103 / 573 码 |
  | 只补数据行（每条航线取模拟最优值） | 25 (3.2%) | 122 码 | 141 / 2884 码 |
- 建议：优先做**代码修法**（`Tracker::Trim` 兜底分支：候选点对按直线段长度排序，用 `m_owner.GetMap()->GetHeight(x,y,z)`（含 vmap）逐点验证，取第一条不穿地的；全都不行就不裁）——改动小、离线可验证、对将来数据缺失自动兜底；`taxi_shortcuts` 可以顺带补，但纯数据只能修 ~60%。本地复现脚本：`_agent_tmp/taxi_terrain*.py`、`taxi_fallback_rules.py`、`taxi_rock_check.py`、`taxi_data_fix_sim.py`。

### 追加 2（同日）：站长反馈「守望堡附近确实容易穿模，但不是每次都穿」+ **已加诊断日志（只写日志、不改行为）**
- ⚠️ **修正上一段的判断**：上一段里"铁炉堡那批 200~345 码穿透"**不可信**——铁炉堡是**山洞城**，进出航线本来就走在 WMO 内部通道里，而原始 `.map` 地形**不含 WMO 挖空**，所以拿地形高度比对会把它整段判成"在地下"。反证：原版 DBC 自己的 12,804 段里，被判"地形高出 >20 码"的 624 段**绝大多数就在铁炉堡这一圈**（坐标 ≈(-4850,-1000)），说明该判据在 WMO 内部失效。**守望堡（node 45，诅咒之地开阔地形）与卡加斯那批判据才有效**，站长也确认穿模确实出现在守望堡一带（命中记录：`path 381 -> path 262`，兜底接缝、穿透 126 码、直线段 766 码）。
- 因此改为**用服务端自己的高度查询（含 vmap）在真实飞行上取证**。已加诊断日志（`src/game/Entities/Taxi.cpp`，**纯日志，无任何行为改动**；`Trim()` 保持 `static` 原样，`.h` 未改）：
  - `Tracker::AddRoute`：每形成一个中转接缝就打印**接缝类型**（`shortcut-data` / `FALLBACK-trimmer` / `none`）、两条航线的裁剪节点数（含表里的 landing/takeoff 值）、以及接缝直线的长度/ΔZ/地形净空；
  - `Tracker::Prepare`：打印每条腿的裁剪范围（`node range A..B`），并列出这次飞行所有 **>120 码的直线段**（原版长段与接缝直线都会出现）及其地形净空；
  - `Tracker::AddRoutes(std::vector<DestID>)`：打印**客户端请求的完整中转链**（解释"同一目的地为何有时走不同路线"）。
  - 每条采样段给出：`height above point: low-query X yd, +100yd-probe Y yd (worst at ...)`（`low = GetHeight(x,y,z)`、`high = GetHeight(x,y,z+100)`，两个查询都低于该点 Z 才算安全）与 `endpoint clearance 首/尾`。
  - **开关**：GM 命令 `.debug taxi`（`Chat::HandleDebugTaxiCommand`，默认关闭 ⇒ 零开销）。日志前缀统一 `[TAXI-DIAG]`，同时进 `logs/Server.log` 与控制台。
- 本地已编译并部署（2026-09-23 23:43 启动，`x64_Debug\mangosd.exe` md5 `A14A8AB8620D60BA66FA476935F0A308`，启动 9 秒无报错）；**未推云端**。
- **云端同步记录（2026-09-23 23:46，站长指示"把日志版本同步到云"）**：云端源码树 `/root/Nmangos-tbc`（当时 HEAD `19964c635`）**只同步了这次提交的 3 个文件**（scp 覆盖，非 `git reset --hard`；`git push` 到云端仓库因公钥不被云端 git 接受而放弃）：
  - `src/game/Entities/Taxi.cpp` md5 `1623cab9d67802aac1e95fc5e0c10e8e`（诊断日志本体）
  - `src/game/AuctionHouseBot/AuctionHouseBot.cpp` md5 `e8b1dae694035e3b636ccc52dfcbf754`（**同一提交里带的 AHBot 改动**；云端 `ahbot_market_state` 目前没有 `category=2` 行 ⇒ 行为不变，等 `dev/111` 数据上去才生效）
  - `dev/KNOWN_ISSUES.md`（文档）
  - **未同步** `dev/111`（AH 上架商人配方，站长尚未验收）⇒ 夜间 `apply_dev_sql.sh` 不会自动应用它（云端 `dev/` 里没有该文件）。**该状态已于同日 23:59 由站长指示解除——见文末「AHBot 上架商人可交易配方」章节的云端同步记录。**
  - 覆盖前备份：`/root/_prep_taxilog_20260923_2346/{Taxi.cpp,AuctionHouseBot.cpp,KNOWN_ISSUES.md}`（md5 `da464f73…` / `836d8d46…` / `253b4f5a…`）。
  - `Taxi.h` 云端与提交一致**未被改动**（`git diff --name-only HEAD -- src/game/Entities/Taxi.h` 为空）。
  - 生效方式：**04:06 夜间任务** `flock -w 5400 /var/lock/nightly_build.lock /root/nightly_build_restart.sh` —— 它先用 `make -n` 判断要编译 ⇒ 停 mangosd ⇒ `make -C /root/Nmangos-tbc-build -j2`（增量：`Taxi.cpp.o` 是 04:32 的旧产物 ⇒ 至少这 1 个 TU）⇒ 二进制有变化才 `cp` 安装 ⇒ 重启。同步时云端在线 4 人，**没有做任何编译/重启**。
  - 云端日志位置：`sLog.outString` 进 `/tmp/mangosd_run.log`（实测启动行 "taxi shortcuts" 在该文件里出现 91 次）⇒ `[TAXI-DIAG]` 也在这里，grep 即可。
- 复现步骤：进本地测试服 → `.debug taxi` → 飞一次守望堡那条线（最好再飞一次"正常"的线做对照）→ 我读 `Server.log` 里的 `[TAXI-DIAG]` 行判断穿模点落在**接缝直线**还是**原版 DBC 长段**上、以及该点的 `high-probe` 是否明显为正。
- 判读表：① `kind = FALLBACK-trimmer` 且该段 `+100yd-probe` 明显为正 ⇒ 兜底接缝穿山（改 `Trim` 兜底算法）；② `kind = shortcut-data` 但净空为负 ⇒ `taxi_shortcuts` 里那条"近似"值裁过头（改数据）；③ `long-segment` 出现在**没有中转**的单段航线上 ⇒ 原版 DBC 航点本身太稀（要做"长段贴地形补点"）；④ 净空全为负但玩家看到穿模 ⇒ 判据要换成 vmap-only 查询再核。

### 可选动作（**均未实施**，等站长定）
0. **（本次新增，推荐）** 按上面「追加」一节的代码修法改兜底接缝算法（需本地编译 + 站长游戏内看一次铁炉堡中转确认）。
1. 补 `taxi_shortcuts`（卡利莫多最缺）：改完需重启（表可 `.reload taxi_shortcuts`，按 P0 规矩我们不用 `.reload`）。注意：本库 / `tbcmangos_orig` / `tbcdb_ref` / `wotlkmangos` 都是**同源 235 行**，上游没有更全的版本可抄，只能自己按视频/实测补。
2. 改兜底算法：距离改 3D、接缝取几何最近点对（而非锁步）、跨图/跨地图 id 时保守不裁。
3. 打开 `LongFlightPathsPersistence = 1`（多段航线重登续飞）——注意会改变收费/存档行为（`Taxi.cpp:152`、`:236`），需站长确认。
4. 复核 `Player.cpp:18474-18488` 那段容差写法（上游 wart），避免误判"离空运站太远"。

### 复现用的临时脚本（`_agent_tmp/`，非交付物）
`taxi_dbc_dup.py`（DBC 重复 (from,to) 检查）、`taxi_shortcut_coverage.py` / `taxi_junction_check.py`（覆盖率与中转组合统计）、`taxi_shortcut_by_map.py`（分大陆覆盖率 + 奎岛相关航线）、`taxi_mpq_probe.py` / `taxi_mpq_diff.py` / `taxi_node_decode.py` / `taxi_client_compare.py`（从客户端 MPQ 提取并逐字节/逐行比对 taxi DBC）。

---

## [经济] AHBot 上架「商人出售的可交易配方」（固定商人价）—— `dev/111`，2026-09-23 已上云端

### 需求（站长 2026-09-23）
「让 AH 上架来自商人出售的装绑配方」→ 细化后：**上白 + 绿两档、固定按商人售价**；机制上"把 `category 2` 改成固定价格，在表里用价格字段决定"。

### 范围（本库实测）
- 口径：`item_template` class=9(配方) + `bonding=0`（可交易）+ Quality 1(白)/2(绿) + **确实有真实商人卖它**（`npc_vendor` 或 `creature_template.VendorTemplateId` 指向的 `npc_vendor_template`，且商人 entry 在 `creature` 里有刷点）。
- 命中 **292 件 = 白 270 + 绿 22**；商人售价合计 **5,037,570 铜**。
- 排除：蓝色仅 1 件（**12703** 设计图：风暴护手，站长要求不上）；另有 **476 件**商人卖的配方是 `bonding=1`(BoP 拾取绑定) **不可交易**，不在范围内。本库 class 9 只有 bonding 0/1，没有 bonding 2 ⇒ "装绑"按"可交易"理解。

### 机制与参数（`dev/111_AH上架商人可交易配方_固定商人价.sql`，1 条 `INSERT IGNORE`(292 行) + 25 条带守卫的 `UPDATE` 兜底）
- 表：`ahbot_market_state`（角色库，PK=`(item, auction_house)`，AHBot operator 表）。
- `auction_house = 2`（中立 AH —— 与既有 `category=1` 行一致；catalog 只读 house 2）。
- `category = 2` = **固定单价**，单价取本行 `price`（铜币）；代码 `GetCatalogFixedPrice()` = `category==2 ? price : 0`。
- `price` = `price_ref` = 该配方的**商人售价 BuyPrice**（AH 与 NPC 同价）。
- `target = 4` / `capacity = 8` ⇒ 曝光切片 `max(1, target*QuoteExposurePct/100)` = **每件挂 1 个**（默认 target=50/capacity=200 会让每件挂十几个）。
- 幂等：`INSERT IGNORE` + `UPDATE … AND category<>2` ⇒ 重复执行 0 行变更（本地实测）。

### 配套代码（同批上线：`src/game/AuctionHouseBot/AuctionHouseBot.cpp`，仅 14 行）
1. `LoadCatalogOverrides()` 的 supply universe 由 `category==1` 扩为 **`category==1 || category==2`**（否则 category 2 只定价、不供货）。
2. 固定价商品的**出价价值**不再乘 `ValueWithVariance`：`uint32 buyUnitValue = fixedBuy ? itemWorth : ValueWithVariance(itemWorth);`（固定价商品的收购价也应按固定价，不该带随机浮动）。
- 无 `category=2` 行时该改动**行为等价于旧版** ⇒ 可先上代码、后上数据。

### 本地验证（2026-09-23）
- 应用后本地库 `category=2 AND auction_house=2` = **292 行**；重跑 0 行变更。
- 本地测试服启动日志：`AHBot market-maker catalog: 410 book items (459 operator overrides)`（410 = 旧 118 条 category 1 + 新增 292）。
- 遗留：老的中立 AH 里已挂的 class 9 商品（约 1201 条，`itemowner=0` = AHBot 自己挂的）仍是旧价（约商人价 2 倍），要等自然过期；如需立刻生效可清理这些挂单（**未做**，等站长定）。

### 云端同步记录（2026-09-23 23:59，站长指示"同步 AH 上架商人配方"）
- 同步文件：`/root/Nmangos-tbc/dev/111_AH上架商人可交易配方_固定商人价.sql`，md5 `25b7bc86203d80be992825c9dba72abb`（与本地一致；scp 覆盖）。
- 同步前核对云端 `tbccharacters.ahbot_market_state` **表结构与本地逐列一致**，且**没有任何 `category=2` 行**（当时只有 `category=1` 125 行、`category=3` 41 行）⇒ `INSERT IGNORE` 不会覆盖既有行。
- `DRYRUN=1 bash /root/apply_dev_sql.sh` 实测输出：`[dry-run] would apply 111: 111_AH上架商人可交易配方_固定商人价.sql`，标记仍停在 **110**（**没有现在执行**）。
- 生效方式：**04:06 夜间任务**先跑 `apply_dev_sql.sh`（应用 111、标记→111），再增量编译（`Taxi.cpp` + `AuctionHouseBot.cpp` 两个 TU）→ 安装二进制 → 重启。⇒ 数据与代码同一次重启一起生效。
- 回滚件：`dev/rollback/111_回滚_AH上架商人配方.sql`（**只在本地**，未同步；它不在 `dev/` 根目录，`apply_dev_sql.sh` 不会自动执行它；需要时手工 `mysql tbcmangos < 该文件` + 重启或 `.ahbot reload`）。
- 同步时云端在线 3 人，**没有做任何编译/重启/SQL 执行**。

### 后续：AHBot loot 来源调整（`ahbot.conf`，站长 2026-09-24 指示）
站长原话：*"Disenchant 我们改成 mm 管理了应该没什么用；大部分 skinning 和 go 来源也会被 category=1 过滤。Fishing 改成 10,12,5,10，Skinning 改成 20,30,5,10，go 和 item 先按这个来。"*

**最终值（本地 + 云端一致）**
| 键 | 旧 | 新 | 备注 |
|---|---|---|---|
| `AuctionHouseBot.Loot.Disenchant` | `3, 4, 10, 15` | **`0, 0, 0, 0`（关闭）** | 实测其产出**全部**已被 MM 目录接管 ⇒ 该来源实际产出为 0 |
| `AuctionHouseBot.Loot.Fishing` | `10, 12, 10, 20` | `10, 12, 5, 10` | 数量减半、品种不变 |
| `AuctionHouseBot.Loot.Gameobject` | `40, 50, 10, 20` | `15, 18, 6, 12` | 刷次量 700 → ≈153（−78%） |
| `AuctionHouseBot.Loot.Skinning` | `10, 12, 5, 10` | `20, 30, 5, 10` | 品种变宽、数量不变 |
| `AuctionHouseBot.Loot.Item` | `10, 12, 1, 2` | `3, 4, 1, 2` | 刷次量 ≈17 → ≈5.5（−68%） |

**"会被 category 过滤"实测（本地库，判据：`AuctionHouseBot.cpp:466` —— 有 operator 行且 `category != 0` 的物品**永不**走 legacy loot 供给）**
- operator 行总计 **459**（category1 118 + category2 292 + category3 49）。
- 按**产出品种**算被过滤比例：Disenchant **30/30 = 100%**、Skinning 23/86 = 26.7%、Fishing 2/40 = 5%、GO 78/2929 = 2.7%、Item(开箱) 36/1550 = 2.3%、Creature 99/5447 = 1.8%。
- 按**模板行暴露度**（`loot_template` 里 (entry,item) 行数）算：Disenchant **102/102 = 100%**、**Skinning 1599/3369 = 47.5%**、GO **342/9440 = 3.6%**、Item 215/4709 = 4.6%、Fishing 7/199 = 3.5%、Creature 9045/174709 = 5.2%。
- ⇒ 站长的判断对 **Disenchant（100%，关了等于没关，纯省计算）** 和 **Skinning（近半被接管）** 成立；但**Gameobject 只有 3.6% 的模板行被过滤 ⇒ 它仍是最大投放源**（这也是它需要被砍 78% 的原因）。

**改动落点与生效**
- 本地 `x64_Debug\ahbot.conf`：已改 + 已于 2026-09-24 00:48 重启验证（`AHBot using configuration file ahbot.conf` + catalog 410 条加载正常）；备份 `_agent_tmp\ahbot.conf.bak_local_20260924_0043`。
- 云端 `/opt/mangos/etc/ahbot.conf`：已改（md5 前 `ed892633…` → 后 **`e6632bd4…`**，`diff` 只有这几行 + 注释变化），备份 `/opt/mangos/etc/ahbot.conf.bak_20260924_loot`（md5 `ed892633…`）。**随 04:06 夜间重启生效**；若要提前，`.ahbot reload` 会走 `ReloadAllConfig()` → 整份重读该文件（热生效）。
- 注意：本地测试服的 `Loot.Creature.Normal` 仍是 `100, 100, 5, 8`（云端是 `25, 25, 3, 5`），本次**未动**——本地是测试服，两边总投放量本来就不同。

**运维教训（配置解析）**：`Config::Reload()` 只跳过"**行首** `#`"的行（`Config.cpp:65`），**不剥行内注释**；值后面的 `# 注释` 之所以还能生效，纯粹是 `atoi` 在第一个非数字字符处停下（云端已有的 `MarketMaker.ProbeUnits = 0   # …`、`MaxGoldPer*` 都是这样"侥幸"生效的）。⇒ 以后给配置加说明一律写成**独立注释行**，别写字尾注释。

### 元素类（class 7 / subclass 10）在 MM 目录里的归属 —— 2026-09-24 核查
站长问：*"除了源生和微粒还有哪些在 category=1 管理？"* 结论（**以云端 live 为准**）：

元素类在本库共 **31 件，全部有归属 = 30 件 category=1 + 1 件 category=3**：
- **源生 7 件**（21884 源生火焰 / 21885 源生之水 / 21886 源生生命 / 22451 源生空气 / 22452 源生之土 / 22456 源生暗影 / 22457 源生法力）= **category=1（MM 管理）**。
- **微粒 7 件**（22572~22578：空气/土/火/生命/法力/暗影/水之微粒）= **category=1**。
- **其余 16 件也都在 category=1**（站长问的"还有哪些"就是这 16 件）：**7067 元素之土、7068 元素火焰、7069 元素空气、7070 元素之水、7075 大地之核、7076 大地精华、7077 火焰之心、7078 火焰精华、7079 纯水之球、7080 水之精华、7081 风之气息、7082 空气精华、7972 亡灵腐液、10286 野性之心、12803 生命精华、12808 死灵精华**。
- **唯一例外：23571 源生之能（Primal Might）= category=3（封禁）** ⇒ MM 不挂牌、loot 供给也跳过。

类别构成（云端 category=1 共 125 行）：草药 40 / **元素 30** / 附魔 29 / 金属与石头 14 / 皮革 6 / 布料 6。

⚠️ **本地测试库与云端不一致（本次顺带查出来的漂移）**：本地 cat1 = 118、cat3 = 49；云端 cat1 = 125、cat3 = 41。差异恰好是：**云端把 7 件源生放在 cat1（MM 管理），本地把 7 件源生 + 21840 灵纹布卷放在 cat3（封禁）**；其余完全相同（本地 cat1 ⊂ 云端 cat1）。⇒ 若要在本地复现云端行为（做 AHBot 测试时目录一致），需要把 7 件源生改回 cat1、并解除 21840 的封禁；**未改**，等站长定。

### 处置：这 16 件元素材料退出 MM 目录（`dev/112`，2026-09-24）
站长指示：*"还有这 16 件不应该在 category=1，应该是 0。"*

- **`dev/112_元素类16件退出MM目录改category0.sql`**：`UPDATE tbccharacters.ahbot_market_state SET category = 0 WHERE auction_house=2 AND category=1 AND item IN (16 件)`。单条静态 SQL、幂等（带 `AND category = 1`，重跑 0 行）。
- 回滚件：`dev/rollback/112_回滚_元素16件重回MM目录.sql`（`category 0 → 1`，同样幂等）。
- **语义**：`category = 0`（等同"无行"）= untouched ⇒ ① MM 不再为其定价/挂牌；② `AuctionHouseBot.cpp:466` 的 `category != 0 → continue` 只过滤非 0，所以它们**重新回到普通 loot 来源供给**（生物/采集/剥皮，受 `ahbot.conf` 的 `Loot.*` + `Chance.Sell` 控制）。
- **保留不变**：源生 7 件 + 微粒 7 件仍 `category=1`（MM 管理）；源生之能 23571 仍 `category=3`（封禁）。
- **本地已应用并验证**（2026-09-24 00:52 重启）：`category` 计数 `cat1 118→102 / cat2 292 / cat3 49 / **cat0 +16**`；16 行实测全部为 0；启动日志 `AHBot market-maker catalog: 394 book items (459 operator overrides)`（410 → 394，正好 −16）。
- **云端已同步、等 04:06 生效**：`dev/112` + 回滚件已 scp 到云端（md5 `4bc1a047…`），`DRYRUN=1 bash /root/apply_dev_sql.sh` 显示待执行顺序 **111 → 112**，标记仍停在 110（同步时在线 3 人，未执行任何 SQL / 未重启）。04:06 跑完后线上目录计数应为 `cat0=16 / cat1=109 / cat2=292 / cat3=41`。

### 本地测试库对齐云端（站长 2026-09-24 01:00 指示"把本地对齐成云端"）
- **比对方法**：把本地与云端 `tbccharacters.ahbot_market_state`（`auction_house=2` 全部行）导成 `item|enabled|category` 与"配置列"两份文本逐行 diff（脚本 `_agent_tmp/diff_house2.py`、`_agent_tmp/diff_cfg.py`）。
- **实质差异只有 2 处**（16 件元素材料那批是本地已执行 `dev/112`、云端未执行造成的临时差异）：
  1. 7 件源生（21884/21885/21886/22451/22452/22456/22457）：本地 `category=3`（封禁）→ 云端 `category=1`（MM 管理）⇒ 本地改回 `1`（`enabled=1`）；
  2. **21840 灵纹布卷**：本地 `category=3`（封禁）→ 云端**没有这一行** ⇒ 本地**删行**（等同 category 0）。
- 修正脚本：`_agent_tmp/local_align_from_cloud.sql`（**仅本地执行**，云端本来就是目标状态；幂等：`UPDATE ... AND category=3` + 带 item 条件的 `DELETE`）。重跑 0 行变更。
- **刻意不对齐的字段**（市场商人运行期自己改，不是配置，对齐了也会立刻漂开）：`price / price_ref / target / qty / avg_cost / spent / earned / flow_bought / flow_sold / day_price / day_start / last_settle_time`。实测 `price_ref` 有 63 项、`target` 有 23 项与云端不同（运行时浮动 / 需求加成 / 闲置衰减）。
- **对齐后**本地：`cat0=16 / cat1=109 / cat2=292 / cat3=41`（共 458 行）—— 与云端 04:06 执行完 111+112 后的预期**逐行一致**（云端当前仍是 `cat1=125 / cat3=41`，差的正是未执行的 dev/111 292 行与 dev/112 的 16 行）。逐行 diff 复检结果：共同物品里只剩那 16 件"云端还没执行 dev/112"的临时差异，`只在云端=0`，`只在本地=292`（=dev/111）。
- 本地重启验证（00:57）：`AHBot market-maker catalog: 401 book items (458 operator overrides)`（109 + 292 = 401 ✓，覆盖行 458 = 对齐后总行数 ✓）。
- **以后复检方法**：两边各跑一次 `SELECT CONCAT_WS('|', item, enabled, category) FROM ahbot_market_state WHERE auction_house=2 ORDER BY item;` 再 diff，预期只剩"云端尚未执行某个 dev/NNN"造成的临时差异。

### 追加：玩家可能是"代理 + 现代客户端"——判读穿模时要把这一层排除（2026-09-24）
站长贴来的两行报错（`游戏内对象信息更新失败 WowGuid128 …` / `NewHighGuidLegacy error high= 50575<=>C58F`，2026-09-23 22:35~2026-09-24 00:24）**来源已定位**：
- 这两个字符串只存在于 **`SugarProxy.exe`**（`D:\Game\小黑兔\tools\sugar-proxy\`；Go 符号 `sugar/core/wow_guid.NewHighGuidLegacy`、`sugar/world/enums.(*ObjectType).Convert`、`wow_guid.WowGuid128`、`HighGuid703`），我们核验过的三份 2.4.3 客户端里都没有。
- 同目录 `realm.txt` = **`39.96.90.39:3724`**（就是我们的服），`manifest.json` 指向 `static.xiaoheitu.cn` 的 hotfix 包 ⇒ **玩家用"小黑兔糖糖代理"接入**，客户端是**现代客户端**（`HighGuid703` = 7.x 世代 GUID 方案），不是在本地核验过的 2.4.3 纯净客户端。
- 两条报错含义：① 代理按 128 位 GUID 更新某个游戏内对象失败（对象标识/更新层）；② 现代高段 GUID ↔ legacy 高段换算自检不一致（`50575` 与 `C58F` 是同一个值的十进制/十六进制）。报错里的 `2882308159563644032` = `0x2800040000003C80`（现代 128 位格式）。

**与"飞行穿模"的关系**：机制上**无直接因果**——航线折线由服务端按 DBC 节点算好、以 `SMSG_MONSTER_MOVE` 下发，GUID/对象更新层的错误不会改折线。但**代理客户端是一个必须排除的独立变量**：
- 现代客户端用自己的地形/碰撞/坐骑与样条处理；代理翻译包时还可能改动样条相关字段；
- 之前"客户端 taxi DBC 与服务端逐字节一致"的核验**只覆盖三份 2.4.3 客户端**，**不覆盖**代理/现代客户端。
⇒ 判读顺序（`[TAXI-DIAG]` 日志是**服务端侧**、与客户端无关）：① 让报穿模的玩家飞一次，看日志里那条段的 `+100yd-probe`：**明显为正** ⇒ 服务端几何确实穿山（改兜底接缝/补数据）；**净空为负（在空中）却仍看到穿模** ⇒ 属于客户端/代理侧，与上述两条报错同一层面，不该归到我们的接缝算法上。② 同一路线用 2.4.3 纯净客户端复飞对照：只有代理客户端穿 ⇒ 问题在代理/现代客户端。

---

## [本地化] 官方 API 物品名全量比对跑完：350 件不一致，其中 **279 件是坏 zhCN 译名（线上可见）** —— 2026-09-24（**未改**）

- 扫描范围：全库 30,407 件（`item_template`），逐件问 Blizzard 官方 API（`tw.api.blizzard.com` `/data/wow/item/{id}`，一次取全语言）：
  **一致 28,188**、**官方查不到（已删除/404）2,219**、**不一致 350**。
- 350 件拆解（脚本 `_agent_tmp/item_diff_classify3.py`；清单 `_agent_tmp/物品名称_本地vs官方_待审.tsv`）：
  | 类型 | 数量 | 说明 |
  |---|---|---|
  | zhCN **为空** ⇒ 游戏内显示英文 | **3** | 5632 怯逃药水 / 29877 / 39149 `"Fred"` |
  | zhCN 是中文但与官方不同，且**本地 zhTW == 官方 zhTW** | **279** | **高可信**：说明该条目本身没被改过，是 zhCN 那一列来源不好 |
  | zhCN 与官方不同、且本地 zhTW 也不同 | **68** | 需人工确认 |
- **坏译名的模式**（很典型，像是"照英文单词机翻"）：`徽记 ← Head`（官方"头颅"）、`精华 ← Heart`（官方"心脏"）、`标记 ← Remains`（官方"残骸"）、`穴居人 ← Trogg`（官方"石腭怪"）、`装满烈酒的酒桶 ← Tainted Keg`（官方"被污染的酒桶"）、`铜质宽剑 ← Heavy Copper Broadsword`（官方"铜质重剑"）、`腐朽之尘 ← Dust of Decay`（官方"蚀骨灰"）、`药剂 ← Potion`（官方"药水"）……
- **云端 live 同样是这些坏名字**（抽查 182 加瑞克的徽记 / 1532 皱缩的徽记 / 2382 藏尸者的精华 / 2828 妮萨的标记 / 3382 弱效巨魔之血药剂 / 3520 装满烈酒的酒桶 / 3571 穴居人巨锤 —— 云端 `locales_item.name_loc4` 与本地一致）⇒ **玩家现在就看到这些**。

---

## [机制] 「未知的服务器错误」= `ERR_TAXIUNSPECIFIEDSERVERERROR`：它只在"一个航段都没建成"时发出 —— 2026-09-24（诊断日志已加，**行为未改**）

站长补充线索：*"当我飞行穿模的时候，总会提示一个未知的服务器错误"* + *"而且总是我骑在坐骑上的时候"*。

### 报错源头（已逐字确认）
- 客户端 `Data\locale-zhCN.MPQ` 的 `Interface\FrameXML\GlobalStrings.lua` 里 **`ERR_TAXIUNSPECIFIEDSERVERERROR = "未知的服务器错误"`**（全表唯一匹配；`ERR_TAXIPLAYERALREADYMOUNTED` 是"你已经骑乘了"、`ERR_TAXITOOFARAWAY` 是"离空运站太远"，都不是这条）。
- 服务端**只有一处**会发这个值：`Player::ActivateTaxiPathTo`（`Player.cpp:18511`）——条件是 **`m_taxiTracker.AddRoutes(...)` 返回 false**，即 `m_routes` 为空、**第一段航段就没建成**。
- 三种拒绝原因（`Tracker::AddRoute`）：
  1. **tracker 忙**：`AddRoutes` 开头 `Clear()` 失败（`m_state > TRACKER_STAGING`，也就是"已经在飞/正在准备飞"）⇒ 与"总是骑在坐骑（飞行坐骑）上的时候"最吻合：**客户端在一次飞行进行中又发了一次飞行请求**；
  2. `sObjectMgr.GetTaxiPath(from, to)` 返回 0 ⇒ **客户端给的这对起终点在 DBC 里没有航线**；
  3. 起点节点**该阵营没有飞行坐骑 display**（`GetTaxiMountDisplayId == 0`）。
- ⚠️ 关键区分：如果只是**后续某一段**失败，`AddRoutes` 仍返回 true（只要有一段成功）⇒ **不会**报这个错；所以这条 toast 一定意味着**第一段**失败。

### 与"穿模"的可能联系（推断，待日志证实）
"飞行途中又被拒一次飞行请求"说明**客户端自己认为要再开一段航程**（服务端并没有让它继续）——这正是"客户端接管移动、直接用直线飞过去"这类观感的典型前置条件；而客户端是"代理 + 现代客户端"时（见上一节）尤其可疑。**目前仍是推断**，因此先加日志取证、不动行为。

### 已加的诊断日志（只写日志、`.h` 未改；`.debug taxi` 打开，默认零开销）
| 位置 | 内容 |
|---|---|
| `TaxiHandler.cpp` | 客户端每次请求（`CMSG_ACTIVATETAXI` / `CMSG_ACTIVATETAXIEXPRESS`）：完整节点链、坐骑 display、是否处于 `UNIT_STAT_TAXI_FLIGHT`、客户端控制标志 |
| `Tracker::AddRoute`（`Taxi.cpp`） | **每一种拒绝原因**：tracker 忙（带 state）/ 该起终点无 DBC 航线 / 起点节点该阵营无坐骑 display |
| `Tracker::AddRoutes`（`Taxi.cpp`） | 结果：加了几段、尝试了几段、返回值（false 会明确写"client will show 'unknown server error'"） |
| `Player::ActivateTaxiPathTo` | **发 `ERR_TAXIUNSPECIFIEDSERVERERROR` 的现场**（节点链 + 坐骑 + 飞行状态 + tracker state）；以及以前**完全静默**的 `Prepare()` 失败 |
| `Player::OnTaxiFlightEnd` / `OnTaxiFlightEject` | 飞行**结束/被弹出**时的坐标与剩余腿数（判断"服务端计划到哪结束" vs "客户端以为到哪"） |

- 本地已编译部署验证（2026-09-24 01:32 启动，`x64_Debug\mangosd.exe` md5 `A74BFDAFBCC65E334CE5282C25359580`，启动 16 秒，AHBot `401 book items` 正常）。
- **云端已同步这 3 个文件**（md5 `573601d8…`(TaxiHandler) / `df48e79b…`(Taxi) / `8f210884…`(Player)，均为**纯新增**：`git diff --no-index` 显示 0 删除、只有 37/50/39 行新增）；云端对象文件是 04:32~04:36 的旧产物 ⇒ **04:06 夜间会增量编译这 3 个 TU**。
- 复现判读：线上 `grep '\[TAXI-DIAG\]' /tmp/mangosd_run.log`（本地 `logs\Server.log`）——
  `AddRoutes FAILED at Clear(): tracker busy` ⇒ 飞行中重复请求；`no DBC taxi path for pair (X -> Y)` ⇒ 客户端给的节点对服务端不存在（客户端/代理数据问题）；`no taxi mount display for source node X` ⇒ 该节点缺坐骑外观（数据问题，可按节点补）。

### 改成**常开**：所有飞行都自动记录（站长 2026-09-24："我没法预测哪一次会出 bug"）
- 三个文件里各放了一个**常开开关**，事件日志与 `.debug taxi` 解耦：
  - `Entities/Taxi.cpp:62`、`Maps/TaxiHandler.cpp:45`：`inline bool TaxiDiagEnabled() { return true; }`
  - `Entities/Player.cpp:18393`：`static bool TaxiDiagEnabled() { return true; }`
  - 想恢复"只在 `.debug taxi` 时记录"：把 `return true` 改成 `return m_debug` / `return player.IsTaxiDebug()` / `return IsTaxiDebug()`（对应各自的上下文）。**`.debug taxi` 现在只控制采样精度**：常开时每 25 码采一个点、最多 40 点（控开销）；`.debug taxi` 打开时每 10 码、最多 200 点。
- 每次飞行**自动**进日志的行（前缀统一 `[TAXI-DIAG]`，带玩家名/GUID/地图）：
  1. 客户端请求：`CMSG_ACTIVATETAXI[EXPRESS] request … chain: 2 -> 6 -> 213 (3 nodes) | mounted display … taxi flight state … client control lost …`
  2. `itinerary (client request)` / `junction: … kind = shortcut-data|FALLBACK-trimmer|none` / `leg: path … node range …`
  3. 每个 **>120 码**直线段：`long-segment / junction-chord: path A idx X -> path B idx Y | len … yd, dZ … | height above point: low-query … +100yd-probe … | endpoint clearance …`
  4. 拒绝原因（**新增，专为这条报错**）：`AddRoute REFUSED: tracker busy (state N > STAGING)` / `no DBC taxi path for pair (X -> Y)` / `no taxi mount display for source node X (team T), path P`
  5. `AddRoutes result: N leg(s) added, M attempted, return TRUE|FALSE (client will show 'unknown server error')`
  6. `ActivateTaxiPathTo: AddRoutes FAILED => ERR_TAXIUNSPECIFIEDSERVERERROR | … chain …` / `Prepare() FAILED (no reply sent)`
  7. `flight END: path … player pos (x,y,z) map M` / `flight EJECT (clear=…): player pos … tracker state … legs left …`
- 本地已编译部署（01:38 启动，`x64_Debug\mangosd.exe` md5 `EAAB02232B805278EDC5715C22521380`，启动 9 秒，AHBot 401 书目正常）；**云端已同步**（md5 `0282803f…`(TaxiHandler) / `7b0c17f5…`(Taxi) / `275111c1…`(Player)，云端已确认 `if (m_debug)`/`if (IsTaxiDebug()` 事件门**为 0 处**）；云端 `.o` 仍是 04:32~04:36 旧产物 ⇒ **04:06 夜间增量编译这 3 个 TU** 后自动常开。
- 日志量预估：每次飞行约 10~40 行；线上日志在 `/tmp/mangosd_run.log`（`grep '\[TAXI-DIAG\]'`），本地在 `x64_Debug\logs\Server.log`。

### ⚠️ 运维教训：Windows/MSVC（代码页 936）下**别用 Python 整文件重写带中文注释的源码**
本次为改"常开开关"用 Python `open(..., "w", newline="")` 重写了 `Player.cpp`/`Taxi.cpp`/`TaxiHandler.cpp`，把仓库本来的 **CRLF 换行改成了 LF**，结果 MSVC 按 GBK 解码中文注释时，行尾少掉的那个 `0x0D` 让**悬挂的前导字节吃掉了换行符**，注释与下一行代码粘连，编译报出 `C2181 没有匹配 if 的非法 else` / `C2059` / `C3861 TaxiDiagEnabled 找不到标识符` 等**看似无关**的错误。
- 证据：同一目录里未被重写的 `Unit.cpp`/`AuctionHouseBot.cpp` 都是 **CRLF**（`CRLF == LF` 计数相等）。
- 结论/规则：① 本仓库源码是 **CRLF**，改动后必须保持 CRLF（`bytes.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')` 归一化即可）；② 新加的**注释也一律用 ASCII**（本次所有新诊断代码的注释都是英文，就是为了避开这个坑）；③ 报出"找不到自己刚写的符号/非法 else"这类怪错时，先查换行与编码，别怀疑逻辑。
- 建议修法（未做，等站长定）：`dev/113` —— 只对 **279 件高可信**（本地 zhTW == 官方 zhTW）用官方 zhCN 覆盖 `locales_item.name_loc4`（带旧值守卫 `AND name_loc4='旧值'` ⇒ 幂等），3 件空的补齐，68 件列出人工确认。用"zhTW 也一致"当闸门可规避"官方现代译名在后续资料片被改名"的风险。`locales_item` 启动载入 ⇒ 需重启生效。

---

## [部署] 源码分发从 scp 改为 git（**夜间 git sync 仍然保持关闭**）—— 2026-09-24

站长问："一直用 scp 能保证版本稳定吗？" 结论：**scp 不能**。举证（改之前）：云端 `/root/Nmangos-tbc` 的 `HEAD` 停在 `19964c635`（9-23 旧提交，且是 detached），而工作树里有 **19 处**未提交改动（含我们 scp 上去的 `Taxi.cpp`/`Player.cpp`/`TaxiHandler.cpp`、`dev/*.sql` 等）⇒ **那棵树不对应任何一个提交**，"线上跑的是哪一版"无法回答，出错也无法整体回滚。`dev/NNN_*.sql` 那套（编号 + 升序 + 幂等 + `.dev_sql_applied` 标记）本身是可靠的，问题只在**源码树分发**。

### 已做的三件事
1. **修好 git over ssh**（根因不是密钥）：git 经 `sh` 执行 ssh 时把 Windows 路径的**反斜杠吃掉**了（`Warning: Identity file C:UsersnYmpH.sshcodex_ecs_deploy not accessible`）。改用正斜杠即通，并写进本地仓库配置：
   `git config core.sshCommand "ssh -i C:/Users/nYmpH/.ssh/codex_ecs_deploy -o StrictHostKeyChecking=no"`；验证：`git ls-remote ssh://root@39.96.90.39/root/Nmangos-tbc` 列出 `HEAD / master / release` ✓。
2. **本地提交 push 成云端 `deploy` ref**（只加 ref，**不动工作树**）：`git push ssh://root@39.96.90.39/root/Nmangos-tbc HEAD:refs/heads/deploy` ⇒ 云端 `deploy = 3e72be978（添加鸟点飞行日志）`。
3. **装手动部署助手 `/root/deploy_from_git.sh`**（权限 755，`bash -n` 通过）——**只做**"备份就地改动 → checkout 到指定提交（detached，保证以后还能继续 push `deploy`）→ 打印版本指纹"，**不编译、不重启、不动 dev SQL 标记、不碰配置文件**：
   - `bash /root/deploy_from_git.sh deploy --dry-run` 先看要做什么；
   - **工作树脏就拒绝执行**（实测：当前 19 处未提交 ⇒ `[refuse] … 加 --allow-dirty-tree 重跑`），需要强切时先把 tracked 改动导成 `_prep_git_deploy_<ts>.patch`、未跟踪文件打包 `_prep_git_deploy_<ts>_untracked.tgz`、构建树里的旧二进制也留一份；
   - 结束后打印 `HEAD = <sha>` + `dirty files = 0` + 工作树内容指纹 `git ls-files -s | sha1sum`。
4. **夜间脚本只加"只读版本指纹"**（`/root/nightly_build_restart.sh`，改动为**纯新增 10 行**，`bash -n` 通过，备份 `nightly_build_restart.sh.bak_20260924_fingerprint`）：
   `[info] source HEAD: <sha> (<标题>)` + `[info] source dirty files: N`（N≠0 时逐行列出）。**`git sync disabled` 那段保持原样、没有启用** —— 按站长要求，绝不让夜间流程自动切换源码版本，避免把不稳定版本自动带上线。

### 还没做完的一步（需要站长拍板）
- 本地仍有未提交改动：`dev/KNOWN_ISSUES.md`、`src/game/Entities/Player.cpp`、`src/game/Entities/Taxi.cpp`、`src/game/Maps/TaxiHandler.cpp` + 未跟踪 `dev/112_*.sql`、`dev/rollback/112_*.sql`、`dev/rollback/112b_*.sql`（注意：`HEAD=3e72be978` 里只有**第一批**飞行日志，扩展/常开那批与 `TaxiHandler.cpp`/`Player.cpp` 还没进 git）。
- 这些提交后，云端树才算"= 某个提交"；届时跑一次
  `bash /root/deploy_from_git.sh deploy --allow-dirty-tree`（一次性对齐，会先备份），
  之后就用 `git push … :refs/heads/deploy` + `bash /root/deploy_from_git.sh deploy`（干净树无需 `--allow-dirty-tree`），**不再用 scp 传源码**。
- 生效方式不变：编译/重启仍只在夜间窗口或手工流程里做（`04:06` nightly / `03:00` restart）。





