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

#include "Entities/Creature.h"
#include "Entities/Player.h"
#include "Movement/MoveSplineInit.h"
#include "Movement/MoveSpline.h"
#include "MotionGenerators/RandomMovementGenerator.h"

void AbstractRandomMovementGenerator::Initialize(Unit& owner)
{
    owner.addUnitState(i_stateActive);

    m_pathFinder = std::make_unique<PathFinder>(&owner);

    // Client-controlled unit should have control removed
    if (const Player* controllingClientPlayer = owner.GetClientControlling())
        controllingClientPlayer->UpdateClientControl(&owner, false);
    // Non-client controlled unit with an AI should drop target
    else if (owner.AI())
    {
        owner.SetTarget(nullptr);
        owner.MeleeAttackStop(owner.GetVictim());
    }

    // Stop any previously dispatched splines no matter the source
    if (!owner.movespline->Finalized())
    {
        if (owner.IsClientControlled())
            owner.StopMoving(true);
        else
            owner.InterruptMoving();
    }
}

void AbstractRandomMovementGenerator::Finalize(Unit& owner)
{
    owner.clearUnitState(i_stateActive | i_stateMotion);

    // Client-controlled unit should have control restored
    if (const Player* controllingClientPlayer = owner.GetClientControlling())
        controllingClientPlayer->UpdateClientControl(&owner, true);

    // Stop any previously dispatched splines no matter the source
    if (!owner.movespline->Finalized())
    {
        if (owner.IsClientControlled())
            owner.StopMoving(true);
        else
            owner.InterruptMoving();
    }
}

void AbstractRandomMovementGenerator::Interrupt(Unit& owner)
{
    owner.InterruptMoving();

    owner.clearUnitState(i_stateMotion);
}

void AbstractRandomMovementGenerator::Reset(Unit& owner)
{
    i_nextMoveTimer.Reset(0);

    Initialize(owner);
}

bool AbstractRandomMovementGenerator::Update(Unit& owner, const uint32& diff)
{
    if (!owner.IsAlive())
        return false;

    if (owner.hasUnitState(UNIT_STAT_NO_FREE_MOVE & ~i_stateActive))
    {
        i_nextMoveTimer.Update(diff);
        owner.clearUnitState(i_stateMotion);
        return true;
    }

    if (owner.movespline->Finalized())
    {
        i_nextMoveTimer.Update(diff);

        if (i_nextMoveTimer.Passed())
        {
            if (_setLocation(owner))
            {
                if (i_nextMoveCount > 1)
                    --i_nextMoveCount;
                else
                {
                    i_nextMoveCount = urand(1, i_nextMoveCountMax);
                    i_nextMoveTimer.Reset(urand(i_nextMoveDelayMin, i_nextMoveDelayMax));
                }
            }
            else
                i_nextMoveTimer.Reset(owner.HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_PLAYER_CONTROLLED) ? 100 : 500);
        }
    }

    return true;
}

int32 AbstractRandomMovementGenerator::_setLocation(Unit& owner)
{
    // Look for a random location within certain radius of initial position
    float x = i_x, y = i_y, z = i_z;

    if (i_pathLength != 0.0f)
        m_pathFinder->setPathLengthLimit(i_pathLength);

    m_pathFinder->ComputePathToRandomPoint(Vector3(x, y, z), i_radius);

    if ((m_pathFinder->getPathType() & PATHFIND_NOPATH) != 0)
        return 0;

    auto& path = m_pathFinder->getPath();

    // ====== 修正路径点高度 ======
<<<<<<< HEAD
    // 确保每个路径点都在正确的高度
    for (auto& point : path)
    {
        // 对于游泳生物，不使用水面高度修正
        /*
        if (owner.IsInWater())
        {
            // 获取水面高度
            float waterLevel = owner.GetTerrain()->GetWaterLevel(point.x, point.y, point.z);

            // 如果当前点在水下，使用水面高度
            if (point.z < waterLevel)
            {
                point.z = waterLevel - 0.5f; // 保持在水面下一点
            }
            // 如果当前点在水面上，保持原高度
        }
        else
        */
        {
            // 非游泳生物使用标准地面高度修正
            owner.UpdateAllowedPositionZ(point.x, point.y, point.z);
        }
    }

    // ====== 斜率检查（仅对不能飞行且不游泳的单位）======
    if (!owner.CanFly() && !owner.IsInWater())
=======
    // 确保每个路径点都在正确的地面高度
    for (auto& point : path)
    {
        owner.UpdateAllowedPositionZ(point.x, point.y, point.z);
    }

    // ====== 斜率检查（仅对不能飞行的单位）======
    if (!owner.CanFly())
>>>>>>> f5247ff74649980739b2c7627d204ead6cfe4a11
    {
        for (size_t i = 0; i < path.size() - 1; ++i)
        {
            const Vector3& p1 = path[i];
            const Vector3& p2 = path[i + 1];

            // 计算水平距离和垂直距离
            float dx = p2.x - p1.x;
            float dy = p2.y - p1.y;
            float dz = p2.z - p1.z;
            float horizontal_distance = sqrt(dx * dx + dy * dy);
            float vertical_distance = std::abs(dz);

            // 小距离移动允许较大的垂直变化（如台阶）
            if (horizontal_distance < 0.5f)
            {
                // 台阶高度不超过2.0f
                if (vertical_distance > 2.0f)
                {
                    return 0; // 路径无效：台阶太高
                }
            }
            // 检查斜率是否超过45度（垂直/水平 > 1.0）
            else if (vertical_distance / horizontal_distance > 1.0f)
            {
                return 0; // 路径无效：斜率太大
            }
        }
    }

    Movement::MoveSplineInit init(owner);
    init.MovebyPath(path);
<<<<<<< HEAD

    // 设置游泳动画（如果单位在水中）
    if (owner.IsInWater())
    {
        init.SetFly();
    }
    else
    {
        init.SetWalk(i_walk);
    }
=======
    init.SetWalk(i_walk);
>>>>>>> f5247ff74649980739b2c7627d204ead6cfe4a11

    if (owner.IsSlowedInCombat())
        init.SetCombatSlowed(1.f - (30.f - std::min(owner.GetHealthPercent(), 30.f)) * 1.67);

    int32 duration = init.Launch();

    if (duration)
        owner.addUnitState(i_stateMotion);

    return duration;
}

ConfusedMovementGenerator::ConfusedMovementGenerator(float x, float y, float z) :
    AbstractRandomMovementGenerator(UNIT_STAT_CONFUSED, UNIT_STAT_CONFUSED_MOVE, 500, 1500)
{
    i_radius = 2.5f;
    i_x = x;
    i_y = y;
    i_z = z;
}

ConfusedMovementGenerator::ConfusedMovementGenerator(const Unit& owner) :
    ConfusedMovementGenerator(owner.GetPositionX(), owner.GetPositionY(), owner.GetPositionZ())
{
}

WanderMovementGenerator::WanderMovementGenerator(float x, float y, float z, float radius, float verticalZ) :
    AbstractRandomMovementGenerator(UNIT_STAT_ROAMING, UNIT_STAT_ROAMING_MOVE, 3000, 10000, 3)
{
    i_x = x;
    i_y = y;
    i_z = z;
    i_radius = radius;
    i_verticalZ = verticalZ;
}

WanderMovementGenerator::WanderMovementGenerator(const Creature& npc) :
    AbstractRandomMovementGenerator(UNIT_STAT_ROAMING, UNIT_STAT_ROAMING_MOVE, 3000, 10000, 3)
{
    npc.GetRespawnCoord(i_x, i_y, i_z, nullptr, &i_radius);
}

void WanderMovementGenerator::Finalize(Unit& owner)
{
    AbstractRandomMovementGenerator::Finalize(owner);

    if (owner.GetTypeId() == TYPEID_UNIT)
        static_cast<Creature&>(owner).SetWalk(!owner.hasUnitState(UNIT_STAT_RUNNING_STATE), false);
}

void WanderMovementGenerator::Interrupt(Unit& owner)
{
    AbstractRandomMovementGenerator::Interrupt(owner);

    if (owner.GetTypeId() == TYPEID_UNIT)
        static_cast<Creature&>(owner).SetWalk(!owner.hasUnitState(UNIT_STAT_RUNNING_STATE), false);
}

void WanderMovementGenerator::AddToRandomPauseTime(int32 waitTimeDiff, bool force)
{
    if (force)
        i_nextMoveTimer.Reset(waitTimeDiff);
    else if (!i_nextMoveTimer.Passed())
    {
        // creature is stopped already
        // Prevent <= 0, the code in Update requires to catch the change from moving to not moving
        int32 newWaitTime = i_nextMoveTimer.GetExpiry() + waitTimeDiff;
        i_nextMoveTimer.Reset(newWaitTime > 0 ? newWaitTime : 1);
    }
}

TimedWanderMovementGenerator::TimedWanderMovementGenerator(Creature const& npc, uint32 timer, float radius, float verticalZ)
    : TimedWanderMovementGenerator(timer, npc.GetPositionX(), npc.GetPositionY(), npc.GetPositionZ(), radius, verticalZ)
{
}

bool TimedWanderMovementGenerator::Update(Unit& owner, const uint32& diff)
{
    m_durationTimer.Update(diff);
    if (m_durationTimer.Passed())
        return false;

    return WanderMovementGenerator::Update(owner, diff);
}

FleeingMovementGenerator::FleeingMovementGenerator(Unit const& source) :
    AbstractRandomMovementGenerator(UNIT_STAT_FLEEING, UNIT_STAT_FLEEING_MOVE, 500, 1500)
{
    source.GetPosition(i_x, i_y, i_z);
    i_pathLength = 30;
    i_walk = false;
}

#define MIN_QUIET_DISTANCE 28.0f
#define MAX_QUIET_DISTANCE 43.0f

int32 FleeingMovementGenerator::_setLocation(Unit& owner)
{
    float dist_from_source = owner.GetDistance(i_x, i_y, i_z);

    if (dist_from_source < MIN_QUIET_DISTANCE)
        i_radius = frand(0.4f, 1.3f) * (MIN_QUIET_DISTANCE - dist_from_source);
    else if (dist_from_source > MAX_QUIET_DISTANCE)
        i_radius = frand(0.4f, 1.0f) * (MAX_QUIET_DISTANCE - MIN_QUIET_DISTANCE);
    else    // we are inside quiet range
        i_radius = frand(0.6f, 1.2f) * (MAX_QUIET_DISTANCE - MIN_QUIET_DISTANCE);

    return AbstractRandomMovementGenerator::_setLocation(owner);
}

void PanicMovementGenerator::Initialize(Unit& owner)
{
    owner.addUnitState(UNIT_STAT_PANIC);

    FleeingMovementGenerator::Initialize(owner);
}

void PanicMovementGenerator::Finalize(Unit& owner)
{
    owner.clearUnitState(UNIT_STAT_PANIC);

    // Since two fleeing mmgens are mutually exclusive, we are also responsible for the removal of that flag, nobody will clear this for us
    owner.RemoveFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_FLEEING);

    FleeingMovementGenerator::Finalize(owner);

    if (owner.AI())
        owner.AI()->TimedFleeingEnded();
}

void PanicMovementGenerator::Interrupt(Unit& owner)
{
    FleeingMovementGenerator::Interrupt(owner);

    if (owner.AI())
        owner.AI()->TimedFleeingEnded();
}

bool PanicMovementGenerator::Update(Unit& owner, const uint32& diff)
{
    m_fleeingTimer.Update(diff);
    if (m_fleeingTimer.Passed())
        return false;

    return FleeingMovementGenerator::Update(owner, diff);
}
