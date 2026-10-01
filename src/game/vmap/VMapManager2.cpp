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

#include <iomanip>
#include <string>
#include <sstream>
#include "VMapManager2.h"
#include "MapTree.h"
#include "ModelInstance.h"
#include "WorldModel.h"
#include "VMapDefinitions.h"
#include "Maps/GridMapDefines.h"

using G3D::Vector3;

namespace VMAP
{
    //=========================================================

    VMapManager2::VMapManager2() : m_thread_safe_environment(true)
    {
    }

    //=========================================================

    VMapManager2::~VMapManager2(void)
    {
        for (auto& iInstanceMapTree : iInstanceMapTrees)
        {
            delete iInstanceMapTree.second;
        }
        for (auto& iLoadedModelFile : iLoadedModelFiles)
        {
            delete iLoadedModelFile.second.getModel();
        }
    }

    void VMapManager2::InitializeThreadUnsafe(const std::vector<uint32>& mapIds)
    {
        // the caller must pass the list of all mapIds that will be used in the VMapManager2 lifetime
        for (const uint32& mapId : mapIds)
            iInstanceMapTrees.insert(InstanceTreeMap::value_type(mapId, nullptr));

        m_thread_safe_environment = false;
    }

    //=========================================================

    Vector3 VMapManager2::convertPositionToInternalRep(float x, float y, float z) const
    {
        Vector3 pos;
        const float mid = 0.5f * 64.0f * 533.33333333f;
        pos.x = mid - x;
        pos.y = mid - y;
        pos.z = z;

        return pos;
    }

    InstanceTreeMap::const_iterator VMapManager2::GetMapTree(uint32 mapId) const
    {
        // return the iterator if found or end() if not found/NULL
        InstanceTreeMap::const_iterator itr = iInstanceMapTrees.find(mapId);
        if (itr != iInstanceMapTrees.cend() && !itr->second)
            itr = iInstanceMapTrees.cend();

        return itr;
    }

    // move to MapTree too?
    std::string VMapManager2::getMapFileName(unsigned int pMapId)
    {
        std::stringstream fname;
        fname.width(3);
        fname << std::setfill('0') << pMapId << std::string(MAP_FILENAME_EXTENSION2);
        return fname.str();
    }

    //=========================================================

    VMAPLoadResult VMapManager2::loadMap(const char* pBasePath, unsigned int pMapId, int x, int y)
    {
        VMAPLoadResult result = VMAP_LOAD_RESULT_IGNORED;
        if (isMapLoadingEnabled())
        {
            iBasePath = pBasePath ? pBasePath : "";     // [VMAP-KEEPALIVE] 供 EnsureMapLoaded() 按需重载用
            if (_loadMap(pMapId, pBasePath, x, y))
                result = VMAP_LOAD_RESULT_OK;
            else if (iNoVmapDataMaps.find(pMapId) != iNoVmapDataMaps.end())
                result = VMAP_LOAD_RESULT_IGNORED;      // 这张图磁盘上就没有 vmap 数据：不是"加载失败"，别刷错误日志
            else
                result = VMAP_LOAD_RESULT_ERROR;
        }
        return result;
    }

    //=========================================================
    // Check if specified map have tile loaded
    bool VMapManager2::IsTileLoaded(uint32 mapId, uint32 x, uint32 y) const
    {
        InstanceTreeMap::const_iterator instanceTree = iInstanceMapTrees.find(mapId);
        if (instanceTree == iInstanceMapTrees.end() || instanceTree->second == nullptr)
            return false;
        return instanceTree->second->IsTileLoaded(x, y);
    }

    //=========================================================
    // [VMAP-KEEPALIVE 2026-10-01] 诊断用：树是否在内存里（IsTileLoaded 分不清"树没了"和"非分块图的假 tile"）
    bool VMapManager2::IsMapTreeLoaded(uint32 mapId) const
    {
        return GetMapTree(mapId) != iInstanceMapTrees.end();
    }

    //=========================================================
    // [VMAP-KEEPALIVE 2026-10-01] 诊断用：分块图（有 .vmtile）还是非分块图（只有 .vmtree）；树不在时报 false
    bool VMapManager2::IsMapTiled(uint32 mapId) const
    {
        InstanceTreeMap::const_iterator instanceTree = GetMapTree(mapId);
        return instanceTree != iInstanceMapTrees.end() && instanceTree->second->isTiled();
    }

    //=========================================================
    // load one tile (internal use only)

    bool VMapManager2::_loadMap(unsigned int mapId, const std::string& basePath, uint32 tileX, uint32 tileY)
    {
        InstanceTreeMap::iterator instanceTree = iInstanceMapTrees.find(mapId);
        if (instanceTree == iInstanceMapTrees.end())
        {
            if (m_thread_safe_environment)
                instanceTree = iInstanceMapTrees.insert(InstanceTreeMap::value_type(mapId, nullptr)).first;
            else
                MANGOS_ASSERT(false && "Invalid mapId passed to VMapManager2 after startup in thread unsafe environment");
        }

        // [VMAP-KEEPALIVE 2026-10-01] 磁盘上就没有这张图的 vmap 数据（.vmtree 打不开）：记住，
        // 以后不要再反复 fopen（网格加载、LOS 查询都会走这里）。
        if (iNoVmapDataMaps.find(mapId) != iNoVmapDataMaps.end())
            return false;

        if (!instanceTree->second)
        {
            std::string mapFileName = getMapFileName(mapId);
            StaticMapTree* newTree = new StaticMapTree(mapId, basePath);
            if (!newTree->InitMap(mapFileName, this))
            {
                delete newTree;
                iNoVmapDataMaps.insert(mapId);
                return false;
            }

            // insert new data
            {
                std::lock_guard<std::mutex> lock(m_vmStaticMapMutex);
                instanceTree->second = newTree;
            }
        }

        // [VMAP-KEEPALIVE 2026-10-01] 同一个 tile 不重复加载：对分块图，LoadMapTile() 会重新
        // fopen .vmtile 并重新 acquireModelInstance()（引用计数只增不减 => 模型泄漏）；对非分块图
        // 则是覆盖同一条假记录。TerrainInfo::LoadMapAndVMap() 现在会用 loadMap() 来补登记
        // （见那里的注释），所以这里必须幂等。
        if (instanceTree->second->IsTileRegistered(tileX, tileY))
            return true;

        return instanceTree->second->LoadMapTile(tileX, tileY, this);
    }

    //=========================================================
    // [VMAP-KEEPALIVE 2026-10-01] 让 vmap 查询自愈，为什么需要它：
    //   ① 副本图是"非分块图"（例如 556 塞泰克大厅只有 556.vmtree，没有 .vmtile）：
    //      碰撞几何由 StaticMapTree::InitMap() 一次性加载，LoadMapTile() 只写一条值为 false 的
    //      "假 tile 记录"，而 unloadMap(mapId, x, y) 只要 iLoadedTiles 空了就把整棵树删掉。
    //   ② 清账的是 TerrainInfo::CleanUpGrids()：每 60 秒把引用计数为 0 的网格连同它的 vmap
    //      记录一起释放；TerrainInfo 是同一 mapId 的所有副本实例共用的。
    //   ③ 而 TerrainInfo::LoadMapAndVMap() 过去在 IsTileLoaded()==true 时直接 return ——
    //      非分块图只要树还在就恒为 true，于是新加载的网格从不登记，记录只减不增，
    //      树被删掉后再没有任何路径把它加载回来。
    //   后果：整张图的 vmap 消失，VMapManager2::isInLineOfSight() 找不到树就直接
    //   return true（= 全图通视），游戏里的表现就是"同一根柱子有时挡视线、有时完全不挡"，
    //   而且是"进本时正常、打一会儿就失灵"这种随机形态。
    //   这里做两层修复的第 2 层（第 1 层见 TerrainInfo::LoadMapAndVMap 的补登记）：
    //   查询时发现树不在就按需重新加载。正常情况（树在）只多一次哈希查找，不会碰磁盘。
    bool VMapManager2::EnsureMapLoaded(uint32 mapId, float x1, float y1, float x2, float y2)
    {
        if (GetMapTree(mapId) != iInstanceMapTrees.end())
            return true;

        if (!isMapLoadingEnabled() || iBasePath.empty())
            return false;

        // 不在启动时注册的 map 列表里：不做动态插入（线程不安全环境下会 assert）
        if (iInstanceMapTrees.find(mapId) == iInstanceMapTrees.end())
            return false;

        // 这张图本来就没有 vmap 数据
        if (iNoVmapDataMaps.find(mapId) != iNoVmapDataMaps.end())
            return false;

        std::lock_guard<std::mutex> lock(m_vmEnsureMutex);
        if (GetMapTree(mapId) != iInstanceMapTrees.end())       // 双检：可能已被别的线程加载回来
            return true;

        // 两个端点各自所在的图块都试一次（非分块图随便哪个 tile 都会把同一棵树建起来）
        static constexpr float tileSize = 533.33333333f;        // SIZE_OF_GRIDS
        static constexpr uint32 maxTiles = 64;                  // MAX_NUMBER_OF_GRIDS
        float const points[2][2] = { { x1, y1 }, { x2, y2 } };
        for (auto const& pt : points)
        {
            Vector3 const p = convertPositionToInternalRep(pt[0], pt[1], 0.0f);
            // 与 TerrainInfo::GetGrid()/LoadMapAndVMap() 一致：grid = (int)(32 - coord / SIZE_OF_GRIDS)
            uint32 const tileX = uint32(p.x / tileSize);
            uint32 const tileY = uint32(p.y / tileSize);
            if (tileX >= maxTiles || tileY >= maxTiles)
                continue;

            if (_loadMap(mapId, iBasePath, tileX, tileY) && GetMapTree(mapId) != iInstanceMapTrees.end())
            {
                NOTICE_LOG("VMAP: map %u had NO vmap tree in memory (it was unloaded while still in use) - "
                           "reloaded on demand for tile %u,%u; all line of sight / height queries for this map "
                           "returned 'clear' until now", mapId, tileX, tileY)
                return true;
            }
        }

        return GetMapTree(mapId) != iInstanceMapTrees.end();
    }

    //=========================================================

    void VMapManager2::unloadMap(unsigned int pMapId)
    {
        InstanceTreeMap::iterator instanceTree = iInstanceMapTrees.find(pMapId);
        if (instanceTree != iInstanceMapTrees.end() && instanceTree->second)
        {
            instanceTree->second->UnloadMap(this);
            if (instanceTree->second->numLoadedTiles() == 0)
            {
                delete instanceTree->second;
                instanceTree->second = nullptr;
            }
        }
    }

    //=========================================================

    void VMapManager2::unloadMap(unsigned int  pMapId, int x, int y)
    {
        InstanceTreeMap::iterator instanceTree = iInstanceMapTrees.find(pMapId);
        if (instanceTree != iInstanceMapTrees.end() && instanceTree->second)
        {
            instanceTree->second->UnloadMapTile(x, y, this);
            if (instanceTree->second->numLoadedTiles() == 0)
            {
                delete instanceTree->second;
                instanceTree->second = nullptr;
            }
        }
    }

    //==========================================================

    bool VMapManager2::isInLineOfSight(unsigned int mapId, float x1, float y1, float z1, float x2, float y2, float z2, bool ignoreM2Model)
    {
        if (!isLineOfSightCalcEnabled()) return true;
        bool result = true;
        // [VMAP-KEEPALIVE 2026-10-01] 树没了 => 以前这里直接返回 true（全图通视），现在先尝试按需重载
        EnsureMapLoaded(mapId, x1, y1, x2, y2);
        InstanceTreeMap::const_iterator instanceTree = GetMapTree(mapId);
        if (instanceTree != iInstanceMapTrees.end())
        {
            Vector3 pos1 = convertPositionToInternalRep(x1, y1, z1);
            Vector3 pos2 = convertPositionToInternalRep(x2, y2, z2);
            if (pos1 != pos2)
            {
                result = instanceTree->second->isInLineOfSight(pos1, pos2, ignoreM2Model);
            }
        }
        return result;
    }
    //=========================================================
    /**
    get the hit position and return true if we hit something
    otherwise the result pos will be the dest pos
    */
    bool VMapManager2::getObjectHitPos(unsigned int mapId, float x1, float y1, float z1, float x2, float y2, float z2, float& rx, float& ry, float& rz, float pModifyDist)
    {
        bool result = false;
        rx = x2;
        ry = y2;
        rz = z2;
        if (isLineOfSightCalcEnabled())
        {
            EnsureMapLoaded(mapId, x1, y1, x2, y2);     // [VMAP-KEEPALIVE] 同上：树没了先尝试按需重载
            InstanceTreeMap::const_iterator instanceTree = GetMapTree(mapId);
            if (instanceTree != iInstanceMapTrees.end())
            {
                Vector3 pos1 = convertPositionToInternalRep(x1, y1, z1);
                Vector3 pos2 = convertPositionToInternalRep(x2, y2, z2);
                Vector3 resultPos;
                result = instanceTree->second->getObjectHitPos(pos1, pos2, resultPos, pModifyDist);
                resultPos = convertPositionToInternalRep(resultPos.x, resultPos.y, resultPos.z);
                rx = resultPos.x;
                ry = resultPos.y;
                rz = resultPos.z;
            }
        }
        return result;
    }

    //=========================================================
    /**
    get height or INVALID_HEIGHT if no height available
    */

    float VMapManager2::getHeight(unsigned int mapId, float x, float y, float z, float maxSearchDist)
    {
        float height = VMAP_INVALID_HEIGHT_VALUE;           // no height
        if (isHeightCalcEnabled())
        {
            EnsureMapLoaded(mapId, x, y, x, y);             // [VMAP-KEEPALIVE] 同上：树没了先尝试按需重载
            InstanceTreeMap::const_iterator instanceTree = GetMapTree(mapId);
            if (instanceTree != iInstanceMapTrees.end())
            {
                Vector3 pos = convertPositionToInternalRep(x, y, z);
                height = instanceTree->second->getHeight(pos, maxSearchDist);
                if (!(height < G3D::inf()))
                {
                    height = VMAP_INVALID_HEIGHT_VALUE;     // no height
                }
            }
        }
        return height;
    }

    //=========================================================

    bool VMapManager2::getAreaInfo(unsigned int mapId, float x, float y, float& z, uint32& flags, int32& adtId, int32& rootId, int32& groupId) const
    {
        bool result = false;
        InstanceTreeMap::const_iterator instanceTree = GetMapTree(mapId);
        if (instanceTree != iInstanceMapTrees.end())
        {
            Vector3 pos = convertPositionToInternalRep(x, y, z);
            result = instanceTree->second->getAreaInfo(pos, flags, adtId, rootId, groupId);
            // z is not touched by convertPositionToMangosRep(), so just copy
            z = pos.z;
        }
        return result;
    }

    uint8 GetLiquidMask(uint32 type) // wotlk uses dbc
    {
        switch (type)
        {
            case 0: return MAP_LIQUID_TYPE_NO_WATER;
            case 1: return MAP_LIQUID_TYPE_WATER;
            case 2: return MAP_LIQUID_TYPE_OCEAN;
            case 3: return MAP_LIQUID_TYPE_MAGMA;
            case 4: return MAP_LIQUID_TYPE_SLIME;
            case 21: return MAP_LIQUID_TYPE_SLIME;
            case 41: return MAP_LIQUID_TYPE_WATER;
            case 61: return MAP_LIQUID_TYPE_WATER;
            default: return 0;
        }
    }

    bool VMapManager2::GetLiquidLevel(uint32 pMapId, float x, float y, float z, uint8 ReqLiquidTypeMask, float& level, float& floor, uint32& type) const
    {
        InstanceTreeMap::const_iterator instanceTree = iInstanceMapTrees.find(pMapId);
        if (instanceTree != iInstanceMapTrees.end() && instanceTree->second)
        {
            LocationInfo info;
            Vector3 pos = convertPositionToInternalRep(x, y, z);
            if (instanceTree->second->GetLocationInfo(pos, info))
            {
                floor = info.ground_Z;
                type = info.hitModel->GetLiquidType();
                if (ReqLiquidTypeMask && !(GetLiquidMask(type) & ReqLiquidTypeMask))
                    return false;
                if (info.hitInstance->GetLiquidLevel(pos, info, level))
                    return true;
            }
        }
        return false;
    }

    //=========================================================

    WorldModel* VMapManager2::acquireModelInstance(const std::string& basepath, const std::string& filename)
    {
        std::lock_guard<std::mutex> lock(m_vmModelMutex);
        ModelFileMap::iterator model = iLoadedModelFiles.find(filename);
        if (model == iLoadedModelFiles.end())
        {
            WorldModel* worldmodel = new WorldModel();
            if (!worldmodel->readFile(basepath + filename + ".vmo"))
            {
                ERROR_LOG("VMapManager2: could not load '%s%s.vmo'!", basepath.c_str(), filename.c_str());
                delete worldmodel;
                return nullptr;
            }

            // insert new data
            DEBUG_FILTER_LOG(LOG_FILTER_MAP_LOADING, "VMapManager2: loading file '%s%s'.", basepath.c_str(), filename.c_str());
            model = iLoadedModelFiles.insert(std::pair<std::string, ManagedModel>(filename, ManagedModel())).first;
            model->second.setModel(worldmodel);
        }
        model->second.incRefCount();
        return model->second.getModel();
    }

    void VMapManager2::releaseModelInstance(const std::string& filename)
    {
        ModelFileMap::iterator model = iLoadedModelFiles.find(filename);
        if (model == iLoadedModelFiles.end())
        {
            ERROR_LOG("VMapManager2: trying to unload non-loaded file '%s'!", filename.c_str());
            return;
        }
        if (model->second.decRefCount() == 0)
        {
            DEBUG_FILTER_LOG(LOG_FILTER_MAP_LOADING, "VMapManager2: unloading file '%s'", filename.c_str());
            delete model->second.getModel();
            iLoadedModelFiles.erase(model);
        }
    }
    //=========================================================

    bool VMapManager2::existsMap(const char* pBasePath, unsigned int mapId, int x, int y)
    {
        return StaticMapTree::CanLoadMap(std::string(pBasePath), mapId, x, y);
    }
} // namespace VMAP
