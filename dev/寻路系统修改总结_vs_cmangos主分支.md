# 寻路系统修改总结：Nmangos-tbc vs CMaNGOS 主分支

> 对比基准：fork 分叉点 `3e69c84c9`（2026-08-05，上游 master）；对比对象：上游最新 master `6904884e4`（本地 mangos-tbc 仓库）。
> 统计：27 个文件，**+1332 / -97** 行（`git diff 6904884e4..HEAD -- src/game/MotionGenerators src/game/vmap src/game/Maps/GridMap.cpp src/game/Maps/Map.cpp src/game/Movement src/game/Entities/Unit.cpp src/game/Entities/Creature.cpp contrib/mmap dep/recastnavigation`）。
> 整理时间：2026-08-27。历史演变细节见《KNOWN_ISSUES.md》寻路章节（时间线 8-14 ~ 8-27）。
> ⚠️ Unit.cpp/Creature.cpp 内还混有**非寻路改动**（黑兔仇恨协议、圣印舞、死怪攻击防御、辅助呼叫返回值），本文不展开。

---

## 〇、总览：fork 的三个设计取向 vs 上游

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

## 一、mmap 生成器（contrib/mmap + dep/recastnavigation）——数据侧

> 规则的改动需要**重新生成 mmtile**。本地已全量生成 v8（2764 tile + 72 个 .mmap，云端已部署）。`MoveMapGen` 部署注意：复制到 `x64_Debug/Extractors/MoveMapGen.exe`。

### 1. 三角形来源标记（TerrainBuilder + MapBuilder）
- `MeshData` 新增 `triSource`（每个三角形 0=ADT / 1=WMO / 2=矮M2 / 3=高M2），随 solidTris 同步生成。
- 按来源分别光栅化：**先 WMO（室内真地板）→ 再 ADT（洞/入口真表面）→ 最后 M2**（矮装饰需下方有实地面，否则 STEEP）。

### 2. 坡度规则（确定稿，v8）
- **ADT 地形**：保持上游 `rcClearUnwalkableTriangles` 60° 清除（曾试 89° 全可走 → 虚空 tile 顶点超 0xffff → 改回 60°）。
- **WMO 建筑**：`MarkSteepTrianglesAsSteep`——≥60° 标 `NAV_AREA_GROUND_STEEP`（障碍）而非清除；**向下朝的面（天花板底面，n.y<0）也必须 STEEP**（2026-08-24 修，fabsf 会让天花板变可走地板）。
- **M2 装饰**：高模型（> 4×walkableClimb×0.2667 ≈ 1.07码）全 STEEP（柱子/墙/大石不可爬）；矮模型默认待定，经 `HasSpanInWindow`（下方 0.5~4.5 码内有 span）判为可踩地面（箱子/车/桶）或 STEEP（悬空台阶）。
- **移除 WMO 覆盖 ADT 检查**（曾加 cy-15..cy-0.5 窗口判断，误删洞口 ADT → 门口缝隙 → 卡闪避）。
- **移除 `rcMedianFilterWalkableArea`**（中值滤波）。

### 3. 孤立 polygon 清理（MapBuilder buildTile）
- 对每个 navmesh poly：无内部邻居（neis=0）且无 EXT portal 的 GROUND poly，清掉 GROUND 标志 → 寻路过滤直接跳过。防 `findNearestPoly/getPolyHeight` 报幽灵高度（掉坑/飘顶根源）。
- 注意 neis 解码：`nei = raw & 0x8000 ? 0 : raw - 1`（存储为邻居索引+1，bit15=border）。

### 4. 侵蚀保留薄墙（RecastArea.cpp `rcErodeWalkableArea`，recast 库改动）
- STEEP（area 10）span 当作**侵蚀边界**（邻居是 STEEP 即 break），且 **STEEP 自身永不侵蚀**——薄墙/薄柱不再被蚀掉消失，保留为障碍。

---

## 二、运行时 vmap 高度模型（防"选错层"）

### 1. frontFacesOnly（MapTree / ModelInstance / WorldModel）
- 高度查询链路 `getIntersectionTime(..., frontFacesOnly=true)` 只接受**与射线方向夹角 ≤60° 的朝上面**（`n·rayDir <= -cos60` 才命中），墙/天花板背面/悬挑不再被当作地板。
- 其他用途（LOS、相交检测）不受影响（默认 false）。

### 2. `TerrainInfo::GetHeightStatic` 多层取层修复（GridMap.cpp）
- **[FIX-1] 限制无限搜索**：mapHeight 有效且调用者在地表上方（z2 > mapHeight）时，vmap 兜底搜索距离封顶 `z2 - mapHeight + 2.0f`；在地表下方（洞内怪）保留 10000 穿透找洞底。
- **[FIX-2] 接近性判定**：
  ```
  vmapCloseToZ   = |vmapHeight - z|        <= 1.0f   // 单位贴自己那层的地面（实测差 0.00~0.06）
  vmapCloseToMap = |vmapHeight - mapHeight| <= 3.0f  // 同层差 <1，跨层（表层/地下）差 >20
  两者都不满足 → 用 mapHeight（.map 地表），拒绝远层 vmap
  ```
- 这是 `.go name` / 宠物跟随 / `UpdateAllowedPositionZ` 共用入口，修好后地表单位不再被吸进地下墓穴层。

---

## 三、PathFinder（运行时寻路，+313 行）

### 1. 无 tile / 无 poly 的链式策略（防"卡闪避"）
- **无 tile**：`calculate` 一律 `BuildShortcut`（上游行为），不再对地面单位标 NOPATH（无 navmesh tile 的地面怪会冻住卡闪避）。
- **INVALID_POLY（起点/终点无 poly）**：游泳快捷路径**要求两端都位于可游水域** + 直线 LOS 可见；否则 NOPATH（防水面怪追岸上/空中目标被直线"抬升出水面"、防浅水直线穿过楼板）。
- **farFromPoly（终点距 poly 表面 >7 码，如玩家在二楼）**：陆地单位 LOS 可见 → `NORMAL|NOT_USING` 直线追（不穿空气）；LOS 被挡 → NOPATH（宁停不穿楼板）；飞行/游泳保持上游 INCOMPLETE。

### 2. 终点贴面（根因修复：穿模/飘顶）
- 陆地（非飞、非水）终点无条件 `closestPointOnPoly` 吸附到 navmesh 表面（两端都做：起点下方模型面会被拉回，玩家跳坑上方不会再让怪垂直升空）。
- **同 poly**：水中→直接 shortcut（不贴面防拖下海床）；飞行→LOS 校验后 shortcut；陆地→两点必须都在 poly 表面 **1.5 码内**，否则 NOPATH（跨层桥接 poly 直线穿空气被禁），通过后终点吸附到面上。

### 3. 平滑路径（findSmoothPath）
- iterPos/targetPos 补 `getPolyHeight`（closestPointOnPolyBoundary 不改高度）。
- **ZSnap 兜底已移除**（2026-08-24）：`|z-unitZ|>10 → z=unitZ+0.5` 会把 >10 码下坡压成水平线（怪飞着走，如 58284 z=67.59 地面 47）；信任 navmesh poly 高度。

### 4. 随机漫步点生成（ComputePathToRandomPoint）
- **深水分支**（CanSwim && IsInSwimmableWater）：目的地水柱校验 `[底+0.5, 水面-0.5]` 内保持当前深度，沿途 4 点采样地形，任何一点高于游深 → NOPATH 重掷（防钻地/浮空）；浅水不再当游泳走（浅水怪之前永远不移动）。
- **陆地分支**：随机点必须落在自己那层的地面上（floorZ 误差 ≤1.0），且到目标直线 **LOS 可见**（防随机点选在树根/岩石/建筑里卡住）。

### 5. 其他
- `PathFinder::setPathType` 新增（供追击器改写类型）。
- `[PFDBG]` 日志（aura 10909 门控，见第七章）。

---

## 四、追击 / 跟随（TargetedMovementGenerator，+362 行）

### 1. Chase（追击）
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

### 2. Follow（跟随）
- **水中跟随**：canSwim && IsInWater → 直线到主人位置（无论主人在水中还是岸上），type 置 NORMAL。
- 陆地路径点 `GetHeight` floorZ 修正：vmap floor 比 navmesh 低 **2 码以上**视为错层，跳过不拉低；否则贴地。
- **相邻点 z 差 >3 码且 LOS 不通 → 路径非法拦截**（防宠物穿墙/穿洞）。
- Relocation 类型修复：`TypeId()==UNIT` 才 `CreatureRelocation`（防 Player 下转型 UB）。
- 下水/上岸状态切换重寻路（同 Chase）。

---

## 五、水移动系统（游泳状态 + 路径 + 客户端呈现）

### 1. 动态游泳状态（Unit.cpp `Update`）
- 迟滞式判定：`z < 水面-0.5` → SetSwim(true)；`z > 水面+0.5` → SetSwim(false)；中间带保持原状态；**跳过 WALK_IN_WATER**（螃蟹贴底）。
- `SetSwim` 同步写 **`UNIT_FIELD_FLAGS` 的 `UNIT_FLAG_SWIMMING`(0x8000)**——客户端游泳动画的持久锚定（0x30B 单发 ~2s 衰减、重建对象无效，仅此方案一直有效）。

### 2. 统一水中路径重写（MoveSplineInit.cpp）
- **GATE：只在单位确实在水中（IsInWater）时才重写路径 z**（曾对所有 spline 生效：GetHeight 穿透 WMO 缝隙到海底 z=-92.4，把陆地怪拖进地下室）。
- walkInWater 或不会游泳 → 贴 `groundZ+0.5`；会游泳 → clamp 到 `[groundZ+0.5, 水面-1.5]`（完全没入水中）；路径点在水面上（岸/船甲板）→ 跳过不拉低。
- 覆盖所有移动类型（chase/follow/wander/waypoint/home）。

### 3. 其他移动相关（Unit.cpp）
- `UpdateAllowedPositionZ`：**水中单位跳过 z 修正**（防水面/水底弹跳）；陆地 z 拉回上限 **10 码**（防 GetHeight 错层一帧帧拉下深坑）。
- `UpdateSplinePosition`：spline 移动后同步 `m_movementInfo.ChangePosition`（防 movement 包带陈旧出生点位置）。
- `MoveSpline.cpp`：零长度 spline 不再刷 `zero length spline` 错误日志（强制 1ms 原地停留）。

---

## 六、其他运行时改动

### 1. MoveMap（mmap 内存与按需加载）
- **`TrimMmapMemory()`**：三处卸载路径（tile / .mmap / instance）后 30 秒节流 `_heapmin()`(Win) / `malloc_trim(0)`(Linux)，解决卸载后 RSS 不降。
- **`loadMap` 崩溃修复**：遇到未预加载的 map 改为**自动 `loadMapData`**（而非 `MANGOS_ASSERT`）——修复启动期 `RespawnEmeraldDragons → IsSwimmable → GetHeightStatic → loadMap(530)` 直接 SIGABRT（与 v8 mmap 缺 72 个 .mmap 文件叠加导致）。

### 2. 网格/内存（Map.cpp，与寻路交互）
- `ForceLoadGrid` 去掉 `setUnloadExplicitLock(true)` 永久锁；`ActiveObjectsNearGrid` 只查玩家+transport（active 怪不再阻止卸载）→ 网格完全懒加载，启动内存 -50%（详见 KNOWN_ISSUES [内存] 章）。
- 附带 UAF 修复（ObjectGridLoader 卸载前 RemoveFromActive）见 KNOWN_ISSUES [宕机根因]。

### 3. 随机/巡逻地面吸附
- `RandomMovementGenerator::_setLocation`：非飞行/悬浮/水中单位路径每点 `GetHeightInRange` 吸地（b82434357 引入；GetHeightStatic 修复后不再误伤）。
- `WaypointMovementGenerator`：**已移除** GetHeightInRange 吸附（08-24，注释说明信任 navmesh poly 高度，重吸附会把巡逻怪拖进错误层）。

### 4. 冲锋（MotionMaster::MoveCharge）
- 改为 navmesh 路径（`MoveTo(..., generatePath=true)`）：终点落 navmesh 表面，不再直线穿墙/飘顶（曾试直线冲锋，08-24 移除）。

---

## 七、调试设施：PfDebug.h（新增）

- 统一寻路调试日志：`IsPfDbg(unit)` = 单位且带 **aura 10909（心灵视界）** 才打印，前缀 `[PFDBG]`，sLog.outError 级。
- 覆盖 PathFinder（calculate/FINAL/BuildPolyPath/随机点）、TargetedMovementGenerator（Dispatch/SPLINE）、MoveSplineInit（water gate）等；**保留在代码中**（本地+云端），排查穿模/掉坑时给 GM 目标怪上 10909 即可定点抓日志。
- 云端 Server.log 的 `[PFDBG]` 即此设施产物（须有 aura 10909 才刷）。

---

## 八、Commit 映射（本地 release，倒序）

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

## 九、已知权衡与遗留（结论）

1. **多层地形穿模（Duskwood 洞穴案）**：GCC vs MSVC 浮点差异导致 findSmoothPath 插值判层不同，本地平滑/云端跳变；已接受现状，拒绝 z 斜率限制（会引入卡闪避/新穿模）。仅多层地形区偶发。
2. **湿地维尔加挖掘场桥**：宠物绕桥下的 vmap 多层未命中问题，待办中（见 KNOWN_ISSUES [地图]）。
3. **PFDBG 日志保留**（aura 10909 门控，无 GM 操作不刷屏），供后续排障；GRIDDBG/HEIGHTDBG 等亦保留但限区域/防刷屏。
4. **mmap v8**：云端已部署（2764 .mmtile + 72 .mmap）；`MMAP_VERSION=8` 与云端一致，改规则必须升版本或手动删旧 tile。
5. 大原则：**服务端逻辑向客户端靠拢**，导航网格（navmesh poly 高度）是移动可走性的唯一权威，vmap/.map 高度只做接近性兜底。