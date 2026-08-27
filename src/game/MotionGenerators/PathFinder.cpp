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

#include "MotionGenerators/MoveMap.h"
#include "Maps/GridMap.h"
#include "Entities/Creature.h"
#include "MotionGenerators/PathFinder.h"
#include "MotionGenerators/PfDebug.h"
#include "Log/Log.h"
#include "World/World.h"
#include "Entities/Transports.h"
#include <Detour/Include/DetourCommon.h>
#include <Detour/Include/DetourMath.h>

#ifdef BUILD_METRICS
 #include "Metric/Metric.h"
#endif

#include <limits>
////////////////// PathFinder //////////////////
PathFinder::PathFinder(const Unit* owner, bool ignoreNormalization) :
    m_type(PATHFIND_BLANK), m_useStraightPath(false), m_forceDestination(false), m_straightLine(false),
    m_pointPathLimit(MAX_POINT_PATH_LENGTH), // TODO: Fix legitimate long paths
    m_cachedPoints(m_pointPathLimit * VERTEX_SIZE), m_pathPolyRefs(m_pointPathLimit), m_polyLength(0),
    m_smoothPathPolyRefs(m_pointPathLimit), m_sourceUnit(owner), m_navMesh(nullptr), m_navMeshQuery(nullptr),
    m_defaultMapId(m_sourceUnit->GetMapId()), m_ignoreNormalization(ignoreNormalization)
#ifdef ENABLE_PLAYERBOTS
    , m_defaultInstanceId(m_sourceUnit->GetInstanceId())
#endif
{
    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::PathInfo for %u \n", m_sourceUnit->GetGUIDLow());

    if (MMAP::MMapFactory::IsPathfindingEnabled(m_sourceUnit->GetMapId(), m_sourceUnit))
    {
        MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();
        m_defaultNavMeshQuery = mmap->GetNavMeshQuery(m_sourceUnit->GetMapId(), m_sourceUnit->GetInstanceId());
    }

    createFilter();
}

#ifdef ENABLE_PLAYERBOTS
PathFinder::PathFinder() :
    m_polyLength(0), m_type(PATHFIND_BLANK),
    m_useStraightPath(false), m_forceDestination(false), m_straightLine(false), m_pointPathLimit(MAX_POINT_PATH_LENGTH), // TODO: Fix legitimate long paths
    m_sourceUnit(nullptr), m_navMesh(nullptr), m_navMeshQuery(nullptr), m_cachedPoints(m_pointPathLimit* VERTEX_SIZE), m_pathPolyRefs(m_pointPathLimit), m_smoothPathPolyRefs(m_pointPathLimit), m_defaultMapId(0), m_defaultInstanceId(0)
{

}

PathFinder::PathFinder(uint32 mapId, uint32 instanceId) :
    m_polyLength(0), m_type(PATHFIND_BLANK),
    m_useStraightPath(false), m_forceDestination(false), m_straightLine(false), m_pointPathLimit(MAX_POINT_PATH_LENGTH), // TODO: Fix legitimate long paths
    m_sourceUnit(nullptr), m_navMesh(nullptr), m_navMeshQuery(nullptr), m_cachedPoints(m_pointPathLimit* VERTEX_SIZE), m_pathPolyRefs(m_pointPathLimit), m_smoothPathPolyRefs(m_pointPathLimit), m_defaultMapId(mapId), m_defaultInstanceId(instanceId)
{
    MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();
    m_defaultNavMeshQuery = mmap->GetNavMeshQuery(mapId, instanceId);
    createFilter();
}
#endif

PathFinder::~PathFinder()
{
    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::~PathInfo() for %u \n", m_sourceUnit->GetGUIDLow());
}

void PathFinder::SetCurrentNavMesh()
{
    if (m_sourceUnit && MMAP::MMapFactory::IsPathfindingEnabled(m_sourceUnit->GetMapId(), m_sourceUnit))
    {
        MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();
        if (GenericTransport* transport = m_sourceUnit->GetTransport())
            m_navMeshQuery = mmap->GetModelNavMeshQuery(transport->GetDisplayId());
        else
        {
            if (m_defaultMapId != m_sourceUnit->GetMapId())
                m_defaultNavMeshQuery = mmap->GetNavMeshQuery(m_sourceUnit->GetMapId(), m_sourceUnit->GetInstanceId());

            m_navMeshQuery = m_defaultNavMeshQuery;
        }

        if (m_navMeshQuery)
            m_navMesh = m_navMeshQuery->getAttachedNavMesh();

    }
#ifdef ENABLE_PLAYERBOTS
    else if (!m_sourceUnit && MMAP::MMapFactory::IsPathfindingEnabled(m_defaultMapId, nullptr))
    {
        MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();
        m_navMeshQuery = m_defaultNavMeshQuery;

        if (m_navMeshQuery)
            m_navMesh = m_navMeshQuery->getAttachedNavMesh();
    }
#endif
}

bool PathFinder::calculate(float destX, float destY, float destZ, bool forceDest/* = false*/, bool straightLine/* = false*/)
{
    float x, y, z;
    m_sourceUnit->GetPosition(x, y, z, m_sourceUnit->GetTransport());
    Vector3 dest(destX, destY, destZ);
    if (GenericTransport* transport = m_sourceUnit->GetTransport())
        transport->CalculatePassengerOffset(dest.x, dest.y, dest.z);
    return calculate(Vector3(x, y, z), dest, forceDest, straightLine);
}

bool PathFinder::calculate(Vector3 const& start, Vector3 const& dest, bool forceDest/* = false*/, bool straightLine/* = false*/)
{
    if (!MaNGOS::IsValidMapCoord(dest.x, dest.y, dest.z))
        return false;

    if (!MaNGOS::IsValidMapCoord(start.x, start.y, start.z))
        return false;

#ifndef ENABLE_PLAYERBOTS
    if (!m_sourceUnit)
        return false;
#endif

#ifdef BUILD_METRICS
    metric::duration<std::chrono::microseconds> meas("pathfinder.calculate", {
        { "entry", std::to_string(m_sourceUnit->GetEntry()) },
        { "guid", std::to_string(m_sourceUnit->GetGUIDLow()) },
        { "unit_type", std::to_string(m_sourceUnit->GetGUIDHigh()) },
        { "map_id", std::to_string(m_sourceUnit->GetMapId()) },
        { "instance_id", std::to_string(m_sourceUnit->GetInstanceId()) }
    }, 1000);
#endif

    //if (GenericTransport* transport = m_sourceUnit->GetTransport())
    //    transport->CalculatePassengerOffset(dest.x, dest.y, dest.z, nullptr);

    // [PFDBG] calculate 入口：本次寻路请求的起终点与模式（%.8f 供离线复现精确输入）
    PFDBG_MSG(m_sourceUnit, "calculate map=%u start(%.8f,%.8f,%.8f) end(%.8f,%.8f,%.8f) forceDest=%d straightLine=%d",
              m_defaultMapId, start.x, start.y, start.z, dest.x, dest.y, dest.z, forceDest ? 1 : 0, straightLine ? 1 : 0);
    // [PFDBG] 当前怪物坐标的 GPS：groundZ(MAX_HEIGHT 查地面=ADT) vs floorZ(怪z查面=WMO/ADT)
    //   怪 z≈floorZ>groundZ → 在 WMO 上; 怪 z≈floorZ≈groundZ → 在 ADT 上
    if (IsPfDbg(m_sourceUnit))
    {
        float const gz = m_sourceUnit->GetMap()->GetHeight(start.x, start.y, MAX_HEIGHT);
        float const fz = m_sourceUnit->GetMap()->GetHeight(start.x, start.y, start.z);
        sLog.outError("[PFDBG] GPS map=%u x=%.8f y=%.8f z=%.8f groundZ=%.8f floorZ=%.8f",
                      m_defaultMapId, start.x, start.y, start.z, gz, fz);
    }

    setStartPosition(start);

    setEndPosition(dest);

    m_forceDestination = forceDest;
    m_straightLine = straightLine;

    SetCurrentNavMesh();

#ifdef ENABLE_PLAYERBOTS
    if(m_sourceUnit)
#endif
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::calculate() for %u \n", m_sourceUnit->GetGUIDLow());

    // make sure navMesh works - we can run on map w/o mmap
    // check if the start and end point have a .mmtile loaded (can we pass via not loaded tile on the way?)
#ifdef ENABLE_PLAYERBOTS
    if (!m_navMesh || !m_navMeshQuery || (m_sourceUnit && m_sourceUnit->hasUnitState(UNIT_STAT_IGNORE_PATHFINDING)) ||
#else
    if (!m_navMesh || !m_navMeshQuery || m_sourceUnit->hasUnitState(UNIT_STAT_IGNORE_PATHFINDING) ||
#endif    
        !HaveTile(start) || !HaveTile(dest))
    {
        // No navigation tile at start or destination: fall back to a straight
        // shortcut for everyone (upstream behaviour). Marking ground units
        // NOPATH here froze them in ungenerated tiles (stuck evading).
        PFDBG_MSG(m_sourceUnit, "NO tile: navMesh=%d query=%d ignorePF=%d haveStartTile=%d haveEndTile=%d -> BuildShortcut NORMAL|NOT_USING",
                  m_navMesh ? 1 : 0, m_navMeshQuery ? 1 : 0,
                  m_sourceUnit ? (m_sourceUnit->hasUnitState(UNIT_STAT_IGNORE_PATHFINDING) ? 1 : 0) : 0,
                  HaveTile(start) ? 1 : 0, HaveTile(dest) ? 1 : 0);
        BuildShortcut();
        m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
        return true;
    }

    updateFilter();

    BuildPolyPath(start, dest);

    // [PFDBG] 最终路径点（带 aura 10909 过滤）：type + 全部平滑点
    if (IsPfDbg(m_sourceUnit))
    {
        PathType const pt = getPathType();
        auto const& pp = getPath();
        sLog.outError("[PFDBG] FINAL map=%u start(%.8f,%.8f,%.8f) end(%.8f,%.8f,%.8f) type=%d npts=%zu",
                      m_defaultMapId, start.x, start.y, start.z,
                      dest.x, dest.y, dest.z,
                      (int)pt, pp.size());
        for (size_t i = 0; i < pp.size(); ++i)
            sLog.outError("[PFDBG] FINAL pt%zu map=%u (%.8f,%.8f,%.8f)", i, m_defaultMapId, pp[i].x, pp[i].y, pp[i].z);
        // 目标点 GPS：判断玩家/目标在 WMO 上还是 ADT 上
        {
            float const egz = m_sourceUnit->GetMap()->GetHeight(dest.x, dest.y, MAX_HEIGHT);
            float const efz = m_sourceUnit->GetMap()->GetHeight(dest.x, dest.y, dest.z);
            sLog.outError("[PFDBG] FINAL endGPS map=%u x=%.8f y=%.8f z=%.8f groundZ=%.8f floorZ=%.8f",
                          m_defaultMapId, dest.x, dest.y, dest.z, egz, efz);
        }
    }

    return true;
}

#ifdef ENABLE_PLAYERBOTS
void PathFinder::setArea(uint32 mapId, float x, float y, float z, uint32 area, float range)
{
    if (!MaNGOS::IsValidMapCoord(x, y, z))
        return;

    MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();

    dtNavMeshQuery const* query = mmap->GetNavMeshQuery(mapId, m_defaultInstanceId);
    dtNavMesh const* cnavMesh = mmap->GetNavMesh(mapId);
    dtNavMesh* navMesh = const_cast<dtNavMesh*> (cnavMesh);
    dtQueryFilter m_filter;

    uint16 includeFlags = 0;
    uint16 excludeFlags = 0;


    includeFlags |= (NAV_GROUND | NAV_WATER);
    excludeFlags |= (NAV_MAGMA_SLIME | NAV_GROUND_STEEP);


    m_filter.setIncludeFlags(includeFlags);
    m_filter.setExcludeFlags(excludeFlags);

    dtPolyRef polyRef = INVALID_POLYREF;


    float point[VERTEX_SIZE] = { y, z, x };
    float extents[VERTEX_SIZE] = { 5.0f, 5.0f, 5.0f };    // bounds of poly search area
    float closestPoint[VERTEX_SIZE] = { 0.0f, 0.0f, 0.0f };
    //unsigned int dtResult = INVALID_POLYREF;
    //m_navMeshQuery->getNodePool();

    dtStatus dtResult = query->findNearestPoly(point, extents, &m_filter, &polyRef, closestPoint);
    static const int MAX_POLYS = 2560;
    dtPolyRef m_polys[MAX_POLYS];
    dtPolyRef m_parent[MAX_POLYS];
    int m_npolys;

    if (dtResult == DT_FAILURE || polyRef == INVALID_POLYREF)
        return;

    query->findPolysAroundCircle(polyRef, closestPoint, range, &m_filter, m_polys, m_parent, 0, &m_npolys, MAX_POLYS);

    if (dtResult == DT_FAILURE || polyRef == INVALID_POLYREF)
        return;

    for (int i = 0; i < m_npolys; i++)
    {
        unsigned char curArea;
        dtStatus status = navMesh->getPolyArea(m_polys[i], &curArea);

        if (curArea != 8 && curArea < area)
            dtStatus status = navMesh->setPolyArea(m_polys[i], area);
    }
}

uint32 PathFinder::getArea(uint32 mapId, float x, float y, float z)
{
    if (!MaNGOS::IsValidMapCoord(x, y, z))
        return 99;

    MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();

    dtNavMeshQuery const* query = mmap->GetNavMeshQuery(mapId, m_defaultInstanceId);
    dtNavMesh const* cnavMesh = mmap->GetNavMesh(mapId);
    dtNavMesh* navMesh = const_cast<dtNavMesh*> (cnavMesh);
    dtQueryFilter m_filter;
    dtPolyRef polyRef = INVALID_POLYREF;


    float point[VERTEX_SIZE] = { y, z, x };
    float extents[VERTEX_SIZE] = { 5.0f, 5.0f, 5.0f };    // bounds of poly search area
    float closestPoint[VERTEX_SIZE] = { 0.0f, 0.0f, 0.0f };

    dtStatus dtResult = query->findNearestPoly(point, extents, &m_filter, &polyRef, closestPoint);

    if (dtResult == DT_FAILURE || polyRef == INVALID_POLYREF)
        return 99;

    unsigned char area;

    dtStatus status = navMesh->getPolyArea(polyRef, &area);

    return area;
}

unsigned short PathFinder::getFlags(uint32 mapId, float x, float y, float z)
{
    if (!MaNGOS::IsValidMapCoord(x, y, z))
        return 0;

    MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();

    dtNavMeshQuery const* query = mmap->GetNavMeshQuery(mapId, 0);
    dtNavMesh const* cnavMesh = mmap->GetNavMesh(mapId);
    dtNavMesh* navMesh = const_cast<dtNavMesh*> (cnavMesh);
    dtQueryFilter m_filter;
    dtPolyRef polyRef = INVALID_POLYREF;


    float point[VERTEX_SIZE] = { y, z, x };
    float extents[VERTEX_SIZE] = { 5.0f, 5.0f, 5.0f };    // bounds of poly search area
    float closestPoint[VERTEX_SIZE] = { 0.0f, 0.0f, 0.0f };

    dtStatus dtResult = query->findNearestPoly(point, extents, &m_filter, &polyRef, closestPoint);

    if (dtResult == DT_FAILURE || polyRef == INVALID_POLYREF)
        return 0;

    unsigned short flags;

    dtStatus status = navMesh->getPolyFlags(polyRef, &flags);

    return flags;
}


void PathFinder::setAreaCost(uint32 area, float cost)
{
    m_filter.setAreaCost(area, cost);
}
#endif

dtPolyRef PathFinder::getPathPolyByPosition(const dtPolyRef* polyPath, uint32 polyPathSize, const float* point, float* distance, const float maxDist) const
{
    if (!polyPath || !polyPathSize)
        return INVALID_POLYREF;

    dtPolyRef nearestPoly = INVALID_POLYREF;
    float minDist3d = std::numeric_limits<float>::max();

    for (uint32 i = 0; i < polyPathSize; ++i)
    {
        float closestPoint[VERTEX_SIZE];
        if (dtStatusFailed(m_navMeshQuery->closestPointOnPoly(polyPath[i], point, closestPoint, nullptr)))
            continue;

        float d = dtVdistSqr(point, closestPoint);
        if (d < minDist3d)
        {
            minDist3d = d;
            nearestPoly = polyPath[i];
        }

        if (minDist3d < 1.0f) // shortcut out - close enough for us
            break;
    }

    if (distance)
        *distance = dtMathSqrtf(minDist3d);

    return (minDist3d <= maxDist) ? nearestPoly : INVALID_POLYREF;
}

dtPolyRef PathFinder::getPolyByLocation(const float* point, float* distance)
{
    // first we check the current path
    // if the current path doesn't contain the current poly,
    // we need to use the expensive navMesh.findNearestPoly
    dtPolyRef polyRef = getPathPolyByPosition(m_pathPolyRefs.data(), m_polyLength, point, distance);
    if (polyRef != INVALID_POLYREF)
        return polyRef;

    //We have more stored points. Search those too
    if (m_pathPolyRefs.size() > std::max(m_polyLength, m_pointPathLimit)) 
    {
        dtPolyRef polyRef = getPathPolyByPosition(&m_pathPolyRefs[m_pointPathLimit], m_pathPolyRefs.size() - m_pointPathLimit, point, distance, 7.0f);
        if (polyRef != INVALID_POLYREF)
            return polyRef;
    }

    // we don't have it in our old path
    // try to get it by findNearestPoly()
    // first try with NearPolySearchBound
    float closestPoint[VERTEX_SIZE] = {0.0f, 0.0f, 0.0f};
    dtStatus dtResult = m_navMeshQuery->findNearestPoly(point, NearPolySearchBound, &m_filter, &polyRef, closestPoint);
    if (dtStatusSucceed(dtResult) && polyRef != INVALID_POLYREF)
    {
        float newDistance = dtVdist(closestPoint, point);
        if (!*distance || newDistance < *distance) //Only store found point if it's actually closer than the one found from the path.
            m_pathPolyRefs.push_back(polyRef);
        *distance = newDistance;
        return polyRef;
    }

    // still nothing ..
    // try with bigger search box
    // From dtNavMeshQuery::findNearestPoly: "If the search extents overlaps more than
    // 128 polygons it may return an invalid result".We just use FarPolySearchBound.

    dtResult = m_navMeshQuery->findNearestPoly(point, FarPolySearchBound, &m_filter, &polyRef, closestPoint);
    if (dtStatusSucceed(dtResult) && polyRef != INVALID_POLYREF)
    {
        float newDistance = dtVdist(closestPoint, point);
        if (!*distance || newDistance < *distance) //Only store found point if it's actually closer than the one found from the path.
            m_pathPolyRefs.push_back(polyRef);
        *distance = newDistance;
        return polyRef;
    }

    return INVALID_POLYREF;
}

void PathFinder::BuildPolyPath(const Vector3& startPos, const Vector3& endPos)
{
#ifndef ENABLE_PLAYERBOTS
    if (!m_sourceUnit)
        return;
#endif

    // *** getting start/end poly logic ***
#ifndef ENABLE_PLAYERBOTS
    if (m_sourceUnit->GetMap()->IsDungeon())
#else
    if ((m_sourceUnit && m_sourceUnit->GetMap()->IsDungeon()) || (sMapStore.LookupEntry(m_defaultMapId) && sMapStore.LookupEntry(m_defaultMapId)->IsDungeon()))
#endif
    {
        float distance = sqrt((endPos.x - startPos.x) * (endPos.x - startPos.x) + (endPos.y - startPos.y) * (endPos.y - startPos.y) + (endPos.z - startPos.z) * (endPos.z - startPos.z));
        if (distance > 300.f)
            m_pointPathLimit = MAX_POINT_PATH_LENGTH * 4;
        else if (distance > 200.f)
            m_pointPathLimit = MAX_POINT_PATH_LENGTH * 3;
        else if (distance > 100.f)
            m_pointPathLimit = MAX_POINT_PATH_LENGTH * 2;
        if (m_pointPathLimit > m_pathPolyRefs.size())
            m_pathPolyRefs.resize(m_pointPathLimit);
    }
    float distToStartPoly, distToEndPoly;
    float startPoint[VERTEX_SIZE] = {startPos.y, startPos.z, startPos.x};
    float endPoint[VERTEX_SIZE] = {endPos.y, endPos.z, endPos.x};

    dtPolyRef startPoly = getPolyByLocation(startPoint, &distToStartPoly);
    dtPolyRef endPoly = getPolyByLocation(endPoint, &distToEndPoly);

    // [PFDBG] start/end poly 查找结果（带 aura 10909 过滤）
    PFDBG_MSG(m_sourceUnit, "BuildPolyPath startPoly=%u endPoly=%u distS=%.8f distE=%.8f unitZ=%.8f",
              (uint32)startPoly, (uint32)endPoly, distToStartPoly, distToEndPoly,
              m_sourceUnit ? m_sourceUnit->GetPositionZ() : 0.f);
    if (IsPfDbg(m_sourceUnit) && startPoly != INVALID_POLYREF && endPoly != INVALID_POLYREF)
    {
        float spz = -9999.0f, epz = -9999.0f, scp[3], ecp[3];
        if (dtStatusSucceed(m_navMeshQuery->closestPointOnPoly(startPoly, startPoint, scp, nullptr)))
            spz = scp[1];
        if (dtStatusSucceed(m_navMeshQuery->closestPointOnPoly(endPoly, endPoint, ecp, nullptr)))
            epz = ecp[1];
        sLog.outError("[PFDBG] BuildPolyPath startPolyZ=%.8f endPolyZ=%.8f (两 poly 表面高度)", spz, epz);
    }

    dtStatus dtResult;

    // we have a hole in our mesh
    // make shortcut path and mark it as NOPATH ( with flying exception )
    // its up to caller how he will use this info
    if (startPoly == INVALID_POLYREF || endPoly == INVALID_POLYREF)
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: (startPoly == 0 || endPoly == 0)\n");
        PFDBG_MSG(m_sourceUnit, "BuildPolyPath INVALID_POLY start=%d end=%d -> BuildShortcut 分支",
                  startPoly == INVALID_POLYREF ? 1 : 0, endPoly == INVALID_POLYREF ? 1 : 0);
        BuildShortcut();

#ifdef ENABLE_PLAYERBOTS
        if (m_sourceUnit)
        {
#endif
            // Check for swimming or flying shortcut
            // Swimmers take the shortcut only when BOTH the start AND the end
            // are in swimmable water: a straight underwater line must not be
            // used to chase a target that is in the air/on shore (that lifts
            // the swimmer out of the water into the sky). Land creatures that
            // merely CAN swim (InhabitType includes WATER, e.g. Mo'arg/Gan'arg)
            // chasing a flying target fall through to the ground branch
            // (NOPATH -> evade), matching upstream.
            if (m_sourceUnit && m_sourceUnit->CanSwim() &&
                m_sourceUnit->GetTerrain()->IsSwimmable(startPos.x, startPos.y, startPos.z) &&
                m_sourceUnit->GetTerrain()->IsSwimmable(endPos.x, endPos.y, endPos.z))
            {
                // Straight shortcut must be LOS-clear: a near-horizontal line that
                // clips through floors (Magisters' Terrace 24560: start z -31 in a
                // shallow lower hall, target z -2 on the floor above -> line cuts
                // straight through solid ground) must not be used. NOPATH if the
                // straight segment is blocked by geometry.
                float const h = m_sourceUnit->GetCollisionHeight();
                if (m_sourceUnit->GetMap()->IsInLineOfSight(startPos.x, startPos.y, startPos.z + h,
                                                            endPos.x, endPos.y, endPos.z + h, true))
                    m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
                else
                    m_type = PATHFIND_NOPATH;
            }
            // Sinkhole between two water points: only shortcut when BOTH ends
            // are in swimmable water (a missing poly in deep water). A single
            // in-water end with a land/air start would lift the creature up.
            else if (m_sourceUnit->GetTerrain()->IsSwimmable(startPos.x, startPos.y, startPos.z) &&
                     m_sourceUnit->GetTerrain()->IsSwimmable(endPos.x, endPos.y, endPos.z))
                m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
            else
            {
                if (m_sourceUnit->GetTypeId() != TYPEID_PLAYER)
                    m_type = m_sourceUnit->CanFly() ? PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH) : PATHFIND_NOPATH;
                else

                    m_type = PATHFIND_NOPATH;
            }
#ifdef ENABLE_PLAYERBOTS
        }
#endif


        return;
    }

    // we may need a better number here
    bool farFromPoly = (distToStartPoly > 7.0f || distToEndPoly > 7.0f);
    if (farFromPoly)
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: farFromPoly distToStartPoly=%.3f distToEndPoly=%.3f\n", distToStartPoly, distToEndPoly);

        bool buildShortcut = false;
#ifdef ENABLE_PLAYERBOTS
        if (m_sourceUnit)
        {
#endif
            Vector3 p = (distToStartPoly > 7.0f) ? startPos : endPos;
            if (m_sourceUnit->GetTerrain()->IsUnderWater(p.x, p.y, p.z))
            {
                DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: underWater case\n");
                if (m_sourceUnit->CanSwim())
                    buildShortcut = true;
            }
            else
            {
                DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: flying case\n");
                if (m_sourceUnit->CanFly())
                    buildShortcut = true;
            }
#ifdef ENABLE_PLAYERBOTS
        }
#endif

#ifdef ENABLE_PLAYERBOTS
        if (m_sourceUnit && m_sourceUnit->IsPlayer() && IsPointHigherThan(getActualEndPosition(), getStartPosition()))
        {
            sLog.outDebug("%s (%u) Path Shortcut skipped: endPoint is higher", m_sourceUnit->GetName(), m_sourceUnit->GetGUIDLow());
            buildShortcut = false;
        }
#endif

        if (buildShortcut)
        {
            PFDBG_MSG(m_sourceUnit, "farFromPoly buildShortcut (underWater/CanFly) -> NORMAL|NOT_USING");
            BuildShortcut();
            m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
            return;
        }
        float closestPoint[VERTEX_SIZE];
        // we may want to use closestPointOnPolyBoundary instead
        if (dtStatusSucceed(m_navMeshQuery->closestPointOnPoly(endPoly, endPoint, closestPoint, nullptr)))
        {
            dtVcopy(endPoint, closestPoint);
            setActualEndPosition(Vector3(endPoint[2], endPoint[0], endPoint[1]));
        }

        // Land units whose destination is far from the navmesh surface
        // (farFromPoly: target >7 yd away, e.g. the player on a floor level NOT
        // connected to the creature's floor - Magisters' Terrace 24560 chasing
        // a player on the 2nd floor): do NOT snap the end to a wrong layer's
        // poly (deep pit / upper floor), which made the creature clip straight
        // through the floor. Instead:
        //  - if the straight line to the target is LOS-clear, keep chasing
        //    directly (no floor clipping possible through clear air);
        //  - if the line is blocked by geometry (floor/wall between the
        //    levels), NOPATH - the creature stops instead of clipping through.
        // Flyers/swimmers keep the INCOMPLETE behaviour.
        if (m_sourceUnit && !m_sourceUnit->CanFly() && !m_sourceUnit->IsInWater())
        {
            float const h = m_sourceUnit->GetCollisionHeight();
            bool const los = m_sourceUnit->GetMap()->IsInLineOfSight(startPos.x, startPos.y, startPos.z + h,
                                                                    endPos.x, endPos.y, endPos.z + h, true);
            PFDBG_MSG(m_sourceUnit, "farFromPoly 陆地: LOS(竖直+%d,即到目标直线)=%d -> %s",
                      (int)h, los ? 1 : 0, los ? "NORMAL|NOT_USING(直线追)" : "NOPATH");
            if (los)
                m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
            else
                m_type = PATHFIND_NOPATH;
        }
        else
            m_type = PATHFIND_INCOMPLETE;
    }

    // *** poly path generating logic ***

    // Root fix: the path must always end on the walkable navmesh surface.
    // A destination below the surface (e.g. on a steep model face like a cave
    // mushroom) would pull units into unwalkable geometry, and a destination
    // above the surface (e.g. a player jumping into a cave hole) would make
    // units rise vertically through the air. Snap the end both ways. Units in
    // water are excluded: the snap would drag an underwater destination onto
    // the navmesh surface (into the seabed / below the water level).
    if (m_sourceUnit && !m_sourceUnit->CanFly() && !m_sourceUnit->IsInWater())
    {
        float closestPoint[VERTEX_SIZE];
        if (dtStatusSucceed(m_navMeshQuery->closestPointOnPoly(endPoly, endPoint, closestPoint, nullptr)))
        {
            dtVcopy(endPoint, closestPoint);
            setActualEndPosition(Vector3(endPoint[2], endPoint[0], endPoint[1]));
        }
    }

    // start and end are on same polygon
    // just need to move in straight line
    if (startPoly == endPoly)
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: (startPoly == endPoly)\n");

        // Underwater units keep the raw straight shortcut: the land-oriented
        // surface-snap validation would reject or drag a swim path onto the
        // navmesh surface (into the seabed) when the points lie far from the
        // polygon surface.
        if (m_sourceUnit && m_sourceUnit->IsInWater())
        {
            BuildShortcut();
            m_type = farFromPoly ? PATHFIND_INCOMPLETE : PATHFIND_NORMAL;
            return;
        }

        // Flying units legitimately hover above the polygon surface (3-7 yd),
        // so the surface-snap distance check below would wrongly NOPATH them
        // when both endpoints share one poly. Skip the snap for flyers, but
        // still require a clear line of sight so the straight shortcut cannot
        // clip through floors/walls.
        if (m_sourceUnit && m_sourceUnit->CanFly())
        {
            float const h = m_sourceUnit->GetCollisionHeight();
            if (!m_sourceUnit->GetMap()->IsInLineOfSight(startPos.x, startPos.y, startPos.z + h,
                                                         endPos.x, endPos.y, endPos.z + h, true))
            {
                BuildShortcut();
                m_type = PATHFIND_NOPATH;
                return;
            }
            BuildShortcut();
            m_type = farFromPoly ? PATHFIND_INCOMPLETE : PATHFIND_NORMAL;
            return;
        }

        // A straight shortcut between two points of the same polygon is only
        // valid when both points actually lie on the polygon's surface; a
        // point far above/below the surface (multi-level polygons bridging
        // floors / cave rims) would make units walk straight through the air.
        float startClosest[VERTEX_SIZE];
        float endClosest[VERTEX_SIZE];
        // Both points must actually lie on the polygon's surface. closestPointOnPoly
        // returns the nearest point on the poly for any query (even one 15 yd away),
        // so a success alone is not enough - the distance must be small.
        if (dtStatusFailed(m_navMeshQuery->closestPointOnPoly(startPoly, startPoint, startClosest, nullptr)) ||
            dtStatusFailed(m_navMeshQuery->closestPointOnPoly(endPoly, endPoint, endClosest, nullptr)) ||
            dtVdist(startPoint, startClosest) > 1.5f ||
            dtVdist(endPoint, endClosest) > 1.5f)
        {
            // keep a valid 2-point path so callers that launch the spline
            // without checking NOPATH (e.g. HomeMovement) do not get an empty path
            BuildShortcut();
            m_type = PATHFIND_NOPATH;
            return;
        }
        // snap the end onto the polygon surface so the shortcut stays on the plane
        dtVcopy(endPoint, endClosest);
        setActualEndPosition(Vector3(endPoint[2], endPoint[0], endPoint[1]));

        BuildShortcut(); // todo move in straight line is different than build shortcut!

        m_pathPolyRefs[0] = startPoly;
        m_polyLength = 1;

        m_type = farFromPoly ? PATHFIND_INCOMPLETE : PATHFIND_NORMAL;
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: path type %d\n", m_type);
        return;
    }

    // look for startPoly/endPoly in current path
    // TODO: we can merge it with getPathPolyByPosition() loop
    bool startPolyFound = false;
    bool endPolyFound = false;
    uint32 pathStartIndex = 0;
    uint32 pathEndIndex = 0;

    if (m_polyLength)
    {
        for (pathStartIndex = 0; pathStartIndex < m_polyLength; ++pathStartIndex)
        {
            // here to catch few bugs
            if (m_pathPolyRefs[pathStartIndex] == INVALID_POLYREF)
            {
#ifdef ENABLE_PLAYERBOTS
                if (m_sourceUnit)
#endif
                    sLog.outError("Invalid poly ref in BuildPolyPath. polyLength: %u, pathStartIndex: %u,"
                        " startPos: %s, endPos: %s, mapId: %u",
                        m_polyLength, pathStartIndex, startPos.toString().c_str(), endPos.toString().c_str(),
                        m_sourceUnit->GetMapId());
                break;
            }

            if (m_pathPolyRefs[pathStartIndex] == startPoly)
            {
                startPolyFound = true;
                break;
            }
        }

        for (pathEndIndex = m_polyLength - 1; pathEndIndex > pathStartIndex; --pathEndIndex)
        {
            if (m_pathPolyRefs[pathEndIndex] == endPoly)
            {
                endPolyFound = true;
                break;
            }
        }
    }

    if (startPolyFound && endPolyFound)
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: (startPolyFound && endPolyFound)\n");

        // we moved along the path and the target did not move out of our old poly-path
        // our path is a simple subpath case, we have all the data we need
        // just "cut" it out

        m_polyLength = pathEndIndex - pathStartIndex + 1;
        memmove(m_pathPolyRefs.data(), m_pathPolyRefs.data() + pathStartIndex, m_polyLength * sizeof(dtPolyRef));
    }
    //else if (startPolyFound && !endPolyFound)
    //{
    //    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: (startPolyFound && !endPolyFound)\n");

    //    // we are moving on the old path but target moved out
    //    // so we have atleast part of poly-path ready

    //    m_polyLength -= pathStartIndex;

    //    // try to adjust the suffix of the path instead of recalculating entire length
    //    // at given interval the target cannot get too far from its last location
    //    // thus we have less poly to cover
    //    // sub-path of optimal path is optimal

    //    // take ~80% of the original length
    //    // TODO : play with the values here
    //    uint32 prefixPolyLength = uint32(m_polyLength * 0.8f + 0.5f);
    //    memmove(m_pathPolyRefs.data(), m_pathPolyRefs.data() + pathStartIndex, prefixPolyLength * sizeof(dtPolyRef));

    //    dtPolyRef suffixStartPoly = m_pathPolyRefs[prefixPolyLength - 1];

    //    // we need any point on our suffix start poly to generate poly-path, so we need last poly in prefix data
    //    float suffixEndPoint[VERTEX_SIZE];
    //    if (dtStatusFailed(m_navMeshQuery->closestPointOnPoly(suffixStartPoly, endPoint, suffixEndPoint, nullptr)))
    //    {
    //        // we can hit offmesh connection as last poly - closestPointOnPoly() don't like that
    //        // try to recover by using prev polyref
    //        --prefixPolyLength;
    //        suffixStartPoly = m_pathPolyRefs[prefixPolyLength - 1];
    //        if (dtStatusFailed(m_navMeshQuery->closestPointOnPoly(suffixStartPoly, endPoint, suffixEndPoint, nullptr)))
    //        {
    //            // suffixStartPoly is still invalid, error state
    //            BuildShortcut();
    //            m_type = PATHFIND_NOPATH;
    //            return;
    //        }
    //    }

    //    // generate suffix
    //    uint32 suffixPolyLength = 0;

    //    if (!m_straightLine)
    //    {
    //        dtResult = m_navMeshQuery->findPath(
    //                                suffixStartPoly,    // start polygon
    //                                endPoly,            // end polygon
    //                                suffixEndPoint,     // start position
    //                                endPoint,           // end position
    //                                &m_filter,            // polygon search filter
    //                                m_pathPolyRefs.data() + prefixPolyLength - 1,    // [out] path
    //                                (int*)&suffixPolyLength,
    //                                m_pointPathLimit - prefixPolyLength);   // max number of polygons in output path
    //    }
    //    else
    //    {
    //        float hit = 0.0f;
    //        float hitNormal[3] = {0.0f, 0.0f, 0.0f};

    //        dtResult = m_navMeshQuery->raycast(
    //                        suffixStartPoly,
    //                        suffixEndPoint,
    //                        endPoint,
    //                        &m_filter,
    //                        &hit,
    //                        hitNormal,
    //                        m_pathPolyRefs.data() + prefixPolyLength - 1,
    //                        (int*)&suffixPolyLength,
    //                        m_pointPathLimit - prefixPolyLength);

    //        // raycast() sets hit to FLT_MAX if there is a ray between start and end
    //        if (hit != FLT_MAX)
    //        {
    //            // the ray hit something, return no path instead of the incomplete one
    //            m_type = PATHFIND_NOPATH;
    //            return;
    //        }
    //    }

    //    if (!suffixPolyLength || dtStatusFailed(dtResult))
    //    {
    //        // this is probably an error state, but we'll leave it
    //        // and hopefully recover on the next Update
    //        // we still need to copy our preffix
    //        sLog.outError("%u's Path Build failed: 0 length path", m_sourceUnit->GetGUIDLow());
    //    }

    //    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++  m_polyLength=%u prefixPolyLength=%u suffixPolyLength=%u \n", m_polyLength, prefixPolyLength, suffixPolyLength);

    //    // new path = prefix + suffix - overlap
    //    m_polyLength = prefixPolyLength + suffixPolyLength - 1;
    //}
    else
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ BuildPolyPath :: (!startPolyFound && !endPolyFound)\n");

        // either we have no path at all -> first run
        // or something went really wrong -> we aren't moving along the path to the target
        // just generate new path

        // free and invalidate old path data
        clear();

        if (!m_straightLine)
        {
            dtResult = m_navMeshQuery->findPath(
                    startPoly,          // start polygon
                    endPoly,            // end polygon
                    startPoint,         // start position
                    endPoint,           // end position
                    &m_filter,          // polygon search filter
                    m_pathPolyRefs.data(), // [out] path
                    (int*)&m_polyLength,
#ifdef ENABLE_PLAYERBOTS
                    m_pointPathLimit / 2);
#else
                    m_pointPathLimit);  // max number of polygons in output path
#endif
        }
        else
        {
            float hit = 0.0f;
            float hitNormal[3] = {0.0f, 0.0f, 0.0f};

            dtResult = m_navMeshQuery->raycast(
                            startPoly,
                            startPoint,
                            endPoint,
                            &m_filter,
                            &hit,
                            hitNormal,
                            m_pathPolyRefs.data(),
                            (int*)&m_polyLength,
#ifdef ENABLE_PLAYERBOTS
                            m_pointPathLimit / 2);
#else
                            m_pointPathLimit);
#endif

            // raycast() sets hit to FLT_MAX if there is a ray between start and end
            if (hit != FLT_MAX)
            {
                // the ray hit something, adjust the end before compute path if need
                float hitPos[3];
                float distanceToPoly;

#ifdef ENABLE_PLAYERBOTS
                if (m_sourceUnit)
                {
#endif
                    hit = hit - m_sourceUnit->GetCollisionWidth();
                    if (hit < 0.1f)
                    {
                        m_type = PATHFIND_NOPATH;
                        return;
                    }
#ifdef ENABLE_PLAYERBOTS
                }
#endif

                dtVlerp(hitPos, startPoint, endPoint, hit);
                dtPolyRef poly = getPolyByLocation(hitPos, &distanceToPoly);
                if (poly != INVALID_POLYREF)
                {
                    // first we have to fix z value before hit test, z is in index 1 of hit position
                    dtStatus dtResult = m_navMeshQuery->getPolyHeight(poly, hitPos, &hitPos[1]);
                    Vector3 hitPosVec(hitPos[2], hitPos[0], hitPos[1]);
                    if ((startPos - hitPosVec).squaredMagnitude() > 0.01)
                    {
                        setEndPosition(hitPosVec);
                        BuildPointPath(startPoint, hitPos);
                        m_type = PATHFIND_INCOMPLETE;

                        //sLog.outString("PathFinder::BuildPolyPath> HIT for %s at %s", m_sourceUnit->GetGuidStr().c_str(), hitPosVec.toString().c_str());
                        return;
                    }
                    //sLog.outString("PathFinder::BuildPolyPath> HIT with no path for %s at %s", m_sourceUnit->GetGuidStr().c_str(), hitPosVec.toString().c_str());
                    m_type = PATHFIND_NOPATH;
                    return;
                }
                else
                {
                    //Vector3 hitPosVec(hitPos[2], hitPos[0], hitPos[1]);
                    //sLog.outString("PathFinder::BuildPolyPath> FAILED HIT for %s at %s", m_sourceUnit->GetGuidStr().c_str(), hitPosVec.toString().c_str());
                    m_type = PATHFIND_NOPATH;
                    return;
                }
            }
        }

        // [PFDBG] findPath/raycast 返回的 poly 路径：每个 poly 的表面 z（判断是否含 endPoly 二楼、z 是否跳变）
        if (IsPfDbg(m_sourceUnit))
        {
            std::string polyLog;
            char buf[96];
            for (uint32 pi = 0; pi < m_polyLength; ++pi)
            {
                dtPolyRef const ref = m_pathPolyRefs[pi];
                float cp[3], hz = 0.0f;
                if (dtStatusSucceed(m_navMeshQuery->closestPointOnPoly(ref, startPoint, cp, nullptr)))
                    hz = cp[1];
                snprintf(buf, sizeof(buf), " #%u(z=%.8f)", (uint32)ref, hz);
                polyLog += buf;
            }
            sLog.outError("[PFDBG] findPath dtResult=0x%08X polyLength=%u type=%d polyPath:%s",
                          (uint32)dtResult, m_polyLength, (int)m_type, polyLog.c_str());
        }

        if (!m_polyLength || dtStatusFailed(dtResult))
        {
            // only happens if we passed bad data to findPath(), or navmesh is messed up
            PFDBG_MSG(m_sourceUnit, "findPath FAILED: polyLength=%u dtResult=0x%08X -> BuildShortcut NOPATH", m_polyLength, (uint32)dtResult);
#ifdef ENABLE_PLAYERBOTS
            if (m_sourceUnit)
#endif
                sLog.outError("%u's Path Build failed: 0 length path", m_sourceUnit->GetGUIDLow());

#ifdef ENABLE_PLAYERBOTS
            if (m_sourceUnit && m_sourceUnit->IsPlayer() && IsPointHigherThan(getActualEndPosition(), getStartPosition()))
            {
                sLog.outDebug("%s (%u) Path Shortcut skipped: endPoint is higher", m_sourceUnit->GetName(), m_sourceUnit->GetGUIDLow());
                return;
            }
#endif

            BuildShortcut();
            m_type = PATHFIND_NOPATH;
            return;
        }
    }

    // by now we know what type of path we can get
    if (m_pathPolyRefs[m_polyLength - 1] == endPoly && !(m_type & PATHFIND_INCOMPLETE))
        m_type = PATHFIND_NORMAL;
    else
        m_type = PATHFIND_INCOMPLETE;

    // generate the point-path out of our up-to-date poly-path
    BuildPointPath(startPoint, endPoint);

}

void PathFinder::BuildPointPath(const float* startPoint, const float* endPoint)
{
    if (m_pointPathLimit * VERTEX_SIZE > m_cachedPoints.size())
        m_cachedPoints.resize(m_pointPathLimit * VERTEX_SIZE);
    uint32 pointCount = 0;
    dtStatus dtResult = DT_FAILURE;

    if (m_straightLine)
    {
        Vector3 startVec = Vector3(startPoint[2], startPoint[0], startPoint[1]);
        Vector3 endVec = Vector3(endPoint[2], endPoint[0], endPoint[1]);
        Vector3 pathDir = (endVec - startVec);
        float pathLength = pathDir.magnitude();

        // not sure about the exact limit value below but it should be ok
        if (pathLength > 0.1f)
        {
            float stepCountFloat = pathLength / SMOOTH_PATH_STEP_SIZE;
            uint32 stepCount = static_cast<uint32>(stepCountFloat);
            float stepPart = stepCountFloat - stepCount;

            // merge last point with previous point if it is 30% less than SMOOTH_PATH_STEP_SIZE
            if (stepCount > 1.0f && stepPart < 0.3f)
                --stepCount;

            Vector3 prevVec = startVec;
            Vector3 diffVec = pathDir * (SMOOTH_PATH_STEP_SIZE / pathLength);

            // little optimization
            m_pathPoints.clear();
            m_pathPoints.reserve(stepCount + 2);

            // first point
            m_pathPoints.push_back(startVec);

            float distanceToPoly;
            for (uint32 step = 0; step < stepCount; ++step)
            {
                prevVec += diffVec; // move toward the end pos

                // fix height using detail data (be aware that format is [y, z, x] for detour query)
                float convertedPoint[3] = {prevVec.y, prevVec.z, prevVec.x};
                dtPolyRef poly = getPolyByLocation(convertedPoint, &distanceToPoly);
                if (poly != INVALID_POLYREF)
                    m_navMeshQuery->getPolyHeight(poly, convertedPoint, &prevVec.z);

                m_pathPoints.push_back(prevVec);
            }

            // last point
            m_pathPoints.push_back(endVec);
            pointCount = static_cast<uint32>(m_pathPoints.size());

            dtResult = DT_SUCCESS;
        }
    }
    else
    {
        float* pathPoints = m_cachedPoints.data();

        if (m_useStraightPath)
        {
            dtResult = m_navMeshQuery->findStraightPath(
                startPoint,         // start position
                endPoint,           // end position
                m_pathPolyRefs.data(), // current path
                m_polyLength,       // lenth of current path
                pathPoints,         // [out] path corner points
                nullptr,               // [out] flags
                nullptr,               // [out] shortened path
                (int*)&pointCount,
                m_pointPathLimit);   // maximum number of points/polygons to use
        }
        else
        {
            dtResult = findSmoothPath(
                startPoint,         // start position
                endPoint,           // end position
                m_pathPolyRefs.data(), // current path
                m_polyLength,       // length of current path
                pathPoints,         // [out] path corner points
                (int*)&pointCount,
                m_pointPathLimit);    // maximum number of points
        }

        if (pointCount > 2 && sWorld.getConfig(CONFIG_BOOL_PATH_FIND_OPTIMIZE))
        {
            uint32 tempPointCounter = 2;

            PointsArray tempPathPoints;
            tempPathPoints.resize(pointCount);

            for (uint32 i = 0; i < pointCount; ++i)      // y, z, x  expected here
            {
                uint32 pointPos = i * VERTEX_SIZE;
                tempPathPoints[i] = Vector3(pathPoints[pointPos + 2], pathPoints[pointPos], pathPoints[pointPos + 1]);
            }

            // Optimize points
            Vector3 emptyVec = { 0.0f, 0.0f, 0.0f };

            uint8 cutLimit = 0;
            for (uint32 i = 1; i < pointCount - 1; ++i)
            {
                G3D::Vector3 p = tempPathPoints[i];     // Point
                G3D::Vector3 p1 = tempPathPoints[i - 1]; // PrevPoint
                G3D::Vector3 p2 = tempPathPoints[i + 1]; // NextPoint

                float lineLen = (p1.y - p2.y) * p.x + (p2.x - p1.x) * p.y + (p1.x * p2.y - p2.x * p1.y);

                if (fabs(lineLen) < LINE_FAULT && cutLimit < SKIP_POINT_LIMIT)
                {
                    tempPathPoints[i] = emptyVec;
                    cutLimit++;
                }
                else
                {
                    tempPointCounter++;
                    cutLimit = 0;
                }
            }

            m_pathPoints.resize(tempPointCounter);

            uint32 pointPos = 0;
            for (uint32 i = 0; i < pointCount; ++i)
            {
                if (tempPathPoints[i] != emptyVec)
                {
                    m_pathPoints[pointPos] = tempPathPoints[i];
                    pointPos++;
                }
            }

            pointCount = tempPointCounter;
        }
        else
        {
            m_pathPoints.resize(pointCount);
            for (uint32 i = 0; i < pointCount; ++i)
            {
                uint32 pointPos = i * VERTEX_SIZE;
                m_pathPoints[i] = { pathPoints[pointPos + 2], pathPoints[pointPos], pathPoints[pointPos + 1] };
            }
        }
    }

    if (pointCount < 2 || dtStatusFailed(dtResult))
    {
        // only happens if pass bad data to findStraightPath or navmesh is broken
        // single point paths can be generated here
        // TODO : check the exact cases
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::BuildPointPath FAILED! path sized %d returned\n", pointCount);
        BuildShortcut();
        m_type = PATHFIND_NOPATH;
        return;
    }

    if (pointCount == m_pointPathLimit)
    {
        DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "BuildPointPath FAILED! path sized %d returned, lower than limit set to %d\n", pointCount, m_pointPathLimit);
        BuildShortcut();
        m_type = PATHFIND_SHORT;
        return;
    }

    // first point is always our current location - we need the next one
    setActualEndPosition(m_pathPoints[pointCount - 1]);

    // force the given destination, if needed
    if (m_forceDestination && ((m_type & PATHFIND_NORMAL) == 0 || getEndPosition() != getActualEndPosition()))
    {
        // we may want to keep partial subpath
        if (dist3DSqr(getActualEndPosition(), getEndPosition()) < 0.3f * dist3DSqr(getStartPosition(), getEndPosition()))
        {
            setActualEndPosition(getEndPosition());
            m_pathPoints[m_pathPoints.size() - 1] = getEndPosition();
        }
        else if (m_sourceUnit && (m_sourceUnit->CanFly() || m_sourceUnit->CanSwim() ||
                                 m_sourceUnit->IsLevitating() || m_sourceUnit->IsHovering() ||
                                 m_sourceUnit->IsInWater()))
        {
            setActualEndPosition(getEndPosition());
            BuildShortcut();
            m_type = PathType(PATHFIND_NORMAL | PATHFIND_NOT_USING_PATH);
        }
        else
            m_type = PATHFIND_NOPATH;
    }

    NormalizePath();

    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::BuildPointPath path type %d size %d poly-size %d\n", m_type, pointCount, m_polyLength);
}

void PathFinder::NormalizePath()
{
    if (!sWorld.getConfig(CONFIG_BOOL_PATH_FIND_NORMALIZE_Z) || m_ignoreNormalization || !m_sourceUnit)
        return;

    GenericTransport* transport = m_sourceUnit->GetTransport();

    for (auto& m_pathPoint : m_pathPoints)
    {
        if (transport)
            transport->CalculatePassengerPosition(m_pathPoint.x, m_pathPoint.y, m_pathPoint.z);
        m_sourceUnit->UpdateAllowedPositionZ(m_pathPoint.x, m_pathPoint.y, m_pathPoint.z);
        if (transport)
            transport->CalculatePassengerOffset(m_pathPoint.x, m_pathPoint.y, m_pathPoint.z);
    }
}

void PathFinder::BuildShortcut()
{
    DEBUG_FILTER_LOG(LOG_FILTER_PATHFINDING, "++ PathFinder::BuildShortcut :: making shortcut\n");

    clear();

    // make two point path, our curr pos is the start, and dest is the end
    m_pathPoints.resize(2);

    // set start and a default next position
    m_pathPoints[0] = getStartPosition();
    m_pathPoints[1] = getActualEndPosition();

    // No navmesh to follow here, so walk straight to the destination
    // (upstream behaviour); the caller decides what to do with the shortcut.
    NormalizePath();

    m_type = PATHFIND_SHORTCUT;
}

#ifdef ENABLE_PLAYERBOTS
bool PathFinder::IsPointHigherThan(const Vector3& posOne, const Vector3& posTwo)
{
    return posOne.z > posTwo.z;
}
#endif

void PathFinder::createFilter()
{
    uint16 includeFlags = 0;
    uint16 excludeFlags = 0;

#ifdef ENABLE_PLAYERBOTS
    if (!m_sourceUnit || m_sourceUnit->GetTypeId() == TYPEID_PLAYER)
    {
        // perfect support not possible, just stay 'safe'
        if (!m_sourceUnit || ((Player*)m_sourceUnit)->GetPlayerbotAI()) //Blank or bot-navigation
        {
            includeFlags |= (NAV_GROUND | NAV_WATER);
            excludeFlags |= (NAV_MAGMA_SLIME | NAV_GROUND_STEEP);

            m_filter.setAreaCost(9, 20.0f);  //Water
            m_filter.setAreaCost(12, 5.0f);  //Mob proximity
            m_filter.setAreaCost(13, 20.0f); //Mob aggro
        }
        else
        {
            includeFlags |= (NAV_GROUND | NAV_WATER | NAV_GROUND_STEEP);
            excludeFlags |= (NAV_MAGMA_SLIME);
        }
    }
    else if (m_sourceUnit->GetTypeId() == TYPEID_UNIT)
    {
        Creature* creature = (Creature*)m_sourceUnit;
        if (creature->CanWalk())
            includeFlags |= (NAV_GROUND | NAV_GROUND_STEEP);          // walk

        // creatures don't take environmental damage
        if (creature->CanSwim())
            includeFlags |= (NAV_WATER | NAV_MAGMA_SLIME);           // swim
    }
#else
    if (m_sourceUnit->GetTypeId() == TYPEID_UNIT)
    {
        Creature* creature = (Creature*)m_sourceUnit;
        if (creature->CanWalk())
            includeFlags |= NAV_GROUND;          // walk

        // creatures don't take environmental damage
        if (creature->CanSwim())
            includeFlags |= (NAV_WATER | NAV_MAGMA_SLIME);           // swim
    }
    else if (m_sourceUnit->GetTypeId() == TYPEID_PLAYER)
    {
        // perfect support not possible, just stay 'safe'
        includeFlags |= (NAV_GROUND | NAV_WATER);
    }
#endif

    m_filter.setIncludeFlags(includeFlags);
    m_filter.setExcludeFlags(excludeFlags);

    updateFilter();
}

void PathFinder::updateFilter()
{
    // allow creatures to cheat and use different movement types if they are moved
    // forcefully into terrain they can't normally move in
    if (m_sourceUnit && (m_sourceUnit->IsInWater() || m_sourceUnit->IsUnderwater()))
    {
        uint16 includedFlags = m_filter.getIncludeFlags();
        includedFlags |= getNavTerrain(m_sourceUnit->GetPositionX(),
                                       m_sourceUnit->GetPositionY(),
                                       m_sourceUnit->GetPositionZ());

        m_filter.setIncludeFlags(includedFlags);
    }
}

NavTerrainFlag PathFinder::getNavTerrain(float x, float y, float z) const
{
    GridMapLiquidData data;
    if (m_sourceUnit && m_sourceUnit->GetTerrain()->getLiquidStatus(x, y, z, MAP_ALL_LIQUIDS, &data) == LIQUID_MAP_NO_WATER)
        return NAV_GROUND;

    switch (data.type_flags)
    {
        case MAP_LIQUID_TYPE_WATER:
        case MAP_LIQUID_TYPE_OCEAN:
            return NAV_WATER;
        case MAP_LIQUID_TYPE_MAGMA:
        case MAP_LIQUID_TYPE_SLIME:
            return NAV_MAGMA_SLIME;
        default:
            return NAV_GROUND;
    }
}

bool PathFinder::HaveTile(const Vector3& p) const
{
    if (m_sourceUnit && m_sourceUnit->GetTransport())
        return true;

    int tx = -1, ty = -1;
    float point[VERTEX_SIZE] = {p.y, p.z, p.x};

    m_navMesh->calcTileLoc(point, &tx, &ty);

    /// Workaround
    /// For some reason, often the tx and ty variables wont get a valid value
    /// Use this check to prevent getting negative tile coords and crashing on getTileAt
    if (tx == -1 || ty == -1)
        return false;

    return (m_navMesh->getTileAt(tx, ty, 0) != nullptr); // Don't use layer so always set to 0
}

uint32 PathFinder::fixupCorridor(dtPolyRef* path, uint32 npath, uint32 maxPath, dtPolyRef const* visited, uint32 nvisited)
{
    int32 furthestPath = -1;
    int32 furthestVisited = -1;

    // Find furthest common polygon.
    for (int32 i = npath - 1; i >= 0; --i)
    {
        bool found = false;
        for (int32 j = nvisited - 1; j >= 0; --j)
        {
            if (path[i] == visited[j])
            {
                furthestPath = i;
                furthestVisited = j;
                found = true;
            }
        }
        if (found)
            break;
    }

    // If no intersection found just return current path.
    if (furthestPath == -1 || furthestVisited == -1)
        return npath;

    // Concatenate paths.

    // Adjust beginning of the buffer to include the visited.
    uint32 req = nvisited - furthestVisited;
    uint32 orig = uint32(furthestPath + 1) < npath ? furthestPath + 1 : npath;
    uint32 size = npath > orig ? npath - orig : 0;
    if (req + size > maxPath)
        size = maxPath - req;

    if (req >= maxPath)
        return npath;

    if (size)
        memmove(path + req, path + orig, size * sizeof(dtPolyRef));

    // Store visited
    for (uint32 i = 0; i < req; ++i)
        path[i] = visited[(nvisited - 1) - i];

    return req + size;
}

bool PathFinder::getSteerTarget(const float* startPos, const float* endPos,
                                float minTargetDist, const dtPolyRef* path, uint32 pathSize,
                                float* steerPos, unsigned char& steerPosFlag, dtPolyRef& steerPosRef) const
{
    // Find steer target.
    static const uint32 MAX_STEER_POINTS = 3;
    float steerPath[MAX_STEER_POINTS * VERTEX_SIZE];
    unsigned char steerPathFlags[MAX_STEER_POINTS];
    dtPolyRef steerPathPolys[MAX_STEER_POINTS];
    uint32 nsteerPath = 0;
    dtStatus dtResult = m_navMeshQuery->findStraightPath(startPos, endPos, path, pathSize,
                        steerPath, steerPathFlags, steerPathPolys, (int*)&nsteerPath, MAX_STEER_POINTS);
    if (!nsteerPath || dtStatusFailed(dtResult))
        return false;

    // Find vertex far enough to steer to.
    uint32 ns = 0;
    while (ns < nsteerPath)
    {
        // Stop at Off-Mesh link or when point is further than slop away.
        if ((steerPathFlags[ns] & DT_STRAIGHTPATH_OFFMESH_CONNECTION) ||
                !inRangeYZX(&steerPath[ns * VERTEX_SIZE], startPos, minTargetDist, 1000.0f))
            break;
        ++ns;
    }
    // Failed to find good point to steer to.
    if (ns >= nsteerPath)
        return false;

    dtVcopy(steerPos, &steerPath[ns * VERTEX_SIZE]);
    steerPos[1] = startPos[1];  // keep Z value
    steerPosFlag = steerPathFlags[ns];
    steerPosRef = steerPathPolys[ns];

    return true;
}

dtStatus PathFinder::findSmoothPath(const float* startPos, const float* endPos,
                                    const dtPolyRef* polyPath, uint32 polyPathSize,
                                    float* smoothPath, int* smoothPathSize, uint32 maxSmoothPathSize)
{
    *smoothPathSize = 0;
    uint32 nsmoothPath = 0;

    // [PFDBG] findSmoothPath 入口（全精度，供离线复现）：detour 坐标 start=(y,z,x)
    PFDBG_MSG(m_sourceUnit, "smoothIn start(%.8f,%.8f,%.8f) end(%.8f,%.8f,%.8f) npolys=%u firstRef=%u lastRef=%u",
              startPos[0], startPos[1], startPos[2], endPos[0], endPos[1], endPos[2], polyPathSize,
              (uint32)polyPath[0], (uint32)polyPath[polyPathSize - 1]);

    if (m_pointPathLimit > m_smoothPathPolyRefs.size())
        m_smoothPathPolyRefs.resize(m_pointPathLimit);
    memcpy(m_smoothPathPolyRefs.data(), polyPath, polyPathSize * sizeof(dtPolyRef));
    uint32 npolys = polyPathSize;

    float iterPos[VERTEX_SIZE];
    if (dtStatusFailed(m_navMeshQuery->closestPointOnPolyBoundary(m_smoothPathPolyRefs[0], startPos, iterPos)))
        return DT_FAILURE;
    // closestPointOnPolyBoundary returns the query height unchanged when the
    // point is inside the poly's 2D footprint; snap it to the poly surface.
    m_navMeshQuery->getPolyHeight(m_smoothPathPolyRefs[0], iterPos, &iterPos[1]);

    float targetPos[VERTEX_SIZE];
    if (dtStatusFailed(m_navMeshQuery->closestPointOnPolyBoundary(m_smoothPathPolyRefs[npolys - 1], endPos, targetPos)))
        return DT_FAILURE;
    // same here: never steer toward a height above/below the last poly surface.
    m_navMeshQuery->getPolyHeight(m_smoothPathPolyRefs[npolys - 1], targetPos, &targetPos[1]);

    dtVcopy(&smoothPath[nsmoothPath * VERTEX_SIZE], iterPos);
    ++nsmoothPath;

    // Move towards target a small advancement at a time until target reached or
    // when ran out of memory to store the path.
    while (npolys && nsmoothPath < maxSmoothPathSize)
    {
        // Find location to steer towards.
        float steerPos[VERTEX_SIZE];
        unsigned char steerPosFlag;
        dtPolyRef steerPosRef = INVALID_POLYREF;

        if (!getSteerTarget(iterPos, targetPos, SMOOTH_PATH_SLOP, m_smoothPathPolyRefs.data(), npolys, steerPos, steerPosFlag, steerPosRef))
            break;

        const bool endOfPath = (steerPosFlag & DT_STRAIGHTPATH_END) != 0;
        const bool offMeshConnection = (steerPosFlag & DT_STRAIGHTPATH_OFFMESH_CONNECTION) != 0;

        // Find movement delta.
        float delta[VERTEX_SIZE];
        dtVsub(delta, steerPos, iterPos);
        float len = dtMathSqrtf(dtVdot(delta, delta));
        // If the steer target is end of path or off-mesh link, do not move past the location.
        if ((endOfPath || offMeshConnection) && len < SMOOTH_PATH_STEP_SIZE)
            len = 1.0f;
        else
            len = SMOOTH_PATH_STEP_SIZE / len;

        float moveTgt[VERTEX_SIZE];
        dtVmad(moveTgt, iterPos, delta, len);

        // Move
        float result[VERTEX_SIZE];
        const static uint32 MAX_VISIT_POLY = 16;
        dtPolyRef visited[MAX_VISIT_POLY];

        uint32 nvisited = 0;
        m_navMeshQuery->moveAlongSurface(m_smoothPathPolyRefs[0], iterPos, moveTgt, &m_filter, result, visited, (int*)&nvisited, MAX_VISIT_POLY);
        npolys = fixupCorridor(m_smoothPathPolyRefs.data(), npolys, m_pointPathLimit, visited, nvisited);

        m_navMeshQuery->getPolyHeight(m_smoothPathPolyRefs[0], result, &result[1]);
        result[1] += 0.5f;

        // Note: the old ZSnap (|result[1]-unitZ|>10 -> result[1]=unitZ+0.5) was removed
        // on 2026-08-24: it anchored on the unit's absolute Z, so any downhill run
        // taller than 10 yd got its remaining points pinned to a flat line
        // (unitZ+0.5) - creatures flew horizontally (58284: z 67.59 over ground 47).
        // trust getPolyHeight (navmesh poly heights are walkability authorities).

        dtVcopy(iterPos, result);

        // Handle end of path and off-mesh links when close enough.
        if (endOfPath && inRangeYZX(iterPos, steerPos, SMOOTH_PATH_SLOP, 1.0f))
        {
            // Reached end of path.
            dtVcopy(iterPos, targetPos);
            if (nsmoothPath < maxSmoothPathSize)
            {
                dtVcopy(&smoothPath[nsmoothPath * VERTEX_SIZE], iterPos);
                ++nsmoothPath;
            }
            break;
        }
        if (offMeshConnection && inRangeYZX(iterPos, steerPos, SMOOTH_PATH_SLOP, 1.0f))
        {
            // Advance the path up to and over the off-mesh connection.
            dtPolyRef prevRef = INVALID_POLYREF;
            dtPolyRef polyRef = m_smoothPathPolyRefs[0];
            uint32 npos = 0;
            while (npos < npolys && polyRef != steerPosRef)
            {
                prevRef = polyRef;
                polyRef = m_smoothPathPolyRefs[npos];
                ++npos;
            }

            for (uint32 i = npos; i < npolys; ++i)
                m_smoothPathPolyRefs[i - npos] = m_smoothPathPolyRefs[i];

            npolys -= npos;

            // Handle the connection.
            float newStartPos[VERTEX_SIZE], newEndPos[VERTEX_SIZE];
            if (dtStatusSucceed(m_navMesh->getOffMeshConnectionPolyEndPoints(prevRef, polyRef, newStartPos, newEndPos)))
            {
                if (nsmoothPath < maxSmoothPathSize)
                {
                    dtVcopy(&smoothPath[nsmoothPath * VERTEX_SIZE], startPos);
                    ++nsmoothPath;
                }
                // Move position at the other side of the off-mesh link.
                dtVcopy(iterPos, endPos);

                m_navMeshQuery->getPolyHeight(m_smoothPathPolyRefs[0], iterPos, &iterPos[1]);
                iterPos[1] += 0.5f;
            }
        }

        // Store results.
        if (nsmoothPath < maxSmoothPathSize)
        {
            dtVcopy(&smoothPath[nsmoothPath * VERTEX_SIZE], iterPos);
            ++nsmoothPath;
        }
    }

    *smoothPathSize = nsmoothPath;

    // this is most likely a loop
    return nsmoothPath < m_pointPathLimit ? DT_SUCCESS : DT_FAILURE;
}

void PathFinder::ComputePathToRandomPoint(Vector3 const& startPoint, float maxRange)
{
    clear();
    m_type = PathType(PATHFIND_NOPATH);

    // use only straight line
    m_straightLine = true;
    m_forceDestination = false;

    // update unit filter
    updateFilter();

    // be sure navmesh are set
    SetCurrentNavMesh();

    float angle = rand_norm_f() * 2 * M_PI_F;
    float range = rand_norm_f() * maxRange;

    float randomPoint[3];
    randomPoint[2] = startPoint.x + range * cos(angle);
    randomPoint[0] = startPoint.y + range * sin(angle);
    randomPoint[1] = startPoint.z;

    Vector3 currPos;
    m_sourceUnit->GetPosition(currPos.x, currPos.y, currPos.z, m_sourceUnit->GetTransport());
    Vector3 endPoint(randomPoint[2], randomPoint[0], randomPoint[1]);

    // fast check to see if point is far enough
    if ((currPos - endPoint).squaredMagnitude() < 0.01f)
    {
        m_type = PathType(PATHFIND_NOPATH);
        //sLog.outDebug("PathFinder::GetPathToRandomPoint> too small distance from point start(%s) to end(%s) for %s", currPos.toString().c_str(), endPoint.toString().c_str(), m_sourceUnit->GetGuidStr().c_str());
        return;
    }

    setStartPosition(currPos);
    setEndPosition(endPoint);

    // make sure navMesh works - we can run on map w/o mmap
    // check if the start and end point have a .mmtile loaded (can we pass via not loaded tile on the way?)
    if (!m_navMesh || !m_navMeshQuery || m_sourceUnit->hasUnitState(UNIT_STAT_IGNORE_PATHFINDING) ||
        !HaveTile(currPos) || !HaveTile(endPoint))
    {
        BuildShortcut();
        m_type = PathType(PATHFIND_NORMAL | PATHFIND_SHORTCUT);
        //sLog.outString("PathFinder::GetPathToRandomPoint> Shortcut for %s\n", m_sourceUnit->GetGuidStr().c_str());
        return;
    }

    float distanceToPoly;
    dtPolyRef centerPoly = getPolyByLocation(randomPoint, &distanceToPoly);
    bool fail = true;
    if (centerPoly != INVALID_POLYREF)
    {
        // Only deep water (real swimming) takes the swim branch. Shallow water
        // (IsInWater true but not deep enough to swim) must walk normally -
        // treating it as swimming kept the "swim depth" and the water-column
        // check re-rolled the point, so flee/roam creatures in shallow water
        // never moved. Walkers fall through to the ground branch / navmesh floor.
        if (m_sourceUnit && m_sourceUnit->CanSwim() && m_sourceUnit->IsInSwimmableWater())
        {
            // Water: keep the random point at the unit's current swimming depth.
            // Snapping z to the navmesh surface (seabed/shore) made swimmers dive
            // to the floor and bob back up on the next random roll.
            // Validate the destination water column first: if it is too shallow
            // to hold the current depth (shore slope, sandbank) or not water at
            // all, the launch clamp would pull the swimmer up to the shallow
            // bottom (looking like it surfaces) or into the shore - re-roll.
            TerrainInfo const* terrain = m_sourceUnit->GetMap()->GetTerrain();
            float destGroundZ = INVALID_HEIGHT;
            float destWaterLevel = terrain->GetWaterLevel(endPoint.x, endPoint.y, currPos.z, &destGroundZ);
            if (destWaterLevel <= INVALID_HEIGHT || destGroundZ <= INVALID_HEIGHT ||
                currPos.z < destGroundZ + 0.5f || currPos.z > destWaterLevel - 0.5f)
            {
                m_type = PathType(PATHFIND_NOPATH);
                return;
            }
            endPoint.z = currPos.z;
            setEndPosition(endPoint);

            // The straight-line swim must stay inside the water column: if the
            // terrain rises above the swimming depth anywhere along the way
            // (bank, sandbar, underwater ridge), the creature would clip into it
            // ("swimming in underground water"). Sample the terrain along the
            // line and re-roll if it breaks the surface.
            float const swimDepth = currPos.z;
            float const dX = endPoint.x - currPos.x;
            float const dY = endPoint.y - currPos.y;
            uint32 const samples = 4;
            for (uint32 s = 1; s <= samples; ++s)
            {
                float const t = float(s) / float(samples);
                float groundZ = m_sourceUnit->GetMap()->GetHeight(currPos.x + dX * t, currPos.y + dY * t, swimDepth, true);
                if (groundZ > INVALID_HEIGHT && swimDepth < groundZ + 0.5f)
                {
                    m_type = PathType(PATHFIND_NOPATH);
                    return;
                }
            }
        }
        else
        {
        // first we have to fix z value before hit test, z is in index 1 of randomPoint
        dtStatus dtResult = m_navMeshQuery->getPolyHeight(centerPoly, randomPoint, &randomPoint[1]);
        endPoint.z = randomPoint[1];
        setEndPosition(endPoint);

            // The random point must sit on its own floor: check the real ground
            // height at the destination (queried from the point z itself so cave
            // dwellers match their own floor, not the surface above). If the
            // navmesh height is not on that floor (floating above, sunk into a
            // hillside, or a wrong cave layer) the point is unreachable - block it.
            float floorZ = m_sourceUnit->GetMap()->GetHeight(endPoint.x, endPoint.y, endPoint.z, true);
            if (floorZ > INVALID_HEIGHT)
            {
                if (std::fabs(floorZ - endPoint.z) > 1.0f)
                {
                    // not standing on the floor at this point - block the roll
                    m_type = PathType(PATHFIND_NOPATH);
                    return;
                }
                // snap exactly to the floor
                endPoint.z = floorZ;
                setEndPosition(endPoint);
            }

            // Do not pick a destination blocked by a static object (tree root,
            // rock, building): the straight random walk would clip into it and
            // the creature gets stuck inside the model.
            if (!m_sourceUnit->GetMap()->IsInLineOfSight(currPos.x, currPos.y, currPos.z + m_sourceUnit->GetCollisionHeight(),
                endPoint.x, endPoint.y, endPoint.z + m_sourceUnit->GetCollisionHeight(), true))
            {
                m_type = PathType(PATHFIND_NOPATH);
                return;
            }




        if (dtResult == DT_SUCCESS)
        {
            // generate path
            BuildPolyPath(currPos, endPoint);
            fail = false;
            //sLog.outDebug("PathFinder::GetPathToRandomPoint> path type %d size %d poly-size %d\n", m_type, m_pathPoints.size(), m_polyLength);
        }
        }
    }

    bool canShortcut = false;
    if (m_sourceUnit->IsInWater())
    {
        if (m_sourceUnit->CanSwim())
            canShortcut = true;
    }
    else if (m_sourceUnit->IsAboveGround())
    {
        if (m_sourceUnit->IsLevitating() || m_sourceUnit->IsHovering())
            canShortcut = true;
    }

    // navmesh queries do not work in water - need to supplement with los check and just build a shortcut
    if (fail && canShortcut && m_sourceUnit->GetMap()->IsInLineOfSight(currPos.x, currPos.y, currPos.z + m_sourceUnit->GetCollisionHeight(), endPoint.x, endPoint.y, endPoint.z + m_sourceUnit->GetCollisionHeight(), false))
    {
        BuildShortcut();
    }
}

bool PathFinder::inRangeYZX(const float* v1, const float* v2, float r, float h) const
{
    const float dx = v2[0] - v1[0];
    const float dy = v2[1] - v1[1]; // elevation
    const float dz = v2[2] - v1[2];
    return (dx * dx + dz * dz) < r * r && fabsf(dy) < h;
}

bool PathFinder::inRange(const Vector3& p1, const Vector3& p2, float r, float h) const
{
    Vector3 d = p1 - p2;
    return (d.x * d.x + d.y * d.y) < r * r && fabsf(d.z) < h;
}

float PathFinder::dist3DSqr(const Vector3& p1, const Vector3& p2) const
{
    return (p1 - p2).squaredLength();
}
