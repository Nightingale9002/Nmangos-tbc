# 本地单 Boss 并发测试流程

日期：2026-11-18。本文是独立操作流程；贞洁圣女十组并发的实测记录见末节。

所有bot的 `item` 行为由代码永久启用，不受配置项、随机/招募身份或运行时cheat命令影响。代码定位：`playerbot/PlayerbotAI.cpp → PlayerbotAI::HasCheat() / UpdateAI()`。它沿用item既有语义，包括施法材料/物品检查与弹药便利；不代表永久满血、满蓝、无冷却或加速。下文清空两组可选cheat仅为关闭其他作弊，不能关闭item。

## 1. 测试规格：按副本人数，直接并发

每轮选定一个副本、一个 Boss、一个难度和一个装备档，一次准备 N 支完整队伍，再让各队在不同实例中同时战斗。**每队人数 P 按目标副本实际规格确定，不统一设成五人，不安排先一队再增加队伍的阶段。**

| 目标副本规格 | 每队人数 P | N队并发所需角色 |
|---|---:|---:|
| 五人地下城 | 5 | N×5 |
| 十人团队副本 | 10 | N×10 |
| 二十五人团队副本 | 25 | N×25 |
| 其他明确支持的副本规格 | 按该副本额定人数 | N×P |

完整人数指本轮实际在场并参战的人数，不只看团队容量或发出的登录请求。职责配比按具体Boss确定；坦克、治疗数量和DPS构成写入测试卡，不把所有场景强制设成1坦1奶3DPS。队长使用本场承担起手仇恨的坦克。

并发模型：

- 一个专属本地世界服、N个独立实例、N支完整队伍。
- 各队打同一个Boss在不同实例中的原生对象，角色GUID、账号、队伍和实例均不交叉占用。
- 控制台指令由一个调度器依次发送，战斗在服务器内重叠推进；不要求同一毫秒开怪。
- 每队独立起止计时、独立判定、独立停止；一队失败不停止其他队伍。
- N直接使用本轮目标值；容量须以本地实测确定，没有预先验证的固定上限。

## 2. 先核对现有命令能否承载该人数

**副本要求人数与当前工具能力必须分开。** 当前工作树的场景入口有以下限制；本次没有修改这些实现，也没有证明安装产物已包含全部入口。

| 当前入口可执行范围 | 人数 | 就位方式 |
|---|---:|---|
| 可独立激活的非团队五人副本Boss | 5 | `stageclean`，普通或英雄 |
| 卡拉赞map532，Boss entry16457或15691 | 10 | `raidstageclean`，普通难度 |
| 其他十人Boss、二十五人本及其他规格 | 按副本要求 | 当前这套入口未覆盖，停止在工具适配，不缩编开测 |

入口对人数、地图及目标有硬检查。二十五人Boss需要完整二十五人场景控制能力，不能拆成五队五人、降低Boss血量或让五人入场后记为二十五人测试。需要扩展入口时，先补齐对应人数的登录、团队建立、原生实例绑定、追踪、状态采集和分队停止，再本地编译与运行验证；在此之前报告“未执行：场景入口不支持该人数”。

单刷点清场会移除目标以外的生物，因此只用于可独立激活的目标。双Boss、原生助手、刷怪组或前置事件参与的战斗必须保留完整依赖；不适配时记场景不支持，不通过解除免疫或设置事件完成伪造战斗。

## 3. 固定全轮输入与名单

全轮测试卡保存：session、N、P、副本人数依据、map、difficulty、Boss基础entry及英雄映射、原生DB刷点GUID、集合坐标、装备档、各职责配比、观察上限和要验证的具体机制。另存实际二进制MD5/对应符号产物、源码版本与差异、配置副本、本地库备份位置。

每队记录：team、trial、全部P名成员GUID、全部账号ID、真实职责/天赋装备、leader、instance、真实开战时间、deadline和result。

所有角色必须是本地公共固定装备bot，等级合适，不在其他队伍/招募/场景中，不混入真人。账号也要跨队互斥，防止同账号多角色登录互踢。食水、技能和非item覆盖的消耗品准备放在采集前；施法材料不作为bot准入或开战阻塞条件，item永久生效。

公共账号必须按运行时 `RandomBotAccountPrefix + [0, RandomBotAccountCount)` 的精确名称核对。`LIKE 'RNDBOT%'` 会误收RNDBOTT等历史测试账号，数据库存在也可能被bosslogin拒绝；不得据此虚报已配齐100个可登录账号。

本轮 `teams.tsv` 使用UTF-8、无表头、Tab分隔，每行如下：

```text
team标签    leader_GUID    member2_GUID    ...    memberP_GUID
```

上面仅表示列结构，实际文件使用Tab，不能保留省略号。每行恰好1个标签加P个GUID；标签仅字母、数字、下划线或短横线。全表恰好N行，标签唯一，角色及账号全局互斥。账号映射和职责详情保存在测试卡中核对，不能只检查GUID。

只连接本地开发数据库。通过只读查询确认目标刷点和英雄映射；将占位符替换为确定整数：

```sql
SELECT guid,id,map,position_x,position_y,position_z,orientation
FROM tbcmangos.creature WHERE map=<MAP> AND id=<BOSS> ORDER BY guid;
SELECT Entry,HeroicEntry FROM tbcmangos.creature_template WHERE Entry=<BOSS>;
```

集合点需处于原生房间内，地形可站立、不提前引怪，且目标在队长180码搜索范围内；不能直接照抄Boss脚底坐标。

## 4. 专属本地运行环境与发令通道

使用WSL `Ubuntu-20.04`。检查本地进程与端口，确认没有其他轮次占用世界服、角色库或构建树。不强杀其他进程。

准备本轮独立目录 `SESSION`，放入完整的世界服/机器人配置，数据库只指向本地开发库。显式核对以下选项；这些只是配置要求，不能代替完整配置：

```ini
WorldServerPort = 18086
BindIP = "127.0.0.1"
DataDir = "/root/run_local"
# LogsDir必须是本轮独立日志目录的绝对路径。
SOAP.Enabled = 0

AiPlayerbot.Enabled = 1
AiPlayerbot.SimMode = 1
AiPlayerbot.StaticBots = 1
AiPlayerbot.RandomBotAutologin = 0
AiPlayerbot.RandomBotAutoCreate = 0
AiPlayerbot.RandomBotLoginAtStartup = 0
AiPlayerbot.AutoDungeonRun = 0
AiPlayerbot.DungeonRoute = 0
AiPlayerbot.DisableBotOptimizations = 1
AiPlayerbot.BotCheats = ""
AiPlayerbot.RndBotCheats = ""
AiPlayerbot.EquipBestGear = 0
```

配置含凭据，只留本地、不回显、不提交。将本轮的mangosd、aiplayerbot、ahbot三份配置放入独立目录。运行目录及FIFO使用WSL原生文件系统（例如 `/root/run_local/<本轮目录>`）；本机实测在 `/mnt/d` 创建FIFO返回不支持操作。证据可另行复制到D盘。起服前确认所选端口空闲，地图素材与本地数据库可用。在同一个WSL Bash会话中启动；另存脚本时使用LF换行：

```bash
: "${SESSION:?填写已准备完整配置的本轮独立目录}"
: "${BIN:?填写已编译并核对的永久item/nativepull产物绝对路径}"
FIFO="$SESSION/console.fifo"
test -x "$BIN" && test -f "$SESSION/mangosd.conf" && \
    test -f "$SESSION/aiplayerbot.conf" && test -f "$SESSION/ahbot.conf" || exit 1
test ! -e "$FIFO" || exit 1
umask 077
mkdir -p "$SESSION/logs" "$SESSION/teams"
mkfifo "$FIFO"
export BOT_METRICS=1 BOT_KARA_AUDIT=1 BOT_BEHAVIOR_AUDIT=1
nohup sleep 86400 > "$FIFO" 2>/dev/null &
WRITER_PID=$!
nohup "$BIN" -c "$SESSION/mangosd.conf" -p "$SESSION/aiplayerbot.conf" \
    -a "$SESSION/ahbot.conf" \
    < "$FIFO" > "$SESSION/console.log" 2>&1 &
SERVER_PID=$!
printf '%s\n' "$SERVER_PID" > "$SESSION/server.pid"
printf '%s\n' "$WRITER_PID" > "$SESSION/writer.pid"
md5sum "$BIN" > "$SESSION/binary.md5"
```

确认实际进程exe/参数、监听、初始化完成日志与本轮配置一致，且无数据库/配置/素材错误。入口不存在或回执不符时停止核查产物，不据源码存在宣称运行支持。

所有控制写入共用一个锁，避免并发写者把命令混进同一FIFO；返回写入成功仍须看服务端回执：

```bash
send_team() {
    local label="$1" command="$2"
    kill -0 "$SERVER_PID" 2>/dev/null && test -p "$FIFO" || return 1
    (
        flock -w 5 9 || exit 1
        printf '%s\t%s\t%s\n' "$(date -Is)" "$label" "$command" >> "$SESSION/commands.tsv"
        timeout 5 bash -c 'printf "%s\n" "$2" > "$1"' _ "$FIFO" "$command"
    ) 9>"$SESSION/console.lock"
}
```

## 5. 一次性准备全部N支完整队伍

以下是每队模板，对清单内全部N队执行。准备可以依次完成，**全部就绪后才进入正式开战，不先测一队**。每步核对真实回执后再推进；不能把一串异步命令写入当作准备完成。

将当前行读取为队伍标签和P个成员，首名为leader。可用 `read -r -a ROSTER` 将该行成员字段读入Bash数组；执行前核对 `${#ROSTER[@]}` 等于P。

### 5.1 登录、职责与装备

对每队执行：

```bash
: "${TEAM:?填写队伍标签}" "${P:?填写副本要求人数}"
test "${#ROSTER[@]}" -eq "$P" || exit 1
LEADER="${ROSTER[0]}"
send_team "$TEAM" ".rndbot sim bosslogin ${ROSTER[*]}"
```

当前入口接受5或10个GUID，不接受25个。登录回执只表示请求排队；等待每名成员实际上线、传送结束，再分别请求 `verifybot <guid> state` 和 `mechcheck <guid> state`，核对真实职责、装备与技能。

`verifybot state` 的装备槽数不能证明职责正确；`verifybot repair` 会重应用专精/装备，不在正式采集中执行。所有队伍保持测试卡指定的P人和职责配比。

### 5.2 试验前初始化

```bash
for guid in "${ROSTER[@]}"; do
    send_team "$TEAM" ".rndbot sim mechcheck $guid pretrialsetup"
done
```

等本队全部P人传到副本外、脱战、存活且传送完成，再逐人执行：

```bash
for guid in "${ROSTER[@]}"; do
    send_team "$TEAM" ".rndbot sim mechcheck $guid fresh"
done
```

核对逐人解绑回执。`pretrialsetup` 包括退队、复活和补满资源，只能算trial之间的初始化，不计战斗内恢复；`fresh` 要求副本外、无队、存活且空闲。

### 5.3 根据副本人数建立独立实例

```bash
: "${MAP:?填写地图ID}" "${BOSS:?填写Boss基础entry}"
: "${DIFFICULTY:?填写normal或heroic}" "${X:?填写集合X}" "${Y:?填写集合Y}" "${Z:?填写集合Z}"
LEADER="${ROSTER[0]}"
if [ "$P" -eq 5 ]; then
    STAGE=stageclean
elif [ "$P" -eq 10 ] && [ "$MAP" -eq 532 ] && \
     [ "$DIFFICULTY" = normal ] && { [ "$BOSS" -eq 16457 ] || [ "$BOSS" -eq 15691 ]; }; then
    STAGE=raidstageclean
else
    printf '当前场景入口未覆盖该副本人数/地图/Boss，停止本轮准备\n' >&2
    exit 1
fi
send_team "$TEAM" ".rndbot sim mechcheck $LEADER $STAGE $MAP $DIFFICULTY $X $Y $Z ${ROSTER[*]:1} $BOSS"
```

若返回 `pending original spawn update; no teleport`，等待世界更新并核对回执后，对该队用原参数重新请求；不能当作已就位。共享实例、缺Boss或清场残留均为准备失败。

保存该队 `[BOSS-PREENTRY-CLEAN] ... players=0 ... beforeTeleport=1` 及实际传送完成证据。逐人查询 `mechcheck <guid> state`，确认本队全部P人同图同实例、存活、未提前交战，记录实例ID。

卡拉赞传送加载网格可能重建之前清掉的生物。开战前对每队额外执行 `mechcheck <leader> roomclear <boss>`，查看该实例 `[ROOMCLEAR] kept=1 residual=0`；未清净则等待更新再重复，不能在战斗中清场。该操作仍只用于不依赖其他生物的目标。

单Boss就位命令会让队员暂缓AI决策15分钟，日志为 `[BOSS-STAGE-HOLD] untilPull=1`，避免先入场的队伍在等待其他队伍时自己移动开怪。这只用于准备，Boss原生AI与免疫不变；集合点仍须在被动引怪范围之外。正式 `nativepull` 释放该队等待后进入完整生产pull；`stop`/场景清理也恢复正常AI。准备超过15分钟必须取消本轮、核查并重新就位，不能任其自动恢复后再记作统一开战。

正式开战的全轮屏障：N队全部READY；每队实际P人；职责/装备/目标/难度正确；各队实例互异；全部角色和账号互斥；无人正在传送；Boss未提前交战。任一项不满足就修正具体队伍，不降低人数或拆成不同组数的测试阶段。

## 6. 并发正式开战

全部READY后，调度器遍历队伍清单连续发令；每队状态和观察预算分别登记：

```bash
# teams.tsv无表头；最后一个read变量接收该队剩余成员字段。
while IFS=$'\t' read -r TEAM LEADER MEMBERS; do
    send_team "$TEAM" ".rndbot sim mechcheck $LEADER nativepull $BOSS" || break
done < "$SESSION/teams.tsv"
```

发送失败时核对已发队伍的实际状态，分别取证并停止；记部分启动，不自动重发整份清单。

每队核对 `[BOSS-SCENE-START]`、`[BOSS-SCENE-PULL]` 和 `[PULLCHAIN]`：实际地图/实例、原生DB对象、难度和人数必须符合本轮P，且 `nativeAI=1 forcedCast=0 forcedCooldown=0`，pull回执为 `productionPull=1 forcedThreat=0 forcedAttack=0`。

正式开战入口 `nativepull` 只解析本实例原生Boss，并传递目标给生产 `pull my target` 动作；后续完整经过 `PullRequestAction::Execute()` → 准备准入 → `PullStrategy::RequestPull()` → `PullStartAction`/姿态 → `ReachPullAction` → `PullAction::Execute()` → 原生起手施法，与云端pull逻辑相同。场景代码不直接设置战斗、不加仇恨、不调用Boss的AttackStart，也不强制所有队员攻击。`nativeboss/nativeengage` 的强制起攻不作为本流程入口。

正式发令从生产 `pull` 请求开始。分别登记请求接受、`[PULLCHAIN] phase=started`（远程原生起手确认）及Boss/成员首次实际combat，计时使用该队首次实际交战，不能把 `[BOSS-SCENE-PULL] requested=1` 当技能成功。请求后未交战的队伍到预算即记NOT_STARTED并单队停止，其他队继续观察；已经交战但缺少远程起手确认的队伍保留实战结果，并单列pull链证据不完整，不能声称远程起手通过，也不改用强制engage。实际四队防骑的情况见末节。

各队战斗此时并发推进；不得在战中执行补血蓝、复活、清CD、重新就位或修改Boss免疫/技能。

观察器轮询所有RUNNING队伍，按各自leader请求：

```bash
send_team "$TEAM" ".rndbot sim mechcheck $LEADER states"
```

常规快照可每队约5秒一次，记录实际采样时间。具体机制依赖连续技能/光环/移动/伤害日志，不能靠低频快照证明瞬间躲技。N×P增大时同时记录调度延迟、服务器长更新与内存压力，避免把性能过载当AI机制问题。

每队分别在Boss死亡、团灭、持续停滞或到达观察上限时结束采集。该场景不自动提供超时或重试；调度器/操作者必须维护每队截止时间并发停止。

## 7. 证据归属与结果

日志按 `session + team + trial + map + instance + Boss对象` 关联，并保存全部P名成员GUID映射。同Boss并发时不能仅按entry或地图归属。原始共用日志完整保留，分队提取实例事件及成员事件，无法归属的记录单列。

| 结果 | 判据 |
|---|---|
| PASS | 按副本规格完整P人参战，目标真实死亡，场景有效且要求的机制证据齐全 |
| KILL_ONLY | Boss真实死亡，但指定机制未触发或证据不足 |
| WIPE | 本队团灭，保留死亡顺序及Boss剩余血量 |
| TIMEOUT | 本队到达独立截止时间仍未完成 |
| STALL | 持续无有效动作/进展，保留位置、目标、读条和资源 |
| INVALID | 缺人、账号冲突、实例混用、错误难度、战中资源注入或场景破坏 |
| NOT_STARTED | 登录、准备、传送或实际交战未完成，包括工具不支持目标人数 |

击杀需要本trial同实例目标的真实死亡证据，与Boss追踪状态或等价一手证据核对；evade、对象消失和停止清理不算击杀。

每队输出实际参战人数/职责、起止与耗时、胜负、死亡、Boss末态、有效输出/治疗、空蓝情况和机制覆盖。全轮汇总P、N、实际开战队数、全部结果数量、每队明细和负载异常，不只报告最好队伍。

## 8. 分队停止、重测与整轮结束

单队达到终态，先取末态与日志，再仅停止本队：

```bash
send_team "$TEAM" ".rndbot sim mechcheck $LEADER states"
send_team "$TEAM" ".rndbot sim mechcheck $LEADER stopgroup"
```

核对停止回执及全部P人脱战。停止清追踪并结束战斗，存活原生Boss可进入evade，不等于退队、下线或恢复数据库。成员离线/传送或追踪不完整导致拒绝时，保存原因，对本队实际在线成员逐个 `mechcheck <guid> stop`，再核查状态；不触及别队GUID。

重复测量使用相同P、N和阵容，从副本外初始化、解绑、独立实例和原生Boss初态确认重新开始。等其他队伍本轮完成再开新trial，避免结束队不断重开改变并发负载。不把重置队员资源/位置当作Boss及原生事件已恢复的凭据。

全部队伍停止后归档配置、二进制标识、队伍清单、指令台账、原始日志、分队证据及结果表。配置凭据只留本地。退出自己的bot并确认没有场景占用；需要关闭专属世界服时正常退出，确认结束后仅清理自己的writer。恢复数据库须等所有本地占用结束。

## 9. 贞洁圣女10组并发实测（2026-11-18）

北京时间05:10:20，连续发出10条 `nativepull 16457`，各队仅一次，没有nativeboss/nativeengage强制开战。卡拉赞普通难度，map532，entry16457，原生DB spawn5320420，初始生命424900；每队10人、1坦3治疗6DPS，共100个不同角色、100个不同账号、10个不同实例（71–80），全部部落70级公共固定装备bot。全部100人专精ready；传送后存活、脱战、各队完整且实例互斥的就绪屏障通过后才发pull。

运行产物MD5：`767039d7d99eccd8babefcd97051666f`；完整未strip产物MD5：`b8276115a837edcf7c715cbd7e7f7262`。两组可选cheat配置均为空，item由代码永久生效。World与PlayerBots源码含测试开始前其他会话已有的未提交实现，实测对应该工作区产物；本任务选择性commit本身不包含这些既有改动，不能仅凭本任务commit宣称完全重建该产物。

10条生产pull请求均接受，10个Boss均原生交战；原始日志共10条场景START、0条强制ENGAGE。按原生世界tick采样，各队Boss `alive=1 combat=1` 的共同交战窗口为 **63.583秒**。六队战士有原生远程起手成功 `PULLCHAIN phase=started`；01/02/03/05四队防骑只有生产pull接受和真实交战证据，没有该成功回执，不能称其远程起手已经验收。它们没有被改走强制engage，也没有改动生产pull逻辑来补出成功日志。

| 队伍 | 实例 | 结果 | 从场景请求至终态秒 | 战斗中曾死亡角色数 | Boss最低采样血量% | 忏悔光环观测人数 | 忏悔中受神圣地面伤害人数 |
|---|---:|---|---:|---:|---:|---:|---:|
| maiden01 | 71 | WIPE | 114.849 | 10 | 65.47 | 5 | 3 |
| maiden02 | 72 | KILL_ONLY | 310.141–315.330 | 1 | 0 | 9 | 1 |
| maiden03 | 73 | WIPE | 97.514 | 10 | 69.49 | 8 | 2 |
| maiden04 | 74 | WIPE | 69.835 | 10 | 79.39 | 5 | 1 |
| maiden05 | 75 | WIPE | 80.234 | 10 | 88.83 | 4 | 2 |
| maiden06 | 76 | WIPE | 119.616 | 10 | 64.53 | 4 | 3 |
| maiden07 | 77 | WIPE | 130.858 | 10 | 65.82 | 6 | 3 |
| maiden08 | 78 | WIPE | 115.775 | 10 | 75.36 | 7 | 1 |
| maiden09 | 79 | KILL_ONLY | 116.904–117.101 | 2 | 0 | 4 | 3 |
| maiden10 | 80 | WIPE | 175.011 | 10 | 22.70 | 9 | 3 |

合计 **2次击杀、8次团灭**，没有超时。两次击杀均有同实例 `[MOBDIE]`，并与Boss死亡/血量状态核对。团灭耗时来自10名成员原生致死伤害tick；击杀用MOBDIE前后相邻原生日志tick给出区间，不伪造精确死亡时间。最低血量为采样所得，真实最低值可能更低；它不是团灭后evade回血的末态，也不代表恰好死亡那一刻的血量。死亡人数按战斗中曾死亡的不同GUID计，包含后来复活的角色，因此maiden09末态10人存活不等于全程无人死亡。

10队均观测到忏悔光环或对应伤害；Boss来源的伤害流包含29511、29512、29522、32445，另有普通攻击。伤害条数不等于施法次数，光环快照不能逐项证明解控时机、驱散、打断、距离和目标选择全部正确，故两次击杀仅记KILL_ONLY。逐队累计输出/治疗保存在本地audit；这些是角色计数，可能包含准备期行为，且不覆盖完整宠物输出，不当作本Boss精确DPS/HPS。此前仅汇总机制覆盖，未判定8次团灭原因；下述2026-11-18追加分析取代这一分析状态。

**团灭日志追加分析（2026-11-18）**：八队80名角色的正常死亡致死一击为Boss普攻76次、神圣之火29522两次、神圣地面29512两次。致死一击不等于完整根因。01/03/04/05/06/07/08七队均在坦克死亡之前，已有非坦克被Boss普攻杀死；Boss目标快照也直接显示多次转打治疗/远程。这证明攻击目标保护没有稳定维持，尚不能仅凭这些记录区分超仇恨、接怪/嘲讽不足或其他目标选择原因。

- 01：33.581秒术士先被普攻杀，41.740秒奶萨死亡；坦克89.383秒才死，之前已损失4人。第二轮忏悔时剩余两治疗停奶，叠加早期减员。
- 03：41.991秒术士先死；47.605–56.738秒两名治疗持续忏悔，三名治疗有效治疗计数均不增长，58.923秒倒坦。
- 04：6.788秒奶德、19.761秒戒律先被普攻杀，剩一治疗；47.605秒该治疗忏悔，50.238秒倒坦。
- 05：坦克69.952秒死亡前，已正常死亡7名其他队员，包含奶德/神牧；早期非坦克连续吃普攻是首要故障现象。
- 06：7.953秒奶德、16.300秒戒律先死，35.023秒前又损两名DPS，单神牧维持至104.604秒倒坦。
- 07：5.534秒戒律先死，9.677秒DPS再死；100.568秒倒坦前已损3人。
- 08：第二轮忏悔77.954–83.945秒三名戒律全受控、治疗量不增长，蓝量仍8149–11831；坦克从11228血降至3487，87.860秒死亡。这是“治疗全控→停奶→倒坦”的最强证据，不是空蓝。
- 10：133.051秒坦克为首个死者，175.011秒全灭；倒坦前约84–153秒存在快照缺口，不能确定是第三轮忏悔、治疗选择还是资源问题。

击杀对照：09同为战士坦，约78–81秒治疗未受忏悔且有效治疗继续增长，坦克14356→14614血；02三戒律也能击杀，不能直接把职业配比当根因。后续优先验证生产pull后的威胁建立/非坦克保护，以及忏悔预防和解控是否使至少一名治疗持续工作。现有证据不支持直接改血量、治疗倍率或笼统修蓝量；战士Mana=0也不能解释为无怒气。

统计修正：`SpellAuras.cpp → Aura::HandleSpiritOfRedemption()` 会在救赎之魂结束时触发27965 Suicide。它不算再次正常阵亡；06/07旧表132.556/133.618秒误用了这一事件，现改为最后正常死亡119.616/130.858秒，胜负及死亡人数不变。伤害流无法给出完整光环移除/解控时刻，不能把“忏悔中受过一次地面伤害”当作治疗持续可用。详细死亡链、末次快照、前10秒承伤和原日志行号见本地[团灭分析](<../../_agent_tmp/single_boss_concurrent_20261118/WIPE_ANALYSIS.md>)与[死亡证据明细](<../../_agent_tmp/single_boss_concurrent_20261118/wipe_detail.json>)。

本轮观察预算600秒，实际保守地从场景请求起算，早于首次combat约2–5秒，所有终态均在预算内。原驱动曾错误要求十队都必须有远程成功回执；发现四队已实际交战后，停止该等待驱动，接续同一批10个实例的状态观察，没有重开场景、再次pull或在战中补血蓝。接续期间快照有间隔，原生世界日志和伤害流连续保留；表中时间及共同交战窗口使用原生tick重建，不能采用接续时一次批量发现终态而产生的157.93秒虚长共同窗口。后续调度按“请求 / 远程成功 / 实际combat”分开记录。

运行警告及收尾：正式开战前出现2条 `Duplicate entry '83' for key 'groups.leaderGuid'`；开战后没有SQL ERROR，不能把本轮说成完全无数据库警告。此前材料阻塞、错误账号池或提前引怪的准备尝试没有计入这10场。采样VmRSS峰值3752980 KiB（约3.58 GiB），该低频采样值不代表精确内存峰值，也不足以证明无更新延迟。世界服正常退出码0，已只读确认本轮PID不存在、100人全部离本到map1且下线。退本后出现23条仅属于本轮角色的组队记录；在停服、核对队长/全部成员归属并备份行后，事务清理对应9个组，最终本轮group_member残留为0。未恢复整个数据库，也未触碰其他角色/队伍。

本地证据入口：[实测报告](<../../_agent_tmp/single_boss_concurrent_20261118/REPORT.md>)、[逐队原始结果](<../../_agent_tmp/single_boss_concurrent_20261118/results.json>)、[世界tick与机制审计](<../../_agent_tmp/single_boss_concurrent_20261118/audit.json>)、[100人就位清单](<../../_agent_tmp/single_boss_concurrent_20261118/staged_rosters.json>)、[指令台账](<../../_agent_tmp/single_boss_concurrent_20261118/commands.tsv>)、[收尾核验](<../../_agent_tmp/single_boss_concurrent_20261118/cleanup_verification.json>)、[永久item语义测试](<../../_agent_tmp/single_boss_concurrent_20261118/policy_test.txt>)。这些证据与含私密数据的数据库基线备份仅留本机，不随git提交。

完整原生日志在本机WSL：

```text
/root/run_local/single_boss_concurrent_20261118_pull_ready/native.log
size: 12707509 bytes
SHA256: c409cc2f0f7ed0ccbfd24bf649a08685ea6d5426d0e7e9e68c88683082c596ee
```

**同日中午候选复测：当前方案不足，未验收。** 按站长“先测试当前情况是否足够”，本轮候选接入Boss治疗仇恨门、坦克近战短步带位、单治疗忏悔预进圈/解控出圈，并尝试生产pull近距离冲锋/接近开怪。没有调整治疗血线阈值，没有加入坦克带Boss烫醒治疗的备用分支。沿用原100名角色、账号、1坦3治疗6DPS及装备，10个独立实例6–15，仍由生产nativepull发令，结果 **0次击杀、10次团灭**；不能批准该候选为可用修复，也不能据这一组合改动的单轮胜负归因到某一个参数。

| 队伍 | 实例 | 结果 | 正常末次死亡秒 | Boss最低采样血量% |
|---|---:|---|---:|---:|
| maiden01 | 6 | WIPE | 77.350 | 90.64 |
| maiden02 | 7 | WIPE | 78.308 | 89.53 |
| maiden03 | 8 | WIPE | 109.916 | 69.43 |
| maiden04 | 9 | WIPE | 80.656 | 77.00 |
| maiden05 | 10 | WIPE | 100.768 | 74.35 |
| maiden06 | 11 | WIPE | 279.476 | 17.05 |
| maiden07 | 12 | WIPE | 134.147 | 59.63 |
| maiden08 | 13 | WIPE | 272.884 | 39.45 |
| maiden09 | 14 | WIPE | 170.752 | 67.30 |
| maiden10 | 15 | WIPE | 76.788 | 70.26 |

原生tick共同交战窗口68.868秒。01队2.797/6.926秒两名治疗先被普攻杀；10队4.756秒先死治疗；02队40.994秒倒坦。治疗仇恨暂停日志共110条，但表示暂停状态转换次数，不代表门已保护住所有治疗。圣女MAIDEN-WAKE共77条，含进圈、阶段观测、圈外恢复状态；08队首次倒坦延至246.740秒（上一轮87.860秒），仍最终团灭，不能因个别窗口改善宣布整场通过。

本轮10条生产pull均请求接受，10队均实际交战，但PULLCHAIN只记录10条request、10条start-action，没有起手成功started，也没有BOSS-CLOSE-PULL成功记录。因此“冲锋/近距离起手已在游戏生效”没有证据；应先定位pending准备到实际执行/战斗接怪的路径，不能先用调治疗阈值掩盖该执行缺口。坦克带位与完整治疗持续可用性也尚未通过验收。

运行边界：第一次候选启动在100人就位后的roomclear准备阶段SIGSEGV（退出-11），未发正式pull，不计入十场；已备份并仅恢复本轮角色离本下线。使用相同产物第二次启动，附加GDB监控，没有复现崩溃，最终正常退出0；首轮崩溃原因仍未知，不能称已修复。本轮SQL ERROR开战前2条、开战后1条，均属groups键冲突类别。当前代码为未验收工作区候选，源码未作为稳定修复提交或部署；本节仅提交实测证据与结论。

候选strip MD5 `666e060174e3efd5a30ebbce6c628809`，full `aee47fb63dc7c3ceaf5d12972d42de2a`；最终WSL构建成功，但构建通过不等于行为通过。正常停服后本轮PID不存在，100人map1、online0；备份并核对队长及所有成员归属后清理33条本轮残余group_member，最终残留0。本地[候选结果报告](<../../_agent_tmp/boss_behavior_20261118/run2/REPORT.md>)、[机制与死亡明细](<../../_agent_tmp/boss_behavior_20261118/run2/candidate_audit.json>)、[收尾核验](<../../_agent_tmp/boss_behavior_20261118/run2/cleanup_verification.json>)。本轮连续日志：

```text
/root/run_local/single_boss_concurrent_20261118_close_candidate2/native.log
size: 8944329 bytes
SHA256: 91e487cf8fa5f5f1b973a4bd0f5490ce204d05b9536a91402e403e49cb5cf853
```

**补查死亡位置与Boss玩家仇恨表（同日12时）：** 前述日志并非完全没有仇恨数值。`SimMechanicProbe.h → Snapshot()` 中KARA-STATE记录的是 `boss->getThreatManager().getThreat(bot)`，可按每队10个玩家GUID还原采样表；它不含未采样宠物、不等同于死亡当刻完整ThreatList转储。死亡坐标来自 `Unit.cpp → Unit::DealDamage()` 的KARA-DAMAGE，当刻准确；Boss/坦克坐标和仇恨只能给死亡前末次采样及时间差，不能混作同时值。完整20个节点（每队首死、倒坦）的10人表及坐标见本地[死亡位置与仇恨明细](<../../_agent_tmp/boss_behavior_20261118/run2/DEATH_POSITIONS_THREAT.md>)。

- 01队首死2.797秒，治疗2108在 `(-10934.82,-2084.32,92.18)` 被圣女普攻12736杀死；死亡前0.180秒坦克83仍位于集合点 `(-10924,-2077,92.173)`，HP13277、Boss仇恨0，而Boss victim已是治疗2108。十名玩家该次仇恨采样全0，不足以判定“治疗加血OT”，但直接证明坦克尚未建立仇恨时Boss已选中非坦克。预设Boss站位中心约 `(-10945.9,-2103.79)`；死亡发生在集合点往Boss方向的接近区，未到稳定坦克站位后才倒人。
- 07队首死6.814秒，DPS154在 `(-10943.11,-2089.19,92.59)` 被普攻杀；前1.599–1.600秒采样：DPS154=458.100、治疗2310=142.000、坦克942=116.610，Boss victim=154。这里有明确的坦克仇恨落后及Boss打DPS证据。
- 09队首死24.699秒，DPS1365在 `(-10949.09,-2088.98,92.71)` 被普攻杀；前1.189–1.190秒采样：DPS1365=6285.000、DPS1586=5179.500、治疗1617=4507.500、坦克2649=4172.234，Boss victim=1365。坦克HP12134仍活着，仇恨仅玩家第4，属于实质性失去目标控制。
- 08队首死即倒坦246.740秒，坦克2847在 `(-10934.45,-2083.60,91.94)` 被普攻杀；前0.476秒坦克仇恨126981.469、第二名DPS1278=44014.000、第三名DPS1610=42585.562，Boss victim=2847，坦克HP2310。此节点有充足仇恨领先，不能归因为OT；需沿治疗供给、忏悔、承伤与位置继续查。

上述证据支持先修起手接怪与站位移动期间的仇恨建立，但不支持“所有团灭都是坦克仇恨不足”。下一轮若要精确说明切目标原因，应在Boss victim变化和致死伤害时追加包括宠物、在线状态、临时/永久仇恨修正的完整ThreatList观测；本轮现有采样不能补造该信息。本次仅分析既有证据，未改战斗代码或重开测试。

验证边界：最终代码已在指定WSL构建树编译成功；实际HasCheat函数的离线语义测试通过；本文9个Bash片段经 `bash -n` 通过；上述10场为游戏实测。二十五人及第2节未覆盖的场景仍需实现和运行验证，不能由本轮外推。全程仅本地，无云端操作、无push。
