/*
 * PfProbe.h - one-line "vertical probe" for the PFDBG pathfinding logs.
 *
 * For a single world position it prints one line with, in this order:
 *   - terrainH  : raw .map surface height (TerrainInfo::GetHeightStatic with vmaps off)
 *   - vmapTop   : Map::GetHeight(x, y, MAX_HEIGHT)   = the .gps "GroundZ"
 *   - vmapUnder : Map::GetHeight(x, y, z)            = the .gps "FloorZ"
 *   - navmesh   : OK / NO_POLY / NO_NAVMESH (nearest polygon of an unfiltered query)
 *   - area      : that polygon's area decoded into a readable name
 *   - polyH     : that polygon's surface height at the nearest point
 *   - dh / dv   : horizontal / vertical distance from the queried point to it
 *   - walkable  : whether the current pathfinding filter would accept that polygon
 *
 * vmap layer fields (added for the "bridge deck is invisible" case), appended at the end:
 *   - vmapCalc  : 4 digits, VMAP manager present / heightCalc / lineOfSightCalc / mapLoading
 *   - grid      : the .gps grid pair (63 - ComputeGridPair(...)) -> what the .vmtile name uses
 *   - vmapMap   : GridMap::ExistMap  for that grid (raw .map file on disk)
 *   - vmapFile  : GridMap::ExistVMap for that grid (.vmtree + .vmtile on disk)
 *   - vmapTile  : IVMapManager::IsTileLoaded for that grid (runtime: tree exists + tile mesh loaded)
 *   - vmapZ2    : z + 2, the ray origin used by every vmap height query
 *   - vmapH10   : raw VMapManager2::getHeight(x, y, z2, 10)      (DEFAULT_HEIGHT_SEARCH)
 *   - vmapHL    : raw getHeight(x, y, z2,  99984)                (downward, .gps magnitude)
 *   - vmapHU    : raw getHeight(x, y, z2, -99984)                (upward search branch)
 *   - vmapHgps  : raw getHeight(x, y, MAX_HEIGHT + 2, vmapNgps)  = the real .gps GroundZ query
 *   - vmapNgps  : the maxSearchDist that GetHeightStatic derives (GridMap.cpp:846-847)
 *   - vmapNoFront: same downward ray with frontFacesOnly = false (WorldModel floor-candidate
 *                  filter bypassed) via VMapManager2::getObjectHitPos; NONE if no hit / LOS off
 * All of them read only: no loader call, no model acquire, no state is mutated.
 *
 * PURPOSE: tell apart "there is no navmesh polygon here" from "there IS a polygon
 * but the pathfinding filter refuses it" (NAV_AREA_GROUND_STEEP is excluded from
 * includeFlags unless the source is a walking playerbot, see PathFinder::createFilter),
 * and for the vmap side "no tile / not loaded" from "wrong search distance" from
 * "hit but discarded by a later layer".
 *
 * DIAGNOSTIC ONLY. It never sets the filter, never writes a polygon area and never
 * touches movement state. All queries are the ones PathFinder already uses:
 *   MMapManager::GetNavMeshQuery (MoveMap.h:111) -> dtNavMeshQuery::findNearestPoly
 *   -> dtNavMesh::getPolyArea / dtNavMesh::getPolyFlags / dtNavMeshQuery::getPolyHeight
 * (same pattern as PathFinder::getArea / PathFinder::getFlags, PathFinder.cpp:293 and :323)
 *
 * Gating: PfProbeAt(Unit const*, ...) keeps the PFDBG aura 10909 gate, so it can be
 * dropped next to any PFDBG_MSG call site without spamming the log. The Map / manual
 * overloads are NOT gated - they exist for the manually invoked .gps command.
 */
#ifndef CMANGOS_MOTIONGENERATORS_PFPROBE_H
#define CMANGOS_MOTIONGENERATORS_PFPROBE_H

#include "Common.h"
#include "MotionGenerators/PfDebug.h"
#include "MotionGenerators/MoveMap.h"
#include "MotionGenerators/MoveMapSharedDefines.h"
#include "Maps/Map.h"
#include "Maps/GridMap.h"
#include "vmap/VMapFactory.h"
#include "Entities/Unit.h"

namespace PfProbe
{
    // MoveMapSharedDefines.h NavArea -> readable name.
    inline char const* AreaName(unsigned char area)
    {
        switch (area)
        {
            case NAV_AREA_EMPTY:        return "EMPTY";
            case NAV_AREA_GROUND:       return "GROUND";
            case NAV_AREA_GROUND_STEEP: return "GROUND_STEEP";
            case NAV_AREA_WATER:        return "WATER";
            case NAV_AREA_MAGMA_SLIME:  return "MAGMA_SLIME";
            default:                    return "UNKNOWN";
        }
    }

    // Mirror of PathFinder::createFilter() (PathFinder.cpp:1289-1345), hand-kept in
    // sync. Diagnostic only: used to answer "would the pathfinder accept this poly".
    inline void FilterFlags(Unit const* unit, uint16& includeFlags, uint16& excludeFlags)
    {
        includeFlags = 0;
        excludeFlags = 0;

        if (unit && unit->GetTypeId() == TYPEID_UNIT)
        {
#ifdef ENABLE_PLAYERBOTS
            if (unit->CanWalk())
                includeFlags |= (NAV_GROUND | NAV_GROUND_STEEP);          // PathFinder.cpp:1317
#else
            if (unit->CanWalk())
                includeFlags |= NAV_GROUND;                               // PathFinder.cpp:1328
#endif
            if (unit->CanSwim())
                includeFlags |= (NAV_WATER | NAV_MAGMA_SLIME);            // PathFinder.cpp:1332
            return;
        }

        // no unit, or a player source: PathFinder.cpp:1334-1338
#ifdef ENABLE_PLAYERBOTS
        includeFlags |= (NAV_GROUND | NAV_WATER | NAV_GROUND_STEEP);      // PathFinder.cpp:1309
        excludeFlags |= NAV_MAGMA_SLIME;
#else
        includeFlags |= (NAV_GROUND | NAV_WATER);
#endif
    }

    // INVALID_HEIGHT (-100000) means "no surface found here".
    inline char const* HeightText(float h, char* buf, size_t bufSize)
    {
        if (h <= INVALID_HEIGHT)
            snprintf(buf, bufSize, "NONE");
        else
            snprintf(buf, bufSize, "%.4f", h);
        return buf;
    }

    // Same guid / same tag / same spot (0.5 yd grid) inside 5s is printed once only.
    // thread_local: map updates may run on several threads, no shared state needed.
    inline bool ShouldEmit(uint64 guid, uint32 mapId, float x, float y, float z, char const* tag)
    {
        struct Entry
        {
            uint64 guid;
            uint32 mapId;
            uint32 tagHash;
            int64  when;
            int32  gx;
            int32  gy;
            int32  gz;
            bool   used;
        };

        static thread_local Entry  entries[32];
        static thread_local uint32 nextSlot = 0;

        uint32 tagHash = 2166136261u;
        for (char const* c = tag; c && *c; ++c)
            tagHash = (tagHash ^ uint32((unsigned char)*c)) * 16777619u;

        int32 const gx = int32(std::floor(x * 2.0f));
        int32 const gy = int32(std::floor(y * 2.0f));
        int32 const gz = int32(std::floor(z * 2.0f));

        int64 const now = int64(std::chrono::duration_cast<std::chrono::milliseconds>(
                                    std::chrono::steady_clock::now().time_since_epoch()).count());

        Entry* slot = nullptr;
        for (uint32 i = 0; i < 32; ++i)
        {
            Entry& e = entries[i];
            if (!e.used || e.guid != guid || e.mapId != mapId || e.tagHash != tagHash)
                continue;
            if (e.gx != gx || e.gy != gy || e.gz != gz)
                continue;
            if (now - e.when < 5000)
                return false;                                         // already reported
            slot = &e;                                                // stale: reuse
            break;
        }

        if (!slot)
        {
            slot = &entries[nextSlot++ % 32];
            slot->used = true;
        }

        slot->guid    = guid;
        slot->mapId   = mapId;
        slot->tagHash = tagHash;
        slot->gx      = gx;
        slot->gy      = gy;
        slot->gz      = gz;
        slot->when    = now;
        return true;
    }

    // Core emit. `unit` only selects the filter that is mirrored for walkable=
    // (may be null: then the player filter is mirrored). `dedup` suppresses the
    // same guid / tag / spot within 5s and is on for the automatic PFDBG sites
    // only - the manual .gps command always prints its line.
    // Returns true when a line was actually written.
    inline bool Emit(Map const* map, uint32 instanceId, Unit const* unit, uint64 guid,
                     float x, float y, float z, char const* tag, bool dedup)
    {
        if (!map)
            return false;

        if (dedup && !ShouldEmit(guid, map->GetId(), x, y, z, tag))
            return false;

        uint16 includeFlags = 0;
        uint16 excludeFlags = 0;
        FilterFlags(unit, includeFlags, excludeFlags);

        TerrainInfo const* terrain = map->GetTerrain();
        float const terrainH  = terrain ? terrain->GetHeightStatic(x, y, z, false) : INVALID_HEIGHT;
        float const vmapTop   = map->GetHeight(x, y, MAX_HEIGHT);
        float const vmapUnder = map->GetHeight(x, y, z);

        char const* navState = "NO_NAVMESH";
        char const* areaName = "N/A";
        char const* walkable = "N/A";
        char polyHTextBuf[16];
        char const* polyHText = "N/A";
        uint32 areaId    = 0;
        uint32 polyFlags = 0;
        float  dh = 0.0f;
        float  dv = 0.0f;

        MMAP::MMapManager* mmap = MMAP::MMapFactory::createOrGetMMapManager();
        dtNavMesh const* navMesh = nullptr;
        dtNavMeshQuery const* query = nullptr;
        if (mmap && mmap->IsEnabled())
        {
            navMesh = mmap->GetNavMesh(map->GetId());
            query   = mmap->GetNavMeshQuery(map->GetId(), instanceId);
        }

        if (navMesh && query)
        {
            // unfiltered query on purpose: we want the polygon itself, not the one
            // the pathfinder filter happens to allow.
            dtQueryFilter noFilter;                                   // include 0xffff / exclude 0
            float const point[3]   = { y, z, x };                     // Detour order is (y, z, x)
            float const extents[3] = { 5.0f, 5.0f, 5.0f };            // same bound as PathFinder.cpp:308
            float closest[3]       = { y, z, x };
            dtPolyRef polyRef      = 0;                               // INVALID_POLYREF
            dtStatus const status  = query->findNearestPoly(point, extents, &noFilter, &polyRef, closest);

            if (dtStatusFailed(status) || polyRef == 0)
            {
                navState = "NO_POLY";
            }
            else
            {
                unsigned char  area  = NAV_AREA_EMPTY;
                unsigned short flags = 0;
                navMesh->getPolyArea(polyRef, &area);
                navMesh->getPolyFlags(polyRef, &flags);

                areaId    = area;
                polyFlags = flags;
                areaName  = AreaName(area);

                float polyH = closest[1];
                query->getPolyHeight(polyRef, closest, &polyH);       // falls back to closest[1]
                polyHText = HeightText(polyH, polyHTextBuf, sizeof(polyHTextBuf));

                float const dx = closest[0] - y;
                float const dz = closest[2] - x;
                dh = std::sqrt(dx * dx + dz * dz);
                dv = closest[1] - z;

                navState = "OK";
                walkable = ((flags & includeFlags) != 0 && (flags & excludeFlags) == 0) ? "YES" : "NO";
            }
        }

        // ------------------------------------------------------------------
        // vmap layer diagnostics.
        // Added for the "bridge deck is invisible" case: a column query at the
        // Wetlands bridge returned the terrain (16.39) while the navmesh poly was
        // at 23.94, i.e. the vmap height query missed a deck that IS in the data.
        // These fields separate the three candidate causes:
        //   (1) tile/file not available or not loaded  -> vmapMap / vmapFile / vmapTile
        //   (2) search distance or ray origin          -> vmapZ2 / vmapH10 / vmapHL /
        //                                                 vmapHU / vmapHgps / vmapNgps
        //   (3) hit but dropped by a later layer       -> vmapNoFront (frontFacesOnly
        //                                                 bypass, see below)
        // Read-only: no loader call, no model acquire, nothing is mutated.
        // ------------------------------------------------------------------
        VMAP::IVMapManager* vmgr = VMAP::VMapFactory::createOrGetVMapManager();

        int const vmapMgrDigit  = vmgr ? 1 : 0;
        int const vmapHDigit    = (vmgr && vmgr->isHeightCalcEnabled()) ? 1 : 0;
        int const vmapLosDigit  = (vmgr && vmgr->isLineOfSightCalcEnabled()) ? 1 : 0;
        int const vmapLoadDigit = (vmgr && vmgr->isMapLoadingEnabled()) ? 1 : 0;

        // Grid coords derived exactly like the .gps command (Level1.cpp:322-328):
        // gx = 63 - ComputeGridPair(x,y).x_coord, which is also the (x, y) pair
        // IsTileLoaded() / LoadMapAndVMap() use internally, and the pair that the
        // .vmtile file name carries (StaticMapTree::getTileFileName writes Y then X).
        GridPair const gridPair = MaNGOS::ComputeGridPair(x, y);
        int32 const gx = int32(63) - int32(gridPair.x_coord);
        int32 const gy = int32(63) - int32(gridPair.y_coord);
        bool const gridOk = (gx >= 0 && gx < int32(MAX_NUMBER_OF_GRIDS) && gy >= 0 && gy < int32(MAX_NUMBER_OF_GRIDS));

        char const* vmapMap  = "OOR";
        char const* vmapFile = "OOR";
        char const* vmapTile = "NO";
        if (gridOk)
        {
            vmapMap  = GridMap::ExistMap(map->GetId(), gx, gy)  ? "YES" : "NO";
            vmapFile = GridMap::ExistVMap(map->GetId(), gx, gy) ? "YES" : "NO";
            if (vmgr)
                vmapTile = vmgr->IsTileLoaded(map->GetId(), uint32(gx), uint32(gy)) ? "YES" : "NO";
        }

        float const z2 = z + 2.0f;                      // same offset GetHeightStatic() uses

        // raw, unfiltered VMapManager2::getHeight() calls (no .map fallback, no
        // GetHeightStatic layer selection): they return VMAP_INVALID_HEIGHT_VALUE
        // (-200000, printed as NONE) when the tree is missing or nothing was hit.
        float vh10  = INVALID_HEIGHT_VALUE;             // N = DEFAULT_HEIGHT_SEARCH
        float vhL   = INVALID_HEIGHT_VALUE;             // N = 99984 (the .gps GroundZ magnitude)
        float vhU   = INVALID_HEIGHT_VALUE;             // N = -99984 (the upward-search branch)
        float vhGps = INVALID_HEIGHT_VALUE;
        float nGps  = 10.0f;                            // DEFAULT_HEIGHT_SEARCH

        if (vmgr && vmapHDigit)
        {
            vh10 = vmgr->getHeight(map->GetId(), x, y, z2, 10.0f);
            vhL  = vmgr->getHeight(map->GetId(), x, y, z2, 99984.0f);
            vhU  = vmgr->getHeight(map->GetId(), x, y, z2, -99984.0f);

            // reproduce the actual .gps GroundZ query: GetHeightStatic(x, y, MAX_HEIGHT)
            // => z2 = MAX_HEIGHT + 2 and maxSearchDist = z2 - mapHeight + 1 (GridMap.cpp:846-847)
            float const zGps = MAX_HEIGHT + 2.0f;
            if (terrainH > INVALID_HEIGHT && (zGps - terrainH) > nGps)
                nGps = zGps - terrainH + 1.0f;
            vhGps = vmgr->getHeight(map->GetId(), x, y, zGps, nGps);
        }

        // frontFacesOnly bypass. VMapManager2::getObjectHitPos() ->
        // StaticMapTree::getObjectHitPos() -> getIntersectionTime(ray, dist) with the
        // DEFAULT arguments, i.e. frontFacesOnly = false, ignoreM2Model = false and
        // stopAtFirstHit = false. That is the only publicly reachable way to repeat the
        // downward column ray without the WorldModel |n.z| >= 0.5 "floor candidate"
        // filter (WorldModel.cpp:395-401); StaticMapTree::getIntersectionTime itself is
        // private. Gated on isLineOfSightCalcEnabled() by that function.
        float vmapNoFront = INVALID_HEIGHT_VALUE;
        if (vmgr && vmapLosDigit)
        {
            float hx = x;
            float hy = y;
            float hz = z2 - 99984.0f;
            if (vmgr->getObjectHitPos(map->GetId(), x, y, z2, x, y, z2 - 99984.0f, hx, hy, hz, 0.0f))
                vmapNoFront = hz;
        }

        char terrainHText[16];
        char vmapTopText[16];
        char vmapUnderText[16];
        char vh10Text[16];
        char vhLText[16];
        char vhUText[16];
        char vhGpsText[16];
        char vhNoFrontText[16];

        sLog.outError("[PFDBG] VPROBE tag=%s map=%u inst=%u pos=(%.4f,%.4f,%.4f) terrainH=%s vmapTop=%s vmapUnder=%s navmesh=%s area=%s areaId=%u flag=0x%04X polyH=%s dh=%.4f dv=%.4f walkable=%s inc=0x%04X exc=0x%04X"
                      " vmapCalc=%d%d%d%d grid=(%d,%d) vmapMap=%s vmapFile=%s vmapTile=%s vmapZ2=%.4f vmapH10=%s vmapHL=%s vmapHU=%s vmapHgps=%s vmapNgps=%.2f vmapNoFront=%s",
                      tag ? tag : "-", map->GetId(), instanceId, x, y, z,
                      HeightText(terrainH, terrainHText, sizeof(terrainHText)),
                      HeightText(vmapTop, vmapTopText, sizeof(vmapTopText)),
                      HeightText(vmapUnder, vmapUnderText, sizeof(vmapUnderText)),
                      navState, areaName, areaId, polyFlags, polyHText, dh, dv,
                      walkable, uint32(includeFlags), uint32(excludeFlags),
                      vmapMgrDigit, vmapHDigit, vmapLosDigit, vmapLoadDigit, int(gx), int(gy),
                      vmapMap, vmapFile, vmapTile, z2,
                      HeightText(vh10, vh10Text, sizeof(vh10Text)),
                      HeightText(vhL, vhLText, sizeof(vhLText)),
                      HeightText(vhU, vhUText, sizeof(vhUText)),
                      HeightText(vhGps, vhGpsText, sizeof(vhGpsText)),
                      nGps,
                      HeightText(vmapNoFront, vhNoFrontText, sizeof(vhNoFrontText)));
        return true;
    }

    // Unit based probe: keeps the PFDBG gate (aura 10909). Use this next to a
    // PFDBG_MSG call site.
    inline void PfProbeAt(Unit const* unit, float x, float y, float z, char const* tag)
    {
        if (!IsPfDbg(unit))
            return;

        Emit(unit->GetMap(), unit->GetInstanceId(), unit, uint64(unit->GetObjectGuid()), x, y, z, tag, true);
    }

    // Position based probe, NOT gated - only for a manual GM command.
    inline void PfProbeAt(Map const* map, float x, float y, float z, char const* tag)
    {
        Emit(map, map ? map->GetInstanceId() : 0, nullptr, 0, x, y, z, tag, false);
    }

    // Manual probe for a target object (.gps): mirrors the object's own filter when
    // it is a unit, otherwise the player filter. NOT gated.
    inline void PfProbeManual(WorldObject const* obj, float x, float y, float z, char const* tag)
    {
        if (!obj)
            return;

        Unit const* unit = (obj->GetTypeId() == TYPEID_UNIT || obj->GetTypeId() == TYPEID_PLAYER)
                           ? static_cast<Unit const*>(obj) : nullptr;

        Emit(obj->GetMap(), obj->GetInstanceId(), unit, uint64(obj->GetObjectGuid()), x, y, z, tag, false);
    }
}

#endif // CMANGOS_MOTIONGENERATORS_PFPROBE_H
