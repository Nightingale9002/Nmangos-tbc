# 部署必读：conf 文件的坑（2026-09-26 事故复盘）

> 本文是**部署流程**与**交接（HANDOFF）**的必读项。任何一次"编译 + 装新二进制"的部署前，先看这一页。

## 一、事故经过（2026-09-26 凌晨）

1. 凌晨按站长指令在云端执行了完整的构建+部署（`/root/nightly_build_restart.sh`，01:19 停服 → 01:56 装新二进制 → 01:57 世界初始化完成）。
2. 部署后玩家反馈：**拍卖行里没有金属、矿石，也没有任何"书目（cat1）"商品**，而普通 loot 来源的货都在。
3. 排查结论：**不是数据丢了、也不是互通坏了**，而是新二进制读到的 **运行期 conf 与源码树里的模板/我们记忆中的配置不一致**，导致做市商（market maker）的书目供货被整体关停。

## 二、根因：conf 不在 git 里，且分散在两个目录

- **线上 conf 不受版本管理**：仓库里只有上游模板（`src/mangosd/mangosd.conf.dist.in`、`src/game/AuctionHouseBot/ahbot.conf.dist.in`、`src/game/PlayerBot/playerbot.conf.dist.in`、`src/game/Anticheat/module/anticheat.conf.dist.in`），**没有任何一个线上 conf 被 git 跟踪**。
- **同一个程序的 conf 分散在两处**：
  - `mangosd.conf` / `realmd.conf` 在 **`/opt/mangos/bin/`**（进程 cmdline：`./mangosd -c /opt/mangos/bin/mangosd.conf`）
  - `ahbot.conf` / `anticheat.conf` 在 **`/opt/mangos/etc/`**（日志里 AHBot 打印的是 `../etc/ahbot.conf`）
- **新代码可能读取新增的 conf 键**，而线上 conf 是**手工维护**的：键不存在时走 `GetIntDefault/GetBoolDefault` 的**默认值**，默认值往往就是"关闭/最保守"。本次事故就是这类"**新代码 + 旧 conf**"的错配。
- 相关的直接证据链（供后人复用）：
  - `AuctionHouseBot.cpp:222` `m_marketEnabled = GetBoolDefault("AuctionHouseBot.Value.Dynamic", false)`（**默认 false**）
  - `:223` `m_marketRefresh = GetIntDefault("AuctionHouseBot.Value.DynamicRefresh", 60)`
  - `:381` 书目供货唯一入口 `if (m_marketEnabled && m_catalogEnabled) QuoteCatalog(...)`
  - `:466-467` 普通 loot 供货**跳过 `category != 0` 的行** ⇒ 书目物品不走 loot 路径，一旦上面的入口关掉就**整类消失**
  - `:1810-1819` `QuoteCatalog()` 还有个硬守卫：**最近 150 秒内必须跑过一次行情扫描**，否则直接 return

## 三、部署流程里必须加的三步（P0）

**部署前**
1. **记录并对照 conf 关键键**：至少 diff 一次运行期 conf 与上次部署时的快照
   （`/opt/mangos/bin/mangosd.conf`、`/opt/mangos/etc/ahbot.conf`，以及 `realmd.conf`/`anticheat.conf`）。
2. **看新代码有没有引入新键**：对本次改动涉及的模块，`grep` 一下 `GetIntDefault/GetBoolDefault/GetStringDefault` 的键名，
   与运行期 conf 逐条对照；**缺键就用默认值**，而默认值通常是"关闭"。
3. **备份**：`cp` 成带日期的 `.bak`（现场已有多份 `ahbot.conf.bak_*` 的先例，沿用这个习惯）。

**部署后**
4. **验证 AHBot 关键行**：`AHBot selling items: Enabled`、`market-maker catalog: N book items`、
   `price pairs loaded: N`、`price recipes loaded: N`，以及**有没有新的 `ERROR:[AHBOT]` 行**。
5. **验证"看得见的业务"**：至少查一次拍卖行——**cat0（普通 loot）与 cat1（书目）都要有货**
   （`tbccharacters.ahbot_market_state` 按 `category` 分组 + `tbccharacters.auction` 交叉计数）。
   注意 AHBot 的表都在 **character 库（`tbccharacters`）**，不在 world 库（`tbcmangos`）。

## 四、给交接的一句话

> **改动任何"读 conf"的代码时，先确认线上 conf 里有没有那个键。**
> conf 不受 git 管理、还分散在两个目录（`/opt/mangos/bin/` 与 `/opt/mangos/etc/`），
> 这是本服最容易"部署完就出事、而且没有任何日志报错"的地方。

（站长已明确：**暂不做"conf 进 git + 启动项指定路径"**。若将来要做，建议方案：
`conf/` 纳入仓库、连接串用 `@DB_PASSWORD@` 占位、`start_cloud.sh` 渲染后以 `-c` 显式启动，
并让 watchdog 与夜间脚本统一走这个启动脚本。）

## 五、本地 conf ↔ 云端 conf 实测差异表（2026-09-26 复核）

**这是"本地测得好好的、云端不一样"的根源**：本地 `D:\Game\cmangos\x64_Debug\ahbot.conf`
与云端 `/opt/mangos/etc/ahbot.conf` 键集与取值都不一致（本地 478 键 vs 云端 494 键）。

### ✅ 已处置（2026-09-26）：站长指示「用云端 conf 覆盖本地的」

- **只覆盖 `ahbot.conf`**（站长明确范围）：
  - 备份：`D:\Game\cmangos\x64_Debug\ahbot.conf.bak_20260926`（16133 B）
  - 覆盖：`scp root@39.96.90.39:/opt/mangos/etc/ahbot.conf → D:\Game\cmangos\x64_Debug\ahbot.conf`（269 行）
  - 重启本地服后实测生效：`LadderStep = 5`、`ProbeUnits = 0`（探针单关闭）、`BuyDepth = 0`、
    `Value.Epic` 第 3 位 = 50、拍卖时长走 12h；书目照常上架（`[MMQUOTE] quoted=130 full=292`）。
- **覆盖前**的差异（留档，供理解历史结论的可信度）：

| 键 | 旧本地 | 云端 | 影响 |
|---|---|---|---|
| `MarketMaker.LadderStep` | 50 | **5** | 阶梯档距 ⇒ 档数、各档价差、每件挂单张数都不同 |
| `MarketMaker.Time.Min` / `Time.Max` | 24 | **12** | 拍卖时长（小时） |
| `MarketMaker.ProbeUnits` | 5 | **0** | 云端 2026-09-22 起关闭探针单 |
| `MarketMaker.BuyDepth` | 10 | **0** | 隐藏收购上限 |
| `Value.Epic` | 25 | **50** | 紫装估价倍率 |
| `MarketMaker.MinMoveCopper` | 有（1） | **无此键** | 代码默认 1 ⇒ 行为一致（覆盖后本地也走默认，**不要再往本地加这一行**，否则又产生差异） |
| `MarketMaker.QuoteExposurePct` / `ListBatch` / `CatalogCapacity` / `DemandBoostPct` / `IdleTargetDecayPct` / `DepthTarget*` / `DepthStepPct` | 部分有 | 有 | **2026-09-26 起无代码读取** ⇒ 死键，改 conf 时顺手删 |
| loot 各速率（`Loot.Creature.*` 等） | 与云端不同 | — | 随本次覆盖一并消除 |

- **仍未对齐（故意不动）**：`mangosd.conf` / `realmd.conf` / `anticheat.conf` **没有覆盖**——
  云端 `mangosd.conf` 带线上库连接串（`tbccharacters` 的密码）、`/opt/mangos/...` 数据与日志路径，
  直接覆盖会让本地跑不起来。若将来要覆盖面更大的，**只挑玩法相关键逐条对齐**（连接串/路径必须保留本地值）。

**规矩**：要在本地复现云端行为（尤其是拍卖行/经济类改动），**ahbot.conf 必须先与云端一致**
（现在已一致）；改本地 conf 做实验后，**实验完要么改回云端值、要么明确记档**，否则下次又会"本地好好的、云端不一样"。
