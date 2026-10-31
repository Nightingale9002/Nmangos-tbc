# DPS 每专精状态图（2026-10-31）

> 配套 `dev/DESIGN_dps_fsm.md`（分层 / 参数 schema / Optuna）。本文只干一件事：
> **把 9 个手写处理器里的 if 链，画成 17 张显式状态图**，好让 S2/S3 照着实现、让 Optuna 只调阈值。
> 素材来源：`DpsFsm.cpp` 的 `TickMage/TickWarrior/TickRogue/TickHunter/TickWarlock/TickShaman/TickDruid/TickPaladin/TickPriest`
> 逐块抽取（2026-10-31 只读核查），不是凭印象写的循环。

---

## 0. 统一骨架：7 个状态 + 固定转移优先级

现有 9 个处理器的转移链顺序高度一致（资源 → 群 → 斩杀/爆发 → 距离 → 常规），
差别只在**谁先判**和**动作表内容**。所以先定一张骨架图，专精只填三样东西：
**① 哪些状态存在 ② 转移阈值 ③ 每个状态的动作表**。

| # | 状态 | 含义 | 进入（按优先级从上到下，命中即停） |
|---|---|---|---|
| 1 | `Off` | 本专精不接管，整 tick 交回经典引擎 | 专精 ∈ {防护战, 神圣骑, 戒律/神圣牧, 恢复德} |
| 2 | `Idle` | 无目标 | `target == null` |
| 3 | `Prep` | **开怪前准备**（原 3/4/5 合并）：补团队 buff、个人 buff、护甲、形态/姿态、宝石/召唤物，把资源养满 | 脱战 且 任一准备项未满足 |
| 4 | `Flee` | **逃跑/风筝**：血太低或扛不住，后撤拉开距离 | `selfHp < flee_hp` 或 `包夹数 > flee_max && 距离 < flee_range` |
| 5 | `Recover` | 恢复：回蓝/回血（唤醒、分流、绷带、喝水） | `power < recover_enter` 或 `selfHp < recover_hp`（滞回：`> *_exit` 才回） |
| 6 | `Aoe` | 多目标 | `pack(aoe_span) >= aoe_pack` |
| 7 | `Burst` | **爆发**：仇恨稳定后立刻开，早用早 CD（**不再看目标血量**） | `仇恨稳定 && 主要 CD 可用` |
| 8 | `Execute` | 斩杀窗口（可选，多数职业作为 `Maintain` 内的技能替换即可） | `targetHp <= execute_hp` |
| 9 | `Approach` | 够不到 | `dist > range`（近战 6.5 / 远程 30~35） |
| 10 | `Weave` | 猎人专用：等自动射击窗口 | `!canSteady && autoRemain > 0`（见 §3.1） |
| 11 | `Maintain` | 平稳输出期 | 兜底 |

> **2026-10-31 站长口径修订**：原来的 `Form` 与 `Buff` 并进 `Prep`（"补齐 buff 和资源、切好预备的姿态，
> 都是开怪前要做的事，可以放到一起"）；新增 `Flee`（逃跑/风筝）；
> **`Burst` 的进入条件改成"仇恨稳定 + CD 好"，不看目标血量**——理由是"早用早 CD，爆发当资源而不是当斩杀"；
> 血量窗口另立 `Execute`（也可只在 `Maintain` 动作表里换技能，不占状态）。

**固定连招 = 独立的有向图循环（Plan）**：像奥法 3+3（奥冲×3 → 寒冰箭×3 → 卡 0.5 秒读下一发奥冲）这种
"一串有先后、有计数的动作"，不进状态图，而是状态内的一个**子循环**（`planId + planStep`），
本身是一张独立的小有向图。状态负责"走哪条路"，Plan 负责"这条路走到第几步"。

**硬规矩**（从现有代码提炼，必须保留，否则调参没有意义）：

1. **滞回**：`Recover`/`Burst` 进和出用**两个参数**（`recover_enter` / `recover_exit`、`burst_hp` / `burst_exit`），
   单阈值会让状态每 tick 抖动。现在代码里 `lowMana` → `lowMana+20` 就是这个，只是硬编码。
2. **状态只决定"用哪张动作表"，不决定"这一手放哪个技能"**：技能选择留在动作表里按顺序/打分，
   这样 Optuna 调权重时不会牵动状态图。
3. **转移条件只能引用快照字段 + 参数**，不许调用施法、不许查 CD 之外的副作用。
4. **优先级固定为 `Off → Idle → Prep → Flee → Recover → Aoe → Burst → Execute → Approach → Weave → Maintain`**。
5. **"等待"必须是一等公民（2026-10-31 猎人模型逼出来的）**：最优解常常是"这一手什么都不放"。
   但现在的接口是 `Tick*()` 返回 `bool`：`true`=我出手了、`false`=交回引擎——而"交回引擎"会让引擎**立刻放它自己的技能**，
   恰好破坏刚算好的窗口（例如平射锁定期间被塞一发稳固）。
   ⇒ 接口要改成三态：**`Acted`（我放了技能）/ `Hold`（这一 tick 有意空着，引擎也不许动）/ `Decline`（我不处理，交回引擎）**。
   `Hold` 在 sim 里等价于"本 tick 让位"，在线上等价于"抢到这一 GCD 但什么都不做"（依赖 `Ownership` 令牌）。

   现有代码里所有"顺序不一致"都是历史遗留（例如猎人把 `Recover` 放在 `Aoe` 之后），
   统一到这条链，行为差异用阈值表达（`aoe_pack` 调大就等价于"先打单体"）。

---

## 1. 快照字段（现有 `BuildSnapshot` + 需补的 4 个）

已有的：`selfHp` `power` `rage` `energy` `combo` `targetHp` `dist` `moving` `casting` `silenced` `pack10` `pack30`。

需要补（都是现有硬编码逻辑需要、但没进快照的）：

| 字段 | 用途 | 现状 |
|---|---|---|
| `autoRemainMs` | 猎人自动射击剩余时间 | 代码里 `GetAttackTimer(RANGED_ATTACK)` 现算 |
| `formId` | 德/牧形态（猫、熊、旅行、暗影…） | 各处理器各自 `GetShapeshiftForm()` |
| `sealAuraRemain` | 骑：圣印剩余 | 圣印块里 `AuraRemain(<2s)` 现算 |
| `totemSlotEmpty[4]` | 萨：四槽图腾 | `TickShaman` 里 `GetTotemGuid` 现算 |

---

## 2. 17 张状态图

记号：`S={...}` 状态集；转移只写**非默认**边（默认边 = 上一条都不命中时去 `Maintain`）；
参数名列在 §4。**同一行的专精共用一张图，动作表按技能可得性分叉**。

### 2.1 法师（Fire / Frost / Arcane）— 同一张图

```
S = {Idle, Recover, Aoe, Burst, Approach, Maintain}
转移: Idle: 无目标
      Recover: power < recover_enter        (exit: power > recover_exit)
      Aoe:     pack30 >= aoe_pack
      Burst:   targetHp <= burst_hp
      Approach: dist > 30
      Maintain: 兜底
```
| 状态 | 动作表（顺序，截断即停） |
|---|---|
| Recover | 唤醒 → 法力药水(power≤`potion_mana`) → 魔杖/普通攻击 |
| Aoe | 烈焰风暴/暴风雪(地面) → 奥爆/近身 ≤10 |
| Burst | 饰品 → 燃烧/冰冷血脉/奥术强化 → 气定神闲 → 炎爆 → 火冲；寒冰箭/奥冲填充 |
| Maintain | 饰品 → 循环技能（火球/寒冰箭/奥冲）；`clearcasting` 触发时插一发（**不是状态**，是 Maintain 内的最高优先动作） |

> 注意：代码里 `clearcasting` 是**每条转移之前**的前置判断，画图后它就是 Maintain（及各状态）
> 动作表的第一行，不再单独占一个状态。

### 2.2 战士（Arms / Fury）— 同一张图（Protection 是 `Off`）

```
S = {Off, Idle, Recover, Aoe, Burst, Approach, Maintain}
Off: spec == Protection
Recover: rage < core_cost（这是推测项，见 §5 待确认）
Aoe: pack10 >= aoe_pack && dist <= 6.5
Burst: targetHp <= burst_hp
Approach: dist > 6.5
```
| 状态 | 动作表 |
|---|---|
| Aoe | 横扫 → 旋风斩 → 顺劈(怒气≥`cleave_rage`) |
| Burst | 饰品 → 鲁莽/死亡之愿(fury) → 处决(execute 窗口) → 血怒/致死 |
| Maintain | 饰品 → 处决窗口→处决 → 死亡之愿 → 战斗姿态 → 核心技 → 旋风 → 压制 → 猛击 → 英勇打击(`rage_reserve`) |

### 2.3 盗贼（Assassination / Combat / Subtlety）— 一张图（后两者完全等价）

```
S = {Idle, Aoe, Burst, Approach, Maintain}
Aoe: pack10 >= aoe_pack && dist<=6.5
Burst: targetHp <= burst_hp
Approach: dist > 6.5
```
| 状态 | 动作表 |
|---|---|
| Aoe | 饰品 → 冲动/剑刃乱舞 → 落回 Maintain 表 |
| Burst | 饰品 → 冷血(mutilate)/冲动 → 剑刃乱舞 |
| Maintain | 饰品 → 冲动/剑刃乱舞/冷血 → 切割(剩余<`snd_refresh`) → 满星(`fin_cp`)+能量(`fin_energy`)→毒伤/剔骨 → 毁伤/邪恶攻击 |

> 有一条**硬性"停手"边**：`combo >= fin_cp` 且能量不足以放终结技时，代码直接 `break`（等能量，不攒星）。
> 画图后它是 Maintain 内的一个**守卫**（`if combo>=fin_cp && energy<fin_energy: return`），不是状态。

### 2.4 猎人（BM / Survival 等价，MM 多一个瞄准）— 唯一需要 `Weave` 状态

```
S = {Idle, Recover, Aoe, Burst, Approach, Weave, Maintain}
Recover: power < 10 (exit > 30)
Aoe: pack30 >= aoe_pack
Burst: targetHp <= burst_hp
Approach: dist > 35
Weave: autoRemainMs > 0 && !canSteady
```
| 状态 | 动作表 |
|---|---|
| Recover | 蝰蛇守护(self) → 普通射击 |
| Aoe | 乱射(地面) → 多重 → 稳固 |
| Burst | 饰品 → 狂野怒火 → 杀戮命令 → [MM]瞄准 → 稳固 |
| Maintain | 饰品 → 狂野怒火 → 杀戮命令 → 印记 → 毒蛇钉刺 → [MM]瞄准 → 稳固 → 多重 → 奥射 |
| Weave | 奥射 → 多重（等自动射击窗口） |

**自动射击**不是状态：`!moving && 无 CURRENT_AUTOREPEAT_SPELL` 时**先挂自动射击再进任何状态**，
是一条 L0/L6 级不变量（任何施法都会打断它，所以每个动作后都要重挂）。

### 2.5 术士（Affliction / Destruction / Demonology）

```
S = {Idle, Recover, Aoe, Burst, Approach, Maintain}
Recover: power < 12 && selfHp > 55     (exit: power > 40)
Aoe: pack30 >= aoe_pack
Burst: targetHp <= burst_hp
Approach: dist > 30
```
| 状态 | 动作表 |
|---|---|
| Recover | 生命分流（唯一动作） |
| Aoe | 种子(无种子时) → 火雨(地面) → 暗影箭 |
| Burst | 饰品 → 暗影灼烧 → 暗影箭 |
| Maintain | 饰品 → 诅咒位(元素/痛苦) → 腐蚀 → 虹吸/无常(aff) → 献祭/燃烧(dest) → 吸取生命(aff) → 暗影箭 |

> 现有代码的 DoT 判断是"**有没有**"而不是"**还剩多久**"。进图后应改成 `AuraRemain < refresh_*`，
> 这是把隐式状态显式化最直接的收益（补 DoT 的时机变成参数）。

### 2.6 萨满（Enhancement / Elemental，Restoration 等同 Elemental）

```
S = {Idle, Recover, Aoe, Burst, Approach, Maintain}
Recover: power < 10 (exit > 30)
Aoe: pack10 >= aoe_pack && spec==Enhancement
Burst: targetHp <= burst_hp
Approach: dist > (enhance ? 5 : 25)
```
| 状态 | 动作表 |
|---|---|
| Recover | 法力药水 → 普通攻击 |
| Aoe | 闪电链 → 岩浆图腾 → 水之护盾(self) |
| Burst | 饰品 → 图腾补齐(4 槽) → 嗜血/英勇 → 萨满之怒 → 风暴打击 / 元素掌握 → 闪电链 |
| Maintain | 饰品 → 图腾补齐 → 嗜血 → 萨满之怒 → 风暴打击 → 火震(无) → 大地震击（enh）；元素掌握 → 火震 → 闪电链 → 闪电箭 |

**图腾补齐**是 `Form` 类的**前置守卫**：四槽任一为空且技能可用 → 放一个 → 本 tick 结束。
画图后建议单独列成 `Totems` 状态（优先于所有战斗状态），而不是塞在 Burst/Maintain 里各写一遍。

### 2.7 德鲁伊（Feral / Balance）— 两条几乎无关的子图，建议拆成两个 spec

```
Feral:   S = {Idle, Form, Burst, Approach, Maintain}
         Form: shape != CAT          (动作: 猫形态; 已有 aura 但形态错 ⇒ 保持不动，防刷)
         Burst: targetHp <= burst_hp
         Approach: dist > 6.5
Balance: S = {Idle, Form, Recover, Aoe, Burst, Approach, Maintain}
         Form: !moonkin（推测，见 §5）
         Recover: power < 10 (exit > 30)
         Aoe: pack30 >= aoe_pack
```
| 状态 | Feral 动作表 | Balance 动作表 |
|---|---|---|
| Recover | — | 法力药水 → 普通攻击 |
| Aoe | — | 飓风(地面) → 星火 |
| Burst | 饰品 → 猛虎之怒(能量≥80) → 割裂/凶猛撕咬(满星) → 裂伤 → 撕碎 | 饰品 → 自然之力 → 星火 |
| Maintain | 饰品 → 猛虎之怒 → 割裂(无) → 满星→凶猛撕咬/撕裂 → 裂伤 → 斜掠 → 撕碎 | 饰品 → 自然之力 → 月火(无) → 虫群(无) → 月火/星火 |

### 2.8 圣骑士（Retribution；Holy / Protection 是 `Off`）

```
S = {Off, Idle, Seal, Approach, Burst, Maintain}
Off: spec != Retribution
Seal: sealAuraRemain < 2s 或 无圣印     (动作: 挂圣印 → 本 tick 结束)
Approach: !CanReachWithMeleeAttack
Burst: targetHp <= burst_hp
```
| 状态 | 动作表 |
|---|---|
| Seal | 挂当前阵营/天赋可用的圣印 |
| Burst | 饰品 → 复仇之怒 → 愤怒之锤 → 审判 → 十字军打击 |
| Maintain | 饰品 → 复仇之怒 → 审判 → 十字军打击 → 奉献(power>`consecration_mana`) |

> 圣印从"状态机之外的抢占前置"变成**最高优先状态**，是这次重构对圣骑最大的简化：
> 原来它在转移链之前 `return true`，把一整维从状态图里挖掉了。

### 2.9 牧师（Shadow；Discipline / Holy 是 `Off`）

```
S = {Off, Idle, Form, Recover, Burst, Approach, Maintain}
Off: spec != Shadow
Form: !shadowform
Recover: power < 10
Burst: targetHp <= burst_hp
Approach: dist > 30
```
| 状态 | 动作表 |
|---|---|
| Recover | 普通攻击 |
| Burst | 饰品 → 暗言术：灭 → 心灵震爆 |
| Maintain | 饰品 → 暗影形态 → 痛 → 吸血鬼之触 → 心灵震爆 → 灭 → 精神鞭笞 |

---

## 3. 三个硬骨头：怎么塞进图里

### 3.1 猎人的自动射击时间轴（最难）

它不是状态，是**三个叠加的时钟约束**：
`autoRemain`（本次自动射击还剩多久）+ `weave_margin`（稳固能塞几发）+ 每次施法都会打断自动射击、放完必须重挂。

进图方案：
- 快照加 `autoRemainMs`；
- `Weave` 是一个**短驻留状态**（只做瞬发：奥射/多重），转移条件 `autoRemainMs > 0`；
- **重挂自动射击**降级为 L6 不变量：任何施法成功后立刻重挂（不进图）；
- 硬编码的 1500 / 3000 / 700 全部变成参数：`weave_margin`（已有）、`aimed_window`、`instant_window`。

### 3.2 战士的怒气账本

不是状态，是**转移条件里的联立约束**：`rage - cost >= next_cost_reserve`。
建议：把 `core_cost / ww_cost / hs_cost / slam_cost` 作为**运行时计算量**留在动作表里，
只把"预留多少"暴露成参数 `rage_reserve`（现在硬编码 75）。这样 Optuna 调的是"敢不敢花"，而不是"技能多少钱"。

### 3.3 圣骑士的圣印前置

见 §2.8：提升为最高优先状态 `Seal`。注意两个坑要保留：
- 选哪个圣印取决于**阵营 + 天赋**（候选表取第一个 `SpellId != 0`）——这是数据，不是参数；
- 挂不上时**不能死等**（现有代码是软失败继续往下走），图里表现为 `Seal` 状态的动作失败后**落回 Maintain**，不是卡死。

---

## 4. 参数表（状态图专有，其余见 DESIGN_dps_fsm.md §3）

| 参数 | 含义 | 现在是什么 |
|---|---|---|
| `recover_enter` / `recover_exit` | Recover 进/出 | 代码里 `lowMana` / `lowMana+20` 硬编码（法师 10/8/6 三套） |
| `burst_hp` / `burst_exit` | Burst 进/出 | 已有 `burst_hp`，但德/牧回退写死 `>20.0f` |
| `aoe_pack` + `aoe_span` | 群的目标数与统计半径 | 现在一半用 pack10、一半用 pack30，**不统一** |
| `refresh_dot` / `snd_refresh` / `seal_refresh` | DoT/切割/圣印的续期阈值 | 现在是"有没有"或硬编码 2000/2500ms |
| `range_melee` / `range_caster` | 接近阈值 | 硬编码 6.5 / 30 / 35 |
| `weave_margin` / `aimed_window` / `instant_window` | 猎人窗口 | 只有 `weave_margin` 是参数 |
| `rage_reserve` | 战士预留 | 硬编码 75 |
| `totem_range` | 图腾补铺距离 | 已是参数 |

---

## 5. 待确认（不编造）

1. **战士 Recover 的阈值**：现有代码没有"怒气不足 → Recover"这条边（只是 `break` 等普攻），
   图里我按"资源不足"理解；要不要真的建一个 Recover 状态，还是把"等普攻"当 Maintain 的守卫？
2. **德鲁伊 Balance 的 Form**：代码只对 Feral 判形态，Balance 没有 `!moonkin` 门 —— 是否要加？
3. **合并等价专精**：Combat≡Subtlety、BM≡Survival、Elemental≡Restoration 现在完全同路。
   图上是否合并成一张（省一半维护），还是保留各自的动作表只共享转移？
4. **Off 专精**（防护战/神圣骑/戒律·神圣牧/恢复德）继续"不接管、交回经典引擎"，确认吗？
5. **Aoe 判据统一到 `aoe_span` 之后**，近战（战/贼/萨）从 pack10 改口径会不会改变现有效果 —— 需要实测对比。

---

## 6. 动作表草稿（全部 17 专精）

> **谁写的**：我（agent）按三条来源填的草稿 —— ① 2026-10-31 站长口述（冰法、奥法 3+3、爆发口径、状态合并）；
> ② 现有 9 个处理器里已经过实测的先后顺序；③ TBC 通用循环常识。
> **怎么用**：站长**不用填**，只需指出哪条不对（"冰法 Maintain 先深冬再寒冰箭"这种一句话即可）。
> 标 ⚠ 的是我没有把握、最需要被纠正的条目。

### 6.1 法师

> **2026-10-31 站长提供攻略**（"两系对照速览"，按 2T5 口径）。下表按它重写，**不再从旧代码继承顺序**。
> 关键变化：冰法 AoE 主力是**魔爆术**（仇恨安全），冰锥/烈焰风暴只在**仇恨领先**时用，暴风雪是"减速/安全"选项；
> 奥法的恢复顺序固定为 **宝石 → 大蓝 → 唤醒**，而且**唤醒就是切 3+3 的节点**。
> ⚠ 套装效果（如 2T5）会改变循环 ⇒ 做成参数/装备检测，不能写死。

| 状态 | 冰霜 Frost | 火焰 Fire | 奥术 Arcane（2T5） |
|---|---|---|---|
| `Prep` | `arcane intellect`(团队) → `ice armor`（默认）/`molten armor`(凶险时) | 同左（默认 `molten armor`） | `arcane intellect` → `mage armor`（蓝量驱动，续航优先） |
| `Flee` | `frost nova` → `ice barrier` → `blink` → `ice lance` | `blast wave` → `blink` | `frost nova` → `blink` → `arcane barrage`(移动) |
| `Recover` | 宝石 → 大蓝 → `evocation`（按需，蓝压力小） | 同左 | **宝石 → 大蓝 → `evocation`；唤醒落地即切 3+3**。⚠ **唤醒要卡在冰脉（`icy veins`）尾巴上放**（2026-10-31 站长口径）：冰脉快结束时才开唤醒，让唤醒的引导吃在冰脉窗口里 ⇒ 引导更快、回蓝更早到位；不要在冰脉刚开时唤醒（浪费冰脉的输出时间） |
| `Aoe` | **减速是"一个人负责"的团队角色**（参数 `slow_role`：-1=auto ⇒ 队里没有别的法师就由自己铺；1=强制我铺；0=我不铺）。负责时先 `blizzard`（`aoe_slow_rank=1`）→ 再 `arcane explosion`（魔爆术，仇恨安全，近身）→ `cone of cold`（冰锥，仇恨领先）；**不负责时直接上伤害**：`arcane explosion` → `cone of cold` → 远程才 `blizzard` | `flamestrike`(地面) → `blast wave` → `blizzard`（减速，同样受 `slow_role` 约束） | `arcane explosion`（近身）/ `presence of mind + flamestrike`（远程，气定烈焰风暴） |
| `Burst` | **顺序（站长 2026-10-31 修正）：`summon water elemental` → 饰品 → `icy veins`（冰冷血脉）** → 奥冲/寒冰箭；**`cold snap`(急冷) 冷却好就再打第三轮** | 饰品 → `combustion` → `presence of mind` → `pyroblast` → `fire blast` | **顺序：`arcane power`（奥术强化）→ `icy veins`（冰脉，学会了才放）→ 全程 `arcane blast` 连发**；饰品按可用插入；标准 40/21 顺带点出急冷 ⇒ 同样用 `cold snap` 打第三轮 |
| `Maintain` | **深冬之寒叠层 → `frostbolt` 寒冰箭**；蓝压力小 ⇒ **寒冰箭是唯一填充**，不需要省蓝循环；移动中 `ice lance` | `scorch` 叠到 `scorch_stacks`（火球易伤）→ `fireball` 填充；`fire blast` 只在移动/收尾 | **蓝量驱动**：蓝够 → 无脑 `arcane blast`；蓝见底 → 3+3。在"泄蓝"与"省蓝"之间切换，蓝量即伤害 |
| Plan `3+3` | 不适用 | 不适用 | **卡 debuff 最后 0.5 秒打下一发奥冲**：叠满 3 层 → `frostbolt`×3 塞满 8 秒窗口 → 窗口末尾（剩 ≈0.5s）读下一发奥冲（高速、此时叠层已回落 ⇒ 低费）；**唤醒落地后进入该循环** |


> 奥法 3+3 是**Plan**，不是状态：状态仍是 `Maintain`，里面跑一张小有向图（叠满 3 层 debuff → 转寒冰箭 ×3 → 窗口末尾读奥冲）。

### 6.2 战士

| 状态 | 武器 Arms | 狂暴 Fury |
|---|---|---|
| `Prep` | `battle shout` → `commanding shout`(需要血上限时) → 战斗姿态 | 同左 |
| `Flee` | ⚠ 无逃生技：`hamstring` + 后撤 | 同左 |
| `Recover` | 怒气 < `recover_enter` → 只平砍等怒气（不施法） | 同左 |
| `Aoe` | `sweeping strikes` → `whirlwind` → `cleave`(怒气 ≥ `cleave_rage`) | 同左 |
| `Burst` | 饰品 → `recklessness` ⚠ → `death wish`? (狂暴专属) → `mortal strike` | 饰品 → `death wish` → `recklessness` → `bloodthirst` |
| `Execute` | 目标血 < 20% → `execute` | 同左 |
| `Maintain` | `mortal strike` → `overpower` → `whirlwind` → `slam` → `heroic strike`(怒气 ≥ `rage_reserve` 时泄怒) | `bloodthirst` → `whirlwind` → `execute`(窗口) → `heroic strike` |

### 6.3 盗贼（战斗 = 敏锐，同一张）

| 状态 | 内容 |
|---|---|
| `Prep` | **主手：`adamantite sharpening stone`（精金磨刀石，物品）**；**副手：`deadly poison`（致命毒药）** —— 站长 2026-10-31 定 |
| `Flee` | `vanish` ⚠ → `sprint` → 跑 |
| `Recover` | 能量 < `recover_enter` → 等能量（不施法，只平砍） |
| `Aoe` | `blade flurry` → `adrenaline rush` → 落回 `Maintain` 表 |
| `Burst` | 饰品 → `cold blood`(刺杀)/`adrenaline rush` → `blade flurry` |
| `Maintain` | `slice and dice`(剩余 < `snd_refresh`) → 满星(`fin_cp`)+能量够 → `envenom`(刺杀)/`eviscerate` → `mutilate`(刺杀)/`sinister strike` |

### 6.4 猎人 —— 按"四个计时器"重写（2026-10-31 站长给的决策模型）

> **核心**：猎人的一切抉择都围绕四个不同步的计时器 ——
> ① 平射隐藏施法 **0.5s（受加速影响）**② 平射独立冷却 **(武器速度 − 0.5)s（受加速影响）**
> ③ GCD **1.5s —— 不受加速影响**（TBC 固定）④ 稳固读条 **1.5s 基础，受加速影响**。
> ⚠ **关键区别（站长 2026-10-31 强调）**：**GCD 不随加速缩短，稳固读条会**。
> 所以"稳固能不能塞进这一发平射之前"的判据必须用**实际读条时间**（`1.5 / (1+急速)`），
> 不能写死 2.0s；而"占掉一个 GCD"永远按 1.5s 算。
> **稳固的读条与平射剩余时间是零和**：读稳固的瞬间，这段读条时间内平射出不去；剩余不足就会被推后（clip）。
> 所以 Maintain 的判断依据**不是攻速分档**，而是"**我按的这个键会不会让下一发平射迟到**"。
> **不做急速挡位表**（站长 2026-10-31）：普通玩家会靠配装把急速压到 11% 这种简单挡位、
> 或者干脆"每发平射后放一个技能"，那是人工简化；算法能算实际读条，就**按实际值算**，不引入挡位常量。
> 急速 0 时模型会自然退化成"每发平射后一个稳固"，与玩家经验一致 —— 不需要特例代码。

**Maintain 动作表（按顺序，命中即停）**：

| # | 守卫条件 | 动作 |
|---|---|---|
| 1 | `kill command` 可用（兽王） | `kill command`（GCD 外，无条件最高优先） |
| 2 | `auto_remain <= autoshot_land`（0.5s，受加速）｜平射已锁定 | `arcane shot`；**不可用就等待**（绝不能读稳固） |
| 3 | `autoshot_land < auto_remain < steady_window`｜瞬发黄金窗口 | `multi-shot` → `arcane shot` → **等待**（不读稳固） |
| 4 | `auto_remain >= steady_window`｜稳固安全区 | `steady shot` |
| 5 | 断档（多重/奥射都 CD、剩余又尴尬） | **安心等待**，不用劣质填充破坏平射轴 |

其中 **`steady_window = 实际稳固读条时间 + autoshot_land`**（读条时间从核心取，受急速影响；
急速 0 时 = 1.5 + 0.5 = 2.0s，急速越高窗口越小）。**GCD 恒 1.5s**，不参与这个加法。

**需要的快照字段**：`autoRemainMs`（到下一发平射的剩余）、`steadyCastMs`（当前急速下的稳固实际读条）、
`multiReady` / `arcaneReady` / `killCommandReady`。
**参数**：`autoshot_land=0.5`、`weave_margin`（现已有）；`steady_window` **不是参数**，每次由 `steadyCastMs + autoshot_land` 算。


| 状态 | 内容 |
|---|---|
| **宠物** | **首选掠食者（Ravager）**：专属技能 **角刺 `Gore`**（几率双倍伤害）是宠物输出技能里期望最高的；刀锋山抓**裂刃剥石者**（entry `22123`）可同时学高级角刺 + 突进。**备选风蛇（Wind Serpent）**：`lightning breath` 是自然伤害，可绕高护甲、对高甲低自然抗的 boss 更强；但基础系数 107% 略低于掠食者 110%，且**会吞掉增强萨的 buff**（团队里有增强萨时慎用）。参数 `hunter_pet_entry`。 |
| **宠物两个已踩的坑** | ① **学了不一定会放**：`Pet::InitPetCreateSpells()` 会把动作条全写 `ACT_DISABLED`、`addSpell()` 也不写条，而 `PetAI` 的自动施法读动作条 ⇒ 程序化创建的宠物**永远不放技能**（只剩平砍）。修法：建宠后遍历家族技能逐个 `ToggleAutocast(id,true)`（真玩家靠 `LoadPetFromDB` 恢复动作条，没这问题）。② **不贴身**：建出来的宠物 60 秒里离目标 17 码，只偶尔够一下（≈25 dps）；查 `CharmInfo` 的 `COMMAND_*` 与 `REACT_*` 是否压住追击。 |
| `Prep` | `aspect of the hawk` → **宠物：无则 `call pet`（失败则假人场景下按 `hunter_pet_entry` 创建）→ 死亡则 `revive pet` → 血量低于 `pet_mend_hp` 则 `mend pet`** → `hunter's mark`(开怪前) |
| `Flee` | `frost trap`(地面) → `concussive shot` → `wing clip`(近身) → `aspect of the cheetah` |
| `Recover` | 蓝 < 10% → `aspect of the viper` → 普通射击（回到 30% 换回鹰守） |
| `Aoe` | `volley` → `multi-shot` → `steady shot` |
| `Burst` | 饰品 → **`rapid fire`（已确认要加）** → `bestial wrath` → `kill command` → （`use_aimed=1` 时）`aimed shot` |
| `Weave` | `arcane shot` → `multi-shot`（等自动射击窗口） |
| `Maintain` | **见上表（计时器守卫）**。原旧表的 `hunter's mark → serpent sting → steady → multi → arcane` 顺序**作废**；`aimed shot` 仅 `use_aimed=1`（boss 策略点名）；任何施法后**立刻重挂自动射击**（这是 L6 不变量，不是状态） |

### 6.5 术士

| 状态 | 痛苦 | 毁灭 | 恶魔（现走 else 分支） |
|---|---|---|---|
| `Prep` | **`fel armor`（已确认）+ 召唤恶魔卫士 `summon felguard`** | 同左 | 同左（主宠 = 恶魔卫士） |
| `Flee` | `fear` → `curse of exhaustion` → 跑 | 同左 | 同左 |
| `Recover` | `life tap`（血 > 55%）→ 绷带/糖 ⚠ | 同左 | 同左 |
| `Aoe` | **`seed of corruption` 尽量铺满多目标**（2026-11-01 站长口径：术士多目标"更简单"，就是铺种子 + 注意仇恨）→ 铺完再 `rain of fire` / `shadow bolt`；**仇恨用 `EvalThreat` 三档挡着**（`Throttle`/`Wait` 时不再铺新种子） | 同左 | 同左 |
| `Burst` | 饰品 → `shadowburn` → `shadow bolt` | 饰品 → `shadowburn` → `shadow bolt` | 同左 |
| `Maintain` | `curse of elements`(无诅咒位时) → `corruption` → `siphon life` → `unstable affliction` → `drain life` → `shadow bolt` | 诅咒 → `immolate` → `conflagrate` → `shadow bolt` | 诅咒 → `corruption` → `shadow bolt` |

> **痛苦术没有"心爆"那种 6 秒锚点（2026-11-01 站长口径）** ⇒ 排程比暗牧**更简单**：
> 不需要 GCD 时间轮去避让"心爆的拍"，只需要 ① DoT 到期续期（剩余 < `refresh_dot` 就补）、
> ② 剩余 GCD 用 `drain life` / `shadow bolt` 填。多目标同样用**每 GCD 收益判据**
> （见暗牧那条）：DoT 的"剩余跳数×单跳伤害 ÷ 占用 GCD"胜过填充技才铺，否则不铺。
> **三系的复杂度排序（2026-11-01 站长口径）：毁灭最简 < 恶魔 < 痛苦**。
> **毁灭**：主输出只有 `shadow bolt`，其余都是 upkeep（诅咒 + 腐蚀；`immolate → conflagrate` 有就顺手用）；
> **恶魔**：多一层宠物与自身增益维护；
> **痛苦**：DoT 最多（腐蚀/虹吸/无常/诅咒），续期负担最重——但如上面说的，**它不需要时间轮**。

#### 术士的三类特殊动作（2026-11-01 站长口径）

| 动作 | 用法 |
|---|---|
| **腐蚀等 DoT** | **只有"每 GCD 预期收益 > 暗影箭"时才上**（与暗牧同一把尺子）；低于就不上，直接暗影箭 |
| **分流（`life tap`）** | 当作**资源填充**：蓝缺口大且血安全时，用一个 GCD 换蓝，比硬打暗影箭划算（具体阈值 `lifetap_hp` / `lifetap_deficit` 交给 Optuna） |
| **灵魂碎裂（`soul shatter`）** | 当作**消仇恨填充**（⚠ 术士没有"渐隐"，那是牧师的）：**在爆发之前交**，把爆发那段仇恨"腾出来"；**每场战斗只放一次**，不能开局就交 |

#### 术士的仇恨路线（2026-11-01 站长口径，这条决定了他的开局与爆发时机）

```
开场：先等坦克建立仇恨，不要一上来就爆发
  ↓
平稳期：贴着坦克跑（不追求"低仇恨"，追求"刚好不 OT"）
  ↓
爆发前：先交灵魂碎裂，把这一段的仇恨额度腾出来
  ↓
收尾：**理想情况是 boss 倒地那一刻，自己的仇恨刚好接近 OT 线**
```

⇒ 所以术士的仇恨判据**不是"越低越好"，而是"贴着上限跑"**：

- `threat_target_ratio`（默认 0.95）：平稳期就往这个比例贴，不要因为怕 OT 而白白少打；
- 爆发前做**预判**：`当前仇恨 + 这段爆发的预计仇恨 > 危险线` ⇒ 先 `soul shatter` 再爆发；
- 唯一硬红线是**不能真的 OT**（`> 1.0` 或坦克死亡时溢出）。

### 6.6 萨满（元素 = 恢复）

| 状态 | 增强 | 元素 |
|---|---|---|
| `Prep` | 四槽图腾（大地/风/火/水）→ `water shield` ⚠/`lightning shield` | 同左（`water shield` 优先） |
| `Flee` | `frost shock` → `earthbind totem` → 跑 | `frost shock` → `earthbind totem` |
| `Recover` | 蓝 < 10% → `shamanistic rage` ⚠/药水 → 平砍 | 药水 → 等回蓝 |
| `Aoe` | `magma totem` → `chain lightning` → `fire nova totem` ⚠ | `chain lightning` → `magma totem` ⚠ → `lightning bolt` |
| `Burst` | 饰品 → `bloodlust`/`heroism` → `shamanistic rage` → `stormstrike` | 饰品 → `elemental mastery` → `chain lightning` |
| `Maintain` | `stormstrike` → `flame shock`(无) → `earth shock` → 平砍 | `flame shock` → `lightning bolt`（`earth shock` 断条时） |

### 6.7 德鲁伊

| 状态 | 野性 Feral | 平衡 Balance |
|---|---|---|
| `Prep` | `cat form` → `mark of the wild` | **`moonkin form`（已确认需要这个门）** → `mark of the wild` |
| `Flee` | `dash` → `bash`? → 跑 | `entangling roots` ⚠ |
| `Recover` | —（能量自回） | 蓝 < 10% → 药水/激活? |
| `Aoe` | **无多目标策略（已确认）**：继续按 `Maintain` 单点，不切 AoE 状态 | `hurricane` → `starfire` |
| `Burst` | 饰品 → `tiger's fury`(能量 ≥ 80) → `rip`/`ferocious bite` | 饰品 → `force of nature` → `starfire` |
| `Maintain` | `mangle (cat)` → `rip`(无) → 满星 → `ferocious bite` → `shred` → `rake` | `moonfire` → `insect swarm` → `starfire` |

### 6.8 圣骑士（惩戒）

| 状态 | 内容 |
|---|---|
| `Prep` | 圣印（按阵营：`seal of blood`/`seal of command`/`seal of righteousness`）→ 光环 |
| `Flee` | `hammer of justice` → 跑 |
| `Recover` | 蓝 < `recover_enter` → 停手等回蓝（`seal of wisdom` ⚠） |
| `Aoe` | **`consecration`（奉献，已确认可用）** + 保持 `Maintain` 的审判/十字军 |
| `Burst` | 饰品 → `avenging wrath` → `hammer of wrath` → `judgement` → `crusader strike` |
| `Maintain` | 圣印(剩余 < 2s) → `judgement` → `crusader strike` → `consecration`(蓝 > 15%) |

### 6.9 牧师（暗影）

| 状态 | 内容 |
|---|---|
| `Prep` | `shadowform` → `power word: fortitude`(团队) |
| `Flee` | `psychic scream` → `fade` → 跑 |
| `Recover` | 蓝 < 10% → `shadowfiend`? ⚠（TBC 无，用大蓝/暗影魔是 WotLK）→ 魔杖 |
| `Aoe` | **多目标 DoT（已确认）**：给每个目标补 `shadow word: pain` / `vampiric touch`，不切单点。**目标选择与目标数上限按站长 2026-11-01 口径**：① **优先打血量最多的那个**（低血量单位撑不完 DoT，跳不满 = 浪费 GCD）；② **同时挂 DoT 的目标数上限 `multidot_max = 5`**（站长 2026-11-01 定；注意"最舒服的输出环境是 3 目标以内"是**体感结论**，不当作上限），超过 5 个就不再扩、回头集火血量最高的 |
| `Burst` | 饰品 → `shadow word: death` → `mind blast` |
| **多目标的取舍判据** | **按"每 GCD 能产出多少伤害"比（2026-11-01 站长口径）**：给新目标上 DoT 前，先算 `DoT 剩余跳数 × 单跳伤害 ÷ 这次施法占用的 GCD（触是读条 1.5s=1 GCD、痛是瞬发=1 GCD）`，再和"把这些 GCD 用在单体循环上（心爆/鞭/灭）的每 GCD 伤害"比。**DoT 的每 GCD 收益更高才铺**，否则不铺、继续单体。**唯一的例外：所有目标都已经挂上 DoT** ⇒ 不用再比，直接维持（续期优先级按到期时间）。 |
| `Maintain` | **按 GCD 倍数排程（2026-11-01 站长口径）**，不是简单优先级表 —— 详见下 |

#### 暗牧主循环：以 GCD 为单位的时间轮

站长给的模型：**心爆 6 秒 CD = 4 个 GCD**（GCD 1.5s），整个循环应按 **GCD 的倍数**来排：

| 规则 | 内容 |
|---|---|
| 排程粒度 | 一切判断按 **GCD（1.5s）** 对齐；心爆 CD(6s) 正好是 4 个 GCD |
| DoT 续期时机 | **严格等到"结束之后"再续**，不提前覆盖；触有 1.5s 读条 ⇒ 要**提前一个 GCD 起手**，让新触正好落在旧触到期的瞬间 |
| 避让 | 两个 DoT **不要同时到期**；也**不要卡在心爆的节点**（心爆该放的那一 GCD 不能被续 DoT 占掉） |
| 因此 | 需要**错开**触与痛的到期时间：如果发现两者将在同一 GCD 到期，就把其中一个**延后一个 GCD** 续（宁可少一跳，也不要挤掉心爆/挤在一起） |
| 填充 | 剩余拍**先用 `shadow word: death`（灭）填**（2026-11-01 站长补充），CD 没好再用 `mind flay`（引导 3s，按 GCD 计占 2 拍） |
| 灭的守卫 | 灭对**没死的目标会反伤自己** ⇒ 只在"自身血量安全（> `swd_min_self_hp`，默认 50%）"或"目标血量低于灭的单发伤害（能打死）"时才放；否则跳过、交给 `mind flay` |
| **消仇恨填充（`fade` / 渐隐）** | **暗牧同样是仇恨大户（2026-11-01 站长口径）** ⇒ `fade` 也是候选填充动作：仇恨档位到 `Throttle`/`Wait` 时，用一个空 GCD 放 `fade` 比硬打一下更值（按"每 GCD 收益"同一把尺子衡量：省下的仇恨 = 后面能多打的 GCD） |

实现形态：`Maintain` 里维护 `nextMB / vtExpire / swpExpire` 三个时间点（都换算成"距现在多少个 GCD"），
每 tick 先算"这一拍谁到期/谁 CD 好"，再决定本 GCD 的动作；不允许"刚好撞在一起"的拍出现两次以上。

### 6.10 明确标 `Off` 的专精

防护战 / 神圣骑 / 戒律牧 / 神圣牧 / 恢复德 —— 继续交回经典引擎（它们不是 DPS 循环问题，是治疗/坦克职责）。

---

## 7. 站长已确认的口径（2026-10-31）与唯一遗留

| # | 问题 | 结论 |
|---|---|---|
| 1 | 术士 `Prep` 用哪种护甲 / 主宠 | **`fel armor` + 恶魔卫士（`summon felguard`）** |
| 2 | 萨满 `shamanistic rage` 元素能不能用 | **站长也不确定 ⇒ 待实测**（先只在增强里用，元素侧跑 A/B 再定） |
| 3 | 平衡德形态门 / 猫德多目标 | **需要 `moonkin form` 门**；**猫德没有多目标策略**（保持单点，不切 `Aoe`） |
| 4 | 猎人 `rapid fire` | **加** |
| 5 | 盗贼 `Prep` | **主手 `adamantite sharpening stone`（精金磨刀石，物品），副手 `deadly poison`（致命毒药）** |
| 6 | 惩戒骑 `Aoe` | **用 `consecration`（奉献）** |
| 7 | 暗牧多目标 | **多目标 DoT**（每个目标补痛 / 吸血鬼之触） |

### 这些确认暴露出的 3 个代码能力缺口

1. **物品使用**：盗贼的精金磨刀石、法师的法力宝石、术士的糖都是"用物品"，不是施法。
   现有 FSM 只有 `CastSpell` 路线 ⇒ 需要 `UseItemAction` 一类的接口，并在 `Prep` 状态里调用。
2. **多目标遍历**（⚠ 2026-10-31 修正范围）：**范围技能不算这一类** —— 冰法的暴风雪一次覆盖一片，
   直接对怪堆放就行，不需要逐个目标检查（站长纠正）。真正需要逐个目标处理的只有
   **多目标上 DoT**（暗牧的痛/吸血鬼之触、痛苦术的多目标腐蚀）和"看哪只怪还没被标记"这类。
   快照里现在只有单个 `target` + 一个计数 ⇒ 需要补 **`NearbyEnemy` 列表**（2026-11-01 站长确认），
   每项至少包含：`guid`、**剩余血量（绝对值 + 百分比）**、距离、**我对它的仇恨**、**坦克对它的仇恨**、
   以及关键 DoT 的剩余时间（痛 / 触 / 腐蚀 / 献祭 …）。
   **仇恨必须一起读**（站长 2026-11-01）：多目标时"该不该给它上 DoT / 铺种子"要按仇恨判，
   否则会出现"铺得最凶的那只正是我快 OT 的那只"。数据来源同 `EvalThreat`（`ThreatManager` + 队里坦克）。
3. **宠物控制**：术士恶魔卫士、猎人宠物、法师水元素 —— ✅ **2026-10-31 已实现**：
   `PetPresent()` / `CommandPetAttack()`（每 tick 让宠物咬当前目标，掉队/换目标自动重下）/
   `SummonPetIfNeeded()`（没宠物才召，失败打 `[DPSFSM-PET]` 三类原因：`not-learned` / `cast-failed` / `no-pet`），
   另有 10 秒一条 `[DPSFSM-PET] pet=… victim=… dist=…`。冰法实测：水元素**召出来了**（`pet=有`，宠物伤害 9251），
   `mode=5` 从 801 → **903.5 dps**（同机 `mode=3` 基线 944）。

---

## 8. 通用能力：药水（2026-10-31 已实现）

| 能力 | 规则 | 参数 | 用在哪 |
|---|---|---|---|
| **法力药水** | **蓝缺口 > 3000** 就喝（瞬发，不打断输出）；按物品"使用后回蓝（`SPELL_EFFECT_ENERGIZE`）"识别，遍历背包 | `potion_mana_deficit=3000` | 所有有蓝职业的 `Recover` |
| **加速药水** | **没有蓝的职业**（战士/盗贼）把它当**爆发消耗品**，只在 `Burst` 状态喝 | `haste_potion_item`（0 = 按名字 `Haste Potion` 匹配） | 战/贼的 `Burst` |

两条都做了"不重复尝试"节流（3 秒内不重试）和 `IsSpellReady` 判冷却；喝到会打
`[DPSFSM] xxx 喝法力药水 / 喝加速药水` 日志，方便验收。

> 按百分比判断法力药水的旧口径（`potion_mana=35%`）降级成"没有蓝上限信息时的兜底"——
> 因为 35% 对 8000 蓝的号是缺 5200、对 14000 蓝的号是缺 9100，绝对值差太多。



