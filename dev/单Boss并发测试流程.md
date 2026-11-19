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

**忏悔与治疗供给分开复核（同日中午）：** 对上述10败候选的02、07、08队，按KARA-STATE同一world tick、允许±100毫秒配对坦克和三治疗。有效heal是累计量，以下差分覆盖整个采样区间，不能当瞬时HPS；三治疗有缺样就不判定全体控制状态。完整[窗口表](<../../_agent_tmp/boss_opening_20261118/REPENTANCE_WINDOWS.md>)保留本地。

- 02队：23.518–33.804秒三治疗29511均为0，累计有效heal停在10179，治疗蓝量均超过1万；坦克4771→2607→2949血。存在未受忏悔仍停奶的区间，不能归因于三奶全控。38.937秒恢复2645有效治疗，40.994秒仍倒坦。
- 07队：48.953–59.020秒仅一治疗受忏悔，两个连续采样区间仍增加3064、5002有效治疗。倒坦前94.725、99.709、104.844秒三治疗均未受忏悔，持续有807、1946、7782有效治疗增量；不能概括为忏悔全控导致倒坦。
- 08队：114.896秒确实观测三治疗全受忏悔，119.927–125.012秒一治疗已自由、两治疗仍睡，累计有效heal73130不变。末轮221.090–231.299秒为两个自由、一个受控，累计157855不变，坦克11215→5020血；236.285秒三治疗均自由并恢复5920有效治疗，之后两个区间仅增1351、551，246.740秒倒坦。与前述坦克仇恨显著领先的证据合看，须继续定位自由治疗的停顿，包括施法、位移、距离/LOS及仇恨门；现有证据不能把具体原因定为治疗阈值，也不能证明已自由就持续在奶坦。

**贴墙进房与FSM控制权针对性复测（同日中午，尚未验收）：** 站长纠正了入场要求：队长为T时，其他人应贴墙进入Boss房间准备，环形跟随不符合要求。以原01骑士T、08战士T两队各10人进行本地验证，沿用原角色、账号、装备及生产nativepull，未强制仇恨或AttackStart。

- 第一轮产物MD5 `bd6f11cb36d21f27c5abb9a29e640763`，两队63.74/73.95秒团灭；均无成功原生pull回执、无进房分配。请求后约2.12秒，Boss已分别选中治疗2108/1394，坦克仍在入口且仇恨0，十名玩家该采样仇恨全0。代码审查发现 `DpsFsm.cpp → Tick()` 非战斗的控制权判据未包含本次起手准备hold，默认引擎仍可执行跟随；不能仅凭TickInner设置hold就称已暂停默认进场。
- 第二轮产物MD5 `df19f3fe1074da45210f21f2ec1f25ed`，补上精确起手准备的非战斗FSM控制权后，两队均为 **NOT_STARTED**，不是WIPE。18名跟随成员反复报告 `BOSS-ENTRY phase=no-safe-wall`，无分配、无正式开怪；说明默认抢先入场被阻止，但当前几何搜索没有找到安全贴墙准备点。该候选仍不可验收，带位期间的持续仇恨和OT保护也未因此得到游戏验证。
- 两次均已正常停服；各20个精确角色GUID均核验map1、online0、残余group_member0。首轮日志SHA256 `63ec38479146a7cb76abf5c86b3e07b3a806babb3d41f108e0bf0769bec0fc78`，次轮 `cf73e96dcd11520493ae3f77e5765f6829daacd0eda4f3558afb14b3a2d7f859`。本地[首轮结果](<../../_agent_tmp/boss_opening_20261118/results.json>)、[次轮结果](<../../_agent_tmp/boss_opening_20261118/run2/results.json>)保留失败证据。

两次未收敛后，后续先采集候选点过滤阶段计数，区分地面、角色体积、墙体、导航和引怪距离，不继续猜半径、治疗阈值或新增机制备用分支。可行路线是修正实际碰撞/导航证据指向的搜索条件，或使用经游戏核验的该房间进场路径与准备点；尚不存在已核验路径。

后续只读诊断补充：`BossOpening.h → SafeRoute()` 过滤前每名成员已有22–35条墙边导航候选，全部失败于引怪距离；原实现错误添加双方体积半径，而核心 `UnitAI.cpp → DetectOrAttack()` 以中心距离比较 `GetAttackDistance()`。删除误加半径并保留3码余量后，两队各5人获得可走点；其余人的序号角度偏移漏掉同一窄可行区域。统一候选集后，产物MD5 `e838dc8a9c2c19421f00bb8a90487dda` 为18名成员全部分配准备点，但120秒仍无正式开怪，两队 **NOT_STARTED**，两坦克均停留入口、仇恨0。该结果只确认候选分配及已观测的墙边移动进展，不能宣称完整起手通过；下一步需开启现有 `PB_PULL_ADMISSION_TRACE=1`，直接区分准备回执、预动作及pull动作准入失败。该轮已正常停服，20人map1/offline/group_member0，日志SHA256 `e0b0b81815d915ca79a970cc9d421ad61ab95c4ae4b87609942acd7d3a94dcd4`，见本地[分支统计](<../../_agent_tmp/boss_opening_20261118/shared_candidates/opening_metrics.json>)。

2026-11-18 13:50替代说明：详细准入追踪证明两名T均已通过 `prepare-ready/execute-prepared`，后续数百次 `execute-close-prepared=1`，所以前述“准备回执仍堵”仅是当时假设，现已排除。接近诊断给出战士 `useful=1 canMove=1 stay=0 casting=0 reason=position-rejected`；`PartyPositionCoordinator.h → FindNearestCombatPosition()/FindCombatPositionAroundTarget()` 把正式开怪目标也列入闲怪安全过滤。只为通过 `CanExecutePreparedPull()` 的近身Boss坦克增加显式目标许可，其他调用默认关闭，仍保留旁怪、地形、LOS、危险区和路径检查。产物MD5 `2f279a1736b459361a7812b4bbb7b77c` 两队均真实开战、初始victim分别为T83/T2847；已采样T移动时仇恨增长。骑士队184.85秒10人存活、Boss80.01%，判 **TIMEOUT**；战士队134.33秒 **WIPE**，非击杀验收。战士T是首个正常死亡，致死spell29512，末采样T仇恨59417.293，高于DPS42285.344，victim仍T，不是首死OT。其死亡前约15秒三治疗自由，其中两人的累计有效治疗15903/12919不变且蓝量充足、反复移动，第三人仍治疗；随后三人全中忏悔，T低血死亡。应独立处理普通分散走位阻断救急治疗与全控窗口；未改治疗阈值。见本地[战斗审计](<../../_agent_tmp/boss_opening_20261118/target_admission/combat_audit.json>)和[致死对齐](<../../_agent_tmp/boss_opening_20261118/target_admission/death_audit.json>)。本轮正常停服后10名测试角色仍保存副本位置，已先备份角色完整行，再仅修正本轮20个离线GUID至既定外场并清理自有组队；最终20人map1/offline/group0、无世界服，原日志SHA256 `a172568f93ab924afe2742e56b29b3cf90a6c8594cc19bead6a18202ee9ccd15`。

2026-11-18 14:35固定方案补充（仍未验收）：站长明确要求正常起手、不倒T、全员进入预先规划且不重复计算的位置；全员有治疗与驱散覆盖、落位不吃连锁，忏悔阶段才允许临时离位。`EncounterSpread.h → Slot()` 原先因治疗当前LOS丢失清空整队槽位，导致在途换目标；现改为正式pull前求解并冻结，临时机制不改原槽。`DpsFsm.cpp → TickInner()` 在普通落位前尝试实际救急治疗，仅成功施法才抢占走位；该修改不能视作已经解决治疗窗口。首个固定方案产物 `634f43ac62856ff2f8404e03b4ac757a` 两队18个槽位均只生成一次，但仅7/9和5/9成员曾到位，两队约84秒WIPE。覆盖检查发现旧规则仅用40码上限，而方案有35.69码跨度；将所有治疗驱散都要求覆盖所有人也过强，候选 `0f4f337b628334eb4ed8dda44cad5ab3` 两队搜索预算耗尽、未开怪，不得称几何无解。

后续改为真实治疗射程约束，完整方案逐人检查至少一个已学魔法驱散者的范围及LOS；`SpreadGeometry.h → Solve()` 加入默认兼容的完整方案验收回调，无覆盖则继续搜索。离线候选回放证明治疗优先内侧排序在原20000预算内可求解，未降低间隔/连锁约束或提升生产预算；回调的继续搜索、完整拒绝、旧调用默认行为测试通过。产物 `3d578d89346a58854346e9c9831d3070` 两队真实地图分别12325/12697次检查得9个固定槽位并正常开战，但61.85/94.26秒WIPE；**覆盖可行不等于实际全员落位通过**。Boss未被带至规划中心，骑士T早期仇恨不足、治疗受门控，下一项只验证坦克短步后撤限制：`DpsFsm.cpp → ApplyEncounterSpread()` 原要求下一点仍在原近战圈，现只允许从当前近战圈后撤1.5码，等Boss追上后再退，保持威胁循环。该短步候选正待游戏结果。逐人覆盖轮已正常停服并精确回收20人map1/offline/group0；旧PID复用曾使组队清理断言失败，改核验实际世界服进程后完成清理，日志SHA256 `c7e854ed55a3645b47ea7344a82bfaabe2d10f91ccaf4140958e96beb8d412cf`。忏悔全控窗口、实际施法出口OT门和不倒T尚未验收。

2026-11-18 15:26替代说明：站长先指定90%并持续领先3000，后调整为远程120%、近战100%（固定领先3000暂保留）；固定正领先同时生效会先于大于100%的上限拦截，不能把配置120%等同于已允许超过T。只读核查发现此前本地试验服实际继承110%，且 `AttackAction.cpp → WaitingForTankThreat()` 将固定值仅作为T起手总仇恨门槛，并非持续领先差值。现 `DpsFsmPolicy.h → TankThreatHolds()` 同时判定百分比及持续绝对领先，运行审计打印实际pct/lead/hold。90%+3000产物 `e15df967c0f13d49dd63aff5a902e8a4` 共410次Boss门控，57拦截、353放行，非舍入边界未发现判定偏差；真实共享策略的边界和前轮OT输入离线断言通过。战士队122.96秒WIPE，首死T2847受普通攻击2751击杀（当时1878HP），死前最近T仇恨30255.510、DPS最高11742.600、victim仍T，故首死非OT。骑士队NOT_STARTED，失败集中在同一不可达候选点导致20000预算耗尽。两队已正常停服并核验20人map1/offline/group0，日志SHA256 `915000d792e86301aa5117ba84dfc980e997cc8d99ec7fe2015e51add8ffc66c`；见本地[真实门控审计](<../../_agent_tmp/boss_opening_20261118/threat90_gap3000/threat_gate_audit.json>)和[致死证据](<../../_agent_tmp/boss_opening_20261118/threat90_gap3000/death_audit.json>)。

2026-11-18 15:34阈值口径替代说明：站长进一步指出远程核心OT线130%，并澄清固定值表达为“T仇恨＋3000”。核心 `ThreatManager.cpp → ThreatContainer::selectNextVictim()` 实际按距离使用近战110%、远程130%。最终策略因此采用两条上限**并且**成立：远程 `self ≤ min(1.2×tank, tank+3000)`，近战 `self ≤ min(1.0×tank, tank+3000)`；起手T总仇恨不足3000仍等待。这个固定值含义替代前述“始终低于T至少3000”和“从比例上限减3000”两个解释，不得将旧90%轮的通过证据当作新公式的游戏验证。真实共享策略的起手、双上限分别起效、并且/或者差异及精确边界离线测试已通过；包含最终公式的新产物正在重建。

站长随后明确指定忏悔流程，替代旧治疗主动进圈方案：忏悔落地后T选一名仍受控的非骑士治疗，走过去停住等Boss；该治疗29511消失后T返回原定位置。`DpsFsm.cpp → MaidenTankWake()` 已据此替换旧治疗预测进圈及退圈，按实际光环驱动并锁定本轮治疗，记录selected/waiting/awake-return/home；临时行程只占用位置，不阻断治疗与坦克轮转。开怪前继续求解并冻结方案，失败路径点在同次起手缓存并剪枝，成功后复用。该新流程、远近程分档和路径剪枝当前正在本地编译，尚无游戏结果；不得视作已解决忏悔断奶、全员落位或不倒T。

2026-11-18 15:54游戏补充：最终双上限产物 `63fb30288d928260482647300da66eb5` 两队均原生开战，18个正式槽位各发布一次；856次记录均为远程120%、固定值3000，非舍入边界未发现公式判定偏差。本轮没有近战档运行记录，100%仅离线边界通过。骑士/战士队129.85/80.38秒WIPE；骑士首死T，战士首死治疗1696（圣火29522）、随后T被普通攻击击杀，均不可据此验收不倒T。骑士T两次锁定非骑士治疗2257，分别650ms/3682ms后检测忏悔消失并返回，其中一轮12.08秒记录home；行程中已展示的治疗采样moving=0。站长明确确认：**治疗提前醒来即刻返回有效，不要求先到治疗旁，也不要求Boss跟到才算通过**，代码已据实际光环实现，不应增加等待条件。正式存活采样仅4/9及2/9曾进入固定目标附近，多名队员仍存在距离/LOS排除，治疗连续性和全员落位未通过。该轮已正常停服、20人map1/offline/group0，日志SHA256 `5145ca4a9f0b1f3c90146084e6d087141e4a8234b7930b32df98bef7d3b4d7d9`，见本地[双上限与唤醒审计](<../../_agent_tmp/boss_opening_20261118/tank_wake_dual_ceiling/dual_ceiling_wake_audit.json>)。后续只增加SPREAD-MOVE限频出口诊断，区分读条、在途、路径拒绝和安全过滤，不改变阈值及站位规则。

2026-11-18 16:24补充（覆盖“每次执行重新寻路即可保证落位”的假设）：`route_failure_trace` 证实同一固定目标在起手验收可达，中途重新寻路出现 `nav-projection`，与重算队伍方案无关。`EncounterSpread.h → Plan` 随成功解保存已验收完整路线；`EncounterSpread.h → PreparedRoute()` 从当前安全连接到原路线最近线段后继续余程，仍完整检查连接段及剩余路线，不重新投影固定终点；`DpsFsm.cpp → ApplyEncounterSpread()` 保留正在到固定目标的有效spline，避免每秒清空重发。产物 `d1592604afa4a95a1af8c8e341159e1b` 游戏对照未再记录路径拒绝；正式存活采样骑士9/9、战士6/9非T曾到位（仅ever-arrived，不能当作同时稳定站位）。骑士99.36秒WIPE；战士181.76秒TIMEOUT，8人生存、T存活、Boss38.71%，仍未击杀。20人已回收map1/offline/group0，日志SHA256 `18db7843457075e95818035440239bacacfe351f1c1eae48d1b32e5eb9051f18`。

同轮骑士低仇恨阶段出现：T仇恨2304.9时治疗仍被3000起手下限拦截，T被普通攻击打到632/13277后触发 `critical health → divine shield`，随后 `THREAT-SWITCH` 从T2692.5转到宠物542（该次不能误称单纯超过130%OT）。为修复起手无人治疗，`DpsFsmPolicy.h → TankThreatHolds()` 增加起手下限适用参数；`AttackAction.cpp → WaitingForTankThreat()` 让治疗在T已有正仇恨后按同样的双上限准入，不附加DPS的3000起手下限。输出仍保留下限，治疗也仍受120%及T+3000约束；门控日志增加healer/openingFloor。新产物 `3c011c41a3ede9130cd7b2aa87ce056e` 已WSL编译，生产策略头文件17条边界断言通过；游戏对照尚在运行，不能宣称修复已实测通过。T访治疗仍以目标实际忏悔消失为返回条件，无需等T/Boss走到。

2026-11-18全轮日志复核（替代片段归因）：站长要求全面核查各轮每次死亡，已完整读取22个运行身份、316546行/35218618字节，44队次中22次实战（18WIPE、4TIMEOUT）、18次NOT_STARTED、4次中止无结果。结果中的188死亡人次均有对应伤害输入，另有5条重复致命输入候选，全部保留。`Unit.cpp → Unit::DealDamage()` 中KARA-DAMAGE/DEATHDMG在最终防死前记录，不能把damage>=HP直接算作额外实际死亡。解析已覆盖mangos>前缀；不再仅展示前4例。按每个最终死亡成员末次候选关联，直接输入为近战161、圣火13、圣地10、忏悔29511三、神圣愤怒一；近战数不等于OT数，需区分T先死后的连锁、T无敌移交、即时130%转火与采样不足。每例前15秒伤害、前20秒治疗/LOS/距离/门控及之后6秒状态见本地[完整死亡与曲线报告](<../../_agent_tmp/boss_opening_20261118/all_rounds_review/完整死亡与起手曲线.html>)及[结构化证据](<../../_agent_tmp/boss_opening_20261118/all_rounds_review/all_rounds.json>)。所谓普通引擎抢位没有本轮充分日志证明，相关临时未构建改动已撤回；源码与已测WSL版本一致，不将该猜测当作根因。

2026-11-18 17:00站长纠正后替代说明：此前本章所述 `self<=min(1.2T,T+3000)`、3000起手上限解释及据此提出的30000参数建议全部作废。实际必须同时严格满足 `self*pct/100<T` 与 `self+3000<T`，远程pct=120、近战pct=100，相等也停手。`DpsFsmPolicy.h → TankThreatHolds()` 已按此修正；`AttackAction.cpp → WaitingForTankThreat()` 治疗豁免DPS门控，坦克豁免，日志显式标明公式；18个边界断言通过。`PaladinActions.cpp → AllowTankImmunity()` 与 `DpsFsm.cpp → PalCastSelfRaw()` 禁止坦克所有血线使用圣盾/TBC圣佑免疫，移除5%例外。

严格差额/禁免疫首轮build `5cfa6f135862ff07b6f7b1785dcef5f2`：骑士180.61秒TIMEOUT、10活/Boss31.22%；战士182.76秒TIMEOUT、10活/Boss9.44%，20人零死亡；1510条门控逐条复算0不符、188拦截，免疫动作0；六治疗都有实际治疗输出。槽位曾到达骑士8/9、战士7/9，仍有三人未完成移动，不能算全员落位；当前日志证明spline端点反复缩回当前位置附近，但尚未证实截断来源。角色已正常停服精确回收map1/offline/group0。

治疗空缺检查：完整历史66个治疗/146段有伤员且>=10秒有效输出不增。旧轮Siazkaeshu出现整场实际/原始治疗0且无施法估算记录；另一轮12.2–70.1秒没有实际治疗或估算记录，蓝>11000，伴随跑位及LOS/距离排除，不能归因为缺蓝。新严格首轮六治疗均有实际输出，仍有Jodun18.3–79.3秒有效治疗不增、原始+2555的长段；`DpsFsm.cpp → HealFlushPending()` 的DPSFSM-HEAL仅是估算，不等同实际成功落地，不能拿19条估算当作19次真实治疗。已确定的代码问题是规划按已学法术约40码、实际HealCollectTargets按heal_range默认35码过滤，日志有38.6码被反复排除。新增共享 `DpsFsm.cpp → HealingTargetRange()`，规划固定病人及移动成员pairAllowed都取实际法术范围与FSM范围较小值。该单项覆盖修复build `26f37bf73fec84ee50f9b32d54cd9949` 已WSL构建成功并完成独立实测：骑士180.73秒TIMEOUT、10活/Boss23.21%，9/9非T曾到槽位；战士83.29秒WIPE、Boss93.38%，T正式29.929秒先死再连锁。978门控0不符、204拦截、免疫动作0；6治疗距离排除全部0，LOS仍有。战士T死前最后三治疗采样蓝10748/11020/11304、忏悔均0，一人仍移动；Tromi正式9.278–32.82秒有效与原始治疗不增，虽有估算施法记录却不能证明成功落地。需继续查实际施法结束/打断/命中，不能归因为缺蓝/忏悔或未经证实的普通引擎争用。两个非T仍未到位，整体不倒T、稳定落位和治疗连续性尚未通过。两轮均正常停服，精确核实20人map1/offline/group0。完整当前核查见[严格差额与治疗空缺报告](<../../_agent_tmp/boss_opening_20261118/all_rounds_review/严格差额与治疗空缺核查.md>)。

2026-11-18 23:43替代补充：施法不落地已由PlayerBots现有出站包钩子确认沉默取消，调用链为沉默光环→打断→取消。DBC圣地半径12码，治疗已到固定槽位（误差0.3–0.4码）仍距实际Boss约7码；槽位距规划中心14.5码，但Boss实际偏离9–15码，不能继续只看是否到槽位。移动调用栈已确认 `PlayerbotAI.cpp → UpdateAIReaction()` 因旧的move to party slot反应停止现有路线；此前“普通引擎争用未证实”更新为这个具体反应已证实，不扩大归因到全部引擎。`PartyPositionActions.cpp → MoveToPartySlotAction::isPossible()/Execute()` 现在尊重 `EncounterSpread.h → OwnsPosition()` 对完整、同组同实例且Boss仍在战斗的既有计划所有权，拒绝旧槽位动作抢路线；没有重构移动入口。`DpsFsm.cpp → ApplyEncounterSpread()` 取消DPS门控阻止T沿原计划归位的条件，输出门控仍按用户公式执行。

行为基线build `8e24febf12b8a9f50eaf9c7c0b116245`：战士134.9秒10人存活击杀（MOBDIE确认，结果Boss5.9%是最后一次生前采样）；骑士181.61秒9人存活、Boss9.13%，T存活、DPS2622死亡。两队9/9非T分别在约8.2/9.2秒内曾到位；1409条门控0不符、353拦截、免疫0。治疗沉默仍存在，不能写成消失。用户判断该版基本通过，要求延长时间并增加并发；代码冻结后的10队100独立账号、每队360秒扩测已完成：10个原生请求全部被接受，实际7队进入战斗；5击杀、2团灭、3未开战。请求口径击杀率50%，实际战斗口径71.4%，不能称10队全部通过。maiden01骑士队观测246.07秒8活击杀；maiden05 209.65秒8活；maiden06 170.23秒10活；maiden07/08均173.28秒确认击杀，分别8/7活。前期等待其他队开战导致首批击杀延后确认，170–173秒是观测耗时并非精确击杀时刻。两团灭队maiden03 287.33秒/Boss23.86%、maiden04 215.76秒/Boss1.95%；T分别在正式255.889、186.116秒被近战致命输入命中，前面均有队员死亡，不能全归为T起手失败。所有实际规划非T槽位均曾到达（分母按moveMask，不把固定近战算成漏槽）。4369条门控0不符/936拦截，其中远程3579、近战790，首次游戏运行覆盖近战100；免疫0。结果29死全部匹配致命输入：近战15、圣火11、神圣愤怒2、圣地1；完整前15秒状态和输入见[十队扩测报告](<../../_agent_tmp/boss_opening_20261118/concurrent10_360/十队360秒验证.md>)及同目录deaths_full.json/deaths.csv。3个未开战队T120/2649/2278仅持续PULLCHAIN request（46/54/54次），pending=1→1、reset=1，距离约32.4–32.5码；分别复仇者之盾/冲锋及前置动作反复请求，尚未解决，不当作战斗失败或通过。用户接受“基本通过”基线，扩测完成后不继续调行为。世界服正常exit0，100人最终offline/map1/group0已核实；首次回收91/100验证失败，修复脚本目录覆盖并重做通过，保留快照。


2026-11-19 00:30驱散核查替代补充：此前11例“圣火死亡”不能全部叫作漏驱散。7个实际开战队均有2–3名已学988驱散魔法的牧师（共14戒律+3神圣），防骑均已学4987清洁术。正式战斗窗口去观察者重复后58条SMSG_SPELLDISPELLOG均明确移除29522：牧师988共44次、防骑4987共14次；非无驱散职业、非全程未执行。11死中6例是直接命中致死（Gedas、Calco、Zaethos、Galorian、Guineri、Funge），5例为DoT死亡（Fashkawa4.088s、Qadohinauch6.034s、Kallean2.070s、Buhreijo4.034s、Ponze3.919s，计时从本次首击到致命DoT）。这5个窗口无驱散开始/成功，均有对应牧师真实治疗读条被沉默光环打断的调用栈，Qadohinauch/Buhreijo/Ponze窗口另有stun打断和忏悔状态。牧师有蓝、并非全在移动；部分间隙继续读治疗/上盾，未转驱散。`DpsFsm.cpp → TickHealFsm()` 实际先走 `HealEncounterHealth()`/戒律生存层、读条等待、救急，再在 `!emergencyPending` 时 `HealTryDispel()`；所以“驱散最高优先”的旧注释不反映现状。role=2还在代码上排除了驱散，但 `TP()` 当前直接返回默认值，实际role=0，本轮不能归因于错误配置。已证实“治疗优先挤占短窗口+圣地沉默/忏悔阻断”；不把整个2–6秒都描述为持续沉默，不据此声称每个机会一定可成功。仅核查并记录，未改行为代码。原始证据在扩测目录dispel_audit.json、holy_fire_death_dispel_audit.json、holy_fire_window_casts.json。

2026-11-19 01:05神圣愤怒32445逐例核查：maiden04戒律牧Caeith1259在正式167.272秒，命中前863血，被1353伤害致死；死前至少14秒状态均863血，15秒窗口无其他伤害输入，不支持把此例说成连续跳数放大，实际是长时间未补起的低血量。maiden05战斗贼Crim2705在162.556秒被3957伤害命中，之前3327血；同一tick/同实例依次T199伤1765→贼2046伤2815→Crim伤3957，命中坐标相邻4.52/3.57码，证实近战链式命中。此前13秒5次圣地累计1461伤害，4788→3327且未见血量回升，低血量叠加连锁放大致死。三名盗贼均无SPREAD-SLOT，当前moveMask不覆盖近战；故“全部已规划槽位到位”不代表近战无连锁。未为此改行为。用户明确短暂沉默/忏悔正常，驱散优先应提高；已将TickHealFsm共享驱散移到补血/救急/HoT选招之前，团队治疗职责也可驱散，不强断既有读条。WSL构建1b591a7b1617a772aa1e542b029e286a通过，游戏对照按用户“别对照了”在准备阶段取消（未进入试验战斗），不能称实测通过；服exit0、100人offline/map1/group0已核实。此轮驱散改动尚未选择性提交，保留已有脏工作树。

2026-11-19 01:30统一3+7规划替代说明：站长允许最多两人一组吃技能，但随后明确按T与近战共3人、远程治疗共7人做统一规划。`EncounterSpreadRules.h → Profiles()` 为圣女导出全角色move/count mask31，既有 `MovementActions.cpp → MovementAction::ChaseTo()` 读取同一有效规则，近战不再被普通追击拖回密集位置。`EncounterSpread.h → Slot()` 取消圣女T的独立返回分支，把T/近战及外圈一并送入现有Solve；`Candidates()` 按T优先/GUID稳定顺序生成内圈，T沿tankBearing，另外两名相差120°，T半径取真实combined combat reach，近战取真实melee reach减到位容差及0.15码余量。此内圈仅支持最多3人，更多近战明确无候选，不静默复用槽位。外圈保留原半径带；`Endpoint()` 按角色检查近战可攻击范围或外圈/法术范围，最终一次性检查十人间距、所有治疗覆盖、魔法驱散覆盖、LOS及每个分配终点的可行路线。删除原先将所有近战当成T同一点的覆盖假设。计划成功后十人槽位/路线保持冻结，忏悔允许临时离位再回原槽位；没有重构移动入口。

离线真实SpreadGeometry求解器3+7案例（3治疗4远程）：预算20000、访问18822、10个槽位成功；T半径约6.3、两近战约6.98、治疗14.5、远程18.5码，最小两人中心距11.2634码，10码间距加双侧0.5容差均满足，治疗互相及全团覆盖35码、近战可达均通过；重叠内圈及空候选拒绝用例通过。这是几何可行性，不是房间真实地形/路径或战斗实测通过；运行时仍需全部Endpoint/Route/covered准入成功。WSL本地构建 `6e76998ee69c395339ae0de967a47485`（full `d65dcc3b6625e10a6d35513209b2ff83`）成功，保持原有格式及链接warning。2026-11-19 02:00位置执行层重构并入本段（不新造章节）：FSM 不再有 Boss 专用位置分支，`DpsFsm.cpp → TickInner()` 只读 `EncounterPositioning.h → TickMechanic()/TickBase()` 返回的通用 `Result`（`ownsPosition`=站位已由机制或基础分散决定，`consumesTick`=本 tick 的移动/旋转让位）；圣女唤醒恒不消耗 tick，与原 FSM 行为一致。副本识别集中到 `MaidenPositionMechanic.h → Tick()`（原工作树 `DpsFsm.cpp → MaidenTankWake()`），忏悔冻结由 `BlocksBaseMovement()` 判定。原 map/entry 硬编码改为 `EncounterSpreadPolicy.h → EncounterLayout()` 的 `LayoutPolicy`：圣女 `SplitMeleeRing(3,16)` 表示 T+2 近战内圈、全治疗外圈及治疗魔法驱散提供者，内圈容量/受控角色掩码/统一求解都来自策略，不写死在求解器或移动门里。`EncounterSpread.h → BeginPull()/Slot()/OwnsPosition()/PreparedRoute()/ResetPlan()/FindTeam()` 统一按队状态：注册表只在取表项时短锁、求解与寻路持队内 `mutex`；只有 `Status::Solved` 冻结，配置刷新、伤亡、当前坐标、LOS 与 Boss 移动都不重解；失败在同 scope 按 `PlanRetryMs=2000` 节流重试并保留 `rejectedRoutes` 剪枝、不提高预算；`FindTeam()` 只读不建项，未配置战斗组不留下永久 Team；T 的独立 anchor 仅在 `Slot()` 真正通过地形/身体/LOS/危险检查后置 `admitted`，`OwnsPosition()` 要求 `initialized && admitted`。离线 `test_policy.cpp` 输出 `policy tests: ok`、`test_lifecycle.cpp` 输出 `lifecycle tests: ok`（首次 build、1999/2000ms 失败节流、同 scope 重试、成功 Frozen、request 续期不重算、换 boss/instance、Reset），3+7 几何案例输出 `PASS 3 inner + 7 outer`（10 槽位、最小两人中心距 11.2634 码）；`/root/nb-build` 执行 `make -j8 mangosd` exit 0，仅既有 `DpsFsm.cpp` 格式与 libssl/libcrypto 链接 warning，产物 strip MD5 `1a5c1f87180ba1a1d207471cfa051cd0`、full `4b13f52bd7f3a830bf2d4acd257bdb92`。本轮未新增游戏实测，编译与离线用例通过不等于战斗行为通过。用户随后授权在零真人条件下发布；后续02:30段边界修正后的最终产物（`fe57bd4220d0c470b8feee4c007e019e`）已实际部署并完成发布后复查，记录见02:31段。实现与几何脚本位于临时 unified_3plus7/spread_refactor_20261119 目录，馆长及其他既有脏改动保留。

2026-11-19 02:30主审最终边界修正补充（同一主题，不新造章节）：上一轮仍有边界漏洞——`EncounterSpread.h → Slot()` 自建、未 latch 但已 `Solved` 的成功方案虽由 `NextStep()` 返回 `Frozen` 不再重解，却仍把新的 `Profiles()` 结果交给执行层，配置刷新可改变 `arrivalTolerance`/`moveMask`。本轮把判定收进 `EncounterSpreadLifecycle.h → PlanOwnerUse()`（纯函数，无 game 类型）：同一 scope 下，无论 plan 由 `BeginPull()` latch 还是 `Slot()` 在战斗中自建，只要 `built && Solved` 且归属 Boss 仍存活并交战，就使用计划保存的 owner 与 `profile` 快照；未完成/失败的 plan 才允许在重试时跟当前配置。准备阶段 Boss 存活但尚未接战属于 `Hold`，不因 `!EngagedByParty` 清计划；`Slot()` 只在 `Reset` 时释放（离开 map/instance、Boss 失效或死亡），脱战后的下一 pull 释放仍由 `DpsFsm.cpp → CanExecutePreparedPull()` 在 `!bot->IsInCombat() && pull->IsPullPendingToStart()` 下调用 `ResetPlan()` 完成，没有新增 `!Engaged` 清除条件。世界查找抽为只读 `EncounterSpread.h → EngagedBoss()`。离线验证不只测复制逻辑：`tests/test_lifecycle.cpp` 直接执行生产头里的 `PlanOwnerUse()`（覆盖未 latch 成功方案快照、失败可刷新、准备 Hold、map/instance/死亡 Reset）；`tests/wiring_check.py` 对生产源码做 25 项接线断言（Adopt 分支不重读 `Profiles()`、Reset 分支不查接战、Hold 不清计划、`ResetPlan` 仅一处且位于下一 pull 准备窗口、`BeginPull` 在 admitted 快速路径之前等）；`test_policy.cpp`、3+7 几何回归全部通过。`/root/nb-build` 执行 `make -j8 mangosd` exit 0（仅既有格式/链接 warning），新产物 strip MD5 `fe57bd4220d0c470b8feee4c007e019e`、full `769fcea234b4eecda47697392f7f010b`，日志 `_agent_tmp/spread_refactor_20261119/build_spread_retry_20261119.log`。本轮未新增游戏实测，编译与离线通过不等于战斗行为通过。

发布门槛按站长口径更正为“零真人”：从 `_agent_tmp/release_20261114/cloud-deploy.current.py`（MD5 `14f5fdcf6eb10121807697749b6a4878`）复制出 `_agent_tmp/spread_refactor_20261119/cloud-deploy.zero-real.py`，只把 `apply()` 内两处 `if people or connections` 改为 `if people`；连续三次零真人检查与停服前复查全部保留，`:8086` 世界 TCP 连接仍计数并写入 `world_connections` 日志但仅作观测，不再阻塞——替代此前把连接数当门槛的错误口径。DB 查询失败即拒绝、固定候选 hash、旧包备份校验、watchdog pause 独占、nightly 锁、优雅停服不强杀、安装后校验与回滚均未改。离线单元测试直接 import 该文件，用 tmpdir + mock presence/pids/stop/start/wait_health/sleep：0真人2连接可部署、1真人0连接延后且不 pause/stop、DB 异常不 stop、停服前新真人到达延后并保留旧包、hash 不符拒绝，6 项通过，日志同目录 `tests/deploy_tests_20261119.log`。该发布器随后实际上传并替换云端 `/root/binary_deploy_when_empty_20261113.py`（云端 MD5 `179371574454aa261cfe63fa51211af9`），只把两处门槛收敛为 people；DB 查询失败关闭、备份/锁/优雅退出/回滚均未改。

2026-11-19 02:31实际发布与复查（同一主题，不新造章节）：站长明确“只限制零真人，世界TCP连接仅观测、不阻塞、无需等待其结束”，本轮据此执行。北京时间02:29:30、02:29:40、02:29:50连续三次 `people=0`（同期 `world_connections=2` 只记录、不阻塞），02:29:51优雅停旧服，**02:31:10.687910发布完成**，新世界服唯一PID **60634**。上传包、磁盘 `/opt/mangos/bin/mangosd` 与 `/proc/<pid>/exe` 的MD5均为 `fe57bd4220d0c470b8feee4c007e019e`（full符号 `769fcea234b4eecda47697392f7f010b`），旧包 `b9286885754146e129ee3189118acb1d` 已按本轮流程备份。02:34:01复查：健康true、待部署清单为空、watchdog未处于暂停、realmd仍为原PID1629；`Server.log` 与 `/tmp/mangosd_run.log` 各末128KiB未见所查SQL、崩溃或 `SPREAD-CONFIG` 错误；03:00提醒与04:06维护两脚本及root cron与发布前逐件一致。站位规则表云端原本不存在，已同步本地验证过的schema与2条静态绑定，重复执行2行不变且回读匹配。发布证据在 `_agent_tmp/spread_refactor_20261119/deployment-result.json`、`postdeploy-status.json`、`cloud-spread-data-result.json`。边界：本轮只证明二进制发布、服务健康与数据幂等，**没有新增游戏战斗实测**；发布物由已验证的完整worktree构建，其中含既有未提交的Curator等改动，后续选择性commit会继续保留这些未提交改动，因此不能据“已部署”声称纯HEAD可复现同一产物。

2026-11-19 02:57配置加载（同一主题，不新造章节）：发布后配置复查发现云端显式 `AiPlayerbot.WaitForAttackThreatPercent=90` 覆盖已核验的120，属配置未随发布生效，**二进制未换**（上传包/磁盘/`/proc/<pid>/exe` 仍为 `fe57bd4220d0c470b8feee4c007e019e`）。首次一次性脚本在 `screen` 异步启动后过早查PID，把正常启动误判为 `[]`，02:51:48判定失败并自动回滚90、02:52:18恢复健康、旧PID62093（`config-restart-result.json` 保留；根因是脚本顺序，不是二进制）。改为 start→wait_health→pids 并通过18项本地回归（旧代码负对照失败，证明回归可捕获该错）后重跑，**02:57:35加载成功**：新世界服唯一PID **62573**、realmd仍1629、`WaitForAttackThreatPercent=120`；cfg MD5 由 `abb0b626f73a9b927e1448cd07d7745b` 变为 `f0b82222542a34e2b37dab04ecc15eba`。02:58:41复查 healthy true、上传/磁盘/proc 三处MD5一致、`cmdline` 确实加载指定 `aiplayerbot.conf`、逐字节验证只有该一个配置token改动、pending与watchdog暂停均false、03:00/04:06脚本及root cron与备份一致、两日志末128KiB未见所查错误；加载前连续三次及停服前复查 `people=0`，world TCP连接仅观测。证据 `config-restart-result.v2.json`、`config-final-status.json`。上述02:31段PID60634仅作历史，**当前PID由本段62573替代**；本轮仍无新增游戏战斗实测。

选择性暂存（同一主题，已完成提交）：第一轮只纳入 `EncounterSpread.h`、`EncounterSpreadLifecycle.h`；其后把FSM位置迁移、通用调度、原生开怪（未跟踪的 `BossOpening.h`、`PullStrategy → IsCloseBossPull()`、`PullAction` 的 close-boss 路径）与生命周期链（`EncounterSpread.h → BeginPull()/ResetPlan()`、`DpsFsm.cpp → CanExecutePreparedPull()` 的 `bossPullAdmitted`）合成23个文件（+1432/−613）选择性暂存进子模块index，Curator、纯 `bottrace` 施法记录、`healExcludeAt` 日志、驱散优先级、`TankChargeOpener`、圣佑免疫等仍留在worktree未提交；主会话复核后已提交为子模块commit **fe178549**，主仓同步记录子模块指针。另用index暂存树加真实构建flags编译9个关键TU全部exit0，只证明index树语义自洽、关键外部符号在HEAD或暂存中可解析；**不等于用index树整服链接或重新出包**，也不改变上述发布物来自完整worktree这一事实：发布物含当时未提交改动，不能声称纯HEAD可复现。可分离FSM位置迁移候选patch（`_agent_tmp/spread_refactor_20261119/dpsfsm.position-migration.candidate.patch`）仍为未应用的备选，实际暂存不走该patch。

日志实现全部位于PlayerBots：`BotActionTrace.h → Start()/Cast()` 统一常规与FSM施法请求/准入记录；`PlayerbotAI.cpp → HandleBotOutgoingPacket()` 使用已有协议通知记录真实移动、施法开始/失败及治疗落地，准入与估算不等同成功加血。本轮曾加的核心追踪代码已全部撤回，未编译同步进核心；现有核心改动保留。模块直接单位施法和常规SpellStart路径已收拢，任务/初始化等其他调用不据此宣称全库均已迁移。

历史错误公式统计（仅保留追溯，不作为当前参数依据）：最终AND公式的5个诊断轮共有568个输出放行后正威胁增量观测，P95=3638、P99=4401、最大4734。这是检查间多命中/DoT累计，不是单发暴击或独立样本。`C(T)=min(1.2T,T+3000)` 距130%转火线最差余量为 `1.3T-C(T)`；T为3000/10000/15000/20000/25000/30000时余量分别300/1000/1500/3000/4500/6000。仅静态起手保护P99需T约24670、覆盖观察最大需25780；可评估30000，但最新骑士轮104.464秒才到、上一战士存活轮44.847秒才到，不宜直接作为全局门槛。更适合后续单独验证的方向是保持两个上限，施法前为待结算威胁预留约5000，输出起手5000–6000为候选；该建议未改代码、未实测通过。治疗不跟输出共同等待起手下限。曲线为约5秒累计采样，不能伪装成逐秒战斗日志或反事实回放。

治疗独立准入轮 `3c011c41a3ede9130cd7b2aa87ce056e` 最终结果：骑士180.32秒TIMEOUT、T存活、6人生存/Boss39.49%，四名DPS在T活着时遭近战死亡；战士79.92秒WIPE、T先死。17个离线边界断言通过，1238条门控无非舍入判定偏差，整体验收仍未通过。20角色已正常停服回收map1/offline/group0，无云端操作，尚未提交源码。

验证边界：最终代码已在指定WSL构建树编译成功；实际HasCheat函数的离线语义测试通过；本文9个Bash片段经 `bash -n` 通过；上述10场为游戏实测。二十五人及第2节未覆盖的场景仍需实现和运行验证，不能由本轮外推。前述战斗实测全部在本地进行；11-19二进制发布与配置加载见本节记录；无push。

## 10. 馆长十队百人本地实测（2026-11-19）

本轮使用既有完整worktree产物 `fe57bd4220d0c470b8feee4c007e019e`（full `769fcea234b4eecda47697392f7f010b`），未修改C++、未重编、未操作云端。普通卡拉赞map532，原生entry15691、spawn5320143；10队各1坦3治疗6DPS，100角色与100账号互斥，沿用圣女十队固定装备名单。12:41:07通过100人存活/脱战/十实例互斥屏障后，每队只发一条 `nativepull 15691`，十条requested均为1，**实际3队交战、3次团灭、7队未开战、0击杀**，不能称十场完整战斗通过。未使用nativeengage或强制仇恨，战中没有补资源/复活/清场；两组可选cheat均为空，item永久生效。

| 队伍 | 实例 | 结果 | 驱动观察耗时秒 | Boss最低采样血量% | 原生光芒死亡数 | 规划槽/曾到位 |
|---|---:|---|---:|---:|---:|---|
| curator01 | 5 | NOT_STARTED | 361.64 | 100 | 0 | 0/0 |
| curator02 | 6 | NOT_STARTED | 361.65 | 100 | 0 | 0/0 |
| curator03 | 7 | WIPE | 117.48 | 97.18 | 6 | 6/4 |
| curator04 | 8 | WIPE | 51.19 | 99.13 | 2 | 7/7 |
| curator05 | 9 | WIPE | 100.57 | 98.20 | 3 | 6/6 |
| curator06 | 10 | NOT_STARTED | 361.64 | 100 | 0 | 0/0 |
| curator07 | 11 | NOT_STARTED | 361.64 | 100 | 0 | 0/0 |
| curator08 | 12 | NOT_STARTED | 361.64 | 100 | 0 | 0/0 |
| curator09 | 13 | NOT_STARTED | 361.64 | 100 | 0 | 0/0 |
| curator10 | 14 | NOT_STARTED | 361.65 | 100 | 0 | 0/0 |

观察耗时从驱动首次收到combat至终态计算，未开战从发令计算；5秒采样与单队停止有调度误差，不能视作精确死亡时刻。曾到位按原生 `KARA-STATE` 坐标到冻结 `SPREAD-SLOT` 的三维距离≤0.5码，逐人曾到位不等于全员同时持续安全分散。光芒死亡均有同实例 `MOBDIE`，对象消失不计击杀。

七队未开战全部站位计划持续 `BudgetExceeded`（133–175次/队、每次visited20000），同时仅有56–65条 `PULLCHAIN phase=request`，无started，pending=1->1/reset=1/start不断重置。03在50次、04在4次预算耗尽后分别求解成功，05首个计划成功；成功不等于机制验收。起手链停滞与规划预算失败均已证实，尚不能由相关性认定唯一根因。代码定位仍为 `EncounterSpread.h → BeginPull()/Slot()` 与 `DpsFsm.cpp → CanExecutePreparedPull()/TryCuratorFocus()`，本轮未修战斗实现。

战斗证据：03观测10个球对象、清6球，先损DPS再倒坦；04观测4球、清2球，第一名死者治疗Qadohinauch遭馆长普攻，第二名治疗Galane死亡前有30383仇恨弹致命输入候选，倒坦前已失去两名治疗；05观测8球、清3球，前四名正常死者均为DPS，邻近致命输入均来自19783的30235。03、05实际选球覆盖四种entry，04覆盖三种；03有10条bossCast30254唤醒快照（不是十次施法），不能据此证明爆发窗口通过。三队的Boss最低采样血量均高于97%，清球和持续生存整体未通过。每名治疗有效治疗增量、死亡前15秒输入和状态保留在临时审计，增量不冒充Boss精确HPS；命中前伤害输入不能直接当实际死亡，神牧27965不当作初次死亡原因。

准备工具问题与修正：原战斗中心(-11070,-1830,165.765)距巡逻路径约43.87码，在馆长Detection60加等级差的约63码引怪范围内，先前准备阶段提前交战作废。最终准备点改为有既有地形/LOS证据的(-11046,-1810,165.765)，离最近巡逻点75.1码，原DB战斗中心未变。脚本修复重复投递未完成入场命令、成功回执GUID键与队伍名键不一致；不改变生产战斗逻辑。中间子代理中止轮次未完整归档，不计正式成绩；最终轮独立存放全部证据。

12:47:38专属世界服正常exit0；12:49:03回验100人online0/map1/group_member0，关联本轮leader的空组也为0，无其他mangosd。正式原始日志165449977字节，SHA256 `f8a93fe50117252aae2a4a84eac57b1919921c694d539c82ace8326034e45a63`。证据在 `_agent_tmp/curator_concurrent_20261119/attempt_final/`：`REPORT.md`、`strict_audit.json`、`mechanics_summary.json`、`results.json`、`commands.tsv`、`staged_rosters.json`、`cleanup_verification.json`；WSL完整原始日志/独立配置在 `/root/run_local/curator_final_20261119/`，敏感配置不提交。首次无效准备另存 `attempt1_preaggro/`。本轮仅提交此实测记录，既有源码脏改动保留，无push。
