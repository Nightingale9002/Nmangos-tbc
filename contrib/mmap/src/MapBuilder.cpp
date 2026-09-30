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
    config.cs = MMAP::BASE_UNIT_DIM;
    config.ch = MMAP::BASE_UNIT_DIM;
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
                           const char* gameObjectFilePath) :
        m_taskQueue(new TaskQueue(this, threads)),
        m_debug(debug),
        m_skipContinents(skipContinents),
        m_skipJunkMaps(skipJunkMaps),
        m_skipBattlegrounds(skipBattlegrounds),
        m_offMeshFilePath(offMeshFilePath),
        m_workdir(workdir),
        m_gameObjectFilePath(gameObjectFilePath)
    {
        std::ifstream jsonConfig(configInputPath);
        if (jsonConfig)
            m_config = json::parse(jsonConfig);

        m_terrainBuilder = new TerrainBuilder(skipLiquid, workdir);
        m_rcContext = new rcContext(false);

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
        buildCommonTile(modelName.data(), tile, config, tVerts, tVertCount, tTris, tTriCount, nullptr, 0, nullptr, 0, 0,
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

        // get model data
        m_terrainBuilder->loadVMap(mapID, tileY, tileX, meshData);

        // if there is no data, give up now
        if (!meshData.solidVerts.size() && !meshData.liquidVerts.size())
            return;

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

        int polyBits = DT_POLY_BITS;

        int maxTiles = tiles.size();
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
        dtStatus dtResult = navMesh->init(&navMeshParams);
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

                buildCommonTile(tileString, tile, tileCfg, tVerts, tVertCount, tTris, tTriCount, lVerts, lVertCount, lTris, lTriCount, lTriFlags,
                                preErosionMedianPasses, seamBridgeMaxRise, &seamStats);
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
                printf("%s Failed adding tile to navmesh!                     \n", tileString);
                printf("%s\n", GetDTErrorReason(dtResult));
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

    bool MapBuilder::buildCommonTile(const char* tileString, Tile& tile, rcConfig& tileCfg, float* tVerts, int tVertCount, int* tTris, int tTriCount, float* lVerts, int lVertCount,
                                     int* lTris, int lTriCount, uint8* lTriFlags, int preErosionMedianPasses, int seamBridgeMaxRise, SeamFixStats* seamStats)
    {
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

        // mark almost unwalkable triangles with steep flag
        rcModAlmostUnwalkableTriangles(m_rcContext, 50.0f, tVerts, tVertCount, tTris, tTriCount, triFlags);

        rcRasterizeTriangles(m_rcContext, tVerts, tVertCount, tTris, triFlags, tTriCount, *tile.solid, tileCfg.walkableClimb);
        delete[] triFlags;

        rcFilterLowHangingWalkableObstacles(m_rcContext, tileCfg.walkableClimb, *tile.solid);
        rcFilterLedgeSpans(m_rcContext, tileCfg.walkableHeight, tileCfg.walkableClimb, *tile.solid);
        rcFilterWalkableLowHeightSpans(m_rcContext, tileCfg.walkableHeight, *tile.solid);
        if (lVerts)
            rcRasterizeTriangles(m_rcContext, lVerts, lVertCount, lTris, lTriFlags, lTriCount, *tile.solid, tileCfg.walkableClimb);

        // close one cell wide unwalkable seams before they get widened by the erosion below
        SeamFixStats localSeamStats;
        closeThinSeams(m_rcContext, *tile.solid, tileCfg, seamBridgeMaxRise, localSeamStats);
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
        if (!tile.chf || !rcBuildCompactHeightfield(m_rcContext, tileCfg.walkableHeight, tileCfg.walkableClimb, *tile.solid, *tile.chf))
        {
            printf("%s Failed compacting heightfield!                     \n", tileString);
            return false;
        }

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

        // build polymesh
        tile.pmesh = rcAllocPolyMesh();
        if (!tile.pmesh || !rcBuildPolyMesh(m_rcContext, *tile.cset, tileCfg.maxVertsPerPoly, *tile.pmesh))
        {
            printf("%s Failed building polymesh!                          \n", tileString);
            return false;
        }

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
            {"minRegionArea", 60},
            {"walkableClimb", 4},
            {"walkableHeight", 6},
            {"walkableRadius", 2},
            {"walkableSlopeAngle", 60.0f},
            {"liquidFlagMergeThreshold", 0.0f},
            {"preErosionMedianPasses", 1},
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
