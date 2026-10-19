/*
 * [2026-10-19 站长口径] 真人跳跃 / 电梯标注观测（见 PlayerNavObs.h 顶部注释）
 */

#include "MotionGenerators/PlayerNavObs.h"

#include "Database/DatabaseEnv.h"
#include "Entities/Object.h"
#include "Entities/Player.h"
#include "Log/Log.h"
#include "Util/Timer.h"

#include <cmath>
#include <mutex>
#include <unordered_map>

namespace
{
    const float kGridSize = 533.33333f;
    const uint32 kJumpTimeoutMs = 6000;
    const uint32 kLiftMinDz = 4;        // 累计竖移 >= 4 码才算一次"电梯"
    const uint32 kLiftStaleMs = 2500;   // 竖移中断这么久就结束本次电梯

    // mmap tile（"方块"）：文件名为 map<gx*100+gy>.mmtile
    void TileOf(uint32 mapId, float x, float y, int& gx, int& gy, int& tile)
    {
        gx = int(32.0f - y / kGridSize);
        gy = int(32.0f - x / kGridSize);
        tile = gx * 100 + gy;
        (void)mapId;
    }

    struct PendingJump
    {
        bool active = false;
        float x = 0, y = 0, z = 0;
        uint32 startedMs = 0;
        float lastZ = 0;
    };

    struct PendingLift
    {
        bool active = false;
        float startX = 0, startY = 0, startZ = 0;
        float lastZ = 0;
        uint32 startedMs = 0;
        uint32 lastMoveMs = 0;
        float accumDz = 0;
    };

    struct State
    {
        bool valid = false;
        float lastX = 0, lastY = 0, lastZ = 0;
        uint32 lastMs = 0;
        bool falling = false;
        PendingJump jump;
        PendingLift lift;
    };

    std::mutex g_mutex;
    std::unordered_map<uint32, State> g_states;    // player low guid -> state

    bool IsBot(Unit* unit)
    {
        if (!unit || unit->GetTypeId() != TYPEID_PLAYER)
            return false;
        Player* p = static_cast<Player*>(unit);
        return p->GetPlayerbotAI() != nullptr;
    }

    void WriteJump(Unit* unit, float sx, float sy, float sz, float dx, float dy, float dz,
                   uint32 durationMs)
    {
        if (!unit)
            return;
        uint32 const mapId = unit->GetMapId();
        int sgx = 0, sgy = 0, stile = 0, dgx = 0, dgy = 0, dtile = 0;
        TileOf(mapId, sx, sy, sgx, sgy, stile);
        TileOf(mapId, dx, dy, dgx, dgy, dtile);

        float const dist2d = std::sqrt((dx - sx) * (dx - sx) + (dy - sy) * (dy - sy));
        WorldDatabase.PExecute(
            "INSERT INTO ai_playerbot_jump_obs "
            "(`ts`,`map`,`instance_id`,`is_bot`,`player_guid`,`player_name`,"
            "`src_x`,`src_y`,`src_z`,`src_tile`,`src_tile_x`,`src_tile_y`,"
            "`dst_x`,`dst_y`,`dst_z`,`dst_tile`,`dst_tile_x`,`dst_tile_y`,"
            "`dz`,`dist2d`,`duration_ms`,`verified`) VALUES "
            "(%u,%u,%u,%u,%u,'%s',%.3f,%.3f,%.3f,%d,%d,%d,%.3f,%.3f,%.3f,%d,%d,%d,%.2f,%.2f,%u,0)",
            uint32(time(nullptr)), mapId, uint32(unit->GetInstanceId()), IsBot(unit) ? 1 : 0,
            uint32(unit->GetGUIDLow()),
            unit->GetTypeId() == TYPEID_PLAYER ? static_cast<Player*>(unit)->GetName() : "-",
            sx, sy, sz, stile, sgx, sgy,
            dx, dy, dz, dtile, dgx, dgy,
            sz - dz, dist2d, durationMs);

        sLog.outString("[NAVOBS] jump map=%u (%.1f,%.1f,%.1f tile=%d) -> (%.1f,%.1f,%.1f tile=%d) "
                       "dz=%.1f dist=%.1f dt=%ums is_bot=%d by=%s",
                       mapId, sx, sy, sz, stile, dx, dy, dz, dtile,
                       sz - dz, dist2d, durationMs, IsBot(unit) ? 1 : 0,
                       unit->GetTypeId() == TYPEID_PLAYER ? static_cast<Player*>(unit)->GetName() : "-");
    }

    void WriteLift(Unit* unit, float sx, float sy, float sz, float dx, float dy, float dz,
                   uint32 durationMs)
    {
        if (!unit)
            return;
        uint32 const mapId = unit->GetMapId();
        int sgx = 0, sgy = 0, stile = 0, dgx = 0, dgy = 0, dtile = 0;
        TileOf(mapId, sx, sy, sgx, sgy, stile);
        TileOf(mapId, dx, dy, dgx, dgy, dtile);

        WorldDatabase.PExecute(
            "INSERT INTO ai_playerbot_lift_obs "
            "(`ts`,`map`,`instance_id`,`is_bot`,`player_guid`,`player_name`,"
            "`src_x`,`src_y`,`src_z`,`src_tile`,`src_tile_x`,`src_tile_y`,"
            "`dst_x`,`dst_y`,`dst_z`,`dst_tile`,`dst_tile_x`,`dst_tile_y`,"
            "`d_z`,`duration_ms`,`verified`) VALUES "
            "(%u,%u,%u,%u,%u,'%s',%.3f,%.3f,%.3f,%d,%d,%d,%.3f,%.3f,%.3f,%d,%d,%d,%.2f,%u,0)",
            uint32(time(nullptr)), mapId, uint32(unit->GetInstanceId()), IsBot(unit) ? 1 : 0,
            uint32(unit->GetGUIDLow()),
            unit->GetTypeId() == TYPEID_PLAYER ? static_cast<Player*>(unit)->GetName() : "-",
            sx, sy, sz, stile, sgx, sgy,
            dx, dy, dz, dtile, dgx, dgy,
            dz - sz, durationMs);

        sLog.outString("[NAVOBS] lift map=%u (%.1f,%.1f,%.1f tile=%d) -> (%.1f,%.1f,%.1f tile=%d) "
                       "dz=%.1f dt=%ums is_bot=%d by=%s",
                       mapId, sx, sy, sz, stile, dx, dy, dz, dtile,
                       dz - sz, durationMs, IsBot(unit) ? 1 : 0,
                       unit->GetTypeId() == TYPEID_PLAYER ? static_cast<Player*>(unit)->GetName() : "-");
    }
}

namespace navobs
{
    void Init()
    {
        sLog.outString("[NAVOBS] 真人跳跃/电梯标注观测已启用：ai_playerbot_jump_obs / ai_playerbot_lift_obs"
                       "（记录起点/落点/进度方块 tile，verified=0 等人工标注）");
    }

    void OnClientMove(Player* player, Unit* mover, uint32 opcode, MovementInfo const& info)
    {
        if (!player || !mover || mover->GetTypeId() != TYPEID_PLAYER)
            return;

        Position const& pos = info.GetPos();
        uint32 const now = WorldTimer::getMSTime();
        bool const falling = info.HasMovementFlag(MOVEFLAG_FALLING);

        std::lock_guard<std::mutex> guard(g_mutex);
        State& s = g_states[player->GetGUIDLow()];

        // ---- ① 跳跃：起跳 / 落地 ----
        if (opcode == MSG_MOVE_JUMP)
        {
            if (!s.jump.active)
            {
                s.jump.active = true;
                s.jump.x = pos.x;
                s.jump.y = pos.y;
                s.jump.z = pos.z;
                s.jump.startedMs = now;
                s.jump.lastZ = pos.z;
            }
        }
        else if (s.jump.active)
        {
            bool finalize = false;
            if (opcode == MSG_MOVE_FALL_LAND && !falling)
                finalize = true;
            else if (!falling && s.falling && (now - s.jump.startedMs) > 150)
                finalize = true;        // 兜底：下落标志已消失
            else if (now - s.jump.startedMs > kJumpTimeoutMs)
                finalize = true;

            if (finalize)
            {
                WriteJump(player, s.jump.x, s.jump.y, s.jump.z, pos.x, pos.y, pos.z,
                          now - s.jump.startedMs);
                s.jump.active = false;
            }
            else
            {
                s.jump.lastZ = pos.z;
            }
        }

        // ---- ② 电梯：竖移/水平不动 ----
        if (s.valid && !falling && !info.HasMovementFlag(MOVEFLAG_SWIMMING) &&
            !info.HasMovementFlag(MOVEFLAG_FLYING))
        {
            uint32 const dt = WorldTimer::getMSTimeDiff(s.lastMs, now);
            if (dt > 0 && dt < 3000)
            {
                float const dz = pos.z - s.lastZ;
                float const dxy = std::sqrt((pos.x - s.lastX) * (pos.x - s.lastX) +
                                            (pos.y - s.lastY) * (pos.y - s.lastY));
                bool const vertical = std::fabs(dz) > 0.12f && dxy < 0.9f;

                if (vertical)
                {
                    if (!s.lift.active)
                    {
                        s.lift.active = true;
                        s.lift.startX = s.lastX;
                        s.lift.startY = s.lastY;
                        s.lift.startZ = s.lastZ;
                        s.lift.lastZ = pos.z;
                        s.lift.startedMs = now;
                        s.lift.accumDz = 0;
                    }
                    s.lift.accumDz += std::fabs(dz);
                    s.lift.lastZ = pos.z;
                    s.lift.lastMoveMs = now;
                }
                else if (s.lift.active && (dxy > 1.2f || WorldTimer::getMSTimeDiff(s.lift.lastMoveMs, now) > kLiftStaleMs))
                {
                    if (s.lift.accumDz >= float(kLiftMinDz))
                        WriteLift(player, s.lift.startX, s.lift.startY, s.lift.startZ,
                                  pos.x, pos.y, pos.z,
                                  WorldTimer::getMSTimeDiff(s.lift.startedMs, now));
                    s.lift.active = false;
                }
            }
        }
        else if (s.lift.active)
        {
            if (s.lift.accumDz >= float(kLiftMinDz))
                WriteLift(player, s.lift.startX, s.lift.startY, s.lift.startZ,
                          pos.x, pos.y, pos.z, WorldTimer::getMSTimeDiff(s.lift.startedMs, now));
            s.lift.active = false;
        }

        s.valid = true;
        s.lastX = pos.x;
        s.lastY = pos.y;
        s.lastZ = pos.z;
        s.lastMs = now;
        s.falling = falling;
    }

    void OnServerJump(Unit* unit, float srcX, float srcY, float srcZ,
                      float dstX, float dstY, float dstZ)
    {
        if (!unit)
            return;

        // 只有 bot 走服务端跳跃；真人跳跃从客户端包走 OnClientMove，不重复记。
        if (!IsBot(unit))
            return;

        WriteJump(unit, srcX, srcY, srcZ, dstX, dstY, dstZ, 0);
    }
}
