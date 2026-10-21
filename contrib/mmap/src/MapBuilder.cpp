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

#include "MMapCommon.h"
#include "MapBuilder.h"

#include "MapTree.h"
#include "ModelInstance.h"

#include "DetourNavMeshBuilder.h"
#include "DetourCommon.h"

#include <climits>
#include <cstdlib>
#include <fstream>
#include <future>

using namespace VMAP;

// [DEBUG] 前向声明：转储函数的实现在文件后面（见 dumpOpen 那一组）。
// ⚠️ 必须放在 `namespace MMAP` **里面** —— DumpCtx 和 dumpPolyMesh 的实现都在
//    MMAP 里；放在外面会变成第二个同名重载，报"对重载函数的调用不明确"。
namespace MMAP
{
    static void dumpPolyMesh(const DumpCtx& d, const rcPolyMesh& pm);
}

void rcModAlmostUnwalkableTriangles(rcContext* ctx, const float walkableSlopeAngle,
    const float* verts, int /*nv*/,
    const int* tris, int nt,
    unsigned char* areas)
{
    rcIgnoreUnused(ctx);

    const float walkableThr = cosf(walkableSlopeAngle / 180.0f * RC_PI);

    float norm[3];

    for (int i = 0; i < nt; ++i)
    {
        if (areas[i] & RC_WALKABLE_AREA)
        {
            const int* tri = &tris[i * 3];

            float e0[3], e1[3];
            rcVsub(e0, &verts[tri[1] * 3], &verts[tri[0] * 3]);
            rcVsub(e1, &verts[tri[2] * 3], &verts[tri[0] * 3]);
            rcVcross(norm, e0, e1);
            rcVnormalize(norm);

            // Check if the face is walkable.
            if (norm[1] <= walkableThr)
                areas[i] = NAV_AREA_GROUND_STEEP; //Slopes between 50 and 60. Walkable for mobs, unwalkable for players.
        }
    }
}

void from_json(const json& j, rcConfig& config)
{
    config.tileSize = MMAP::VERTEX_PER_TILE;
    config.borderSize = j["borderSize"].get<int>();
    config.cs = MMAP::CELL_SIZE;
    config.ch = MMAP::CELL_HEIGHT;
    config.walkableSlopeAngle = j["walkableSlopeAngle"].get<float>();
    config.walkableHeight = j["walkableHeight"].get<int>();
    config.walkableClimb = j["walkableClimb"].get<int>();
    config.walkableRadius = j["walkableRadius"].get<int>();
    config.maxEdgeLen = j["maxEdgeLen"].get<int>();
    config.maxSimplificationError = j["maxSimplificationError"].get<float>();
    config.minRegionArea = rcSqr(j["minRegionArea"].get<int>());
    config.mergeRegionArea = rcSqr(j["mergeRegionArea"].get<int>());
    config.maxVertsPerPoly = DT_VERTS_PER_POLYGON;
    config.detailSampleDist = j["detailSampleDist"].get<float>();
    config.detailSampleMaxError = j["detailSampleMaxError"].get<float>();
    config.liquidFlagMergeThreshold = j["liquidFlagMergeThreshold"].get<float>();
}

namespace MMAP
{
    inline char const* GetDTErrorReason(dtStatus status) {
        if ((status & DT_WRONG_MAGIC) != 0)
            return "Reason: 'Input data is not recognized'";
        if ((status & DT_WRONG_VERSION) != 0)
            return "Reason: 'Input data is in wrong version'";
        if ((status & DT_OUT_OF_MEMORY) != 0)
            return "Reason: 'Operation ran out of memory'";
        if ((status & DT_INVALID_PARAM) != 0)
            return "Reason: 'An input parameter was invalid'";
        if ((status & DT_BUFFER_TOO_SMALL) != 0)
            return "Reason: 'Result buffer for the query was too small to store all results'";
        if ((status & DT_OUT_OF_NODES) != 0)
            return "Reason: 'Query ran out of nodes during search'";
        if ((status & DT_PARTIAL_RESULT) != 0)
            return "Reason: 'Query did not reach the end location, returning best guess'";
        if ((status & DT_ALREADY_OCCUPIED) != 0)
            return "Reason: 'A tile has already been assigned to the given x,y coordinate'";
    }

    MapBuilder::MapBuilder(const char* configInputPath, int threads, bool skipLiquid, bool skipContinents, bool skipJunkMaps,
                           bool skipBattlegrounds, bool debug, const char* offMeshFilePath, const char* workdir,
                           const char* gameObjectFilePath,
                         bool autoOffMesh) :
        m_taskQueue(new TaskQueue(this, threads)),
        m_debug(debug),
        m_skipContinents(skipContinents),
        m_skipJunkMaps(skipJunkMaps),
        m_skipBattlegrounds(skipBattlegrounds),
        m_offMeshFilePath(offMeshFilePath),
        m_workdir(workdir),
        m_gameObjectFilePath(gameObjectFilePath),
        m_autoOffMesh(autoOffMesh)
    {
        std::ifstream jsonConfig(configInputPath);
        if (jsonConfig)
            m_config = json::parse(jsonConfig);

        m_terrainBuilder = new TerrainBuilder(skipLiquid, workdir);
        // ⚠️ 原来这里是 `new rcContext(false)` —— 把 Recast 的日志**整个关掉**了。
        //    后果：任何 Recast 内部失败（数组溢出、region 超限、分配失败）都是**静默**的，
        //    整格直接消失而地图级只打印 "Movemap build is complete!"。
        //    实测 530 的 5302520 / 5302619 / 5302919 / 5302920 就是这样没的。
        //    改成 true 让 Recast 自己把错误原因打出来。
        m_rcContext = new rcContext(true);

        printf("Using %d thread(s) for processing.\n", threads);
        loadGameObjects();
        discoverTiles();
    }

    /**************************************************************************/
    MapBuilder::~MapBuilder()
    {
        for (auto& model : m_goModelCache)
            delete model.second;
        m_goModelCache.clear();

        delete m_terrainBuilder;
        delete m_rcContext;
    }

    /**************************************************************************/
    // [GOBAKE] GameObject collision as static navmesh geometry.
    //
    // Creatures path on the mmaps, which are built from the static terrain and the vmaps -
    // a gameobject model is in neither, so a mob walks straight through the Sethekk Halls
    // cage (183051) and every other cage/fence/barrier the client happily renders.
    // This reads a file listing every gameobject spawn we want to bake:
    //
    //   <modelFile> <mapId> <x> <y> <z> <rotXdeg> <rotYdeg> <rotZdeg> <scale>
    //
    // where <modelFile> is the vmaps-relative model dump (e.g. "G_Cage02.m2.vmo") and the
    // rotation is in degrees, exactly like the vmap spawn data the terrain path already
    // reads. The geometry is merged into the terrain mesh of every tile the model overlaps,
    // so Recast carves it out of the walkable surface exactly like a wall from a WMO.
    void MapBuilder::loadGameObjects()
    {
        if (!m_gameObjectFilePath || !*m_gameObjectFilePath)
            return;

        std::ifstream file(m_gameObjectFilePath);
        if (!file)
        {
            printf("* Cannot open gameobject input '%s' - no gameobject geometry baked\n", m_gameObjectFilePath);
            return;
        }

        std::string line;
        uint32 parsed = 0, skipped = 0, missingModels = 0;
        while (std::getline(file, line))
        {
            if (line.empty() || line[0] == '#')
                continue;

            std::istringstream iss(line);
            GameObjectSpawn spawn;
            if (!(iss >> spawn.model >> spawn.mapId >> spawn.x >> spawn.y >> spawn.z
                      >> spawn.rotDeg[0] >> spawn.rotDeg[1] >> spawn.rotDeg[2] >> spawn.scale))
            {
                ++skipped;
                continue;
            }

            WorldModel* worldModel = getGameObjectModel(spawn.model);
            if (!worldModel)
            {
                ++missingModels;
                continue;
            }

            // same convention as TerrainBuilder::loadVMap
            G3D::Matrix3 rotation = G3D::Matrix3::fromEulerAnglesXYZ(G3D::pi() * spawn.rotDeg[2] / -180.f,
                                                                     G3D::pi() * spawn.rotDeg[0] / -180.f,
                                                                     G3D::pi() * spawn.rotDeg[1] / -180.f);

            // world box of the transformed model. Two details matter here:
            //  - unlike the vmap spawns (whose positions are stored as world + 32*GRID_SIZE)
            //    the gameobject input carries plain world coordinates, so no shift is applied;
            //  - the box comes from the real mesh data, because GroupModel::GetBound() is
            //    empty for models whose bound chunk was never filled in.
            std::vector<GroupModel> groupModels;
            worldModel->getGroupModels(groupModels);

            Vector3 position(-spawn.x, -spawn.y, spawn.z);
            std::vector<Vector3> corners, transformed;
            bool haveBounds = false;
            G3D::Vector3 lmin(1e9f, 1e9f, 1e9f), lmax(-1e9f, -1e9f, -1e9f);
            for (auto& gm : groupModels)
            {
                std::vector<Vector3> verts;
                std::vector<MeshTriangle> tris;
                WmoLiquid* liquid = nullptr;
                gm.getMeshData(verts, tris, liquid);
                for (Vector3 const& v : verts)
                {
                    haveBounds = true;
                    lmin = lmin.min(v);
                    lmax = lmax.max(v);
                }
            }

            if (!haveBounds)                            // model with no geometry at all
            {
                ++missingModels;
                continue;
            }

            for (int corner = 0; corner < 8; ++corner)
                corners.push_back(Vector3((corner & 1) ? lmax.x : lmin.x,
                                          (corner & 2) ? lmax.y : lmin.y,
                                          (corner & 4) ? lmax.z : lmin.z));
            TerrainBuilder::transform(corners, transformed, spawn.scale, rotation, position);

            spawn.bmin[0] = spawn.bmin[1] = spawn.bmin[2] = 1e9f;
            spawn.bmax[0] = spawn.bmax[1] = spawn.bmax[2] = -1e9f;
            for (Vector3 const& v : transformed)
            {
                // copyVertices() writes (y, z, x) into the mesh arrays, so the tile bounds
                // are in that permuted space: mesh[1] = height, mesh[2] = vmap x
                float const mx = v.y;
                float const my = v.z;
                float const mz = v.x;
                spawn.bmin[0] = std::min(spawn.bmin[0], mx);
                spawn.bmin[1] = std::min(spawn.bmin[1], my);
                spawn.bmin[2] = std::min(spawn.bmin[2], mz);
                spawn.bmax[0] = std::max(spawn.bmax[0], mx);
                spawn.bmax[1] = std::max(spawn.bmax[1], my);
                spawn.bmax[2] = std::max(spawn.bmax[2], mz);
            }

            m_goSpawns[spawn.mapId].push_back(spawn);
            ++parsed;
        }

        printf("Loaded %u gameobject spawn(s) for navmesh baking (%u lines skipped, %u models not in vmaps)\n",
               parsed, skipped, missingModels);
    }

    /**************************************************************************/
    WorldModel* MapBuilder::getGameObjectModel(std::string const& name)
    {
        std::lock_guard<std::mutex> guard(m_goModelMutex);

        auto itr = m_goModelCache.find(name);
        if (itr != m_goModelCache.end())
            return itr->second;

        std::string fullName(m_workdir);
        fullName += "/vmaps/" + name;
        WorldModel* model = new WorldModel();
        if (!model->readFile(fullName))
        {
            delete model;
            m_goModelCache[name] = nullptr;
            return nullptr;
        }

        m_goModelCache[name] = model;
        return model;
    }

    /**************************************************************************/
    void MapBuilder::addGameObjectsToTile(uint32 mapID, float bmin[3], float bmax[3], MeshData& meshData)
    {
        auto itr = m_goSpawns.find(mapID);
        if (itr == m_goSpawns.end())
            return;

        float const margin = 1.0f;
        uint32 accepted = 0, candidates = 0;
        for (GameObjectSpawn const& spawn : itr->second)
        {
            ++candidates;
            // both boxes are in the same mesh space (TerrainBuilder::transform output)
            if (spawn.bmax[0] < bmin[0] - margin || spawn.bmin[0] > bmax[0] + margin)
                continue;
            if (spawn.bmax[1] < bmin[1] - margin || spawn.bmin[1] > bmax[1] + margin)
                continue;
            if (spawn.bmax[2] < bmin[2] - margin || spawn.bmin[2] > bmax[2] + margin)
                continue;
            ++accepted;

            WorldModel* worldModel = getGameObjectModel(spawn.model);
            if (!worldModel)
                continue;

            std::vector<GroupModel> groupModels;
            worldModel->getGroupModels(groupModels);

            bool isM2 = spawn.model.find(".m2") != std::string::npos || spawn.model.find(".M2") != std::string::npos;

            G3D::Matrix3 rotation = G3D::Matrix3::fromEulerAnglesXYZ(G3D::pi() * spawn.rotDeg[2] / -180.f,
                                                                     G3D::pi() * spawn.rotDeg[0] / -180.f,
                                                                     G3D::pi() * spawn.rotDeg[1] / -180.f);
            // The mesh space the generator works in is (worldY, height, worldX) - the same
            // space the vmap spawns end up in after their mirroring - so a gameobject given in
            // world coordinates has to be mapped the same way. Getting this wrong puts the
            // model one tile off (it then merges into empty space and nothing changes).
            Vector3 position(-spawn.x, -spawn.y, spawn.z);

            for (auto& gm : groupModels)
            {
                std::vector<Vector3> tempVertices, transformedVertices;
                std::vector<MeshTriangle> tempTriangles;
                WmoLiquid* liquid = nullptr;
                gm.getMeshData(tempVertices, tempTriangles, liquid);

                TerrainBuilder::transform(tempVertices, transformedVertices, spawn.scale, rotation, position);

                int offset = meshData.solidVerts.size() / 3;
                TerrainBuilder::copyVertices(transformedVertices, meshData.solidVerts);
                TerrainBuilder::copyIndices(tempTriangles, meshData.solidTris, offset, isM2);
            }
        }

        if (accepted)
            printf("[GOBAKE] tile bbox (%.1f,%.1f,%.1f)-(%.1f,%.1f,%.1f): merged %u of %u candidate spawn(s)\n",
                   bmin[0], bmin[1], bmin[2], bmax[0], bmax[1], bmax[2], accepted, candidates);
        else if (candidates)
            printf("[GOBAKE] tile bbox (%.1f,%.1f,%.1f)-(%.1f,%.1f,%.1f): 0 of %u candidate spawn(s) inside\n",
                   bmin[0], bmin[1], bmin[2], bmax[0], bmax[1], bmax[2], candidates);
    }

    /**************************************************************************/
    void MapBuilder::BuildMaps(std::vector<uint32>& ids)
    {
        if (ids.empty())
        {
            for (auto tileItr : m_tiles)
            {
                uint32 const& mapID = tileItr.first;
                if (!shouldSkipMap(mapID))
                    buildMap(mapID);

                m_mapDone.insert(mapID);
            }
        }
        else
        {
            for (auto& mapId : ids)
            {
                if (!shouldSkipMap(mapId))
                    buildMap(mapId);

                m_mapDone.insert(mapId);
            }
        }

        // Wait all work to be done
        m_taskQueue->WaitAll();
    }

    /**************************************************************************/
    void MapBuilder::discoverTiles()
    {
        std::vector<std::string> files;
        uint32 mapID, tileX, tileY, tileID, count = 0;
        char filter[12];
        char maps_dir[1024];
        char vmaps_dir[1024];

        printf("Discovering maps... ");
        sprintf(maps_dir, "%s/maps", m_workdir);
        getDirContents(files, maps_dir);
        for (uint32 i = 0; i < files.size(); ++i)
        {
            mapID = uint32(atoi(files[i].substr(0, 3).c_str()));
            if (m_tiles.find(mapID) == m_tiles.end())
            {
                m_tiles.emplace(mapID, std::set<uint32>{});
                count++;
            }
        }

        files.clear();
        sprintf(vmaps_dir, "%s/vmaps", m_workdir);
        getDirContents(files, vmaps_dir, "*.vmtree");
        for (uint32 i = 0; i < files.size(); ++i)
        {
            mapID = uint32(atoi(files[i].substr(0, 3).c_str()));
            if (m_tiles.find(mapID) == m_tiles.end())
            {
                m_tiles.emplace(mapID, std::set<uint32>{});
                count++;
            }
        }
        printf("found %u.\n", count);

        count = 0;
        printf("Discovering tiles... ");
        for (TileList::iterator itr = m_tiles.begin(); itr != m_tiles.end(); ++itr)
        {
            std::set<uint32>& tiles = (*itr).second;
            mapID = (*itr).first;

            sprintf(filter, "%03u*.vmtile", mapID);
            files.clear();
            getDirContents(files, vmaps_dir, filter);
            for (uint32 i = 0; i < files.size(); ++i)
            {
                tileX = uint32(atoi(files[i].substr(7, 2).c_str()));
                tileY = uint32(atoi(files[i].substr(4, 2).c_str()));
                tileID = StaticMapTree::packTileID(tileY, tileX);

                tiles.insert(tileID);
                count++;
            }

            sprintf(filter, "%03u*", mapID);
            files.clear();
            getDirContents(files, maps_dir, filter);
            for (uint32 i = 0; i < files.size(); ++i)
            {
                tileY = uint32(atoi(files[i].substr(3, 2).c_str()));
                tileX = uint32(atoi(files[i].substr(5, 2).c_str()));
                tileID = StaticMapTree::packTileID(tileX, tileY);

                if (tiles.insert(tileID).second)
                    count++;
            }
        }
        printf("found %u.\n\n", count);
    }

    /**************************************************************************/
    std::set<uint32>& MapBuilder::getTileList(uint32 mapID)
    {
        TileList::iterator itr = m_tiles.find(mapID);
        if (itr != m_tiles.end())
            return (*itr).second;

        return m_tiles.emplace(mapID, std::set<uint32>{}).first->second;
    }

    /**************************************************************************/
    bool MapBuilder::IsMapDone(uint32 mapId) const
    {
        auto itr = std::find(m_mapDone.begin(), m_mapDone.end(), mapId);
        return itr != m_mapDone.end();
    }

    /**************************************************************************/
    void MapBuilder::buildGameObject(std::string modelName, uint32 displayId)
    {
        std::string fullName(m_workdir);
        fullName += "/vmaps/" + modelName;

        printf("Building GameObject model %s\n", modelName.c_str());
        WorldModel m;
        MeshData meshData;
        if (!m.readFile(fullName))
        {
            printf("* Unable to open file\n");
            return;
        }

        // Load model data into navmesh
        vector<GroupModel> groupModels;
        m.getGroupModels(groupModels);

        // all M2s need to have triangle indices reversed
        bool isM2 = modelName.find(".m2") != modelName.npos || modelName.find(".M2") != modelName.npos;

        for (vector<GroupModel>::iterator it = groupModels.begin(); it != groupModels.end(); ++it)
        {
            // transform data
            vector<Vector3> tempVertices;
            vector<MeshTriangle> tempTriangles;
            WmoLiquid* liquid = nullptr;

            (*it).getMeshData(tempVertices, tempTriangles, liquid);

            int offset = meshData.solidVerts.size() / 3;

            TerrainBuilder::copyVertices(tempVertices, meshData.solidVerts);
            TerrainBuilder::copyIndices(tempTriangles, meshData.solidTris, offset, isM2);
        }
        // if there is no data, give up now
        if (!meshData.solidVerts.size())
        {
            printf("* no solid vertices found\n");
            return;
        }
        TerrainBuilder::cleanVertices(meshData.solidVerts, meshData.solidTris);

        // gather all mesh data for final data check, and bounds calculation
        G3D::Array<float> allVerts;
        allVerts.append(meshData.solidVerts);

        if (!allVerts.size())
            return;

        printf("* Model opened (%u vertices)\n", allVerts.size());

        float* tVerts = meshData.solidVerts.getCArray();
        int tVertCount = meshData.solidVerts.size() / 3;
        int* tTris = meshData.solidTris.getCArray();
        int tTriCount = meshData.solidTris.size() / 3;

        // get bounds of current tile
        // keep the raw json around, rcConfig cannot carry generator only options
        json goConfig = getDefaultConfig();

        rcConfig config;
        memset(&config, 0, sizeof(rcConfig));
        config = goConfig;
        config.detailSampleDist = config.cs * 6.0f;
        config.minRegionArea = config.minRegionArea / 2;

        // this sets the dimensions of the heightfield - should maybe happen before border padding
        rcCalcBounds(tVerts, tVertCount, config.bmin, config.bmax);
        rcCalcGridSize(config.bmin, config.bmax, config.cs, &config.width, &config.height);

        Tile tile;
        DumpCtx noDump;
        buildCommonTile(modelName.data(), noDump, tile, config, tVerts, tVertCount, tTris, tTriCount, nullptr, 0, nullptr, 0, 0,
                        goConfig.value("preErosionMedianPasses", 1), goConfig.value("seamBridgeMaxRise", 0), nullptr);

        IntermediateValues iv;
        iv.polyMesh = tile.pmesh;
        iv.polyMeshDetail = tile.dmesh;
        for (int i = 0; i < iv.polyMesh->npolys; ++i)
        {
            if (uint8 area = iv.polyMesh->areas[i] & NAV_AREA_ALL_MASK)
            {
                if (area >= NAV_AREA_MIN_VALUE)
                    iv.polyMesh->flags[i] = 1 << (NAV_AREA_MAX_VALUE - area);
                else
                    iv.polyMesh->flags[i] = NAV_GROUND;
            }
        }

        // Will be deleted by IntermediateValues
        tile.pmesh = nullptr;
        tile.dmesh = nullptr;
        // setup mesh parameters
        dtNavMeshCreateParams params;
        memset(&params, 0, sizeof(params));
        params.verts = iv.polyMesh->verts;
        params.vertCount = iv.polyMesh->nverts;
        params.polys = iv.polyMesh->polys;
        params.polyAreas = iv.polyMesh->areas;
        params.polyFlags = iv.polyMesh->flags;
        params.polyCount = iv.polyMesh->npolys;
        params.nvp = iv.polyMesh->nvp;
        params.detailMeshes = iv.polyMeshDetail->meshes;
        params.detailVerts = iv.polyMeshDetail->verts;
        params.detailVertsCount = iv.polyMeshDetail->nverts;
        params.detailTris = iv.polyMeshDetail->tris;
        params.detailTriCount = iv.polyMeshDetail->ntris;

        params.walkableHeight = BASE_UNIT_DIM * config.walkableHeight;
        params.walkableRadius = BASE_UNIT_DIM * config.walkableRadius;
        params.walkableClimb = BASE_UNIT_DIM * config.walkableClimb;

        rcVcopy(params.bmin, iv.polyMesh->bmin);
        rcVcopy(params.bmax, iv.polyMesh->bmax);
        params.cs = config.cs;
        params.ch = config.ch;
        params.buildBvTree = true;

        unsigned char* navData = nullptr;
        int navDataSize = 0;
        printf("* Building navmesh tile [%f %f %f to %f %f %f]\n",
            params.bmin[0], params.bmin[1], params.bmin[2],
            params.bmax[0], params.bmax[1], params.bmax[2]);
        printf(" %u triangles (%u vertices)\n", params.polyCount, params.vertCount);
        printf(" %u polygons (%u vertices)\n", params.detailTriCount, params.detailVertsCount);
        if (params.nvp > DT_VERTS_PER_POLYGON)
        {
            printf("Invalid verts-per-polygon value!        \n");
            return;
        }
        if (params.vertCount >= 0xffff)
        {
            printf("Too many vertices! (0x%8x)        \n", params.vertCount);
            return;
        }
        if (!params.vertCount || !params.verts)
        {
            printf("No vertices to build tile!              \n");
            return;
        }
        if (!params.polyCount || !params.polys)
        {
            // we have flat tiles with no actual geometry - don't build those, its useless
            // keep in mind that we do output those into debug info
            // drop tiles with only exact count - some tiles may have geometry while having less tiles
            printf("No polygons to build on tile!              \n");
            return;
        }
        if (!params.detailMeshes || !params.detailVerts || !params.detailTris)
        {
            printf("No detail mesh to build tile!           \n");
            return;
        }
        if (!dtCreateNavMeshData(&params, &navData, &navDataSize))
        {
            printf("Failed building navmesh tile!           \n");
            return;
        }

        // TODO: extract additional data that will enable RecastDemo viewing of transport mmaps
        // navmesh creation params
        //dtNavMeshParams navMeshParams;
        //memset(&navMeshParams, 0, sizeof(dtNavMeshParams));
        //navMeshParams.tileWidth = GRID_SIZE;
        //navMeshParams.tileHeight = GRID_SIZE;
        //rcVcopy(navMeshParams.orig, config.bmin);
        //navMeshParams.maxTiles = 1;
        //navMeshParams.maxPolys = 1 << DT_POLY_BITS;

        //dtNavMesh* navMesh = nullptr;
        //navMesh = dtAllocNavMesh();
        //printf("[Map %03i] Creating navMesh...                        \r", displayId);
        //if (!navMesh->init(&navMeshParams))
        //{
        //    printf("[Map %03i] Failed creating navmesh!                   \n", displayId);
        //    return;
        //}

        //sprintf(fileName, "mmaps/%03u.mmap", displayId);

        //FILE* file = fopen(fileName, "wb");
        //if (!file)
        //{
        //    dtFreeNavMesh(navMesh);
        //    char message[1024];
        //    sprintf(message, "[Map %03i] Failed to open %s for writing!             \n", displayId, fileName);
        //    perror(message);
        //    return;
        //}

        //// now that we know navMesh params are valid, we can write them to file
        //fwrite(&navMeshParams, sizeof(dtNavMeshParams), 1, file);
        //fclose(file);

        char fileName[255];
        sprintf(fileName, "%s/mmaps/go%04u.mmtile", m_workdir, displayId);
        FILE* file = fopen(fileName, "wb");
        if (!file)
        {
            char message[1024];
            sprintf(message, "Failed to open %s for writing!\n", fileName);
            perror(message);
            return;
        }

        printf("* Writing to file \"%s\" [size=%u]\n", fileName, navDataSize);

        // write header
        MmapTileHeader header;
        header.usesLiquids = false;
        header.size = uint32(navDataSize);
        fwrite(&header, sizeof(MmapTileHeader), 1, file);

        // write data
        fwrite(navData, sizeof(unsigned char), navDataSize, file);
        fclose(file);
        if (m_debug)
        {
            iv.generateObjFile(modelName, meshData);
            // Write navmesh data
            std::string fname = "/meshes/" + modelName + ".nav";
            fname = m_workdir + fname;
            FILE* file = fopen(fname.c_str(), "wb");
            if (file)
            {
                fwrite(&navDataSize, sizeof(uint32), 1, file);
                fwrite(navData, sizeof(unsigned char), navDataSize, file);
                fclose(file);
            }
        }
    }

    void MapBuilder::buildTransports()
    {
        // List of MO Transport gameobjects
        buildGameObject("Transportship.wmo.vmo", 3015);
        buildGameObject("Transport_Zeppelin.wmo.vmo", 3031);
        buildGameObject("Transportship_Ne.wmo.vmo", 7087);
        // List of Transport gameobjects
        buildGameObject("Elevatorcar.m2.vmo", 360);
        buildGameObject("Undeadelevator.m2.vmo", 455);
        // buildGameObject("Undeadelevatordoor.m2.vmo", 462); // no model on which to path
        buildGameObject("Ironforgeelevator.m2.vmo", 561);
        // buildGameObject("Ironforgeelevatordoor.m2.vmo", 562); // no model on which to path
        buildGameObject("Gnomeelevatorcar01.m2.vmo", 807);
        buildGameObject("Gnomeelevatorcar02.m2.vmo", 808);
        buildGameObject("Gnomeelevatorcar03.m2.vmo", 827); // missing vmap - reusing 03
        buildGameObject("Gnomeelevatorcar03.m2.vmo", 852);
        buildGameObject("Gnomehutelevator.m2.vmo", 1587);
        buildGameObject("Burningsteppselevator.m2.vmo", 2454);
        buildGameObject("Subwaycar.m2.vmo", 3831);
        // TBC+
        buildGameObject("Ancdrae_Elevatorpiece.m2.vmo", 7026);
        buildGameObject("Mushroombase_Elevator.m2.vmo", 7028);
        buildGameObject("Cf_Elevatorplatform.m2.vmo", 7043);
        buildGameObject("Cf_Elevatorplatform_Small.m2.vmo", 7060);
        buildGameObject("Factoryelevator.m2.vmo", 7077);
        buildGameObject("Ancdrae_Elevatorpiece_Netherstorm.m2.vmo", 7163);
    }

    /**************************************************************************/
    void MapBuilder::getGridBounds(uint32 mapID, uint32& minX, uint32& minY, uint32& maxX, uint32& maxY)
    {
        maxX = INT_MAX;
        maxY = INT_MAX;
        minX = INT_MIN;
        minY = INT_MIN;

        float bmin[3] = { 0, 0, 0 };
        float bmax[3] = { 0, 0, 0 };
        float lmin[3] = { 0, 0, 0 };
        float lmax[3] = { 0, 0, 0 };
        MeshData meshData;

        // make sure we process maps which don't have tiles
        // initialize the static tree, which loads WDT models
        if (!m_terrainBuilder->loadVMap(mapID, 64, 64, meshData))
            return;

        // get the coord bounds of the model data
        if (meshData.solidVerts.size() + meshData.liquidVerts.size() == 0)
            return;

        // get the coord bounds of the model data
        if (meshData.solidVerts.size() && meshData.liquidVerts.size())
        {
            rcCalcBounds(meshData.solidVerts.getCArray(), meshData.solidVerts.size() / 3, bmin, bmax);
            rcCalcBounds(meshData.liquidVerts.getCArray(), meshData.liquidVerts.size() / 3, lmin, lmax);
            rcVmin(bmin, lmin);
            rcVmax(bmax, lmax);
        }
        else if (meshData.solidVerts.size())
            rcCalcBounds(meshData.solidVerts.getCArray(), meshData.solidVerts.size() / 3, bmin, bmax);
        else
            rcCalcBounds(meshData.liquidVerts.getCArray(), meshData.liquidVerts.size() / 3, lmin, lmax);

        // convert coord bounds to grid bounds
        maxX = 32 - bmin[0] / GRID_SIZE;
        maxY = 32 - bmin[2] / GRID_SIZE;
        minX = 32 - bmax[0] / GRID_SIZE;
        minY = 32 - bmax[2] / GRID_SIZE;
    }

    /**************************************************************************/
    void MapBuilder::buildSingleTile(uint32 mapID, uint32 tileX, uint32 tileY)
    {
        dtNavMesh* navMesh = NULL;
        buildNavMesh(mapID, navMesh);
        if (!navMesh)
        {
            printf("[Map %03i] Failed creating navmesh!                   \n", mapID);
            return;
        }

        buildTile(mapID, tileX, tileY, navMesh, 1, 1);
        dtFreeNavMesh(navMesh);
    }

    /**************************************************************************/
    void MapBuilder::buildMap(uint32 mapID)
    {
        printf("Building map %03u:                                    \n", mapID);

        std::set<uint32>& tiles = getTileList(mapID);

        // make sure we process maps which don't have tiles
        if (!tiles.size())
        {
            // convert coord bounds to grid bounds
            uint32 minX, minY, maxX, maxY;
            getGridBounds(mapID, minX, minY, maxX, maxY);

            // add all tiles within bounds to tile list.
            for (uint32 i = minX; i <= maxX; ++i)
                for (uint32 j = minY; j <= maxY; ++j)
                    tiles.insert(StaticMapTree::packTileID(i, j));
        }

        if (!tiles.size())
            return;

        // build navMesh
        dtNavMesh* navMesh = nullptr;
        buildNavMesh(mapID, navMesh);
        if (!navMesh)
        {
            printf("[Map %03i] Failed creating navmesh!                   \n", mapID);
            return;
        }

        // now start building mmtiles for each tile
        printf("[Map %03i] We have %u tiles.                          \n", mapID, uint32(tiles.size()));

        uint32 currentTile = 0;
        for (std::set<uint32>::iterator it = tiles.begin(); it != tiles.end(); ++it)
        {
            currentTile++;
            uint32 tileX, tileY;

            // unpack tile coords
            StaticMapTree::unpackTileID((*it), tileX, tileY);

            if (shouldSkipTile(mapID, tileX, tileY))
                continue;

            // Make a copy of the original navMesh object to work on a separate
            // thread since "the data should not be reused in other nav meshes"
            // (see dtNavMesh::addTile description)
            dtNavMesh* navMeshCopy = dtAllocNavMesh();
            dtStatus dtResult = navMeshCopy->init(navMesh->getParams());
            if (dtStatusFailed(dtResult))
            {
                printf("[Map %03i] Failed to copy navmesh!                   \n", mapID);
                printf("%s\n", GetDTErrorReason(dtResult));
                continue;
            }

            // passing by value
            auto builder = [=]()
            {
                // build tile with copy version of the navmesh
                buildTile(mapID, tileX, tileY, navMeshCopy, currentTile, uint32(tiles.size()));

                // free this navmesh
                dtFreeNavMesh(navMeshCopy);
            };

            m_taskQueue->PushWork(builder, mapID);
        }

        dtFreeNavMesh(navMesh);
    }

    /**************************************************************************/
    void MapBuilder::buildTile(uint32 mapID, uint32 tileX, uint32 tileY, dtNavMesh* navMesh, uint32 curTile, uint32 tileCount)
    {
        printf("[Map %03i] Building tile [%02u,%02u] (%02u / %02u)    \n", mapID, tileX, tileY, curTile, tileCount);

        MeshData meshData;

        // get heightmap data
        m_terrainBuilder->loadMap(mapID, tileX, tileY, meshData);

        // 记下"地形三角"的数量（loadVMap 之后三角是地形在前、模型在后）。
        // 生成器用它只对地形放宽坡度限制，建筑模型仍守 60°。
        meshData.terrainTriCount = meshData.solidTris.size() / 3;

        // get model data
        m_terrainBuilder->loadVMap(mapID, tileY, tileX, meshData);

        // if there is no data, give up now
        //
        // ⚠️ 这里原来是个**完全静默**的 return —— 不打任何日志，整格直接消失，
        //    地图级最后只打印 "Movemap build is complete!"。
        //    实测 530 的 [26,19] 用 `--tile 26,19` 烘时就是走到这里无声退出的：
        //        [Map 530] Building tile [26,19] (01 / 01)
        //        Movemap build is complete!
        //    加一行打印，以后一眼能看出是"没几何"而不是"烘失败了"。
        if (!meshData.solidVerts.size() && !meshData.liquidVerts.size())
        {
            // 注意：这个函数里没有 tileString（那个在 buildMoveMapTile 里），直接打。
            printf("[Map %03u] [%02u,%02u]: [TILE-EMPTY] no terrain and no vmap geometry "
                   "(loadMap/loadVMap returned nothing)\n", mapID, tileX, tileY);
            return;
        }

        // remove unused vertices
        TerrainBuilder::cleanVertices(meshData.solidVerts, meshData.solidTris);
        TerrainBuilder::cleanVertices(meshData.liquidVerts, meshData.liquidTris);

        // gather all mesh data for final data check, and bounds calculation
        G3D::Array<float> allVerts;
        allVerts.append(meshData.liquidVerts);
        allVerts.append(meshData.solidVerts);

        if (!allVerts.size())
            return;

        // get bounds of current tile
        float bmin[3], bmax[3];
        getTileBounds(tileX, tileY, allVerts.getCArray(), allVerts.size() / 3, bmin, bmax);

        // [GOBAKE] merge the gameobject collision that falls into this tile, then widen the
        // bounds so Recast keeps the merged geometry (see loadGameObjects()).
        if (!m_goSpawns.empty())
        {
            uint32 const solidBefore = meshData.solidVerts.size();
            addGameObjectsToTile(mapID, bmin, bmax, meshData);
            if (meshData.solidVerts.size() != solidBefore)
            {
                allVerts.clear();
                allVerts.append(meshData.liquidVerts);
                allVerts.append(meshData.solidVerts);
                getTileBounds(tileX, tileY, allVerts.getCArray(), allVerts.size() / 3, bmin, bmax);
            }
        }

        m_terrainBuilder->loadOffMeshConnections(mapID, tileX, tileY, meshData, m_offMeshFilePath);

        // build navmesh tile
        buildMoveMapTile(mapID, tileX, tileY, meshData, bmin, bmax, navMesh);
    }

    /**************************************************************************/
    void MapBuilder::buildNavMesh(uint32 mapID, dtNavMesh*& navMesh)
    {
        std::set<uint32>& tiles = getTileList(mapID);

        // old code for non-statically assigned bitmask sizes:
        ///*** calculate number of bits needed to store tiles & polys ***/
        //int tileBits = dtIlog2(dtNextPow2(tiles.size()));
        //if (tileBits < 1) tileBits = 1;                                     // need at least one bit!
        //int polyBits = sizeof(dtPolyRef)*8 - SALT_MIN_BITS - tileBits;

        // ⚠️ 不要用 `1 << DT_POLY_BITS`。
        // 上游 2023 年把 DT_POLY_BITS 从 12 改成 31（提交 083d78c6f
        // "[Core/MMAP]Change default bit size."），于是这一行在有符号 int 上
        // **溢出成 -2147483648 (0x80000000)**，并且这个值会被原样写进
        // 每个 `<map>.mmap` 的 `dtNavMeshParams.maxPolys`。
        //
        // 实测线上三张图的 .mmap（这个字段是第 24..27 字节）：
        //     map 555 : maxTiles=9    maxPolys=-2147483648 (0x80000000)
        //     map 543 : maxTiles=72   maxPolys=-2147483648
        //     map 530 : maxTiles=800  maxPolys=-2147483648
        //
        // 运行期 `dtNavMesh::init(&params)` 会用它算
        //     m_polyBits = dtIlog2(dtNextPow2((unsigned)maxPolys))  → 31
        //     m_saltBits = min(31, 32 - m_tileBits - m_polyBits)    → ≤ 1
        // 在有 `if (m_saltBits < 10) return DT_FAILURE|DT_INVALID_PARAM;` 的
        // Detour 版本上会**直接初始化失败**；没有那个检查的版本上则是
        // 多边形引用只剩 ≤1 个 salt 位，tile 重载后 ref 极易撞车。
        //
        // 这里改用实际够用的位数：一个 533 码 tile 的多边形数远小于 65536
        // （实测 555 最大的格 2887 个面），16 位足够，salt/tile 位数都留得下。
        static const int MMAP_POLY_BITS = 16;
        int polyBits = MMAP_POLY_BITS;

        // ⚠️ **另一个独立的 bug**：`--tile` 单格模式下走到这里时 `tiles` 还是空的
        //    （它是在下面 buildMoveMapTile 的循环里才被填的），于是 maxTiles = 0，
        //    dtNavMesh 一个 tile 槽都没有，之后**每一次 addTile 都返回
        //    DT_OUT_OF_MEMORY**，整格被丢弃 —— 而地图级仍打印 "complete"。
        //    实测：`--tile 32,32` 必失败；不带 --tile 跑全图则正常。
        int maxTiles = (int)tiles.size();
        if (maxTiles < 1)
            maxTiles = 1;
        int maxPolysPerTile = 1 << polyBits;

        /***          calculate bounds of map         ***/

        uint32 tileXMin = 64, tileYMin = 64, tileXMax = 0, tileYMax = 0, tileX, tileY;
        for (std::set<uint32>::iterator it = tiles.begin(); it != tiles.end(); ++it)
        {
            StaticMapTree::unpackTileID((*it), tileX, tileY);

            if (tileX > tileXMax)
                tileXMax = tileX;
            else if (tileX < tileXMin)
                tileXMin = tileX;

            if (tileY > tileYMax)
                tileYMax = tileY;
            else if (tileY < tileYMin)
                tileYMin = tileY;
        }

        // use Max because '32 - tileX' is negative for values over 32
        float bmin[3], bmax[3];
        getTileBounds(tileXMax, tileYMax, NULL, 0, bmin, bmax);

        /***       now create the navmesh       ***/

        // navmesh creation params
        dtNavMeshParams navMeshParams;
        memset(&navMeshParams, 0, sizeof(dtNavMeshParams));
        navMeshParams.tileWidth = GRID_SIZE;
        navMeshParams.tileHeight = GRID_SIZE;
        rcVcopy(navMeshParams.orig, bmin);
        navMeshParams.maxTiles = maxTiles;
        navMeshParams.maxPolys = maxPolysPerTile;

        navMesh = dtAllocNavMesh();
        printf("[Map %03i] Creating navMesh...                        \r", mapID);
        // [DEBUG] 澄清 "addTile 报 OOM" 到底是不是预算问题：
        //   maxPolysPerTile 如果是有符号溢出出来的负数，(unsigned) 会看到 0x80000000。
        printf("[DEBUG] map=%u tiles=%zu maxTiles=%d maxPolysPerTile=%d (0x%08X) polyBits=%d\n",
               mapID, tiles.size(), maxTiles, maxPolysPerTile,
               (unsigned int)maxPolysPerTile, polyBits);
        dtStatus dtResult = navMesh->init(&navMeshParams);
        printf("[DEBUG] map=%u navMesh->init -> 0x%08X%s\n",
               mapID, (unsigned int)dtResult,
               dtStatusFailed(dtResult) ? "  (FAILED)" : "  (ok)");
        if (dtStatusFailed(dtResult))
        {
            printf("[Map %03i] Failed creating navmesh!                   \n", mapID);
            printf("%s\n", GetDTErrorReason(dtResult));
            return;
        }

        char fileName[1024];
        sprintf(fileName, "%s/mmaps/%03u.mmap", m_workdir, mapID);

        FILE* file = fopen(fileName, "wb");
        if (!file)
        {
            dtFreeNavMesh(navMesh);
            char message[1024];
            sprintf(message, "[Map %03i] Failed to open %s for writing!             \n", mapID, fileName);
            perror(message);
            return;
        }

        // now that we know navMesh params are valid, we can write them to file
        fwrite(&navMeshParams, sizeof(dtNavMeshParams), 1, file);
        fclose(file);
    }

    /**************************************************************************/
    /**
     * [AUTOOFFMESH] 自动为"小连通分量"补 **双向** off-mesh 连接。
     *
     * 为什么需要：`walkableRadius` 是按 agent 半径腐蚀可行走区域的，它会把高度场里
     * 1 格宽（0.2667 码）的窄缝放大成 `1 + 2*radius` 格，把本该连成一片的地面切成
     * 大量互不连通的小孤岛 —— map 530 全图 74,285 个连通分量、最大分量只占
     * 37.17%、42,877 个 1~5 面的小孤岛（96.6% 对外 0 条 portal），其中 27,240 个
     * 真实缺口 < 2 码（中位 1.338 码）。**任何 Recast 参数都修不好**（12 个变体实测）。
     *
     * 530 当年是在外面用 `dev/tools` 的 `gen_offmesh.py` 生成 offmesh 文件补的
     * （34,609 条），但那要跑两遍、而且改了 ch 或生成参数就得整份重算。
     * 这里把同一条规则做进生成器：**一次生成、不需要外部文件**。
     *
     * 规则（**只做格内、不跨格**）：
     *   对每个面数 <= maxComp 的连通分量 C，遍历**所有**不在 C 里的面 o；
     *   对每一对 (C, o) 取二者之间最近的一对顶点，只要 `dh <= maxDH` 且
     *   `|高差| <= maxDV`，就给这一对补一条**双向** off-mesh（dir = 1）。
     *
     *   ⚠️ 与 `dev/tools` 的 `gen_offmesh.py` **刻意不同**：那个工具是每个小分量
     *     只补**最近的一条**；这里是"所有近的都补"。所以同等阈值下链接数会明显更多。
     *
     * ⚠️ 坐标：本 fork 的 mesh 空间是 `(世界Y, 高度, 世界X)`；
     *    `rcPolyMesh` 的 `x=世界Y / y=高度 / z=世界X`，单位是格（`cs`/`ch`），
     *    相对 `polyMesh->bmin`。而 `dtNavMeshCreateParams::offMeshConVerts` 要的是
     *    **绝对世界坐标、同样轴序** —— `dtCreateNavMeshData` 会把 navVerts 用
     *    `bmin + v*cs` 展开成绝对坐标存盘，而 off-mesh 端点是**原样存**的。
     *    所以这里做 `bmin + v*cs/ch` 换算，**绝对不要做轴交换**。
     *
     * ⚠️ 端点高度：Detour 会把 off-mesh 端点吸附到最近多边形的边界上，
     *    这里给的是多边形**顶点**的原始高度。
     *
     * stats: [0]=补了几条 [1]=符合条件的小分量数 [2]=被阈值拒掉的顶点对次数 [3]=扫描过的面-面对数
     */
    static void buildAutoOffMeshConnections(const rcPolyMesh* pm, float maxDH, float maxDV,
                                            int maxComp, float conRadius,
                                            MeshData& meshData, int stats[4])
    {
        stats[0] = stats[1] = stats[2] = stats[3] = 0;
        if (!pm || pm->npolys < 1)
            return;
        const int n = pm->npolys;
        const int nvp = pm->nvp;
        if (nvp < 3 || pm->nverts < 3)
            return;

        // ⚠️ 多边形 i 的两个半段都在 polys 里、步长是 **nvp*2**：
        //      polys[i*nvp*2 + 0 .. nvp-1]      顶点索引（RC_MESH_NULL_IDX 结尾）
        //      polys[i*nvp*2 + nvp .. 2*nvp-1]  邻居（本格面号 / RC_MESH_NULL_IDX / 0x8000|dir）
        //    写成 polys[i*nvp + k] 会读到邻居半段，vi 拿到 0x8000|dir 就 verts 越界 → 段错误。
        const int stride = nvp * 2;

        // 多边形 k 号顶点的绝对世界坐标 (世界Y, 高度, 世界X)
        auto wpos = [pm, stride](int poly, int k, float* out)
        {
            const unsigned short vi = pm->polys[poly * stride + k];
            if (vi >= pm->nverts)
            {
                out[0] = out[1] = out[2] = 0.0f;
                return;
            }
            out[0] = pm->bmin[0] + pm->verts[vi * 3 + 0] * pm->cs;   // 世界Y
            out[1] = pm->bmin[1] + pm->verts[vi * 3 + 1] * pm->ch;   // 高度
            out[2] = pm->bmin[2] + pm->verts[vi * 3 + 2] * pm->cs;   // 世界X
        };
        // 多边形实际顶点数（polys 前半段，RC_MESH_NULL_IDX 结尾）
        auto vcount = [pm, stride](int poly)
        {
            int c = 0;
            while (c < pm->nvp && pm->polys[poly * stride + c] != RC_MESH_NULL_IDX)
                ++c;
            return c;
        };

        // ⚠️ 只有**运行期真能走**的面才配参与补连。
        //    NAV_AREA_GROUND_STEEP（50~60°）在 `PathFinder::createFilter()` 里：
        //      没开 ENABLE_PLAYERBOTS（我们的构建 BUILD_PLAYERBOTS=OFF）时，
        //        生物只拿到 NAV_GROUND —— STEEP **不可走**；
        //      开了 playerbots 才会 include NAV_GROUND_STEEP。
        //    所以补到 STEEP 上的连接在我们这儿是**死连接**：
        //    实测过一次，53.4% 的端点落在 STEEP 上 —— 全部无效，还会把生物放到
        //    过滤器不认的面上、下一次寻路直接失配。
        auto walkable = [pm](int i)
        {
            const unsigned char a = pm->areas[i];
            return a != RC_NULL_AREA && a != NAV_AREA_GROUND_STEEP;
        };

        // ---- 并查集：只沿格内邻居 ----
        // ⚠️ rcPolyMesh **没有 neis 成员**：邻居和顶点同存在 polys 里（见上面的 stride 注释）。
        //    Detour 那边会把面号 +1 写进 dtPoly::neis，所以这里用**原始值**。
        std::vector<int> parent(n);
        for (int i = 0; i < n; ++i)
            parent[i] = i;
        auto find = [&parent](int a)
        {
            while (parent[a] != a) { parent[a] = parent[parent[a]]; a = parent[a]; }
            return a;
        };
        for (int i = 0; i < n; ++i)
            for (int j = 0; j < nvp; ++j)
            {
                const unsigned short nb = pm->polys[i * stride + nvp + j];
                if (nb == RC_MESH_NULL_IDX || (nb & 0x8000) || nb >= n)
                    continue;
                if (!walkable(i) || !walkable(nb))
                    continue;
                const int ra = find(i), rb = find(nb);
                if (ra != rb)
                    parent[rb] = ra;
            }

        // 只把"可走的面"放进分量表 —— 这样 STEEP 面既不会成为补连的起点，
        // 也不会成为终点（它自成一堆、根本不进 members）。
        std::map<int, std::vector<int>> members;
        for (int i = 0; i < n; ++i)
            if (walkable(i))
                members[find(i)].push_back(i);

        // ---- 每个面的水平包围盒（只用于早退，不参与判定）----
        std::vector<float> bbox(n * 4);   // [世界Ymin, 世界Ymax, 世界Xmin, 世界Xmax]
        for (int i = 0; i < n; ++i)
        {
            float* b = &bbox[i * 4];
            b[0] = b[2] = 1e30f;
            b[1] = b[3] = -1e30f;
            const int vc = vcount(i);
            for (int k = 0; k < vc; ++k)
            {
                float p[3];
                wpos(i, k, p);
                if (p[0] < b[0]) b[0] = p[0];
                if (p[0] > b[1]) b[1] = p[0];
                if (p[2] < b[2]) b[2] = p[2];
                if (p[2] > b[3]) b[3] = p[2];
            }
        }

        for (std::map<int, std::vector<int>>::const_iterator it = members.begin();
             it != members.end(); ++it)
        {
            if ((int)it->second.size() > maxComp)
                continue;
            const int comp = it->first;
            const std::vector<int>& mine = it->second;

            float cy0 = 1e30f, cy1 = -1e30f, cx0 = 1e30f, cx1 = -1e30f;
            for (size_t m = 0; m < mine.size(); ++m)
            {
                const float* b = &bbox[mine[m] * 4];
                if (b[0] < cy0) cy0 = b[0];
                if (b[1] > cy1) cy1 = b[1];
                if (b[2] < cx0) cx0 = b[2];
                if (b[3] > cx1) cx1 = b[3];
            }

            // ⚠️ 规则是「**所有**近的非本分量面各补一条」，不是只补最近的一条。
            //    对分量 C 与每个不在 C 里的面 o，各自取二者之间最近的一对顶点；
            //    只要 dh <= maxDH 且 |dv| <= maxDV，就给这一对 (C, o) 补一条双向连接。
            //    （gen_offmesh.py 是整分量只补最近的一条 —— 这里刻意不同。）
            int added = 0;
            for (int o = 0; o < n; ++o)
            {
                if (find(o) == comp)
                    continue;
                if (!walkable(o))          // 不往 STEEP 上补（见上面的 walkable 注释）
                    continue;
                const float* b = &bbox[o * 4];
                if (b[0] > cy1 + maxDH || b[1] < cy0 - maxDH)
                    continue;
                if (b[2] > cx1 + maxDH || b[3] < cx0 - maxDH)
                    continue;
                const int vb = vcount(o);
                float bestDH = -1.0f, bestA[3], bestB[3];
                for (size_t m = 0; m < mine.size(); ++m)
                {
                    const int va = vcount(mine[m]);
                    for (int a = 0; a < va; ++a)
                    {
                        float pa[3];
                        wpos(mine[m], a, pa);
                        for (int c = 0; c < vb; ++c)
                        {
                            float pb[3];
                            wpos(o, c, pb);
                            const float dx = pa[0] - pb[0], dz = pa[2] - pb[2];
                            const float dh = sqrtf(dx * dx + dz * dz);
                            stats[3]++;
                            if (bestDH >= 0.0f && dh >= bestDH)
                                continue;
                            const float dv = pb[1] - pa[1];
                            if (dh > maxDH || fabsf(dv) > maxDV)
                            {
                                stats[2]++;
                                continue;
                            }
                            bestDH = dh;
                            bestA[0] = pa[0]; bestA[1] = pa[1]; bestA[2] = pa[2];
                            bestB[0] = pb[0]; bestB[1] = pb[1]; bestB[2] = pb[2];
                        }
                    }
                }

                if (bestDH < 0.0f)
                    continue;

                // 双向 off-mesh：Detour 的连接点 = 6 个 float，绝对世界坐标、同轴序
                meshData.offMeshConnections.append(bestA[0]);
                meshData.offMeshConnections.append(bestA[1]);
                meshData.offMeshConnections.append(bestA[2]);
                meshData.offMeshConnections.append(bestB[0]);
                meshData.offMeshConnections.append(bestB[1]);
                meshData.offMeshConnections.append(bestB[2]);
                meshData.offMeshConnectionDirs.append(1);              // 1 = 双向
                meshData.offMeshConnectionRads.append(conRadius);      // agent 半径（码）
                meshData.offMeshConnectionsAreas.append((unsigned char)0xFF);
                meshData.offMeshConnectionsFlags.append((unsigned short)0xFF);
                added++;
            }

            if (added > 0)
            {
                stats[0] += added;
                stats[1]++;        // 记"有补过连接的小分量"个数，不是链接数
            }
        }
    }

    /**************************************************************************/
    void MapBuilder::buildMoveMapTile(uint32 mapID, uint32 tileX, uint32 tileY,
                                      MeshData& meshData, float bmin[3], float bmax[3],
                                      dtNavMesh* navMesh)
    {
        // console output
        char tileString[20];
        sprintf(tileString, "[Map %03i] [%02i,%02i]: ", mapID, tileX, tileY);
        printf("%s Building movemap tiles...                          \r", tileString);

        IntermediateValues iv(m_workdir);

        float* tVerts = meshData.solidVerts.getCArray();
        int tVertCount = meshData.solidVerts.size() / 3;
        int* tTris = meshData.solidTris.getCArray();
        int tTriCount = meshData.solidTris.size() / 3;

        float* lVerts = meshData.liquidVerts.getCArray();
        int lVertCount = meshData.liquidVerts.size() / 3;
        int* lTris = meshData.liquidTris.getCArray();
        int lTriCount = meshData.liquidTris.size() / 3;
        uint8* lTriFlags = meshData.liquidType.getCArray();

        rcConfig config;
        memset(&config, 0, sizeof(rcConfig));

        // keep the raw json around, rcConfig cannot carry generator only options
        json tileConfig = getTileConfig(mapID, tileX, tileY);
        config = tileConfig;

        // how many median filter passes are run before the walkable area is eroded
        const int preErosionMedianPasses = tileConfig.value("preErosionMedianPasses", 1);

        // how far one cell geometry may rise above the walkable surface and still
        // be treated as a seam that has to be closed (see closeThinSeams)
        const int seamBridgeMaxRise = tileConfig.value("seamBridgeMaxRise", 0);

        // 【地形专用坡度】只作用于 ADT 地形三角（见 buildCommonTile 里 terrainTriLimit 的说明）。
        // 建筑模型（WMO/M2）仍然用 tileCfg.walkableSlopeAngle（默认 60°）。
        const int terrainTriCount = meshData.terrainTriCount;
        const float terrainSlopeAngle = tileConfig.value("terrainSlopeAngle", 90.0f);

        rcVcopy(config.bmin, bmin);
        rcVcopy(config.bmax, bmax);

        // this sets the dimensions of the heightfield - should maybe happen before border padding
        rcCalcGridSize(config.bmin, config.bmax, config.cs, &config.width, &config.height);

        // allocate subregions : tiles
        Tile* tiles = new Tile[TILES_PER_MAP * TILES_PER_MAP];

        // Initialize per tile config.
        rcConfig tileCfg;
        memcpy(&tileCfg, &config, sizeof(rcConfig));
        tileCfg.width = config.tileSize + config.borderSize * 2;
        tileCfg.height = config.tileSize + config.borderSize * 2;

        // build all tiles
        SeamFixStats seamStats;
        for (int y = 0; y < TILES_PER_MAP; ++y)
        {
            for (int x = 0; x < TILES_PER_MAP; ++x)
            {
                Tile& tile = tiles[x + y * TILES_PER_MAP];

                // Calculate the per tile bounding box.
                tileCfg.bmin[0] = config.bmin[0] + x * float(config.tileSize * config.cs);
                tileCfg.bmin[2] = config.bmin[2] + y * float(config.tileSize * config.cs);
                tileCfg.bmax[0] = config.bmin[0] + (x + 1) * float(config.tileSize * config.cs);
                tileCfg.bmax[2] = config.bmin[2] + (y + 1) * float(config.tileSize * config.cs);

                tileCfg.bmin[0] -= tileCfg.borderSize * tileCfg.cs;
                tileCfg.bmin[2] -= tileCfg.borderSize * tileCfg.cs;
                tileCfg.bmax[0] += tileCfg.borderSize * tileCfg.cs;
                tileCfg.bmax[2] += tileCfg.borderSize * tileCfg.cs;

                DumpCtx dbg;
                dbg.map = mapID; dbg.tileX = tileX; dbg.tileY = tileY;
                dbg.subX = x; dbg.subY = y; dbg.enabled = true;
                buildCommonTile(tileString, dbg, tile, tileCfg, tVerts, tVertCount, tTris, tTriCount, lVerts, lVertCount, lTris, lTriCount, lTriFlags,
                                preErosionMedianPasses, seamBridgeMaxRise, &seamStats,
                                terrainTriCount, terrainSlopeAngle,
                                tileConfig.value("splitTerrain", false));
            }
        }

        if (std::getenv("MMAP_SEAM_STATS") && (seamStats.closed || seamStats.wall || seamStats.steep || seamStats.noFlank))
            printf("%s seam fix: closed=%d (rise<=1:%d 2-4:%d 5-8:%d >8:%d) wall=%d steep=%d noFlank=%d   \n",
                   tileString, seamStats.closed, seamStats.riseLe1, seamStats.riseLe4,
                   seamStats.riseLe8, seamStats.riseMore, seamStats.wall, seamStats.steep, seamStats.noFlank);

        // merge per tile poly and detail meshes
        rcPolyMesh** pmmerge = new rcPolyMesh*[TILES_PER_MAP * TILES_PER_MAP];
        rcPolyMeshDetail** dmmerge = new rcPolyMeshDetail*[TILES_PER_MAP * TILES_PER_MAP];

        int nmerge = 0;
        for (int y = 0; y < TILES_PER_MAP; ++y)
        {
            for (int x = 0; x < TILES_PER_MAP; ++x)
            {
                Tile& tile = tiles[x + y * TILES_PER_MAP];
                if (tile.pmesh)
                {
                    pmmerge[nmerge] = tile.pmesh;
                    dmmerge[nmerge] = tile.dmesh;
                    nmerge++;
                }
            }
        }

        iv.polyMesh = rcAllocPolyMesh();
        if (!iv.polyMesh)
        {
            printf("%s alloc iv.polyMesh FIALED!                          \r", tileString);
            delete[] pmmerge;
            delete[] dmmerge;
            delete[] tiles;
            return;
        }
        rcMergePolyMeshes(m_rcContext, pmmerge, nmerge, *iv.polyMesh);

        iv.polyMeshDetail = rcAllocPolyMeshDetail();
        if (!iv.polyMeshDetail)
        {
            printf("%s alloc m_dmesh FIALED!                              \r", tileString);
            delete[] pmmerge;
            delete[] dmmerge;
            delete[] tiles;
            return;
        }
        rcMergePolyMeshDetails(m_rcContext, dmmerge, nmerge, *iv.polyMeshDetail);

        // free things up
        delete [] pmmerge;
        delete [] dmmerge;
        delete [] tiles;

        // set polygons as walkable
        // TODO: special flags for DYNAMIC polygons, ie surfaces that can be turned on and off
        for (int i = 0; i < iv.polyMesh->npolys; ++i)
        {
            if (uint8 area = iv.polyMesh->areas[i] & NAV_AREA_ALL_MASK)
            {
                if (area >= NAV_AREA_MIN_VALUE)
                    iv.polyMesh->flags[i] = 1 << (NAV_AREA_MAX_VALUE - area);
                else
                    iv.polyMesh->flags[i] = NAV_GROUND; // TODO: these will be dynamic in future
            }
        }

        // setup mesh parameters
        dtNavMeshCreateParams params;
        memset(&params, 0, sizeof(params));
        params.verts = iv.polyMesh->verts;
        params.vertCount = iv.polyMesh->nverts;
        params.polys = iv.polyMesh->polys;
        params.polyAreas = iv.polyMesh->areas;
        params.polyFlags = iv.polyMesh->flags;
        params.polyCount = iv.polyMesh->npolys;
        params.nvp = iv.polyMesh->nvp;
        params.detailMeshes = iv.polyMeshDetail->meshes;
        params.detailVerts = iv.polyMeshDetail->verts;
        params.detailVertsCount = iv.polyMeshDetail->nverts;
        params.detailTris = iv.polyMeshDetail->tris;
        params.detailTriCount = iv.polyMeshDetail->ntris;

        // [DEBUG] 合并后的整块 polyMesh —— 用来夹死"幽灵面"到底是在
        //   rcMergePolyMeshes 里产生的，还是在 dtCreateNavMeshData 里产生的。
        //   实测 555 的 625 个子格 .pmesh 里都没有那个幽灵面，所以看这份就行。
        //   这里没有现成的 DumpCtx（那个在更内层的作用域），单独造一个：
        //   subX/subY 用 -1 标识"整块 tile"。
        {
            DumpCtx tdbg;
            tdbg.map = mapID;
            tdbg.tileX = tileX;
            tdbg.tileY = tileY;
            tdbg.enabled = true;
            if (iv.polyMesh)
                dumpPolyMesh(tdbg, *iv.polyMesh);
        }

        // [AUTOOFFMESH] 自动补连：必须在 dtCreateNavMeshData **之前** 追加进
        // meshData.offMeshConnections（下面 params.offMeshCon* 直接取这个数组）。
        // 与外部 offmesh 文件是**叠加**关系：文件里的那些仍然生效。
        if (m_autoOffMesh && iv.polyMesh && iv.polyMesh->npolys > 1)
        {
            json offCfg = getTileConfig(mapID, tileX, tileY);
            int st[4];
            buildAutoOffMeshConnections(iv.polyMesh,
                                        offCfg.value("autoOffMeshMaxDH", 2.0f),
                                        offCfg.value("autoOffMeshMaxDV", 1.0f),
                                        offCfg.value("autoOffMeshMaxComp", 3),
                                        BASE_UNIT_DIM * offCfg.value("walkableRadius", 2),
                                        meshData, st);
            if (st[0] > 0 || st[1] > 0)
                printf("%s [AUTOOFFMESH] closed %d comp(s) -> +%d bidirectional link(s)"
                       "   (candidates %d, rejected %d)\n",
                       tileString, st[1], st[0], st[3], st[2]);
        }

        params.offMeshConVerts = meshData.offMeshConnections.getCArray();
        params.offMeshConCount = meshData.offMeshConnections.size() / 6;
        params.offMeshConRad = meshData.offMeshConnectionRads.getCArray();
        params.offMeshConDir = meshData.offMeshConnectionDirs.getCArray();
        params.offMeshConAreas = meshData.offMeshConnectionsAreas.getCArray();
        params.offMeshConFlags = meshData.offMeshConnectionsFlags.getCArray();

        params.walkableHeight = BASE_UNIT_DIM * config.walkableHeight;
        params.walkableRadius = BASE_UNIT_DIM * config.walkableRadius;
        params.walkableClimb = BASE_UNIT_DIM * config.walkableClimb;

        params.tileX = (((bmin[0] + bmax[0]) / 2) - navMesh->getParams()->orig[0]) / GRID_SIZE;
        params.tileY = (((bmin[2] + bmax[2]) / 2) - navMesh->getParams()->orig[2]) / GRID_SIZE;
        rcVcopy(params.bmin, bmin);
        rcVcopy(params.bmax, bmax);
        params.cs = config.cs;
        params.ch = config.ch;
        params.tileLayer = 0;
        params.buildBvTree = true;

        // will hold final navmesh
        unsigned char* navData = NULL;
        int navDataSize = 0;

        do
        {
            // these values are checked within dtCreateNavMeshData - handle them here
            // so we have a clear error messages
            if (params.nvp > DT_VERTS_PER_POLYGON)
            {
                printf("%s Invalid verts-per-polygon value!                   \n", tileString);
                continue;
            }
            if (params.vertCount >= 0xffff)
            {
                printf("%s Too many vertices!                                 \n", tileString);
                continue;
            }
            if (!params.vertCount || !params.verts)
            {
                // occurs mostly when adjacent tiles have models
                // loaded but those models don't span into this tile

                // message is an annoyance
                //printf("%sNo vertices to build tile!              \n", tileString);
                continue;
            }
            if (!params.polyCount || !params.polys ||
                    TILES_PER_MAP * TILES_PER_MAP == params.polyCount)
            {
                // we have flat tiles with no actual geometry - don't build those, its useless
                // keep in mind that we do output those into debug info
                // drop tiles with only exact count - some tiles may have geometry while having less tiles
                printf("%s No polygons to build on tile!                      \n", tileString);
                continue;
            }
            if (!params.detailMeshes || !params.detailVerts || !params.detailTris)
            {
                printf("%s No detail mesh to build tile!                      \n", tileString);
                continue;
            }

            printf("%s Building navmesh tile...                           \r", tileString);
            if (!dtCreateNavMeshData(&params, &navData, &navDataSize))
            {
                printf("%s Failed building navmesh tile!                      \n", tileString);
                continue;
            }

            dtTileRef tileRef = 0;
            printf("%s Adding tile to navmesh...                          \r", tileString);
            // DT_TILE_FREE_DATA tells detour to unallocate memory when the tile
            // is removed via removeTile()
            dtStatus dtResult = navMesh->addTile(navData, navDataSize, DT_TILE_FREE_DATA, 0, &tileRef);
            if (!tileRef || dtStatusFailed(dtResult))
            {
                // ⚠️ 这里失败意味着**这一格不会被写出去** —— 下面直接 continue。
                //    但地图级最后只会打印 "Movemap build is complete!"，
                //    所以"静默丢格"是可能的：实测 555 的 [32,32] 曾因
                //    DT_OUT_OF_MEMORY（maxPolys/maxTiles 用尽或真没内存）失败，
                //    整张图仍然报 complete。
                //    加一个**可 grep 的标记**，方便批量检查有没有漏格的图：
                //        findstr /C:"[TILE-FAILED]" build.log
                printf("[TILE-FAILED] map=%u tile=%u,%u reasons=addTile failed: %s\n",
                       mapID, tileX, tileY, GetDTErrorReason(dtResult));
                continue;
            }

            // file output
            char fileName[1024];
            sprintf(fileName, "%s/mmaps/%03u%02i%02i.mmtile", m_workdir, mapID, tileY, tileX);
            FILE* file = fopen(fileName, "wb");
            if (!file)
            {
                char message[1024];
                sprintf(message, "[Map %03i] Failed to open %s for writing!             \n", mapID, fileName);
                perror(message);
                navMesh->removeTile(tileRef, NULL, NULL);
                continue;
            }

            printf("%s Writing to file...                                 \r", tileString);

            // write header
            MmapTileHeader header;
            header.size = uint32(navDataSize);
            header.usesLiquids = m_terrainBuilder->usesLiquids() ? 1 : 0;
            fwrite(&header, sizeof(MmapTileHeader), 1, file);

            // write data
            fwrite(navData, sizeof(unsigned char), navDataSize, file);
            fclose(file);

            // now that tile is written to disk, we can unload it
            navMesh->removeTile(tileRef, nullptr, nullptr);
        }
        while (0);

        if (m_debug)
        {
            // restore padding so that the debug visualization is correct
            for (int i = 0; i < iv.polyMesh->nverts; ++i)
            {
                unsigned short* v = &iv.polyMesh->verts[i * 3];
                v[0] += (unsigned short)config.borderSize;
                v[2] += (unsigned short)config.borderSize;
            }

            iv.generateObjFile(mapID, tileX, tileY, meshData);
            iv.writeIV(mapID, tileX, tileY);
        }
    }

    // Cells that a player can actually walk on. NAV_AREA_GROUND_STEEP spans are
    // obstacles for players (see rcModAlmostUnwalkableTriangles).
    static bool isPlayerWalkableArea(unsigned char area)
    {
        return area != RC_NULL_AREA && area != NAV_AREA_GROUND_STEEP;
    }

    /**
     * Closes one cell wide unwalkable seams in the heightfield.
     *
     * A crack between two terrain surfaces (or a shallow crevice) shows up as a
     * single cell column without any walkable span. rcBuildCompactHeightfield
     * drops such a column, so the seam becomes a hole in the compact
     * heightfield and rcErodeWalkableArea widens it from 1 cell to
     * 1 + 2 * walkableRadius cells, which can cut the navigation mesh into
     * disconnected islands that no creature can path out of.
     *
     * A column is only bridged when it is safe to step across:
     *   - it has no walkable span of its own (the walkable surface is missing,
     *     not merely disconnected),
     *   - two opposite neighbours are walkable and their surfaces differ by no
     *     more than walkableClimb,
     *   - nothing inside the column rises more than walkableClimb above those
     *     neighbour surfaces (a thin wall / pillar stays a wall), and
     *   - the column holds no NAV_AREA_GROUND_STEEP span (these are deliberate
     *     player obstacles, walls are often thinner than the agent radius).
     */
    static void closeThinSeams(rcContext* context, rcHeightfield& solid, const rcConfig& cfg, int maxRise, SeamFixStats& stats)
    {
        for (int z = 1; z + 1 < solid.height; ++z)
        {
            for (int x = 1; x + 1 < solid.width; ++x)
            {
                const int columnIndex = x + z * solid.width;

                bool hasWalkable = false;
                bool hasSteep = false;
                for (rcSpan* s = solid.spans[columnIndex]; s; s = s->next)
                {
                    if (isPlayerWalkableArea(s->area))
                        hasWalkable = true;
                    if (s->area == NAV_AREA_GROUND_STEEP)
                        hasSteep = true;
                }

                // existing walkable surface: nothing to do
                if (hasWalkable)
                {
                    stats.walkable++;
                    continue;
                }

                // top most walkable surface of every neighbour column
                int nbrTop[4];
                unsigned char nbrArea[4];
                int walkableNeighbours = 0;
                for (int dir = 0; dir < 4; ++dir)
                {
                    nbrTop[dir] = -1;
                    nbrArea[dir] = RC_NULL_AREA;

                    const int nx = x + rcGetDirOffsetX(dir);
                    const int nz = z + rcGetDirOffsetY(dir);
                    for (rcSpan* s = solid.spans[nx + nz * solid.width]; s; s = s->next)
                    {
                        if (isPlayerWalkableArea(s->area) && int(s->smax) > nbrTop[dir])
                        {
                            nbrTop[dir] = int(s->smax);
                            nbrArea[dir] = s->area;
                        }
                    }

                    if (nbrTop[dir] >= 0)
                        walkableNeighbours++;
                }

                // only cells that touch walkable ground are interesting
                if (!walkableNeighbours)
                    continue;

                if (hasSteep)
                {
                    stats.steep++;
                    continue;
                }

                // top of everything this column contains
                int highest = 0;
                for (rcSpan* s = solid.spans[columnIndex]; s; s = s->next)
                    highest = rcMax(highest, int(s->smax));

                // an opposite pair of walkable neighbours that can be crossed
                int bridge = -1;
                unsigned char bridgeArea = RC_NULL_AREA;
                for (int dir = 0; dir < 2 && bridge < 0; ++dir)
                {
                    const int opposite = (dir + 2) & 3;
                    if (nbrTop[dir] < 0 || nbrTop[opposite] < 0)
                        continue;
                    if (rcAbs(nbrTop[dir] - nbrTop[opposite]) > cfg.walkableClimb)
                        continue;

                    const int top = rcMax(nbrTop[dir], nbrTop[opposite]);

                    // Geometry that rises more than this above the walkable
                    // surface on both sides is a real obstacle and stays
                    // unwalkable. maxRise widens the tolerance (see the
                    // "seamBridgeMaxRise" generator option).
                    if (highest > top + cfg.walkableClimb + maxRise)
                    {
                        stats.wall++;
                        continue;
                    }

                    bridge = top;
                    bridgeArea = rcMax(nbrArea[dir], nbrArea[opposite]);
                }

                if (bridge < 0)
                {
                    stats.noFlank++;
                    continue;
                }

                // Truncate the column at the bridge level, so the walkable span
                // that survives has exactly the height of both neighbours: a
                // taller span would keep them more than walkableClimb apart and
                // a remaining low clearance would keep them disconnected.
                // Spans live in the heightfield pool, unlinking frees nothing.
                bool marked = false;
                rcSpan* prevSpan = NULL;
                rcSpan* curSpan = solid.spans[columnIndex];
                while (curSpan)
                {
                    rcSpan* nextSpan = curSpan->next;
                    if (int(curSpan->smin) > bridge)
                    {
                        if (prevSpan)
                            prevSpan->next = nextSpan;
                        else
                            solid.spans[columnIndex] = nextSpan;
                        curSpan = nextSpan;
                        continue;
                    }
                    if (int(curSpan->smax) >= bridge)
                    {
                        curSpan->smax = (unsigned short)bridge;
                        curSpan->area = bridgeArea;
                        marked = true;
                    }
                    prevSpan = curSpan;
                    curSpan = nextSpan;
                }

                if (!marked)
                {
                    if (!rcAddSpan(context, solid, x, z, (unsigned short)bridge, (unsigned short)bridge,
                                   bridgeArea, cfg.walkableClimb))
                        continue;
                }

                stats.closed++;
                const int rise = rcMax(0, highest - bridge);
                if (rise <= 1)
                    stats.riseLe1++;
                else if (rise <= 4)
                    stats.riseLe4++;
                else if (rise <= 8)
                    stats.riseLe8++;
                else
                    stats.riseMore++;
            }
        }
    }

    /* =======================================================================
     * [DEBUG] Dump the intermediate Recast data to disk.
     *
     * Enable with the environment variable MMAP_DEBUG_DUMP=<existing dir>.
     * Three files are written per sub-tile:
     *   <map>_<tx>_<ty>_s<sx><sy>.tri    triangles handed to rcRasterizeTriangles + area flags
     *   <map>_<tx>_<ty>_s<sx><sy>.rawhf  raw heightfield after the 3 filters + closeThinSeams
     *   <map>_<tx>_<ty>_s<sx><sy>.chf    compact heightfield after rcBuildCompactHeightfield
     *
     * Why: the navmesh surface sits above the real floor. Two places can cause
     * that and neither is visible with the existing tools:
     *   1) rasterization: rasterizeTri sets the span smax to ceilf(maxY/ch) - it
     *      always rounds up, at most +1 ch;
     *   2) span merging: addSpan merges by [smin,smax] overlap, so a taller
     *      surface in the same column (pillar / ceiling / wall) lifts smax.
     * Recast.cpp:473 shows chf.spans[i].y is *exactly* the raw span smax, so
     * comparing .rawhf smax against the triangle heights in .tri settles which.
     *
     * All coordinates are Recast internal: world (X,Y) -> Recast (z,x), height on axis 1.
     * Absolute height = bmin[1] + y * ch.
     * ======================================================================= */
    // [DEBUG] 前向声明（已在文件顶部给出，这里保留注释说明原因）。
    static FILE* dumpOpen(const DumpCtx& d, const char* suffix)
    {
        const char* dir = std::getenv("MMAP_DEBUG_DUMP");
        if (!dir || !*dir || !d.enabled)
            return NULL;
        char name[1024];
        snprintf(name, sizeof(name), "%s/%03u_%02u_%02u_s%02i%02i.%s",
                 dir, d.map, d.tileX, d.tileY, d.subX, d.subY, suffix);
        FILE* f = fopen(name, "wb");
        if (!f)
            printf("[dump] cannot open %s\n", name);
        return f;
    }

    static void dumpHeader(const DumpCtx& d, FILE* f, const char* magic)
    {
        const uint32 version = 1;
        fwrite(magic, 1, 4, f);
        fwrite(&version, 4, 1, f);
        fwrite(&d.map, 4, 1, f);
        fwrite(&d.tileX, 4, 1, f);
        fwrite(&d.tileY, 4, 1, f);
        int sub[2] = { d.subX, d.subY };
        fwrite(sub, 4, 2, f);
    }

    static void dumpTriangles(const DumpCtx& d, const rcConfig& cfg, const float* verts, int vertCount, const int* tris, int triCount, const unsigned char* flags)
    {
        FILE* f = dumpOpen(d, "tri");
        if (!f)
            return;
        dumpHeader(d, f, "MTRI");
        fwrite(&vertCount, 4, 1, f);
        fwrite(&triCount, 4, 1, f);
        fwrite(cfg.bmin, 4, 3, f);
        fwrite(cfg.bmax, 4, 3, f);
        fwrite(&cfg.cs, 4, 1, f);
        fwrite(&cfg.ch, 4, 1, f);
        fwrite(&cfg.walkableHeight, 4, 1, f);
        fwrite(&cfg.walkableClimb, 4, 1, f);
        fwrite(&cfg.walkableRadius, 4, 1, f);
        fwrite(&cfg.walkableSlopeAngle, 4, 1, f);
        fwrite(verts, 4, (size_t)vertCount * 3, f);
        fwrite(tris, 4, (size_t)triCount * 3, f);
        fwrite(flags, 1, (size_t)triCount, f);
        fclose(f);
    }

    // rcSpan heights are bitfields, taking their address is illegal, copy first
    static void dumpRawHeightfield(const DumpCtx& d, const rcHeightfield& hf)
    {
        FILE* f = dumpOpen(d, "rawhf");
        if (!f)
            return;
        dumpHeader(d, f, "MRHF");
        fwrite(&hf.width, 4, 1, f);
        fwrite(&hf.height, 4, 1, f);
        fwrite(hf.bmin, 4, 3, f);
        fwrite(hf.bmax, 4, 3, f);
        fwrite(&hf.cs, 4, 1, f);
        fwrite(&hf.ch, 4, 1, f);
        for (int i = 0; i < hf.width * hf.height; ++i)
        {
            unsigned short n = 0;
            for (const rcSpan* s = hf.spans[i]; s; s = s->next)
                ++n;
            fwrite(&n, 2, 1, f);
            for (const rcSpan* s = hf.spans[i]; s; s = s->next)
            {
                unsigned short a = (unsigned short)s->smin;
                unsigned short b = (unsigned short)s->smax;
                fwrite(&a, 2, 1, f);
                fwrite(&b, 2, 1, f);
                fwrite(&s->area, 1, 1, f);
            }
        }
        fclose(f);
    }

    static void dumpCompactHeightfield(const DumpCtx& d, const rcCompactHeightfield& chf)
    {
        FILE* f = dumpOpen(d, "chf");
        if (!f)
            return;
        dumpHeader(d, f, "MCHF");
        fwrite(&chf.width, 4, 1, f);
        fwrite(&chf.height, 4, 1, f);
        fwrite(&chf.spanCount, 4, 1, f);
        fwrite(chf.bmin, 4, 3, f);
        fwrite(chf.bmax, 4, 3, f);
        fwrite(&chf.cs, 4, 1, f);
        fwrite(&chf.ch, 4, 1, f);
        fwrite(&chf.walkableHeight, 4, 1, f);
        fwrite(&chf.walkableClimb, 4, 1, f);
        const int cells = chf.width * chf.height;
        for (int i = 0; i < cells; ++i)
        {
            unsigned int idx = (unsigned int)chf.cells[i].index;
            unsigned char cnt = (unsigned char)chf.cells[i].count;
            fwrite(&idx, 4, 1, f);
            fwrite(&cnt, 1, 1, f);
        }
        for (int i = 0; i < (int)chf.spanCount; ++i)
        {
            unsigned short y = (unsigned short)chf.spans[i].y;
            unsigned char h = (unsigned char)chf.spans[i].h;
            fwrite(&y, 2, 1, f);
            fwrite(&h, 1, 1, f);
            fwrite(&chf.areas[i], 1, 1, f);
        }
        fclose(f);
    }

    // [DEBUG] 轮廓集（rcBuildContours 的输出）。
    // ⚠️ 存在的理由：实测发现有些导航面在"输入三角形里根本没有几何"的位置也存在
    //    （555 的 #1935/#1936，4 码内 .tri 里 0 个三角，.rawhf 里 0 个 span，
    //     但 .mmtile 里有两个 0.8x13.6 码的细长面，其中一个整体高出 64*ch）。
    //    要定位只能看轮廓是从哪来的 —— 这个转储就是给那一步用的。
    static void dumpContourSet(const DumpCtx& d, const rcContourSet& cs)
    {
        FILE* f = dumpOpen(d, "contour");
        if (!f)
            return;
        dumpHeader(d, f, "MCTS");
        fwrite(&cs.nconts, 4, 1, f);
        fwrite(cs.bmin, 4, 3, f);
        fwrite(cs.bmax, 4, 3, f);
        fwrite(&cs.cs, 4, 1, f);
        fwrite(&cs.ch, 4, 1, f);
        fwrite(&cs.width, 4, 1, f);
        fwrite(&cs.height, 4, 1, f);
        fwrite(&cs.borderSize, 4, 1, f);
        for (int i = 0; i < cs.nconts; ++i)
        {
            const rcContour& c = cs.conts[i];
            fwrite(&c.nverts, 4, 1, f);
            fwrite(&c.nrverts, 4, 1, f);
            fwrite(&c.reg, 4, 1, f);
            fwrite(&c.area, 4, 1, f);
            for (int k = 0; k < c.nverts * 4; ++k)
            {
                unsigned short v = (unsigned short)c.verts[k];
                fwrite(&v, 2, 1, f);
            }
        }
        fclose(f);
    }

    // [DEBUG] 多边形网格（rcBuildPolyMesh 的输出）—— 最终 .mmtile 的面就是从这来的。
    static void dumpPolyMesh(const DumpCtx& d, const rcPolyMesh& pm)
    {
        FILE* f = dumpOpen(d, "pmesh");
        if (!f)
            return;
        dumpHeader(d, f, "MPMS");
        fwrite(&pm.nverts, 4, 1, f);
        fwrite(&pm.npolys, 4, 1, f);
        fwrite(&pm.nvp, 4, 1, f);
        fwrite(&pm.cs, 4, 1, f);
        fwrite(&pm.ch, 4, 1, f);
        fwrite(pm.bmin, 4, 3, f);
        fwrite(pm.bmax, 4, 3, f);
        for (int i = 0; i < pm.nverts * 3; ++i)
        {
            unsigned short v = (unsigned short)pm.verts[i];
            fwrite(&v, 2, 1, f);
        }
        const int stride = pm.nvp * 2;
        for (int i = 0; i < pm.npolys; ++i)
        {
            for (int k = 0; k < stride; ++k)
            {
                unsigned short v = (unsigned short)pm.polys[i * stride + k];
                fwrite(&v, 2, 1, f);
            }
            fwrite(&pm.regs[i], 2, 1, f);
            fwrite(&pm.areas[i], 1, 1, f);
        }
        fclose(f);
    }

    /**
     * 把一个高度场里的 span 链**并入**另一个（两个高度场必须网格一致）。
     *
     * 为什么要拆两个高度场：站长口径（2026-10-18）——
     *   **ADT 地面什么校验都不做、永远可通行；WMO/M2 的行为与之前完全一致。**
     * 而 Recast 的 rcFilterLedgeSpans / rcFilterLowHangingWalkableObstacles /
     * rcFilterWalkableLowHeightSpans 都作用在**整个高度场**上，没有"地形 / 模型"标记，
     * 所以只能：地形光栅化到 hfA（不过滤）、模型光栅化到 hfB（跑原来的三条过滤），
     * 再把 hfA 的 span 并回 hfB 继续走后面的 compact heightfield / region / polyMesh。
     *
     * 用 Recast 自带的 rcAddSpan 追加：它会保持 smin 有序、并把重叠的 span 合并，
     * 属于"加面"不是"删面"，正合本意。
     */
    static bool mergeHeightfields(rcContext* ctx, rcHeightfield& dst, const rcHeightfield& src)
    {
        if (dst.width != src.width || dst.height != src.height)
            return false;
        for (int y = 0; y < dst.height; ++y)
        {
            for (int x = 0; x < dst.width; ++x)
            {
                for (const rcSpan* s = src.spans[x + y * src.width]; s; s = s->next)
                {
                    if (!rcAddSpan(ctx, dst, x, y, s->smin, s->smax, s->area, 0))
                        return false;
                }
            }
        }
        return true;
    }

    bool MapBuilder::buildCommonTile(const char* tileString, const DumpCtx& dbg, Tile& tile, rcConfig& tileCfg, float* tVerts, int tVertCount, int* tTris, int tTriCount, float* lVerts, int lVertCount,
                                     int* lTris, int lTriCount, uint8* lTriFlags, int preErosionMedianPasses, int seamBridgeMaxRise, SeamFixStats* seamStats,
                                     int terrainTriCount, float terrainSlopeAngle, bool splitTerrain)
    {
        // ⚠️ Recast 的 walkableHeight / walkableClimb 是**体素数**（以 ch 为单位），
        //    而 config.json 里的值是以 BASE_UNIT_DIM 为单位的物理量。
        //    cs = ch = BASE_UNIT_DIM 的年代两者恰好数值相等，所以直接传；
        //    ch 一改就悄悄错位 —— walkableClimb=4 会从 1.07 码缩到 0.71 码，
        //    等于把怪物能迈的台阶砍掉 1/3，地图还会因此多出大量可行走面（体积暴涨）。
        //    这里按 ch 折算成体素数再交给 Recast。
        //
        //    Detour 侧（params.walkableHeight/Radius/Climb）**不动**，仍然是
        //    BASE_UNIT_DIM * 原值，所以导航数据里那几个物理量保持与线上完全一致。
        //
        //    注意用局部副本：tileCfg 是 625 个子格共用的，就地改会累乘。
        rcConfig cfg = tileCfg;
        cfg.walkableHeight = (int)roundf(BASE_UNIT_DIM * float(tileCfg.walkableHeight) / CELL_HEIGHT);
        cfg.walkableClimb  = (int)roundf(BASE_UNIT_DIM * float(tileCfg.walkableClimb) / CELL_HEIGHT);
        if (cfg.walkableHeight < 1) cfg.walkableHeight = 1;
        if (cfg.walkableClimb < 0) cfg.walkableClimb = 0;

        // Build heightfield for walkable area
        tile.solid = rcAllocHeightfield();
        if (!tile.solid || !rcCreateHeightfield(m_rcContext, *tile.solid, tileCfg.width, tileCfg.height, tileCfg.bmin, tileCfg.bmax, tileCfg.cs, tileCfg.ch))
        {
            printf("%s Failed building heightfield!                       \n", tileString);
            return false;
        }

        // mark all walkable tiles, both liquids and solids
        unsigned char* triFlags = new unsigned char[tTriCount];
        memset(triFlags, NAV_AREA_GROUND, tTriCount * sizeof(unsigned char));
        rcClearUnwalkableTriangles(m_rcContext, tileCfg.walkableSlopeAngle, tVerts, tVertCount, tTris, tTriCount, triFlags);

        // 【地形 vs 模型】只对 **ADT 地形**放宽坡度限制。
        //
        // 为什么：官服能走的缓坡，我们用 60° 烘出来是碎的 —— 530 的 26_19 那片区
        // （406x292 码、起伏 118 码）目标连通块只有 1724 面，而把角度放到 90 后涨到
        // 3402 面。但 90 度对 **建筑模型** 是不合适的：WMO 的垂直面会被当成可行走，
        // 怪物会贴墙走。
        //
        // solidTris 的顺序是"地形在前、模型在后"（loadMap 先跑、loadVMap 后跑），
        // 所以前 terrainTriCount 个三角是地形，只放宽这一段。
        const int terrainTriLimit = (terrainTriCount > 0 && terrainTriCount < tTriCount)
                                    ? terrainTriCount : 0;
        const float terrainSlope = terrainSlopeAngle;
        if (terrainTriLimit > 0 && terrainSlope > tileCfg.walkableSlopeAngle)
        {
            const float terrainThr = cosf(terrainSlope / 180.0f * RC_PI);
            int restored = 0;
            for (int ti = 0; ti < terrainTriLimit; ++ti)
            {
                if (triFlags[ti] & RC_WALKABLE_AREA)
                    continue;                       // 本来就判定可走
                const int* tri = &tTris[ti * 3];
                float e0[3], e1[3], nrm[3];
                rcVsub(e0, &tVerts[tri[1] * 3], &tVerts[tri[0] * 3]);
                rcVsub(e1, &tVerts[tri[2] * 3], &tVerts[tri[0] * 3]);
                rcVcross(nrm, e0, e1);
                rcVnormalize(nrm);
                if (nrm[1] > terrainThr)            // 按放宽后的角度算，可走
                {
                    triFlags[ti] = NAV_AREA_GROUND;
                    ++restored;
                }
            }
            // ⚠️ buildCommonTile 是**每个子格**调用一次（一个 tile 625 个），
            //    所以这条日志只在 sub-tile (0,0) 打，否则会刷 625 行。
            if (dbg.enabled && dbg.subX == 0 && dbg.subY == 0)
                printf("%s [TERRAIN-SLOPE] relaxed %d/%d terrain tris (< %.0f deg)\n",
                       tileString, restored, terrainTriLimit, terrainSlope);
        }

        // mark almost unwalkable triangles with steep flag
        // 标"接近不可走"的三角。⚠️ 只对**模型段**标 STEEP —— 地形段已经按 terrainSlopeAngle
        // 放过了，再标成 STEEP 会把它重新排除在怪物可走范围之外。
        rcModAlmostUnwalkableTriangles(m_rcContext, tileCfg.walkableSlopeAngle,
                                       tVerts, tVertCount, tTris, tTriCount, triFlags);
        if (terrainTriLimit > 0)
        {
            // 地形段里被判成 STEEP 的，恢复成普通 GROUND
            for (int ti = 0; ti < terrainTriLimit; ++ti)
                if ((triFlags[ti] & 0x3F) == NAV_AREA_GROUND_STEEP)
                    triFlags[ti] = NAV_AREA_GROUND;
        }

        // ── 【地形 / 模型分开烘】 ──────────────────────────────────────────
        //
        // 站长口径（2026-10-18）：**ADT 地面什么校验都不做、永远可通行；
        // WMO/M2 的行为与之前完全一致。**
        //
        // tTris 的顺序是"地形在前、模型在后"（loadMap 先跑、loadVMap 后跑），
        // terrainTriLimit 就是分界点（0 表示这块没有地形）。
        //   · 地形段 → 单独的高度场，**一条过滤器都不跑**
        //   · 模型段 → tile.solid，跑原来的三条过滤
        // 最后把地形高度场的 span 并用 rcAddSpan 追加进 tile.solid。
        //
        // ⚠️⚠️ 默认**关闭**（splitTerrain = false）—— 这一段在 2026-10-18 的全量烘焙里
        //     让 map 001 崩了：退出码 0xC0000005（访问违规），跑到第 477/1018 格、
        //     打完 `[TERRAIN-RAW] ... rasterized` 之后立刻死，没有 Recast 报错。
        //     单格/小图（530、547）验证是好的（530 的目标连通块 856 → 7,165 面），
        //     但**大图会崩**，所以先关掉，等把合并那一步查清楚再开。
        // splitTerrain 由调用方传入（这个函数拿不到 json）。
        rcHeightfield* hfTerrain = nullptr;
        const int modelTriOff = splitTerrain ? terrainTriLimit * 3 : 0;
        const int modelTriN   = splitTerrain ? (tTriCount - terrainTriLimit) : tTriCount;

        if (splitTerrain && terrainTriLimit > 0)
        {
            hfTerrain = rcAllocHeightfield();
            if (!hfTerrain || !rcCreateHeightfield(m_rcContext, *hfTerrain, tileCfg.width, tileCfg.height,
                                                   tileCfg.bmin, tileCfg.bmax, tileCfg.cs, tileCfg.ch))
            {
                printf("%s Failed building terrain heightfield!               \n", tileString);
                rcFreeHeightField(hfTerrain);
                delete[] triFlags;
                return false;
            }
            rcRasterizeTriangles(m_rcContext, tVerts, tVertCount, tTris, triFlags, terrainTriLimit,
                                 *hfTerrain, cfg.walkableClimb);
            if (dbg.enabled && dbg.subX == 0 && dbg.subY == 0)
                printf("%s [TERRAIN-RAW] %d terrain tris rasterized, no span filters applied\n",
                       tileString, terrainTriLimit);
        }

        if (splitTerrain && modelTriN > 0)
        {
            rcRasterizeTriangles(m_rcContext, tVerts, tVertCount, tTris + modelTriOff,
                                 triFlags + terrainTriLimit, modelTriN, *tile.solid, cfg.walkableClimb);
            rcFilterLowHangingWalkableObstacles(m_rcContext, cfg.walkableClimb, *tile.solid);
            rcFilterLedgeSpans(m_rcContext, cfg.walkableHeight, cfg.walkableClimb, *tile.solid);
            rcFilterWalkableLowHeightSpans(m_rcContext, cfg.walkableHeight, *tile.solid);
        }
        else if (!splitTerrain)
        {
            // 老路径：整体光栅化 + 三条过滤器（splitTerrain 关闭时的默认行为）
            rcRasterizeTriangles(m_rcContext, tVerts, tVertCount, tTris, triFlags, tTriCount,
                                 *tile.solid, cfg.walkableClimb);
            rcFilterLowHangingWalkableObstacles(m_rcContext, cfg.walkableClimb, *tile.solid);
            rcFilterLedgeSpans(m_rcContext, cfg.walkableHeight, cfg.walkableClimb, *tile.solid);
            rcFilterWalkableLowHeightSpans(m_rcContext, cfg.walkableHeight, *tile.solid);
        }

        // 把"不过滤"的地形 span 并回来
        if (hfTerrain)
        {
            if (!mergeHeightfields(m_rcContext, *tile.solid, *hfTerrain))
                printf("%s mergeHeightfields(terrain) FAILED                   \n", tileString);
            rcFreeHeightField(hfTerrain);
            hfTerrain = nullptr;
        }

        dumpTriangles(dbg, cfg, tVerts, tVertCount, tTris, tTriCount, triFlags);
        delete[] triFlags;

        if (lVerts)
            rcRasterizeTriangles(m_rcContext, lVerts, lVertCount, lTris, lTriFlags, lTriCount, *tile.solid, cfg.walkableClimb);

        // close one cell wide unwalkable seams before they get widened by the erosion below
        SeamFixStats localSeamStats;
        closeThinSeams(m_rcContext, *tile.solid, cfg, seamBridgeMaxRise, localSeamStats);
        dumpRawHeightfield(dbg, *tile.solid);
        if (seamStats)
        {
            seamStats->closed += localSeamStats.closed;
            seamStats->wall += localSeamStats.wall;
            seamStats->steep += localSeamStats.steep;
            seamStats->noFlank += localSeamStats.noFlank;
            seamStats->walkable += localSeamStats.walkable;
            seamStats->riseLe1 += localSeamStats.riseLe1;
            seamStats->riseLe4 += localSeamStats.riseLe4;
            seamStats->riseLe8 += localSeamStats.riseLe8;
            seamStats->riseMore += localSeamStats.riseMore;
        }

        // compact heightfield spans
        tile.chf = rcAllocCompactHeightfield();
        if (!tile.chf || !rcBuildCompactHeightfield(m_rcContext, cfg.walkableHeight, cfg.walkableClimb, *tile.solid, *tile.chf))
        {
            printf("%s Failed compacting heightfield!                     \n", tileString);
            return false;
        }
        dumpCompactHeightfield(dbg, *tile.chf);

        // Optional median filter passes before the erosion. The median filter
        // removes area ids that have no majority in their 3x3 neighbourhood, so
        // running it first smooths the walkable area before rcErodeWalkableArea
        // can widen a narrow seam. Configurable with the generator option
        // "preErosionMedianPasses" in config.json (default 1, missing key means 1).
        for (int pass = 0; pass < preErosionMedianPasses; ++pass)
        {
            if (!rcMedianFilterWalkableArea(m_rcContext, *tile.chf))
            {
                printf("%s Failed filtering area before erosion!              \n", tileString);
                return false;
            }
        }

        // build polymesh intermediates
        if (!rcErodeWalkableArea(m_rcContext, tileCfg.walkableRadius, *tile.chf))
        {
            printf("%s Failed eroding area!                               \n", tileString);
            return false;
        }

        if (!rcMedianFilterWalkableArea(m_rcContext, *tile.chf))
        {
            printf("%s Failed filtering area!                             \n", tileString);
            return false;
        }

        if (!rcBuildDistanceField(m_rcContext, *tile.chf))
        {
            printf("%s Failed building distance field!                    \n", tileString);
            return false;
        }

        if (!rcBuildRegions(m_rcContext, *tile.chf, tileCfg.borderSize, tileCfg.minRegionArea, tileCfg.mergeRegionArea))
        {
            printf("%s Failed building regions!                           \n", tileString);
            return false;
        }

        tile.cset = rcAllocContourSet();
        if (!tile.cset || !rcBuildContours(m_rcContext, *tile.chf, tileCfg.maxSimplificationError, tileCfg.maxEdgeLen, *tile.cset))
        {
            printf("%s Failed building contours!                          \n", tileString);
            return false;
        }
        dumpContourSet(dbg, *tile.cset);

        // build polymesh
        tile.pmesh = rcAllocPolyMesh();
        if (!tile.pmesh || !rcBuildPolyMesh(m_rcContext, *tile.cset, tileCfg.maxVertsPerPoly, *tile.pmesh))
        {
            printf("%s Failed building polymesh!                          \n", tileString);
            return false;
        }
        dumpPolyMesh(dbg, *tile.pmesh);

        tile.dmesh = rcAllocPolyMeshDetail();
        if (!tile.dmesh || !rcBuildPolyMeshDetail(m_rcContext, *tile.pmesh, *tile.chf, tileCfg.detailSampleDist, tileCfg.detailSampleMaxError, *tile.dmesh))
        {
            printf("%s Failed building polymesh detail!                   \n", tileString);
            return false;
        }

        // free those up
        // we may want to keep them in the future for debug
        // but right now, we don't have the code to merge them
        rcFreeHeightField(tile.solid);
        tile.solid = nullptr;
        rcFreeCompactHeightfield(tile.chf);
        tile.chf = nullptr;
        rcFreeContourSet(tile.cset);
        tile.cset = nullptr;
        return true;
    }

    /**************************************************************************/
    void MapBuilder::getTileBounds(uint32 tileX, uint32 tileY, float* verts, int vertCount, float* bmin, float* bmax)
    {
        // this is for elevation
        if (verts && vertCount)
            rcCalcBounds(verts, vertCount, bmin, bmax);
        else
        {
            bmin[1] = FLT_MIN;
            bmax[1] = FLT_MAX;
        }

        // this is for width and depth
        bmax[0] = (32 - int(tileX)) * GRID_SIZE;
        bmax[2] = (32 - int(tileY)) * GRID_SIZE;
        bmin[0] = bmax[0] - GRID_SIZE;
        bmin[2] = bmax[2] - GRID_SIZE;
    }

    /**************************************************************************/
    bool MapBuilder::shouldSkipMap(uint32 mapID)
    {
        if (m_skipContinents)
            switch (mapID)
            {
                case 0:
                case 1:
                case 530:
                    return true;
                default:
                    break;
            }

        if (m_skipJunkMaps)
            switch (mapID)
            {
                case 13:    // test.wdt
                case 25:    // ScottTest.wdt
                case 29:    // Test.wdt
                case 42:    // Colin.wdt
                case 169:   // EmeraldDream.wdt (unused, and very large)
                case 451:   // development.wdt
                    return true;
                default:
                    if (isTransportMap(mapID))
                        return true;
                    break;
            }

        if (m_skipBattlegrounds)
            switch (mapID)
            {
                case 30:    // AV
                case 37:    // ?
                case 489:   // WSG
                case 529:   // AB
                case 566:   // EotS
                    return true;
                default:
                    break;
            }

        return false;
    }

    /**************************************************************************/
    bool MapBuilder::isTransportMap(uint32 mapID)
    {
        switch (mapID)
        {
            // transport maps
            case 582:
            case 584:
            case 586:
            case 587:
            case 588:
            case 589:
            case 590:
            case 591:
            case 593:
                return true;
            default:
                return false;
        }
    }

    /**************************************************************************/
    bool MapBuilder::shouldSkipTile(uint32 mapID, uint32 tileX, uint32 tileY)
    {
        char fileName[255];
        sprintf(fileName, "%s/mmaps/%03u%02i%02i.mmtile", m_workdir, mapID, tileY, tileX);
        FILE* file = fopen(fileName, "rb");
        if (!file)
            return false;

        MmapTileHeader header;
        int count = fread(&header, sizeof(MmapTileHeader), 1, file);
        fclose(file);
        if (count != 1)
            return false;

        if (header.mmapMagic != MMAP_MAGIC || header.dtVersion != uint32(DT_NAVMESH_VERSION))
            return false;

        if (header.mmapVersion != MMAP_VERSION)
            return false;

        return true;
    }

    json MapBuilder::getDefaultConfig()
    {
        return {
            {"borderSize", 5},
            {"detailSampleDist", BASE_UNIT_DIM * 16.0f},
            {"detailSampleMaxError", BASE_UNIT_DIM},
            {"maxEdgeLen", VERTEX_PER_TILE + 1},
            {"maxSimplificationError", 1.8f},
            {"mergeRegionArea", 50},
            // ⚠️ minRegionArea **不能设 0**！（2026-10-22 回归实测）
            //
            // 我一度按"ADT 地面不该被删"把它改成 0，结果**反而制造孤岛**：
            // Recast 的 mergeAndFilterRegions() 是两步
            //     ① 小于 mergeRegionArea 的区域 → 并进邻居
            //     ② 小于 minRegionArea 的区域   → 删掉
            // 设 0 之后第 ② 步一刀不砍，本该被清掉的**碎块全部留下来**，各自成一个连通分量。
            // 实测生态船(map 553) entry 17980 的刷点（世界 -204.13, 391.25，格 32_31）：
            //     minRegionArea=60 → 可达 835 面（连成一片）✓
            //     minRegionArea=0  → 可达   7 面（落在一颗碎块上）✗
            // 单参数二分同时排除了 walkableRadius / walkableClimb / terrainSlopeAngle（都不影响）。
            //
            // 60 经 rcSqr() 是 3600 cell ≈ 256 ㎡；以后想放宽往 20~30 试，**不要回到 0**。
            {"minRegionArea", 60},
            // ⚠️ walkableClimb 从 4 提到 5（= 1.3333 码，原来是 1.0667 码）。
            //    原因：实测有一处台沿高 1.18 码，只比旧阈值高 0.11 码，被判定
            //    "爬不上去"⇒ 那个平台成了 5 面孤岛，怪物刷在上面就走不下来
            //    （530 的 X1387.0 Y7392.7 高365.8）。这类"刚好卡在门槛外一点"
            //    的台沿在整张图里不会很多，但每一个都会变成卡怪点。
            //    5 × BASE_UNIT_DIM = 1.3333 码，对 WoW 生物是完全合理的台阶高度。
            {"walkableClimb", 5},
            {"walkableHeight", 6},
            // ⚠️ walkableRadius = 0：**不做侵蚀**（站长口径 2026-10-18："擦墙走是对的"）。
            //
            // 2（= 0.5333 码）时 rcErodeWalkableArea 会把每个可走区域**向内缩 0.53 码**：
            // 实测 547 关掉侵蚀后面数 +48%~66%（5473232：2,960 → 4,639）。
            // 0 ⇒ 侵蚀是空操作，边缘全部保住。
            // 注意：这个值同时会写进 `.mmtile` 头的 agent 半径，运行期 Detour 用它做
            // 寻路走廊约束 —— 0 意味着允许贴墙走，这是站长确认想要的行为。
            {"walkableRadius", 0},
            // 【模型】坡度上限：WMO / M2 仍然守 60°（官方值）。
            {"walkableSlopeAngle", 60.0f},
            // 【地形】坡度上限：只作用于 ADT 地形三角，默认不限制。
            // 官服能走的缓坡，我们用 60° 烘出来是碎的（实测 530 的 26_19 那片区
            // 目标连通块只有 1724 面，放到 90° 后 3402 面）。
            {"terrainSlopeAngle", 90.0f},
            {"liquidFlagMergeThreshold", 0.0f},
            {"preErosionMedianPasses", 1},

            // [AUTOOFFMESH] 自动补连（只在 --autoOffMesh 时生效）
            {"autoOffMeshMaxDH", 2.0f},      // 水平缺口上限（码）
            {"autoOffMeshMaxDV", 1.0f},      // 高差上限（码）。**不得超过 walkableClimb**
                                             // （默认 4 × BASE_UNIT_DIM = 1.0667），
                                             // 否则会把 Recast 故意判成不连通的台阶又连回来，
                                             // 变成"生物能爬上原本走不上去的台阶/矮墙"。
                                             // 实测 1.5 时有 12.8% 的连接超过 climb。
            {"autoOffMeshMaxComp", 3},       // 只给面数 <= 这个值的"小分量"补（实测定 3）
                                             // 2026-10-15 曾试改 5，**已回退**：实测该格
                                             // off-mesh 236 -> 327（+91 条，全局受益），
                                             // 但救不了 5302918（刀锋山 铸魔营地 3784，
                                             // 世界 1383.2/7392.8）那个点 —— 它被 dh/dv
                                             // 判据挡住，不是被 maxComp 挡住的。
                                             // 站长的处置：**参数一律保持原样，这个点
                                             // 单独用人工连接补**（offmesh 输入表）。
        };
    }

    json MapBuilder::getMapIdConfig(uint32 mapId)
    {
        std::string key = std::to_string(mapId);

        json config = getDefaultConfig();
        if (m_config.find(key) != m_config.end())
            config.merge_patch(m_config.at(key));

        return config;
    }

    json MapBuilder::getTileConfig(uint32 mapId, uint32 tileX, uint32 tileY)
    {
        std::string key = std::to_string(tileX) + std::to_string(tileY);

        json config = getMapIdConfig(mapId);
        if (config.find(key) != config.end())
            config.merge_patch(config.at(key));

        for (json::iterator it = config.begin(); it != config.end();) {
            if ((*it).is_object())
                it = config.erase(it);
            else
                ++it;
        }

        return config;
    }
}
