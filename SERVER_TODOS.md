# 服务器待办与发现记录（2026-08）

> 本文件记录会话中产生/确认的待办与已确认发现。代码改动未提交，由用户自行 commit。

## 水移动：已闭环（2026-08-22 确认）
- 核心机制：客户端游泳判定 = UNIT_FIELD_FLAGS 的 UNIT_FLAG_SWIMMING（0x8000），动态 SetSwim 设置（SetFlag + 0x30B）
- 岸上怪下水：正确发送下水标志（判据 z<水面-0.5 → SetSwim(true) → SetFlag + 0x30B；UpdateEntry 变身不丢 SWIMMING）
- 水中怪追岸上目标：修复卡闪避（Chase/Follow 水中直接线不再要求 targetInWater，2026-08-22 改，**未提交未部署云端**）
- **已知瑕疵（可接受）**：极少数情况怪会在水中走路（特殊边界场景）
- 9417/9418 出生点：z 修正（9418→20.41、9417→23.94），本地+云端已同步

## 已完成
- 每 IP 连接限制：云端 iptables（每 IP 3 连接 + 每秒 1 新连接），systemd 持久化
- 手动部署脚本：/root/manual_deploy.sh（云端）+ 运维手册新增小节
- 随机漫步防掉地下：floorZ 贴地 + LOS 碰撞检查（已随 9c3f59674 部署云端）
- 登录问题：b11c9b79d（调整攻击计时）影响进世界 → 用户重提交 9c3f59674 解决，云端已部署
- 宕机根因修复（2026-08-23 确认并验证）：Map::Update objToUpdate 循环 UAF（use-after-free）
  - 根因：修复内存泄漏的网格卸载改动让有活动生物的网格也可卸载；ObjectGridUnloader::Visit 立即 delete 生物但未调用 RemoveFromActive → 活动列表残留已释放指针 → 下一帧 Map::Update 对已释放对象调虚函数崩溃
  - 证据：7b2bcf50a 云端 core（Map::Update+1096 = 虚表调用跳转 0x4032）
  - 修复：ObjectGridLoader.cpp 在 delete 前调用 RemoveFromActive（+9 行）
  - 验证：修复版 7b2bcf50a 云端 58+ 分钟零崩溃（修复前 1-13 分钟必崩），已部署
- 水中随机移动修复（PathFinder.cpp +33，随修复版部署）：目的地水柱校验 + 沿途地形采样（详见 WATER_MOVEMENT_NOTES.md）
- 放弃任务物品清理修复（QuestHandler.cpp，随修复版部署）：只删本任务需求量 + 跳过 SrcItemId（防误删其他任务物品/双重销毁）
- realmd 僵尸连接监控（只记录）：watchdog.sh 检测单 IP >5 条 3724 连接时写日志（不自动重启）；注意：僵尸连接是登录异常的症状非根因，根因是崩溃夜客户端会话错乱（临时自愈）
- watchdog 已恢复：/etc/cron.d/mangos_watchdog 重新启用（之前为回滚临时禁用）

## 待办清单
1. **普通攻击伤害数字延迟**：客户端伤害数字显示比实际计算晚——考虑是否延迟伤害计算；253 客户端已测，需继续测 243
2. **双手武器平衡**：搁置（分析过：惩戒骑/武器战都双手低 AP 系数，方案 A 标准化系数 3.3→3.4 / B 伤害系数 1.03-1.05，未定）
3. **水中怪追岸上修复**（Chase/Follow 直接线）：本地已改，**待用户提交 + 部署云端**

## 备注
- 云端二进制：9c3f59674（已部署）；水移动 Chase 追岸上修复未在云端
- 反作弊：Movement 检测全 Inform（无踢人），Warden 云端关
