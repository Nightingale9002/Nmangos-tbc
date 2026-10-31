# DPS 决策：分层、每专精状态机、Optuna 参数（2026-10-31）

> 本文是 `src/modules/PlayerBots/playerbot/strategy/DpsFsm.cpp` 这一摊的重构**规范**。
> 定位：**每专精一个显式有限状态机**，状态从先验知识（现有 `Tick<Class>` 里的实战结论）提取，
> 阈值/权重交给 Optuna 搜索。目标不是"再写一套 if"，而是把决策压成"**状态（数据）+ 动作表（数据）+ 参数（数据）**"。
>
> 现状（2026-10-31 只读核查）：`DpsFsm.cpp` 117 KB / `DpsPolicy.inc` 68 KB / `DpsValue.inc` 44 KB，
> 内部并存 **3 套决策引擎**（`TickValue` / `TickPolicy` / 手写 `Tick<Class>`），
> 由 4 个布尔（`value/policy/pselect/pauto`）拼出 16 种组合，其中 12 种无意义。
> 手写分支 716~1902 行 ≈ **1186 行** if-chain，与策略表**同一份知识写了两遍半**。

---

## 1. 分层（修订版）

| 层 | 名称 | 职责 | 入口 | 可变性 |
|---|---|---|---|---|
| L0 | 闸门 | 生死/未进世界/disabled/无目标/被控/坦奶/仇恨门 | `dpsfsm::Tick()` 前段 | 无参数 |
| L1 | 快照 | 血量/资源/连击点/目标血量/距离/读条/目标数 | `BuildSnapshot()` | 无参数 |
| **L2** | **状态判定（新）** | `State = Evaluate(snapshot, params)`，**纯函数** | `SpecFsm::Evaluate()` | 阈值参数 |
| L3 | 候选生成 | 当前状态对应的有序动作表 | `SpecFsm::Actions(state)` | 表数据 |
| L4 | 打分（可选） | 同状态内多候选排序 | `ScoreCand()` | `w_*` |
| L5 | 选择 | 取第一个可用 / 最高分 | `Select()` | 模式 |
| L6 | 执行 | Ready→退避→CanCast→Cast | `CastChecked()` | 无参数 |
| L7 | 记账 | castCount / castThisTick / RecordSpellCast | `Tick()` 尾段 | 无参数 |

**关键变化**：L2 是新增的显式一层。现在"下一步干什么"散落在 `Tick<Class>` 的 if-chain 里；
重构后它只由"处于哪个状态"决定，状态由**可读的迁移条件表**决定。

### 决策模式（取代 4 个布尔）

```cpp
enum class Mode { Fsm, Table, Scored, Spellbook, Legacy };
```

| 模式 | 等价旧口径 | 用途 |
|---|---|---|
| `Fsm` | 无（新） | **目标形态**：每专精状态机 |
| `Table` | `policy=1, pselect=0` | 顺序表基线 |
| `Scored` | `policy=1, pselect=1` | 表内两遍打分基线 |
| `Spellbook` | `value=1` / `pauto=1` | 法术书全候选上限参考 |
| `Legacy` | 无参数（现默认） | 手写 if-chain，迁移期对照，**最终删除** |

旧 key 保留一年兼容映射：`value=1→Spellbook`、`policy=1&pselect=0→Table`、`policy=1&pselect=1→Scored`、其余→`Legacy`。
16 态压到 5 态。

---

## 2. 每专精状态机的契约

### 2.1 通用状态集（所有专精共享骨架）

| 状态 | 进入条件（先验，参数化） | 动作表含义 |
|---|---|---|
| `Idle` | 无目标 / 不在战斗 | 自我 buff、坐地回蓝（交回引擎） |
| `Opening` | 刚接战且目标无本方 debuff | 起手：上易伤/破甲/割裂 |
| `Maintain` | 任一关键 debuff 剩余 < `refresh_*` | 补 DoT / 补 buff |
| `Burst` | 冷却齐 + 目标血量 > `burst_hp` 且不在爆发中 | 开饰品/大招/爆发循环 |
| `Fill` | 以上都不满足 | 填充技能 |
| `AoE` | `packNN >= aoe_pack` | 群体循环 |
| `Recover` | 资源 < `min_resource` 或血量 < `min_hp` | 续资源（换形态/喝药/等待） |

专精可加**特有态**（示例）：
- 猫德：`PowerShift`（能量 < `shift_energy` 且蓝 > `shift_mana`）
- 奥法：`Burn`（蓝 > `burn_mana`）/ `Conserve`（否则）
- 术士：`LifeTap`（血 > `lifetap_hp` && 蓝 < `lifetap_mana`）

### 2.2 迁移 = 数据，不是代码

```yaml
# 只描述"什么条件下进什么状态"，顺序即优先级（先命中先返回）
frost_mage:
  - {to: Recover,  when: "mana_pct < min_resource"}
  - {to: AoE,      when: "pack10 >= aoe_pack"}
  - {to: Maintain, when: "aura_remain('frostbolt debuff') < refresh_dot"}
  - {to: Burst,    when: "cooldowns_ready && target_hp > burst_hp && !bursting"}
  - {to: Fill,     when: "true"}
```

**硬规矩**：`Evaluate()` 里不许施法、不许读世界、不许打日志（纯函数），
这样它能被单元测试和离线回放（拿 `[DPSFSM-HB]` 日志里的快照复算状态）。

### 2.3 动作表

```yaml
frost_mage.Burst:
  - {spell: "icy veins",  kind: Self}
  - {spell: "cold snap",  kind: Self}
  - {spell: "frostbolt",  kind: Target}
```

`kind` 沿用现有 `PKind`（Target/Self/Ground/Swing/Burst/Prereq/PowerShift/Hold，共 8 值）。
**不要再往里加枚举**——新的"意图"用参数表达，不加类型。

---

## 3. 参数 schema：唯一事实源

现状：20 个 `TP(m,key)` 键散落在 3 个文件里，代码有默认值、conf 有覆盖、Optuna 有第三份空间，
**三处会漂**。改为一份 schema，代码/tuner/文档都从它生成：

```json
{
  "burst_hp":     {"type": "float", "range": [0, 100],  "default": 20,  "scope": "global",
                   "doc": "目标血量高于该值才进 Burst"},
  "aoe_pack":     {"type": "int",   "range": [2, 8],     "default": 3,   "scope": "global"},
  "w_nuke":       {"type": "float", "range": [0.2, 3],   "default": 1.0, "scope": "global"},
  "refresh_dot":  {"type": "float", "range": [0, 6],     "default": 2.0, "scope": "global"},
  "min_resource": {"type": "float", "range": [0, 60],    "default": 15,  "scope": "global"},
  "feral.shift_energy": {"type": "float", "range": [0, 80], "default": 25, "scope": "feral"}
}
```

- 代码：启动时读 schema 校验 conf（未知键告警、类型错误拒绝启动），`TP()` 只从这一张表取值。
- tuner：`pipeline_combo.py` / `optuna_par.py` 直接从 schema 生成采样空间（含 conditional：只有 `mode==Burst` 的专精才采 `burst_hp`）。
- 文档：本文 §2/§3 与 schema 同源，不再手抄参数表。

**原则**：参数只允许三类——阈值（进/出状态的界）、权重（同状态内排序）、资源门（够不够）。
"我认为应该先打 X 再打 Y"这类规则**一律不许硬编码**，要么进动作表顺序，要么变成权重。

---

## 4. Optuna 环路

```
schema(JSON) ──生成采样空间──▶ Optuna study (每专精一个 / 每职业一组)
        ▲                              │ trial = 一组参数
        │                              ▼
   conf 写回（≥5% 才写）        .rndbot sim arms（17 专精并行、每臂独立木桩、固定 guid）
        ▲                              │
        └──── 同窗口 A/B 复核 ◀──── dps 中位数（120s、N≥3、剔除无效轮）
```

- **测量单元**必须是"同 bot、同木桩、120 秒、高血量"（现行纪律），跨轮比较前先做同批 `arms` 基线。
- **无效轮剔除**：`incombat=0 && dps=0 && casts=0 && melee=0` 一律丢弃，不能进中位数。
- **写回门**：≥5% 才进 conf；一次只改一个专精；改完在下一轮 `arms` 里做同批对照。
- **并行度**：`arms` 一批 17 堆 ⇒ 每专精只能 1 臂/批；要扫参数就分批，或写 `armsfile`。

---

## 5. 迁移计划（每步独立可回退）

| 步 | 内容 | 风险 | 验收 |
|---|---|---|---|
| **S1** | `Mode` 枚举 + 旧 key 兼容映射 + schema 落地（只读校验） | 低 | 17 专精 `arms` 同参数前后 dps 差 <2% |
| **S2** | `SpecFsm` 接口（`Evaluate/Actions`）+ 2 个试点专精（frost、feral） | 中 | 试点专精三模式（Fsm/Table/Legacy）同批对照，Fsm 不低于 Legacy |
| **S3** | 逐专精迁移 17 个；`Tick<Class>` 保留为 `Legacy` 对照 | 中 | 每迁一个跑一次 `arms`，记录 delta 进 KNOWN_ISSUES §10.5x |
| **S4** | 让位协议收口 `Ownership`（`SkipEngine`/`m_fsmCastLock`/`castThisTick`/`EngineCastGuardListener` 四处合一）+ `[DECIDE]` 统一日志 | 低 | 0 dps 场景能一句话归因 |
| **S5** | 删 `Legacy` 与旧 4 键；tuner 全面接 schema | 中 | 全量回归 |

**顺序要求**：S4 必须在 S3 之前做完一半——否则迁移中出问题分不清是"状态判错"还是"引擎抢了施法"。

---

## 6. 观测口径

- `[DECIDE] owner=fsm|engine mode=fsm|table|... state=Maintain reason=...`（每 tick 一条，env `DPS_TRACE=1` 才打）
- `[DPS-EST]`：候选估值（已有）
- `[DPS-OFFTABLE] castable=`：表外候选（已有）
- `[FSM-BAIL]`：闸门驳回（已有，保持只在 L0）
- **新增必须项**：`TickPolicy`/`SpecFsm` 内部零 bail 的盲点要补——`Recover` 必须区分
  `wait-resource` / `all-candidates-failed` / `no-candidate`，否则 0 dps 只能靠猜。

---

## 7. 当前阻塞（2026-10-31 18:00）

工作树里有另一路未提交改动（6 个文件 / +884 行，`DpsPolicy.inc` 最后修改 17:44），
本文件的 S1 起所有代码步骤**必须等它落定并提交**，否则改的是同一批文件。
