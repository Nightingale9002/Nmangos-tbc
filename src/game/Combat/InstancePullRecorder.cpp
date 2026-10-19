/*
 * [副本数据采集 2026-10-18 站长口径] 拉怪记录（所有玩家 / 所有副本图）
 * 见 Combat/InstancePullRecorder.h 顶部注释。
 */

#include "Combat/InstancePullRecorder.h"

#include "Database/DatabaseEnv.h"
#include "Entities/Creature.h"
#include "Entities/Player.h"
#include "Groups/Group.h"
#include "Log/Log.h"
#include "Maps/Map.h"
#include "Maps/MapRefManager.h"
#include "Server/WorldSession.h"

#include <ctime>
#include <iterator>
#include <map>
#include <mutex>
#include <set>
#include <utility>

namespace
{
    // 每实例 1 秒扫一次就够（战斗状态不会 200ms 变一次）
    const time_t kScanIntervalSec = 1;
    // 脱战多久算"这一拉结束了"（防骑乘/瞬断抖一下就记成两波）
    const time_t kCombatEndGraceSec = 2;
    // bot 路线给的"这是第几波"提示的有效期
    const time_t kRouteOrdHoldSec = 180;
    // 表/列存在性的重查间隔（不重启也能建表/加列）
    const time_t kRecheckSec = 300;
    // 空实例状态保留多久（防 map 反复创建导致内存增长）
    const time_t kInstanceStateKeepSec = 3600;

    struct OpenPull
    {
        uint32 mapId;
        uint32 instanceId;
        uint32 leaderGuid;          // 队长 guid low（单人 = 自己）
        uint32 groupId;             // 0 = 单人
        uint32 seq;
        uint16 ord;                 // 0 = 非路线拉怪 / boss 阶段
        bool   routeClaimed;
        time_t startedAt;
        time_t lastCombatAt;
        uint32 membersStart;
        uint32 aliveStart;
        uint32 mobsTotal;
        uint32 lastMobsAlive;
        bool   hasRealPlayer;
        uint32 firstMobGuid;
        uint32 firstMobEntry;
        std::set<uint32> members;       // 开拉时在图的队员 guid low
        std::set<uint32> aliveAtStart;  // 开拉时活着的队员
    };

    struct InstanceState
    {
        time_t lastScan;
        std::map<uint32, OpenPull> pulls;       // 队长 guid low -> 正在拉的那一波
        std::map<uint32, uint32> nextSeq;       // 队长 guid low -> 下一个 seq（内存续号）

        InstanceState() : lastScan(0) {}
    };

    struct GroupSnapshot
    {
        uint32 leaderGuid;
        uint32 groupId;
        uint32 members;
        uint32 alive;
        bool   inCombat;
        bool   hasRealPlayer;
        uint32 firstMobGuid;
        uint32 firstMobEntry;
        float  firstMobX;
        float  firstMobY;
        float  firstMobZ;
        uint32 firstMobGroupId;
        std::set<uint32> memberGuids;
        std::set<uint32> aliveGuids;
        std::set<uint32> mobs;          // 正在打这支队伍的怪（guid low，已过滤存活）

        GroupSnapshot()
            : leaderGuid(0), groupId(0), members(0), alive(0),
              inCombat(false), hasRealPlayer(false), firstMobGuid(0), firstMobEntry(0),
              firstMobX(0), firstMobY(0), firstMobZ(0), firstMobGroupId(0) {}
    };

    std::mutex stateMutex;
    std::map<uint64, InstanceState> instanceStates;              // instanceKey -> 状态
    std::map<uint32, std::pair<uint16, time_t>> routeOrdHold;    // groupId -> (ord, 到期)

    // 表/列探测（和 instanceStates 用不同锁，避免 DB 查询时卡住地图线程太久）
    std::mutex schemaMutex;
    bool   tableChecked = false;
    bool   tableExists = false;
    time_t tableCheckedAt = 0;
    bool   columnsChecked = false;
    bool   hasNewColumns = false;
    time_t columnsCheckedAt = 0;

    inline uint64 InstanceKey(Map* map)
    {
        return (uint64(map->GetId()) << 32) | map->GetInstanceId();
    }

    bool PullLogTableExists()
    {
        std::lock_guard<std::mutex> lock(schemaMutex);
        const time_t now = time(nullptr);
        if (tableChecked && now - tableCheckedAt < kRecheckSec)
            return tableExists;

        tableChecked = true;
        tableCheckedAt = now;
        std::unique_ptr<QueryResult> res = WorldDatabase.Query(
            "SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() "
            "AND table_name = 'ai_playerbot_pull_log'");
        tableExists = (res != nullptr);
        if (!tableExists)
        {
            static bool warned = false;
            if (!warned)
            {
                warned = true;
                sLog.outString("[PULL] ai_playerbot_pull_log 不存在 —— 拉怪记录关闭"
                               "（应用 dev/192_副本拉怪记录表.sql + dev/194 可启用）");
            }
        }
        return tableExists;
    }

    // dev/194 新列（group_id/source/members）是否已加：没加就退回旧列写库，不影响记录
    bool PullLogHasNewColumns()
    {
        std::lock_guard<std::mutex> lock(schemaMutex);
        const time_t now = time(nullptr);
        if (columnsChecked && now - columnsCheckedAt < kRecheckSec)
            return hasNewColumns;

        columnsChecked = true;
        columnsCheckedAt = now;
        std::unique_ptr<QueryResult> res = WorldDatabase.Query(
            "SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() "
            "AND table_name = 'ai_playerbot_pull_log' AND column_name = 'group_id'");
        hasNewColumns = (res != nullptr);
        return hasNewColumns;
    }

    // [2026-10-19] target_x/y/z + spawn_group_id 是否已加：没加就退回旧列，不影响记录
    bool PullLogHasPosColumns()
    {
        static std::mutex m;
        static bool checked = false;
        static bool has = false;
        static time_t checkedAt = 0;
        std::lock_guard<std::mutex> lock(m);
        const time_t now = time(nullptr);
        if (checked && now - checkedAt < kRecheckSec)
            return has;
        checked = true;
        checkedAt = now;
        std::unique_ptr<QueryResult> res = WorldDatabase.Query(
            "SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() "
            "AND table_name = 'ai_playerbot_pull_log' AND column_name = 'spawn_group_id'");
        has = (res != nullptr);
        return has;
    }

    // 调用方必须持 stateMutex（PQuery 只在"该队伍本场第一次拉怪"时发生，量很小）
    uint32 NextSeqLocked(InstanceState& inst, OpenPull const& pull)
    {
        auto it = inst.nextSeq.find(pull.leaderGuid);
        if (it != inst.nextSeq.end())
            return ++it->second;

        uint32 next = 1;
        std::unique_ptr<QueryResult> res = WorldDatabase.PQuery(
            "SELECT COALESCE(MAX(`seq`),0) FROM `ai_playerbot_pull_log` "
            "WHERE `map`='%u' AND `instance_id`='%u' AND `tank_guid`='%u'",
            pull.mapId, pull.instanceId, pull.leaderGuid);
        if (res)
            next = res->Fetch()[0].GetUInt32() + 1;

        inst.nextSeq[pull.leaderGuid] = next;
        return next;
    }

    // 路线提示：只有 bot 自动开怪会写；真人队伍永远没有
    bool RouteOrdFor(uint32 groupId, time_t now, uint16& ord)
    {
        if (!groupId)
            return false;

        auto it = routeOrdHold.find(groupId);
        if (it == routeOrdHold.end() || it->second.second <= now)
            return false;

        ord = it->second.first;
        return true;
    }

    void BeginPull(InstanceState& inst, GroupSnapshot const& snap, Map* map,
                   time_t now, bool logTable, bool newColumns, bool posColumns)
    {
        OpenPull pull;
        pull.mapId = map->GetId();
        pull.instanceId = map->GetInstanceId();
        pull.leaderGuid = snap.leaderGuid;
        pull.groupId = snap.groupId;
        pull.ord = 0;
        pull.routeClaimed = RouteOrdFor(snap.groupId, now, pull.ord);
        pull.startedAt = now;
        pull.lastCombatAt = now;
        pull.membersStart = snap.members;
        pull.aliveStart = snap.alive;
        pull.mobsTotal = (uint32)snap.mobs.size();
        pull.lastMobsAlive = pull.mobsTotal;
        pull.hasRealPlayer = snap.hasRealPlayer;
        pull.firstMobGuid = snap.firstMobGuid;
        pull.firstMobEntry = snap.firstMobEntry;
        pull.members = snap.memberGuids;
        pull.aliveAtStart = snap.aliveGuids;
        pull.seq = NextSeqLocked(inst, pull);

        inst.pulls[snap.leaderGuid] = pull;

        if (logTable)
        {
            if (newColumns && posColumns)
                WorldDatabase.PExecute(
                    "INSERT INTO `ai_playerbot_pull_log` "
                    "(`map`,`instance_id`,`seq`,`ord`,`target_guid`,`target_entry`,`tank_guid`,"
                    "`group_id`,`source`,`members`,`started_at`,`result`,`mobs_total`,`mobs_alive`,"
                    "`target_x`,`target_y`,`target_z`,`spawn_group_id`) VALUES "
                    "('%u','%u','%u','%u','%u','%u','%u','%u','%s','%u','%u','pending','%u','%u',"
                    "'%f','%f','%f','%u')",
                    pull.mapId, pull.instanceId, pull.seq, uint32(pull.ord), pull.firstMobGuid,
                    pull.firstMobEntry, pull.leaderGuid, pull.groupId,
                    snap.hasRealPlayer ? "player" : "bot", snap.members,
                    uint32(now), pull.mobsTotal, pull.mobsTotal,
                    snap.firstMobX, snap.firstMobY, snap.firstMobZ, snap.firstMobGroupId);
            else if (newColumns)
                WorldDatabase.PExecute(
                    "INSERT INTO `ai_playerbot_pull_log` "
                    "(`map`,`instance_id`,`seq`,`ord`,`target_guid`,`target_entry`,`tank_guid`,"
                    "`group_id`,`source`,`members`,`started_at`,`result`,`mobs_total`,`mobs_alive`) VALUES "
                    "('%u','%u','%u','%u','%u','%u','%u','%u','%s','%u','%u','pending','%u','%u')",
                    pull.mapId, pull.instanceId, pull.seq, uint32(pull.ord), pull.firstMobGuid,
                    pull.firstMobEntry, pull.leaderGuid, pull.groupId,
                    snap.hasRealPlayer ? "player" : "bot", snap.members,
                    uint32(now), pull.mobsTotal, pull.mobsTotal);
            else
                WorldDatabase.PExecute(
                    "INSERT INTO `ai_playerbot_pull_log` "
                    "(`map`,`instance_id`,`seq`,`ord`,`target_guid`,`target_entry`,`tank_guid`,"
                    "`started_at`,`result`,`mobs_total`,`mobs_alive`) VALUES "
                    "('%u','%u','%u','%u','%u','%u','%u','%u','pending','%u','%u')",
                    pull.mapId, pull.instanceId, pull.seq, uint32(pull.ord), pull.firstMobGuid,
                    pull.firstMobEntry, pull.leaderGuid, uint32(now), pull.mobsTotal, pull.mobsTotal);
        }

        sLog.outString("[PULL] map=%u inst=%u seq=%u group=%u leader=%u source=%s%s mobs=%u members=%u 开拉",
            pull.mapId, pull.instanceId, pull.seq, pull.groupId, pull.leaderGuid,
            snap.hasRealPlayer ? "player" : "bot", pull.routeClaimed ? " route" : "",
            pull.mobsTotal, snap.members);
    }

    void EndPull(OpenPull& pull, GroupSnapshot const* snap, const char* result,
                 time_t now, bool logTable)
    {
        // 只统计"开拉时在、结束也还在本里"的队员：中途离队/出本不算死亡
        uint32 present = 0;
        uint32 deaths = 0;
        if (snap)
        {
            for (std::set<uint32>::const_iterator i = pull.members.begin(); i != pull.members.end(); ++i)
            {
                if (!snap->memberGuids.count(*i))
                    continue;

                ++present;
                if (pull.aliveAtStart.count(*i) && !snap->aliveGuids.count(*i))
                    ++deaths;
            }
        }

        const uint32 mobsAlive = snap ? (uint32)snap->mobs.size() : 0;
        const uint32 duration = uint32(now > pull.startedAt ? (now - pull.startedAt) : 0);

        if (logTable)
            WorldDatabase.PExecute(
                "UPDATE `ai_playerbot_pull_log` SET `ended_at`='%u', `duration_s`='%u', "
                "`result`='%s', `mobs_alive`='%u', `deaths`='%u' "
                "WHERE `map`='%u' AND `instance_id`='%u' AND `tank_guid`='%u' AND `seq`='%u'",
                uint32(now), duration, result, mobsAlive, deaths,
                pull.mapId, pull.instanceId, pull.leaderGuid, pull.seq);

        sLog.outString("[PULL] map=%u inst=%u seq=%u leader=%u => %s（%us，剩 %u 只，死 %u 人，%u 人还在本里）",
            pull.mapId, pull.instanceId, pull.seq, pull.leaderGuid, result,
            duration, mobsAlive, deaths, present);

        if (pull.groupId)
            routeOrdHold.erase(pull.groupId);
    }
}

namespace pullrec
{
    void SetRouteOrd(Group* group, uint16 ord)
    {
        if (!group)
            return;

        std::lock_guard<std::mutex> lock(stateMutex);
        routeOrdHold[group->GetId()] = std::make_pair(ord, time(nullptr) + kRouteOrdHoldSec);
    }

    void ClearRouteOrd(Group* group)
    {
        if (!group)
            return;

        std::lock_guard<std::mutex> lock(stateMutex);
        routeOrdHold.erase(group->GetId());
    }

    void Update(Map* map)
    {
        if (!map || (!map->IsDungeon() && !map->IsRaid()))
            return;

        const time_t now = time(nullptr);
        const bool logTable = PullLogTableExists();
        const bool newColumns = logTable && PullLogHasNewColumns();

        // ---- 1) 快照：按队长聚合本图玩家（不持锁，避免 DB/遍历卡住其它地图线程）----
        std::map<uint32, GroupSnapshot> snaps;
        MapRefManager const& players = map->GetPlayers();
        for (MapRefManager::const_iterator itr = players.begin(); itr != players.end(); ++itr)
        {
            Player* player = itr->getSource();
            if (!player || !player->IsInWorld() || player->IsBeingTeleported())
                continue;

            Group* group = player->GetGroup();
            const uint32 leader = group ? group->GetLeaderGuid().GetCounter() : player->GetGUIDLow();

            GroupSnapshot& snap = snaps[leader];
            snap.leaderGuid = leader;
            snap.groupId = group ? group->GetId() : 0;
            ++snap.members;
            snap.memberGuids.insert(player->GetGUIDLow());
            if (player->IsAlive())
            {
                ++snap.alive;
                snap.aliveGuids.insert(player->GetGUIDLow());
            }
            if (player->IsInCombat())
                snap.inCombat = true;

            // "真玩家"判据与模块一致：bot 的 session 没有 socket ⇒ 远端地址是 "disconnected/bot"
            if (player->GetSession() && player->GetSession()->GetRemoteAddress() != "disconnected/bot")
                snap.hasRealPlayer = true;

            // 正在打这支队伍的怪：
            //   ① 玩家的 attackers = 当前用**近战自动攻击**打我的单位；
            //   ② 玩家的 hostileRefManager = **对我有仇恨**的单位（含远处放法术的法系怪）——
            //      这一条才是主力：拉法系怪时怪停在 30 码读条，不会进 ①。
            for (Unit* attacker : player->getAttackers())
            {
                if (!attacker || !attacker->IsInWorld() || !attacker->IsAlive())
                    continue;

                Creature* creature = dynamic_cast<Creature*>(attacker);
                if (!creature)
                    continue;

                if (snap.mobs.empty())
                {
                    snap.firstMobGuid = creature->GetGUIDLow();
                    snap.firstMobEntry = creature->GetEntry();
                    snap.firstMobX = creature->GetPositionX();
                    snap.firstMobY = creature->GetPositionY();
                    snap.firstMobZ = creature->GetPositionZ();
                    snap.firstMobGroupId = map->GetSpawnManager().GetGroupIdForObject(creature->GetObjectGuid());
                }
                snap.mobs.insert(creature->GetGUIDLow());
            }

            for (auto& ref : player->getHostileRefManager())
            {
                Unit* hater = ref.getSource() ? ref.getSource()->getOwner() : nullptr;
                if (!hater || !hater->IsInWorld() || !hater->IsAlive())
                    continue;

                Creature* creature = dynamic_cast<Creature*>(hater);
                if (!creature)
                    continue;

                if (snap.mobs.empty())
                {
                    snap.firstMobGuid = creature->GetGUIDLow();
                    snap.firstMobEntry = creature->GetEntry();
                    snap.firstMobX = creature->GetPositionX();
                    snap.firstMobY = creature->GetPositionY();
                    snap.firstMobZ = creature->GetPositionZ();
                    snap.firstMobGroupId = map->GetSpawnManager().GetGroupIdForObject(creature->GetObjectGuid());
                }
                snap.mobs.insert(creature->GetGUIDLow());
            }
        }

        // ---- 2) 更新 / 结束正在拉的波；开始新的一波 ----
        std::lock_guard<std::mutex> lock(stateMutex);

        InstanceState& inst = instanceStates[InstanceKey(map)];
        if (inst.lastScan && now - inst.lastScan < kScanIntervalSec)
            return;
        inst.lastScan = now;

        for (std::map<uint32, OpenPull>::iterator it = inst.pulls.begin(); it != inst.pulls.end();)
        {
            OpenPull& pull = it->second;

            auto snapIt = snaps.find(pull.leaderGuid);
            GroupSnapshot const* snap = (snapIt != snaps.end()) ? &snapIt->second : nullptr;

            uint32 present = 0;
            if (snap)
            {
                for (std::set<uint32>::const_iterator i = pull.members.begin(); i != pull.members.end(); ++i)
                    if (snap->memberGuids.count(*i))
                        ++present;
            }

            if (snap && snap->inCombat)
                pull.lastCombatAt = now;

            const bool stillFighting = snap && snap->inCombat && (now - pull.lastCombatAt) < kCombatEndGraceSec;
            if (present > 0 && stillFighting)
            {
                if (snap)
                    pull.lastMobsAlive = (uint32)snap->mobs.size();
                ++it;
                continue;
            }

            // 人全离开本 ⇒ left；否则按有没有人死区分 died / cleared
            uint32 deaths = 0;
            if (snap)
            {
                for (std::set<uint32>::const_iterator i = pull.members.begin(); i != pull.members.end(); ++i)
                    if (snap->memberGuids.count(*i) && pull.aliveAtStart.count(*i) && !snap->aliveGuids.count(*i))
                        ++deaths;
            }

            const char* result = (present == 0) ? "left" : (deaths > 0 ? "died" : "cleared");
            EndPull(pull, snap, result, now, logTable);
            it = inst.pulls.erase(it);
        }

        for (std::map<uint32, GroupSnapshot>::const_iterator si = snaps.begin(); si != snaps.end(); ++si)
        {
            GroupSnapshot const& snap = si->second;
            if (!snap.inCombat || snap.mobs.empty())
                continue;
            if (inst.pulls.count(snap.leaderGuid))
                continue;

            BeginPull(inst, snap, map, now, logTable, newColumns, PullLogHasPosColumns());
        }

        // ---- 3) 僵尸清理：没有在拉的波、且很久没扫到的实例状态丢掉 ----
        static time_t lastCleanup = 0;
        if (now - lastCleanup >= 600)
        {
            lastCleanup = now;
            for (std::map<uint64, InstanceState>::iterator i = instanceStates.begin(); i != instanceStates.end();)
            {
                if (i->second.pulls.empty() && now - i->second.lastScan > kInstanceStateKeepSec)
                    i = instanceStates.erase(i);
                else
                    ++i;
            }

            for (std::map<uint32, std::pair<uint16, time_t>>::iterator i = routeOrdHold.begin(); i != routeOrdHold.end();)
                i = (i->second.second <= now) ? routeOrdHold.erase(i) : std::next(i);
        }
    }
}
