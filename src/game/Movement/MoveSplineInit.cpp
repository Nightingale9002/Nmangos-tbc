/*
 * This file is part of the CMaNGOS Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "MoveSplineInit.h"
#include "MoveSpline.h"
#include "packet_builder.h"
#include "Entities/Unit.h"
#include "Entities/Creature.h"
#include "Log/Log.h"
#include "MotionGenerators/PfDebug.h"
#include "Maps/TransportSystem.h"
#include "Entities/Transports.h"

namespace Movement
{
    static thread_local uint32 splineCounter = 1;

    int32 MoveSplineInit::Launch()
    {
        // show path in the client if need
        if (unit.HaveDebugFlag(CMDEBUGFLAG_WP_PATH))
        {
            uint32 counter = 0;
            for (auto pt : args.path)
            {
                TempSpawnSettings settings;
                settings.spawner = &unit;
                settings.entry = VISUAL_WAYPOINT;
                settings.x = pt.x; settings.y = pt.y; settings.z = pt.z; settings.ori = 0.0f;
                settings.activeObject = true;
                settings.despawnTime = 30 * IN_MILLISECONDS;
                settings.spawnType = TEMPSPAWN_TIMED_DESPAWN;
                settings.spawnDataEntry = 2;

                settings.tempSpawnMovegen = true;
                settings.waypointId = counter++;

                WorldObject::SummonCreature(settings, unit.GetMap());
            }
        }
        MoveSpline& move_spline = *unit.movespline;
        TransportInfo* transportInfo = unit.GetTransportInfo();
        // TODO: merge these two together
        GenericTransport* transport = unit.GetTransport();

        Location real_position(unit.GetPositionX(), unit.GetPositionY(), unit.GetPositionZ(), unit.GetOrientation());

        // If boarded use current local position
        if (transportInfo)
            transportInfo->GetLocalPosition(real_position.x, real_position.y, real_position.z, real_position.orientation);
        if (transport)
            transport->CalculatePassengerOffset(real_position.x, real_position.y, real_position.z, &real_position.orientation);

        // there is a big chance that current position is unknown if current state is not finalized, need compute it
        // this also allows calculate spline position and update map position in much greater intervals
        if (!move_spline.Finalized())
            real_position = move_spline.ComputePosition();

        bool pathEmpty = false;
        if (args.path.empty())
        {
            // should i do the things that user should do?
            MoveTo(real_position);
            pathEmpty = true;
        }

        // corrent first vertex
        args.path[0] = real_position;

        // Unified in-water path handling for creatures, covering every movement
        // type (chase/follow/wander/waypoint/home): swimmers stay in the
        // [floor+0.5, surface] band, non-swimmers and WALK_IN_WATER creatures
        // walk on the seabed.
        //
        // GATE: only re-height when the unit is actually inside water. This
        // block used to run for EVERY creature spline: GetHeight() falls
        // through WMO seams to the ADT pit / seabed far below a building's
        // floor (Magisters' Terrace 24560/24685: floor z=-20/-2.6, seabed
        // z=-92.4), and re-writing land path points to groundZ+0.5 dragged
        // creatures straight through the floor into the basement. The
        // navmesh decides walkability; land units keep their path z.
        if (unit.GetTypeId() == TYPEID_UNIT)
        {
            CreatureInfo const* cinfo = static_cast<Creature const&>(unit).GetCreatureInfo();
            bool const walkInWater = (cinfo->ExtraFlags & CREATURE_EXTRA_FLAG_WALK_IN_WATER) != 0;
            bool const canSwim = unit.CanSwim();
            // [WATER-POINT] Water handling is now per path-point, not gated on the
            // unit being inside water at Launch time. A patrol that STARTS on shore
            // and crosses a lake used to skip this whole block (unit.IsInWater()
            // false) -> waypoints kept their table Z -> the creature glided on the
            // water surface. The same happened to water patrols whose table Z sat
            // at/above the surface. Every point is now judged by the terrain
            // structure at its own 2D position:
            //   - no liquid there          -> keep table Z (land/bridge/boat deck)
            //   - ground < water surface   -> the point IS inside a water body:
            //       swimmer                -> submerge into [floor+0.5, surface-1.5]
            //       non-swimmer / WALK_IN_WATER -> seabed+0.5, but ONLY when the
            //       point itself is already below the surface (a land patrol
            //       crossing a bridge/shore rock must not be pulled down by a
            //       GetHeight that fell through a WMO seam, e.g. Magisters' Terrace
            //       seabed z=-92.4 below a floor at -20).
            // [PERF-GUARD] Land-only units (cannot swim AND not currently in water)
            // skip all per-point terrain queries -> no extra cost vs the old
            // unit.IsInWater() gate. Amphibious / water units get per-point handling.
            if (unit.IsInWater() || canSwim)
            {
                bool sawUnderwater = false;
                Map const* map = unit.GetMap();
                auto terrain = map->GetTerrain();
                for (auto& p : args.path)
                {
                    float const origZ = p.z;
                    float groundZ = map->GetHeight(p.x, p.y, p.z, true);
                    if (groundZ <= INVALID_HEIGHT)
                        continue;
                    float waterLevel = terrain->GetWaterLevel(p.x, p.y, p.z, &groundZ);
                    if (waterLevel <= INVALID_HEIGHT)
                        continue;                                   // no liquid here
                    if (walkInWater || !canSwim)
                    {
                        // land walker / crab: walk the seabed, but never drag a point
                        // that is above the surface down (bridge, shore rock, WMO seam)
                        if (p.z <= waterLevel)
                            p.z = groundZ + 0.5f;
                        continue;
                    }
                    // swimmer: submerge the point only when it is a real water body
                    // AND the point is not far above the surface (a point on a
                    // bridge/high ledge must not be dragged down if GetHeight fell
                    // through to the water below it)
                    if (groundZ < waterLevel && p.z <= waterLevel + 2.0f)
                    {
                        sawUnderwater = true;
                        // fully-submerged band requires enough depth (bottom+0.5 <
                        // surface-1.5). In a shallow pocket (e.g. waterline at 18.27,
                        // floor 18.20) max(groundZ+0.5, min(p.z, surface-1.5)) used to
                        // pin the point to groundZ+0.5 = 18.70, i.e. ABOVE the surface
                        // -> creature floated out of the water. Clamp to the band when
                        // it exists, else floor or skim the waterline.
                        float const lo = groundZ + 0.5f;
                        float const hi = waterLevel - 1.5f;
                        if (lo <= hi)
                            p.z = std::max(lo, std::min(p.z, hi));
                        else
                            p.z = std::min(lo, waterLevel);        // shallow: walk floor / skim surface
                    }
                    PFDBG_MSG(&unit, "MoveSplineInit water-rewrite pt(%.8f,%.8f) origZ=%.8f -> newZ=%.8f groundZ=%.8f waterLevel=%.8f walkInWater=%d canSwim=%d",
                              p.x, p.y, origZ, p.z, groundZ, waterLevel, walkInWater ? 1 : 0, canSwim ? 1 : 0);
                }

                // [SWIM-FLAG] A swim-capable creature whose path enters a water body
                // must enter the SWIMMING state now, so the spline carries the swim
                // movement flag and the client plays the swim animation. The z
                // correction alone leaves it "walking through water". Unit::Update
                // clears the flag when the unit surfaces (z > surface + 0.5).
                if (sawUnderwater && canSwim && !walkInWater &&
                    !unit.m_movementInfo.HasMovementFlag(MOVEFLAG_SWIMMING))
                {
                    unit.SetSwim(true);
                    PFDBG_MSG(&unit, "MoveSplineInit set-swim: path enters water -> SWIMMING");
                }
            }
        }

        args.flags.enter_cycle = args.flags.cyclic;
        uint32 moveFlags = unit.m_movementInfo.GetMovementFlags();
        if (args.flags.runmode)
            moveFlags &= ~MOVEFLAG_WALK_MODE;
        else
            moveFlags |= MOVEFLAG_WALK_MODE;

        moveFlags |= (MOVEFLAG_SPLINE_ENABLED | MOVEFLAG_FORWARD);

        if (args.velocity == 0.f) // ignore swim speed and flight speed because its not used in generic scripting - always possible to override
        {
            args.velocity = unit.GetSpeed(MovementInfo::GetSpeedType(MovementFlags(moveFlags & ~(MOVEFLAG_FLYING | MOVEFLAG_SWIMMING))));
            if (args.slowed != 0.f) // when set always > 0.5
                args.velocity *= args.slowed;
        }

        if (!args.Validate(&unit))
            return 0;

        if (moveFlags & MOVEFLAG_ROOT && !pathEmpty)
        {
            sLog.outCustomLog("Invalid movement during root. Entry: %u IsImmobilized %s, moveflags %u", unit.GetEntry(), unit.IsImmobilizedState() ? "true" : "false", moveFlags);
            sLog.traceLog();
            return 0;
        }

        args.splineId = splineCounter++;

        unit.m_movementInfo.SetMovementFlags(MovementFlags(moveFlags));
        move_spline.Initialize(args);

        WorldPacket data(SMSG_MONSTER_MOVE, 64);
        data << unit.GetPackGUID();

        if (transportInfo || transport)
        {
            data.SetOpcode(SMSG_MONSTER_MOVE_TRANSPORT);
            if (transportInfo)
                data << transportInfo->GetTransportGuid().WriteAsPacked();
            else if (transport)
                data << transport->GetPackGUID();
        }

        PacketBuilder::WriteMonsterMove(move_spline, data);
        unit.SendMessageToAllWhoSeeMeMove(data, ObjectGuid());

        return move_spline.Duration();
    }

    void MoveSplineInit::Stop(bool forceSend /*= false*/)
    {
        MoveSpline& move_spline = *unit.movespline;

        // No need to stop if we are not moving
        if (!forceSend && move_spline.Finalized())
            return;

        TransportInfo* transportInfo = unit.GetTransportInfo();
        // TODO: merge these two together
        GenericTransport* transport = unit.GetTransport();

        Location real_position(unit.GetPositionX(), unit.GetPositionY(), unit.GetPositionZ(), unit.GetOrientation());

        // If boarded use current local position
        if (transportInfo)
            transportInfo->GetLocalPosition(real_position.x, real_position.y, real_position.z, real_position.orientation);
        if (transport)
            transport->CalculatePassengerOffset(real_position.x, real_position.y, real_position.z, &real_position.orientation);

        // there is a big chance that current position is unknown if current state is not finalized, need compute it
        // this also allows calculate spline position and update map position in much greater intervals
        if (!move_spline.Finalized())
            real_position = move_spline.ComputePosition();

        if (args.path.empty())
        {
            // should i do the things that user should do?
            MoveTo(real_position);
        }

        // current first vertex
        args.path[0] = real_position;

        args.splineId = splineCounter++;

        args.flags = MoveSplineFlag::Done;
        unit.m_movementInfo.RemoveMovementFlag(MovementFlags(MOVEFLAG_FORWARD | MOVEFLAG_SPLINE_ENABLED));
        move_spline.Initialize(args);

        WorldPacket data(SMSG_MONSTER_MOVE, 64);
        data << unit.GetPackGUID();

        if (transportInfo || transport)
        {
            data.SetOpcode(SMSG_MONSTER_MOVE_TRANSPORT);
            if (transportInfo)
                data << transportInfo->GetTransportGuid().WriteAsPacked();
            else
                data << transport->GetPackGUID();
        }

        data << real_position.x << real_position.y << real_position.z;
        data << move_spline.GetId();
        data << uint8(MonsterMoveStop);
        unit.SendMessageToAllWhoSeeMeMove(data, ObjectGuid());
    }

    MoveSplineInit::MoveSplineInit(Unit& m) : unit(m)
    {
        // mix existing state into new
        args.flags.runmode = !unit.m_movementInfo.HasMovementFlag(MOVEFLAG_WALK_MODE);
        args.flags.flying = unit.m_movementInfo.HasMovementFlag((MovementFlags)(MOVEFLAG_CAN_FLY | MOVEFLAG_HOVER | MOVEFLAG_FLYING | MOVEFLAG_LEVITATING));
    }

    void MoveSplineInit::SetFacing(const WorldObject* target)
    {
        args.flags.EnableFacingTarget();
        args.facing.target = target->GetObjectGuid().GetRawValue();
    }

    void MoveSplineInit::SetFacing(float angle)
    {
        args.facing.angle = G3D::wrap(angle, 0.f, (float)G3D::twoPi());
        args.flags.EnableFacingAngle();
    }
}
