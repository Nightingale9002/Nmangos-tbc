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

| 状态 | 含义 | 进入（按优先级从上到下，命中即停） |
|---|---|---|
| `Off` | 本专精不接管，整 tick 交回经典引擎 | 专精 ∈ {防护战, 神圣骑, 戒律/神圣牧, 恢复德} |
| `Idle` | 无目标 | `target == null` |
| `Form` | 形态不对（德：非猫形态；牧：非暗影形态） | `spec==Feral && form!=CAT` / `spec==Shadow && !shadowform` |
| `Recover` | 资源不足 | `power < recover_enter`（滞回：`power > recover_exit` 才回 `Maintain`） |
| `Aoe` | 多目标 | `pack(aoe_span) >= aoe_pack` |
| `Burst` | 斩杀/爆发窗口 | `targetHp <= burst_hp && cooldowns_ready`（滞回：`targetHp > burst_exit` 回 `Maintain`） |
| `Approach` | 够不到 | `dist > range`（近战 6.5 / 远程 30~35） |
| `Maintain` | 常规输出 | 兜底 |
| `Weave` | 猎人专用：等自动射击窗口 | `!canSteady && autoRemain > 0`（见 §3.1） |

**硬规矩**（从现有代码提炼，必须保留，否则调参没有意义）：

1. **滞回**：`Recover`/`Burst` 进和出用**两个参数**（`recover_enter` / `recover_exit`、`burst_hp` / `burst_exit`），
   单阈值会让状态每 tick 抖动。现在代码里 `lowMana` → `lowMana+20` 就是这个，只是硬编码。
2. **状态只决定"用哪张动作表"，不决定"这一手放哪个技能"**：技能选择留在动作表里按顺序/打分，
   这样 Optuna 调权重时不会牵动状态图。
3. **转移条件只能引用快照字段 + 参数**，不许调用施法、不许查 CD 之外的副作用。
4. **优先级固定为 `Off → Idle → Form → Recover → Aoe → Burst → Approach → Maintain`**。
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
