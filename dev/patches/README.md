# PlayerBots 模块补丁与子模块（相对上游）

## 现状（2026-10-15 起）

`src/modules/PlayerBots` 现在是**外层仓库的子模块**（`.gitmodules` + gitlink），指向我们自己的 fork：

| 项 | 值 |
|---|---|
| 子模块路径 | `src/modules/PlayerBots` |
| 我们的仓库 | `https://github.com/Nightingale9002/playerbots.git`（fork 自 `cmangos/playerbots`） |
| 上游 | `https://github.com/cmangos/playerbots.git` |
| 我们的分支 | `kabu-2026.10` |
| 分支基点（上游） | `2f5ace00` |
| 我们的提交 | `2c8ed963`（vmap 修复 + GearProgression 告警）→ `c54ecb01`（装备阶段/不抢装备/缓存等级） |
| 本地兜底镜像 | `dev/hold/playerbots-bare.git`（裸仓库，已 ignore；模块内 remote 名 `mirror`） |
| 云端备份 | `/root/Nmangos-tbc/src/modules/PlayerBots` 的分支 `kabu-2026.10`（**只备份分支，云端工作分支仍是 master**） |

外层的 `.gitignore` 已做两处调整：
- 删除原来的 `src/modules/`（整目录忽略 ⇒ 模块改动不被跟踪）；
- 加白名单 `!.gitmodules`、`!dev/patches/*.patch`（否则被 `.*` 与 `*.patch` 规则挡掉）。

## 换机器 / 重新 clone

```bash
git clone --recursive <外层仓库>
# 已 clone 过的：git submodule update --init --recursive
```

## 重放补丁（不依赖子模块时）

```bash
cd src/modules/PlayerBots
git fetch upstream
git checkout -b kabu-2026.10 upstream/master
git am /path/to/dev/patches/0001-*.patch /path/to/dev/patches/0002-*.patch
```

补丁文件（`dev/patches/`，与分支内容一致，作为外层仓库里的可审查凭据）：

| 文件 | 内容 |
|---|---|
| `0001-fix-vmap-gear-*.patch` | ① `WorldPosition::loadVMap()` 的 vmap basePath 少了 `vmaps/` ⇒ `VMapManager2::_loadMap` 打不开 `.vmtree` 就把 mapId 写进 `iNoVmapDataMaps` **永久拉黑**，此后核心侧传对路径也无效；表现 `.los` 永远 `tree=NO`、vmap 高度/水位落回 `.map`（副本 -95）、水陆判据错乱＝**陆地上游泳**；只有 bot 会高频走 `getAreaFlag()` → `loadVMap()`，所以只有开 bot 才触发 ② `UpdateGearAction` 把配置里表示"该槽位留空"的 `0` 当物品 entry 装备，失败后刷聊天框告警 |
| `0002-feat-gear-*.patch` | 按副本换装备阶段（`GearProgressionSystem.InstancePhases`）、组里有真人时不抢装备（`PassRollsWithRealPlayer`）、装备缓存只建配置等级（`CacheLevels`）、随机装备默认阶段（`DefaultPhase`） |

## 上游升级流程

```bash
cd src/modules/PlayerBots
git fetch upstream
git checkout kabu-2026.10
git rebase upstream/master          # 把我们的两个提交挪到新上游之上
# 解冲突 → 本地 Release 编译 + 游戏内验证
git push origin kabu-2026.10
git push mirror kabu-2026.10
git format-patch upstream/master..kabu-2026.10 --output-directory ../../../dev/patches
```

> 注意（P0 铁律）：**未本地编译验证的模块改动不得同步到云端源码树**；云端分支只是备份，
> 要把改动真正上线，必须由站长明确下令后再切换/合并云端工作分支。

## 网络提示

本机访问 GitHub 需要走系统代理（`127.0.0.1:10792`）。模块仓库已就地配置 `http(s).proxy`；
临时命令可用：

```bash
GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=http.proxy GIT_CONFIG_VALUE_0=http://127.0.0.1:10792 \
GIT_CONFIG_KEY_1=https.proxy GIT_CONFIG_VALUE_1=http://127.0.0.1:10792 git push ...
```
