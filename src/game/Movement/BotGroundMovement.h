#ifndef MANGOS_BOT_GROUND_MOVEMENT_H
#define MANGOS_BOT_GROUND_MOVEMENT_H

#include "Entities/Player.h"
#include "Maps/Map.h"
#include "MotionGenerators/MotionMaster.h"
#include "Movement/MoveSpline.h"
#include <cmath>

namespace Movement
{
    // Server-driven players have no client to settle their feet after a spline.
    // Keep this separate from scripted creature placement and client movement.
    inline bool GroundBotMaySettle(Unit& unit)
    {
#ifdef ENABLE_PLAYERBOTS
        if (!unit.IsPlayer() || static_cast<Player&>(unit).isRealPlayer() || !unit.IsAlive() || !unit.IsInWorld())
            return false;
        Player& player = static_cast<Player&>(unit);
        MovementFlags const special = MovementFlags(MOVEFLAG_JUMPING | MOVEFLAG_FALLING | MOVEFLAG_FALLINGFAR |
            MOVEFLAG_SWIMMING | MOVEFLAG_WATERWALKING | MOVEFLAG_FLYING | MOVEFLAG_LEVITATING | MOVEFLAG_HOVER | MOVEFLAG_ONTRANSPORT);
        if (player.IsBeingTeleported() || player.IsTaxiFlying() || player.IsLaunched() ||
            unit.GetTransport() || unit.GetTransportInfo() || unit.IsFlying() || unit.IsLevitating() || unit.IsHovering() ||
            unit.IsInWater() || unit.m_movementInfo.HasMovementFlag(special) || unit.movespline->IsFalling())
            return false;
        MotionMaster const& motion = *unit.GetMotionMaster();
        if (!motion.empty())
        {
            MovementGeneratorType const type = motion.GetCurrentMovementGeneratorType();
            if (type == FALL_MOTION_TYPE || type == EFFECT_MOTION_TYPE || type == TAXI_MOTION_TYPE)
                return false;
        }
        return true;
#else
        return false;
#endif
    }

    inline bool GroundBotFloorZ(Unit& unit, float x, float y, float z, float maxDrop, float& floor)
    {
        if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z) || maxDrop <= 0.0f)
            return false;
        floor = unit.GetTerrain()->GetHeightStatic(x, y, z, false);
        if (!std::isfinite(floor) || floor <= INVALID_HEIGHT || floor > z || z - floor > maxDrop)
            floor = INVALID_HEIGHT_VALUE;
        float hitX = x, hitY = y;
        // Stop at the ADT when it is below us; in a cave the ADT is overhead,
        // so use the core's maximum fall range to find the first actual floor.
        float hitZ = floor > INVALID_HEIGHT ? floor : std::max(z - maxDrop, float(INVALID_HEIGHT));
        if (unit.GetMap()->GetHitPosition(x, y, z + 2.0f, hitX, hitY, hitZ, 0.0f))
        {
            if (!std::isfinite(hitZ) || hitZ > z)
                return false;
            if (z - hitZ <= maxDrop)
                floor = std::max(floor, hitZ);
        }
        return std::isfinite(floor) && floor > INVALID_HEIGHT && floor <= z && z - floor <= maxDrop;
    }

    inline bool GroundBotStopZ(Unit& unit, float x, float y, float& z)
    {
        if (!GroundBotMaySettle(unit) || unit.GetTerrain()->IsInWater(x, y, z))
            return false;
        float floor;
        if (!GroundBotFloorZ(unit, x, y, z, 2.0f, floor) || z - floor <= 0.01f)
            return false;
        z = floor;
        return true;
    }
}
#endif
