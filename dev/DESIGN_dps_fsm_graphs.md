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

| 状态 | 冰霜 Frost | 火焰 Fire | 奥术 Arcane |
|---|---|---|---|
| `Prep` | `arcane intellect`(团队) → `ice armor`/`molten armor`(按 `armor_pref`) | 同左（默认 `molten armor`） | 同左（默认 `mage armor` 续航） |
| `Flee` | `frost nova` → `ice barrier` → `blink` → `ice lance` | `blast wave` → `dragon's breath` ⚠ → `blink` | `frost nova` → `blink` → `arcane barrage`(移动) |
| `Recover` | `evocation` → 法力宝石/大蓝 → 魔杖 | 同左 | 同左；3+3 循环本身也是省蓝手段 |
| `Aoe` | **对怪堆放 `blizzard` 即可**（范围减速，一次覆盖一片，**不需要逐个目标检查**）；用 `aoe_slow_rank`（默认 1 级）省蓝省仇恨；已经铺上后能站桩就继续 `blizzard`，被打断/怪散了再补 | `flamestrike`(地面) → `blizzard`(减速) ⚠ → `blast wave` | `blizzard` → `arcane explosion`(≤10 码) |
| `Burst` | `summon water elemental` → `icy veins` → `cold snap` → `ice lance`/`frostbolt` | 饰品 → `combustion` → `presence of mind` → `pyroblast` → `fire blast` | 饰品 → `arcane power` → `arcane blast` 连发（蓝够时） |
| `Maintain` | **常规输出 = 完整循环**：① 开怪先 `frostbolt` 上"深冬之寒/冰霜易伤"；② 之后一直 `frostbolt`；③ `clearcasting` 触发照常 `frostbolt`（免费不占额外 GCD）；④ 移动中改 `ice lance`；⑤ 目标身上易伤掉了靠 `frostbolt` 自然续，不用额外补 | **完整循环**：① `scorch` 叠到 `scorch_stacks`（叠满才有暴击加成）；② `fireball` 填充；③ `fire blast` 只在移动/收尾用（不打断读条）；④ 有 `clearcasting` 优先 `fireball` | **完整循环**：蓝够（`> burn_mana`）→ 无脑 `arcane blast`；蓝不够 → Plan **3+3**（奥冲×3 → 寒冰箭×3 → 卡 0.5 秒读下一发奥冲）；移动中 `arcane barrage` |

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

### 6.4 猎人（兽王 = 生存；射击专精默认也不打瞄准，见下）

> **2026-10-31 站长口径**：**猎人不需要瞄准射击**，除非有 boss 策略指定。
> 所以 `aimed shot` 不进 `Maintain`/`Burst`，改成一个参数 `use_aimed`（默认 0），
> 只有 boss 策略（`ai_playerbot_boss_strategy` 之类）点名时才置 1。现有 `TickHunter` 里
> `mm && canAimed && aimed shot` 那条属于历史遗留，保留在 legacy 路径，不动。

| 状态 | 内容 |
|---|---|
| `Prep` | `aspect of the hawk` → 宠物召唤 → `hunter's mark`(开怪前) |
| `Flee` | `frost trap`(地面) → `concussive shot` → `wing clip`(近身) → `aspect of the cheetah` |
| `Recover` | 蓝 < 10% → `aspect of the viper` → 普通射击（回到 30% 换回鹰守） |
| `Aoe` | `volley` → `multi-shot` → `steady shot` |
| `Burst` | 饰品 → **`rapid fire`（已确认要加）** → `bestial wrath` → `kill command` → （`use_aimed=1` 时）`aimed shot` |
| `Weave` | `arcane shot` → `multi-shot`（等自动射击窗口） |
| `Maintain` | `hunter's mark` → `serpent sting` → `steady shot` → `multi-shot` → `arcane shot`；`aimed shot` **仅 `use_aimed=1`**；任何施法后**立刻重挂自动射击** |

### 6.5 术士

| 状态 | 痛苦 | 毁灭 | 恶魔（现走 else 分支） |
|---|---|---|---|
| `Prep` | **`fel armor`（已确认）+ 召唤恶魔卫士 `summon felguard`** | 同左 | 同左（主宠 = 恶魔卫士） |
| `Flee` | `fear` → `curse of exhaustion` → 跑 | 同左 | 同左 |
| `Recover` | `life tap`（血 > 55%）→ 绷带/糖 ⚠ | 同左 | 同左 |
| `Aoe` | `seed of corruption` → `rain of fire` → `shadow bolt` | 同左 | 同左 |
| `Burst` | 饰品 → `shadowburn` → `shadow bolt` | 饰品 → `shadowburn` → `shadow bolt` | 同左 |
| `Maintain` | `curse of elements`(无诅咒位时) → `corruption` → `siphon life` → `unstable affliction` → `drain life` → `shadow bolt` | 诅咒 → `immolate` → `conflagrate` → `shadow bolt` | 诅咒 → `corruption` → `shadow bolt` |

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
| `Aoe` | **多目标 DoT（已确认）**：给每个目标补 `shadow word: pain` / `vampiric touch`，不切单点 |
| `Burst` | 饰品 → `shadow word: death` → `mind blast` |
| `Maintain` | `shadow word: pain` → `vampiric touch` → `mind blast` → `shadow word: death` → `mind flay` |

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
   快照里现在只有单个 `target` + 一个计数 ⇒ 需要补"附近敌人列表 + 每个目标身上的关键 debuff"。
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



