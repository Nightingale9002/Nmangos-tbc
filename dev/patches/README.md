# PlayerBots 模块补丁（相对上游）

## 为什么有这个目录

`src/modules/PlayerBots` 是**独立的 git 仓库**（上游 `https://github.com/cmangos/playerbots.git`），
而外层 `Nmangos-tbc` 的 `.gitignore:99` 有 `src/modules/`，所以**模块代码不被外层仓库跟踪**。
我们对模块做的修复因此不在任何 git 历史里，一旦重新 clone / reset / 换机器就会静默丢失。
这里存放"我们相对上游的补丁"，作为外层仓库里的凭据与重放手段。

## 当前补丁

| 文件 | base（上游 commit） | 我们的提交 | 内容 |
|---|---|---|---|
| `playerbots_2026-10-15_vmap_and_gearslot.patch` | `2f5ace00` | `79d8b5c2`（分支 `kabu-2026.10`） | ① `WorldPosition::loadVMap()` 的 vmap basePath 少了 `vmaps/`，会让 `VMapManager2` 把整张图写进 `iNoVmapDataMaps` **永久拉黑**（表现为 `.los` 永远 `tree=NO`、vmap 高度落回 `.map`、副本 -95、水陆判据错乱＝"陆地上游泳"；只有开 bot 才会触发）② `UpdateGearAction` 把配置里表示"该槽位留空"的 `0` 当物品 entry 装备，失败后刷聊天框告警 |

## 怎么重放（在模块仓库里）

```bash
cd src/modules/PlayerBots
git fetch origin
git checkout -b kabu-2026.10 origin/master      # 或先把分支 fast-forward 到新的上游 master
git am /path/to/dev/patches/playerbots_2026-10-15_vmap_and_gearslot.patch
```
有冲突就手工合，然后把新提交继续放在 `kabu-2026.10` 上，并更新本文件的表格。

## 上游升级流程（目标形态）

1. `cd src/modules/PlayerBots && git fetch origin && git checkout master && git merge --ff-only origin/master`
2. `git checkout kabu-2026.10 && git rebase master`（把我们的补丁挪到新上游之上）
3. 重新导出补丁：`git format-patch -1 kabu-2026.10 --stdout > dev/patches/<新文件>.patch`
4. 本地 Release 编译 + 验证（见 HANDOFF 的 P0：**未验证不得同步云端**）

## 计划：改成 git submodule

既然模块是独立仓库，长期方案是把它作为**子模块**挂到外层仓库，让外层记录确切 commit：

1. 在 GitHub 建 fork：`cmangos/playerbots` → `Nightingale9002/playerbots`
2. 模块仓库：`git remote add kabu https://github.com/Nightingale9002/playerbots.git`
   `git push kabu kabu-2026.10:kabu-2026.10`（可再把 `kabu-2026.10` 设为该 fork 的默认分支）
3. 外层仓库：删掉 `.gitignore:99` 的 `src/modules/`，然后
   `git submodule add https://github.com/Nightingale9002/playerbots.git src/modules/PlayerBots`
   （若目录已存在：先备份 `.git`，再 `git submodule add --force <url> <path>`）
4. 外层提交 `.gitmodules` 与 gitlink；之后 clone 用 `git submodule update --init --recursive`
5. 云端源码树同步时，模块部分改为记录 fork 的 commit（**仍按 P0**：验证过才同步）

> 注意：改成子模块后，本目录的补丁文件**保留**，作为"外层的可审查凭据"；权威版本以子模块仓库的 `kabu-2026.10` 分支为准。
