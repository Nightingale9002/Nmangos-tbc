# 水中移动问题总结（2.4.3 私服）—— 最终版

> 会话上下文已满，此文档用于续接。所有改动均未提交，由用户自行 commit。

## 目标与原则
- 修水中移动三件事：不卡闪避 / 不抽搐 / 不穿模
- 原则：**服务器逻辑向客户端靠拢**（客户端是原版，服务器应匹配）
- 分类：会游泳的永远游泳；不会游泳的永远不游泳（贴水底/水面上方走路）；CREATURE_EXTRA_FLAG_WALK_IN_WATER（螃蟹）永远贴水底
- 2.4.3 客户端 movement flags：**SWIMMING = 0x00200000**（玩家 MSG_MOVE_START_SWIM 包证实）

## 最终解决方案（核心发现）

**客户端判定怪物游泳，看的是 UNIT_FIELD_FLAGS 里的 UNIT_FLAG_SWIMMING（0x8000），不是 movement flags（m_movementInfo）！**

- 水生怪 spawn 时 Creature.cpp 会把它写进 UNIT_FIELD_FLAGS（CREATE 锚定）-> 一直游泳
- 陆地怪下水：动态游泳判据触发 SetSwim(true) -> **SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SWIMMING)** -> 客户端通过字段更新持久获得游泳状态
- 这是 boss_the_lurker_below.cpp 里官方用法（JustSummoned 里 SetFlag 让娜迦游泳）

### 完整方案（组件）
1. **动态游泳判据**（Unit::Update，迟滞式）：
   - 进入游泳：z < 水面 - 0.5（浅水也游，不贴浅滩）
   - 退出游泳：z > 水面 + 0.5（完全出水才走路）
   - 中间 +-0.5 迟滞带保持当前状态（防水面边缘翻转）
   - 跳过 WALK_IN_WATER
2. **SetSwim**：m_movementInfo 加 SWIMMING + **SetFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_SWIMMING)** + 发 0x30B（原版行为）
3. **Launch 统一水中路径处理**（MoveSplineInit，对所有 creature 移动生效）：游泳者路径点约束 [水底+0.5, 水面]，不穿底不冒头，**跟随目标深度**（不强制固定深度）；陆地点（groundZ > waterLevel）保持原 z
4. **RefineWaterPath**（Chase）：GetWaterLevel（浅水也有效）替代 GetWaterOrGroundLevel（浅水返回地面导致贴底），groundZ 判别 + walkInWater 贴底
5. **双方都在水中且会游泳 -> 直线游到目标深度**（Chase/Follow）：水下导航网格是水底，走廊路径会潜到水底够不到目标；WALK_IN_WATER 保持走廊
6. **swim 状态变化强制重新寻路**（Chase/Follow relaunch，m_lastSwimState）：下水/上岸切换路径模式，防旧陆地路径卡住闪避
7. **PathFinder**：CanSwim() || IsInWater() -> 快捷路径（浅水 IsSwimmable()==false 会 NOPATH -> 闪避）；随机点水中保持当前深度
8. **UpdateAllowedPositionZ**：水中单位跳过 z 修正（防水面/水底弹跳）
9. **UpdateSplinePosition 同步 m_movementInfo.pos**：防 CREATE/movement 块带陈旧出生点位置

## 排查过程关键经验（供后续参考）

### 为什么"投递游泳状态"各种方法都失败
| 方法 | 结果 |
|---|---|
| SMSG_SPLINE_MOVE_START_SWIM (0x30B) 单发 | 有效但 ~2 秒后客户端自己衰减回走路 |
| 0x30B 周期重发（1s/500ms） | 保持游泳但**抖**（每次重发动画状态机重置） |
| CREATE_OBJECT2 重建（对已存在单位） | 不应用，无效 |
| destroy + create（强制重建） | 短暂游泳后仍回走路（客户端不重新锚定） |
| monster move 带状态 | **SMSG_MONSTER_MOVE 协议不带 movement flags**（查实），无此通道 |
| UPDATETYPE_MOVEMENT | 4 次实验全失败（位置错乱/怪消失），放弃 |

**结论：客户端游泳 = UNIT_FIELD_FLAGS 的 UNIT_FLAG_SWIMMING 锚定，0x30B 只是临时动画提示。动态 SetFlag 是唯一持久方案。**

### 其他
- monster move 的 spline_id 字段 = 自增计数器，不是动画 ID（客户端动画不靠它）
- 客户端水底高度 = 服务器一致（实测 -6），无地形认知差异
- "怪物被拉到 -2"问题：早期 clamp 强制深度，已删（跟随目标深度）
- 玩家跳跃时怪物"瞬移"：未确认是位置跳变还是模型朝向/动画切换（日志已清无法复现）；已尝试水中忽略 z 防 relaunch（未验证，已还原）

## 死怪攻击问题（2026 检查）
- 现象：已死亡的怪物偶尔还能发动攻击（玩家掉血）
- 排查：主循环 Unit::Update 有 if (AI() && IsAlive()) 保护；死亡走 SetDeathState -> CombatStop（清理完整）
- **根因（GM 技能复现）**：GM 的 area death（INSTAKILL 类伤害）把血量归零但**跳过 SetDeathState** -> m_deathState 仍为 ALIVE -> IsAlive() 返回 true -> 死怪继续攻击（仅 IsAlive 防御无效）
- **修复（防御，已保留）**：
  1. UpdateMeleeAttackingState：!IsAlive() || GetHealth() == 0 才允许挥砍（hp=0 视为死亡，即使死亡状态未设置）
  2. UnitAI::UpdateAI 开头：!IsAlive() || GetHealth() == 0 提前返回（纵深防御）
- 云端未见此问题（可能只是 GM 测试工具的 edge case），防御无害保留
- 附带发现：阿图门"被杀死后复活"= GM 技能 INSTAKILL 绕过 SetDeathPrevention 死亡保护、打乱 25% 骑乘变身脚本，非服务器 bug

## 最终工作树改动（8 文件 + 2 防御，未提交）
- Unit.cpp：动态游泳迟滞判据 + SetSwim 设 UNIT_FLAG_SWIMMING + UpdateAllowedPositionZ 水中跳过 + UpdateSplinePosition 同步 m_movementInfo.pos + UpdateMeleeAttackingState 存活/hp 防御
- MoveSplineInit.cpp：Launch 统一水中路径 z 处理
- TargetedMovementGenerator.cpp/.h：RefineWaterPath + 双水中直线游（Chase/Follow）+ swim 变化重寻路（m_lastSwimState）
- PathFinder.cpp/.h：游泳/水中快捷路径 + 随机点保深 + setPathType
- UnitAI.cpp：UpdateAI 存活/hp 防御
- Map.cpp / ObjectGridLoader.cpp：删 GRIDDBG 调试日志
- （HomeMovementGenerator / MovementHandler 改动已还原——被 Launch 统一处理覆盖 / 纯调试）

## 2026-08-23 水中随机移动修复（2 处，待提交）
- 现象：水中随机移动的怪物被拉到水面 / 游进地面下的水里（dbguid 10898 蓝鳃突袭者复现）
- 根因：随机点只保留起始深度（endPoint.z = currPos.z），不校验目的地水柱；且直线路径可能穿过岸边/坡地地形（Launch 钳制把浅水区路径点抬到"浅底+0.5≈水面"）
- 修复（PathFinder.cpp ComputePathToRandomPoint 水分支）：
  1. **目的地水柱校验**：destGroundZ+0.5 <= 当前深度 <= destWaterLevel-0.5，不满足或非水 → PATHFIND_NOPATH 重掷
  2. **沿途地形采样**：直线路径采样 4 点，任何一点地形高于游泳深度 → PATHFIND_NOPATH 重掷
- 效果：随机点要么落在合理水柱内，要么重掷；既不拉水面、也不钻地底
- 附带：本版同时部署了网格卸载 UAF 修复（ObjectGridLoader）与放弃任务物品清理修复（QuestHandler），详见 SERVER_TODOS.md

## 遗留观察
- 玩家跳跃时怪物偶尔"瞬移一下"：疑似模型转向/动画切换的视觉现象，未确认真实位置跳变（无日志无法判断）
- 测试方法：心灵视界 aura 10909 门控的调试日志已全部清理；如需复现排查需重新加日志
