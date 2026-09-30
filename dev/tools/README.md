# dev/tools — 导航网格（mmaps）重生成与 GO 烘焙工具

这套工具用于**全量重生成 dbc / maps / vmaps / mmaps**，其中 mmaps 这一层额外支持把
**gameobject 的碰撞模型烘进地形导航网格**（解决"怪物穿过笼子"这类问题）。
2026-09-30 用它完整跑过一次，产物与结论见 `KNOWN_ISSUES.md` 的
「[寻路] 2026-09-30 全量素材重生成 + GO 碰撞烘焙」一章。

## 前置：编译提取器

```powershell
cmake --build D:\Game\cmangos\build1 --config Release
# 产物在 build1\bin\x64_Release\Extractors\：
#   ad.exe            dbc + maps
#   vmap_extractor.exe 原始 vmaps（写入 <out>\Buildings）
#   vmap_assembler.exe 组装成 vmaps
#   MoveMapGen.exe     导航网格（本 fork 版：支持 --configInputPath / --offMeshInput / --gameObjectInput）
```

## 一键跑（两个阶段）

```powershell
# 阶段 1+2：dbc + maps + vmaps  →  powershell -File regen_stage12.ps1
# 阶段 3  ：mmaps（生产配置 + 530 offmesh + 全库 GO 烘焙） →  powershell -File regen_stage3.ps1
```

两个脚本都只写 `D:\Game\cmangos\_regen\`，**不碰线上数据目录**。
阶段 1+2 实测 2.5 分钟，阶段 3 实测 **8.4 分钟**（16 线程，72 图 / 3586 格）。

## 各文件说明

| 文件 | 作用 |
|---|---|
| `config_prod.json` | **生产 mmap 配置**：出厂 `config.json` 的全套 per-map/tile 值 + 两处修正（见下） |
| `gen_go_bake.py` | 从世界库导出 GO 刷点 + `GameObjectDisplayInfo.dbc` 解析模型名，生成 `--gameObjectInput` 文件 |
| `check_go_bake.py` | 在世界坐标处查导航面（验证烘焙是否把模型位置挖掉），依赖 `ray_ground_probe.py` |
| `ray_ground_probe.py` | mmtile 解析库（被 `check_go_bake.py` import） |
| `vmtree_probe.py` | 解析 `<map>.vmtree`：tiled 标志、BIH 规模、全局模型 |
| `vmo_probe.py` | 解析 `*.vmo`：每个 group 的顶点/三角形数（判断模型有没有碰撞几何） |

## 必须知道的坑

1. **`vmap_assembler` 要求输出目录先存在**：不先 `mkdir <out>\vmaps` 会报
   `Cannot open .../vmaps/000.vmtree` + `error converting *.wmo` 直接退出（标准
   `ExtractResources.sh` 里有这一步，自己写脚本容易漏）。
2. **`config_prod.json` 里 `532/3552` 的 `maxSimplificationError` 被故意删掉**：
   该值为 1.0 时 `rcBuildContours` 失败 ⇒ 卡拉赞那一格（`mmaps/5325235.mmtile`）
   **静默不写出**。出厂 `config.json` 至今还带着这个值，每次生成前都要处理。
3. **不要用新提取的 dbc 覆盖线上 dbc**：`Spell.dbc` 与 `SkillLineAbility.dbc` 是我们改过的
   （内容与客户端原版不同），覆盖会把补丁冲掉。`maps` / `vmaps` 重提取与现用完全一致，可放心替换。
4. **GO 烘焙的坐标约定**（踩了很久的坑）：
   - 传进生成器的必须是世界坐标，生成器内部做 `(-x, -y)` 镜像；
   - 生成器 mesh 空间 = `(worldY, 高度, worldX)`；
   - mmtile 文件名 = `<map><tileY><tileX>`，`tileY = int(32 - world_x/533.33)`、`tileX = int(32 - world_y/533.33)`。
   弄错会"几何合并进去了但导航网格毫无变化"（模型被扔到差一格的空域）。
5. **GO 烘焙只对"在 vmaps 里有碰撞几何"的模型有效**：全库 63,804 个刷点里只有
   32,413 个能烘（其余模型只有视觉、没有碰撞体）。可先用 `vmo_probe.py` 抽查。

## 用法示例

```powershell
# 只重生成 map 556（快速验证）
MoveMapGen.exe 556 --workdir D:\Game\cmangos\_regen `
  --configInputPath D:\Game\cmangos\_regen\config_prod.json `
  --offMeshInput    D:\Game\cmangos\_regen\offmesh_530_all.txt `
  --gameObjectInput D:\Game\cmangos\_regen\go_bake_all.txt `
  --silent --threads 8

# 重新生成"交通/升降梯"的 go*.mmtile（不在上面那次里）
MoveMapGen.exe --workdir D:\Game\cmangos\_regen --buildGameObjects --silent

# 生成 GO 烘焙输入（全库 / 只某图）
python gen_go_bake.py go_bake_all.txt
python gen_go_bake.py go_bake_556.txt 556

# 验证：某世界点在新旧两套 mmaps 里有没有导航面
python check_go_bake.py 556 -161.01 157.32 0.01 <旧mmaps目录> <新mmaps目录>
```
