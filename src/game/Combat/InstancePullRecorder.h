#pragma once

// ---------------------------------------------------------------------------
// [副本数据采集 2026-10-18 站长口径] 拉怪记录改为**所有玩家**（含真人）。
//
// 站长原话："拉怪日志是记录所有玩家在副本的日志，因为我们要采集真玩家数据，所有图都放行。"
//
// ⇒ 不再绑在 bot 路线（DungeonRoute）与 verified=1 上，而是在核心 Map::Update() 里对
//   所有副本实例图（5 人本 / 团本）逐 tick 观测：
//     每支队伍（或单人）"进入战斗 → 脱战"算一次拉怪（seq 递增），落 `ai_playerbot_pull_log`
//     （world 库；原表结构见 dev/192，本版扩列见 dev/194）。
//
// 与旧实现（模块 dungeonroute::PullBegin/PullEnd）的区别：
//   - 不再只有"驱动坦克按路线自动开怪"才记 ⇒ 真人手动拉怪、随机本、团本全都记；
//   - 不再要求 verified=1 / 自动开怪开关 ⇒ 所有图都放行；
//   - **单一写入方**（避免同一波被记两遍）；bot 路线拉怪只用 SetRouteOrd() 补一个 ord。
//
// 失败/缺表一律静默（数据采集是可选增强，绝不影响正常战斗/推图）。
// 表缺失时只记日志、不写库；缺 dev/194 新列时自动退化为旧列写库。
// ---------------------------------------------------------------------------

#include "Common.h"

class Group;
class Map;

namespace pullrec
{
    // Map::Update() 每 tick 调一次（非副本图直接返回；每实例 1 秒节流）。
    void Update(Map* map);

    // [bot 路线专用] 告诉记录器"这个队伍这一次拉的是第几波"（ord = 0 表示 boss 阶段）。
    // 有效期 180 秒；拉怪结束由 ClearRouteOrd() 主动清。真人队伍永远不会调用。
    void SetRouteOrd(Group* group, uint16 ord);
    void ClearRouteOrd(Group* group);
}
