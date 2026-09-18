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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#include "OutdoorPvPNA.h"
#include "Server/WorldPacket.h"
#include "World/World.h"
#include "Globals/ObjectMgr.h"
#include "Entities/Object.h"
#include "Entities/Creature.h"
#include "Entities/GameObject.h"
#include "Entities/Player.h"
#include "Tools/Language.h"

#include <algorithm>

OutdoorPvPNA::OutdoorPvPNA() : OutdoorPvP(),
    m_zoneOwner(TEAM_NONE),
    m_zoneWorldState(0),
    m_zoneMapState(WORLD_STATE_NA_HALAA_NEUTRAL),
    m_guardsLeft(0),
    m_isUnderSiege(false)
{
    // initially set graveyard owner to neither faction
    SetGraveYardLinkTeam(GRAVEYARD_ID_HALAA, GRAVEYARD_ZONE_ID_HALAA, TEAM_INVALID, 530);
}

void OutdoorPvPNA::FillInitialWorldStates(WorldPacket& data, uint32& count)
{
    if (m_zoneOwner != TEAM_NONE)
    {
        FillInitialWorldState(data, count, m_zoneWorldState, WORLD_STATE_ADD);

        // map states
        for (unsigned int i : m_roostWorldState)
            FillInitialWorldState(data, count, i, WORLD_STATE_ADD);
    }

    FillInitialWorldState(data, count, m_zoneMapState, WORLD_STATE_ADD);
    FillInitialWorldState(data, count, WORLD_STATE_NA_GUARDS_MAX, MAX_NA_GUARDS);
    FillInitialWorldState(data, count, WORLD_STATE_NA_GUARDS_LEFT, m_guardsLeft);
}

void OutdoorPvPNA::SendRemoveWorldStates(Player* player)
{
    player->SendUpdateWorldState(m_zoneWorldState, WORLD_STATE_REMOVE);
    player->SendUpdateWorldState(m_zoneMapState, WORLD_STATE_REMOVE);

    for (unsigned int i : m_roostWorldState)
        player->SendUpdateWorldState(i, WORLD_STATE_REMOVE);
}

void OutdoorPvPNA::HandlePlayerEnterZone(Player* player, bool isMainZone)
{
    OutdoorPvP::HandlePlayerEnterZone(player, isMainZone);

    // remove the buff from the player first because there are some issues at relog
    player->RemoveAurasDueToSpell(SPELL_STRENGTH_HALAANI);

    // buff the player if same team is controlling the zone
    if (player->GetTeam() == m_zoneOwner)
        player->CastSpell(player, SPELL_STRENGTH_HALAANI, TRIGGERED_OLD_TRIGGERED);
}

void OutdoorPvPNA::HandlePlayerLeaveZone(Player* player, bool isMainZone)
{
    // remove the buff from the player
    player->RemoveAurasDueToSpell(SPELL_STRENGTH_HALAANI);

    OutdoorPvP::HandlePlayerLeaveZone(player, isMainZone);
}

void OutdoorPvPNA::HandleObjectiveComplete(uint32 eventId, const std::list<Player*>& players, Team team)
{
    if (eventId == EVENT_HALAA_BANNER_WIN_ALLIANCE || eventId == EVENT_HALAA_BANNER_WIN_HORDE)
    {
        for (auto player : players)
        {
            if (player && player->GetTeam() == team)
                player->KilledMonsterCredit(NPC_HALAA_COMBATANT);
        }
    }
}

// Cast player spell on opponent kill
void OutdoorPvPNA::HandlePlayerKillInsideArea(Player* player)
{
    if (player->GetAreaId() == ZONE_HALAA)
        player->CastSpell(nullptr, player->GetTeam() == ALLIANCE ? SPELL_NAGRAND_TOKEN_ALLIANCE : SPELL_NAGRAND_TOKEN_HORDE, TRIGGERED_OLD_TRIGGERED);
}

void OutdoorPvPNA::HandleCreatureCreate(Creature* creature)
{
    switch (creature->GetEntry())
    {
        case NPC_RESEARCHER_KARTOS:
        case NPC_QUARTERMASTER_DAVIAN:
        case NPC_MERCHANT_ALDRAAN:
        case NPC_VENDOR_CENDRII:
        case NPC_AMMUNITIONER_BANRO:
        case NPC_RESEARCHER_AMERELDINE:
        case NPC_QUARTERMASTER_NORELIQE:
        case NPC_MERCHANT_COREIEL:
        case NPC_VENDOR_EMBELAR:
        case NPC_AMMUNITIONER_TASALDAN:
        {
            // The vendors of both teams are permanent DB spawns, so they are re-created (=
            // respawned) on every grid unload/reload while the owner state is not persisted.
            // Re-apply the owner state here every time, otherwise every vendor despawned on
            // capture simply comes back as soon as the zone is unloaded and loaded again.
            const ObjectGuid vendorGuid = creature->GetObjectGuid();
            // [2026-09-19] 中立（TEAM_NONE）时也不显示任何商人 —— 镇子是空的，点旗帜就能占领。
            if (m_zoneOwner == TEAM_NONE || GetVendorTeam(creature->GetEntry()) != m_zoneOwner)
            {
                if (std::find(m_foreignVendors.begin(), m_foreignVendors.end(), vendorGuid) == m_foreignVendors.end())
                    m_foreignVendors.push_back(vendorGuid);

                creature->ForcedDespawn();
                break;
            }

            if (std::find(m_teamVendors.begin(), m_teamVendors.end(), vendorGuid) == m_teamVendors.end())
                m_teamVendors.push_back(vendorGuid);
            break;
        }
        case NPC_HORDE_HALAANI_GUARD:
        case NPC_ALLIANCE_HANAANI_GUARD:
        {
            // [2026-09-19] 卫兵同样是永久 DB 刷点（双方各 15 个、同位置成对）：只显示当前占领方那一半，
            //   中立时全部隐藏（镇子空着，点旗帜即可占领）。
            //   与商人同一套思路：非当方的先 ForcedDespawn 并记进 m_foreignGuards，易主时再 Respawn 回来。
            const ObjectGuid guardGuid = creature->GetObjectGuid();
            if (m_zoneOwner == TEAM_NONE || GetGuardTeam(creature->GetEntry()) != m_zoneOwner)
            {
                if (!creature->IsAlive())
                    return;

                if (std::find(m_foreignGuards.begin(), m_foreignGuards.end(), guardGuid) == m_foreignGuards.end())
                    m_foreignGuards.push_back(guardGuid);

                creature->ForcedDespawn();
                return;
            }

            // Guard spawns are re-created on every grid unload/reload (and on every summon), so
            // a guard may only be counted once while it is alive. Counting every creation made
            // the counter drift upwards on each reload - "Guards Left" lied, Halaa could never
            // be captured again and the old uint8 counter even wrapped around to 0.
            // （静态刷点的 guid 跨网格卸载/重载是稳定的，所以这个去重集合现在真正有效。）
            if (!creature->IsAlive() || !m_aliveGuards.insert(guardGuid).second)
                return;

            // prevent updating guard counter on owner take over
            if (m_guardsLeft >= MAX_NA_GUARDS)
                return;

            if (m_guardsLeft == 0)
            {
                LockHalaa(creature);

                // update world state
                SendUpdateWorldState(m_zoneMapState, WORLD_STATE_REMOVE);
                m_zoneMapState = m_zoneOwner == ALLIANCE ? WORLD_STATE_NA_HALAA_ALLIANCE : WORLD_STATE_NA_HALAA_HORDE;
                SendUpdateWorldState(m_zoneMapState, WORLD_STATE_ADD);
            }

            ++m_guardsLeft;
            SendUpdateWorldState(WORLD_STATE_NA_GUARDS_LEFT, m_guardsLeft);
            break;
        }
    }
}

void OutdoorPvPNA::HandleCreatureDeath(Creature* creature)
{
    if (creature->GetEntry() != NPC_HORDE_HALAANI_GUARD && creature->GetEntry() != NPC_ALLIANCE_HANAANI_GUARD)
        return;

    // [2026-09-19] 战死的卫兵【不再补回来】：这一版彻底去掉了"临时召唤那套"（死亡位置队列 + 复活计时器 +
    //   RespawnSoldier 在原位临时召回一名卫兵）。理由：卫兵现在是永久 DB 刷点，复活这件事交给刷点本身
    //   （dev/093 把 spawntimesecs 设成 2592000 = 30 天，等价于"核心不复活"），所以谁死谁就永久消失，
    //   小镇被慢慢打空 = 可被占领，这正是原版攻城玩法的意图；不再有"临时召唤"参与，也就没有
    //   "网格卸载丢卫兵 / 网格重载多卫兵 / 计数器和实际人数对不上"这些问题。

    // decrease the counter, but only for a guard that was counted as alive, and never below
    // zero: a death of an uncounted guard used to underflow the counter (= instant capture)
    if (m_aliveGuards.erase(creature->GetObjectGuid()) && m_guardsLeft > 0)
        --m_guardsLeft;
    SendUpdateWorldState(WORLD_STATE_NA_GUARDS_LEFT, m_guardsLeft);

    if (m_guardsLeft == 0)
    {
        // no guards left: the town is defenseless and can be captured
        m_isUnderSiege = true;

        // make capturable
        UnlockHalaa(creature);

        // update world state
        SendUpdateWorldState(m_zoneMapState, WORLD_STATE_REMOVE);
        m_zoneMapState = m_zoneOwner == ALLIANCE ? WORLD_STATE_NA_HALAA_NEUTRAL_A : WORLD_STATE_NA_HALAA_NEUTRAL_H;
        SendUpdateWorldState(m_zoneMapState, WORLD_STATE_ADD);

        sWorld.SendDefenseMessage(ZONE_ID_NAGRAND, LANG_OPVP_NA_DEFENSELESS);
    }
}

void OutdoorPvPNA::HandleGameObjectCreate(GameObject* go)
{
    OutdoorPvP::HandleGameObjectCreate(go);

    switch (go->GetEntry())
    {
        case GO_HALAA_BANNER:
            m_capturePoint = go->GetObjectGuid();
            go->SetGoArtKit(GetBannerArtKit(m_zoneOwner));
            break;

        case GO_WYVERN_ROOST_ALLIANCE_SOUTH:
            m_roostsAlliance[0] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_ALLIANCE_NORTH:
            m_roostsAlliance[1] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_ALLIANCE_EAST:
            m_roostsAlliance[2] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_ALLIANCE_WEST:
            m_roostsAlliance[3] = go->GetObjectGuid();
            break;

        case GO_BOMB_WAGON_HORDE_SOUTH:
            m_wagonsHorde[0] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_HORDE_NORTH:
            m_wagonsHorde[1] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_HORDE_EAST:
            m_wagonsHorde[2] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_HORDE_WEST:
            m_wagonsHorde[3] = go->GetObjectGuid();
            break;

        case GO_DESTROYED_ROOST_ALLIANCE_SOUTH:
            m_roostsBrokenAlliance[0] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_ALLIANCE_NORTH:
            m_roostsBrokenAlliance[1] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_ALLIANCE_EAST:
            m_roostsBrokenAlliance[2] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_ALLIANCE_WEST:
            m_roostsBrokenAlliance[3] = go->GetObjectGuid();
            break;

        case GO_WYVERN_ROOST_HORDE_SOUTH:
            m_roostsHorde[0] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_HORDE_NORTH:
            m_roostsHorde[1] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_HORDE_EAST:
            m_roostsHorde[2] = go->GetObjectGuid();
            break;
        case GO_WYVERN_ROOST_HORDE_WEST:
            m_roostsHorde[3] = go->GetObjectGuid();
            break;

        case GO_BOMB_WAGON_ALLIANCE_SOUTH:
            m_wagonsAlliance[0] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_ALLIANCE_NORTH:
            m_wagonsAlliance[1] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_ALLIANCE_EAST:
            m_wagonsAlliance[2] = go->GetObjectGuid();
            break;
        case GO_BOMB_WAGON_ALLIANCE_WEST:
            m_wagonsAlliance[3] = go->GetObjectGuid();
            break;

        case GO_DESTROYED_ROOST_HORDE_SOUTH:
            m_roostsBrokenHorde[0] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_HORDE_NORTH:
            m_roostsBrokenHorde[1] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_HORDE_EAST:
            m_roostsBrokenHorde[2] = go->GetObjectGuid();
            break;
        case GO_DESTROYED_ROOST_HORDE_WEST:
            m_roostsBrokenHorde[3] = go->GetObjectGuid();
            break;
    }
}

void OutdoorPvPNA::UpdateWorldState(uint32 value)
{
    SendUpdateWorldState(m_zoneWorldState, value);
    SendUpdateWorldState(m_zoneMapState, value);

    UpdateWyvernsWorldState(value);
}

void OutdoorPvPNA::UpdateWyvernsWorldState(uint32 value)
{
    for (unsigned int i : m_roostWorldState)
        SendUpdateWorldState(i, value);
}

// process the capture events
bool OutdoorPvPNA::HandleEvent(uint32 eventId, Object* source, Object* /*target*/)
{
    if (!source->IsGameObject())
        return false;

    GameObject* go = static_cast<GameObject*>(source);
    // If we are not using the Halaa banner return
    if (go->GetEntry() != GO_HALAA_BANNER)
        return false;

    bool eventHandled = true;

    switch (eventId)
    {
        case EVENT_HALAA_BANNER_WIN_ALLIANCE:
            ProcessCaptureEvent(go, ALLIANCE);
            eventHandled = false;
            break;
        case EVENT_HALAA_BANNER_WIN_HORDE:
            ProcessCaptureEvent(go, HORDE);
            eventHandled = false;
            break;
        case EVENT_HALAA_BANNER_PROGRESS_ALLIANCE:
            SetBannerVisual(go, CAPTURE_ARTKIT_ALLIANCE, CAPTURE_ANIM_ALLIANCE);
            sWorld.SendDefenseMessage(ZONE_ID_NAGRAND, LANG_OPVP_NA_PROGRESS_A);
            break;
        case EVENT_HALAA_BANNER_PROGRESS_HORDE:
            SetBannerVisual(go, CAPTURE_ARTKIT_HORDE, CAPTURE_ANIM_HORDE);
            sWorld.SendDefenseMessage(ZONE_ID_NAGRAND, LANG_OPVP_NA_PROGRESS_H);
            break;
    }

    // there are some events which required further DB script
    return eventHandled;
}

void OutdoorPvPNA::ProcessCaptureEvent(GameObject* go, Team team)
{
    BuffTeam(m_zoneOwner, SPELL_STRENGTH_HALAANI, true);

    // update capture point owner
    m_zoneOwner = team;

    LockHalaa(go);
    m_guardsLeft = MAX_NA_GUARDS;   // 新占领方满编（他们的卫兵刷点是 DB 常驻的）

    // [2026-09-19] 旧占领方的卫兵此刻还站在镇上（m_aliveGuards 里记的就是他们）→ 全部藏掉，
    //   并把 guid 收进候选名单：他们现在是输方，下次易主时要能整体放回来
    //   （不收的话要等到下一次网格重载才轮到 HandleCreatureCreate 重新判定 → 会有一段空窗）。
    GuidList candidatesGuards;
    for (GuidSet::const_iterator itr = m_aliveGuards.begin(); itr != m_aliveGuards.end(); ++itr)
    {
        if (Creature* soldier = go->GetMap()->GetCreature(*itr))
            soldier->ForcedDespawn();

        candidatesGuards.push_back(*itr);
    }
    m_aliveGuards.clear();
    candidatesGuards.insert(candidatesGuards.end(), m_foreignGuards.begin(), m_foreignGuards.end());

    m_isUnderSiege = false;

    UpdateWorldState(WORLD_STATE_REMOVE);

    // 旧占领方的商人：DespawnVendors 会清空 m_teamVendors，先把 guid 收进候选名单
    GuidList candidatesVendors(m_teamVendors.begin(), m_teamVendors.end());
    DespawnVendors(go);
    candidatesVendors.insert(candidatesVendors.end(), m_foreignVendors.begin(), m_foreignVendors.end());

    // [2026-09-19] 候选里**只有属于新占领方的那批**放回来。
    //   ⚠️ 不能整表放：owner == TEAM_NONE（中立）期间双方 NPC 都会被记进 m_foreign*，
    //      整表放回来会让两个阵营的 NPC 同时站在镇上（2026-09-19 站长用
    //      `.debug script command capturehalaa` 实测到：联盟占领，部落 NPC 也刷了）。
    //   仍然属于对方的那些写回 m_foreign*（保持隐藏），等下一次易主再放。
    m_teamVendors.clear();
    m_foreignVendors.clear();
    for (GuidList::const_iterator itr = candidatesVendors.begin(); itr != candidatesVendors.end(); ++itr)
    {
        Creature* vendor = go->GetMap()->GetCreature(*itr);
        if (!vendor)
            continue;                                       // 网格卸载：重载时 HandleCreatureCreate 会重新判定

        if (GetVendorTeam(vendor->GetEntry()) != m_zoneOwner)
        {
            if (std::find(m_foreignVendors.begin(), m_foreignVendors.end(), *itr) == m_foreignVendors.end())
                m_foreignVendors.push_back(*itr);
            continue;
        }

        if (!vendor->IsAlive())
            vendor->Respawn();

        if (std::find(m_teamVendors.begin(), m_teamVendors.end(), *itr) == m_teamVendors.end())
            m_teamVendors.push_back(*itr);
    }

    m_aliveGuards.clear();
    m_foreignGuards.clear();
    for (GuidList::const_iterator itr = candidatesGuards.begin(); itr != candidatesGuards.end(); ++itr)
    {
        Creature* soldier = go->GetMap()->GetCreature(*itr);
        if (!soldier)
            continue;

        if (GetGuardTeam(soldier->GetEntry()) != m_zoneOwner)
        {
            if (std::find(m_foreignGuards.begin(), m_foreignGuards.end(), *itr) == m_foreignGuards.end())
                m_foreignGuards.push_back(*itr);
            continue;
        }

        if (!soldier->IsAlive())
            soldier->Respawn();

        m_aliveGuards.insert(soldier->GetObjectGuid());
    }

    SetGraveYardLinkTeam(GRAVEYARD_ID_HALAA, GRAVEYARD_ZONE_ID_HALAA, m_zoneOwner, 530);

    if (m_zoneOwner == ALLIANCE)
    {
        m_zoneWorldState = WORLD_STATE_NA_GUARDS_ALLIANCE;
        m_zoneMapState = WORLD_STATE_NA_HALAA_ALLIANCE;
    }
    else
    {
        m_zoneWorldState = WORLD_STATE_NA_GUARDS_HORDE;
        m_zoneMapState = WORLD_STATE_NA_HALAA_HORDE;
    }

    HandleFactionObjects(go);
    UpdateWorldState(WORLD_STATE_ADD);

    SendUpdateWorldState(WORLD_STATE_NA_GUARDS_LEFT, m_guardsLeft);

    BuffTeam(m_zoneOwner, SPELL_STRENGTH_HALAANI);
    sWorld.SendDefenseMessage(ZONE_ID_NAGRAND, m_zoneOwner == ALLIANCE ? LANG_OPVP_NA_CAPTURE_A : LANG_OPVP_NA_CAPTURE_H);
}

// Handle the gameobjects spawn/despawn depending on the controller faction
void OutdoorPvPNA::HandleFactionObjects(const WorldObject* objRef)
{
    if (m_zoneOwner == ALLIANCE)
    {
        for (uint8 i = 0; i < MAX_NA_ROOSTS; ++i)
        {
            RespawnGO(objRef, m_wagonsHorde[i], false);
            RespawnGO(objRef, m_roostsBrokenAlliance[i], false);
            RespawnGO(objRef, m_roostsAlliance[i], false);
            RespawnGO(objRef, m_wagonsAlliance[i], false);
            RespawnGO(objRef, m_roostsBrokenHorde[i], true);

            m_roostWorldState[i] = nagrandRoostStatesHordeNeutral[i];
        }
    }
    else
    {
        for (uint8 i = 0; i < MAX_NA_ROOSTS; ++i)
        {
            RespawnGO(objRef, m_wagonsAlliance[i], false);
            RespawnGO(objRef, m_roostsBrokenHorde[i], false);
            RespawnGO(objRef, m_roostsHorde[i], false);
            RespawnGO(objRef, m_wagonsHorde[i], false);
            RespawnGO(objRef, m_roostsBrokenAlliance[i], true);

            m_roostWorldState[i] = nagrandRoostStatesAllianceNeutral[i];
        }
    }
}

// Team the permanent (DB) vendors of Halaa belong to
Team OutdoorPvPNA::GetVendorTeam(uint32 entry) const
{
    switch (entry)
    {
        case NPC_RESEARCHER_KARTOS:
        case NPC_QUARTERMASTER_DAVIAN:
        case NPC_MERCHANT_ALDRAAN:
        case NPC_VENDOR_CENDRII:
        case NPC_AMMUNITIONER_BANRO:
            return ALLIANCE;

        case NPC_RESEARCHER_AMERELDINE:
        case NPC_QUARTERMASTER_NORELIQE:
        case NPC_MERCHANT_COREIEL:
        case NPC_VENDOR_EMBELAR:
        case NPC_AMMUNITIONER_TASALDAN:
            return HORDE;
    }

    return TEAM_NONE;
}

// [2026-09-19] Team the permanent (DB) guards of Halaa belong to
Team OutdoorPvPNA::GetGuardTeam(uint32 entry) const
{
    switch (entry)
    {
        case NPC_ALLIANCE_HANAANI_GUARD:
            return ALLIANCE;
        case NPC_HORDE_HALAANI_GUARD:
            return HORDE;
    }

    return TEAM_NONE;
}

// Handle vendors despawn when the city is captured by the other faction
void OutdoorPvPNA::DespawnVendors(const WorldObject* objRef)
{
    // despawn all team vendors
    for (GuidList::const_iterator itr = m_teamVendors.begin(); itr != m_teamVendors.end(); ++itr)
    {
        if (Creature* soldier = objRef->GetMap()->GetCreature(*itr))
            soldier->ForcedDespawn();
    }
    m_teamVendors.clear();
}

bool OutdoorPvPNA::HandleGameObjectUse(Player* player, GameObject* go)
{
    if (player->GetTeam() == ALLIANCE)
    {
        for (uint8 i = 0; i < MAX_NA_ROOSTS; ++i)
        {
            if (go->GetEntry() == nagrandWagonsAlliance[i])
            {
                // update roost states
                UpdateWyvernsWorldState(WORLD_STATE_REMOVE);
                m_roostWorldState[i] = nagrandRoostStatesHordeNeutral[i];
                UpdateWyvernsWorldState(WORLD_STATE_ADD);

                // spawn the broken roost and despawn the other one
                RespawnGO(go, m_roostsHorde[i], false);
                RespawnGO(go, m_roostsBrokenHorde[i], true);

                // no need to iterate the other roosts
                return false;
            }
            if (go->GetEntry() == nagrandRoostsBrokenAlliance[i])
            {
                // update roost states
                UpdateWyvernsWorldState(WORLD_STATE_REMOVE);
                m_roostWorldState[i] = nagrandRoostStatesAlliance[i];
                UpdateWyvernsWorldState(WORLD_STATE_ADD);

                // spawn the repaired one along with the explosive wagon - the broken one despawns by self
                RespawnGO(go, m_wagonsHorde[i], true);
                RespawnGO(go, m_roostsAlliance[i], true);

                // no need to iterate the other roosts
                return false;
            }
            if (go->GetEntry() == nagrandRoostsAlliance[i])
            {
                // mark player as pvp
                player->UpdatePvP(true);

                // prevent despawning after go use
                go->SetRespawnTime(0);

                // no need to iterate the other roosts
                return false;
            }
        }
    }
    else if (player->GetTeam() == HORDE)
    {
        for (uint8 i = 0; i < MAX_NA_ROOSTS; ++i)
        {
            if (go->GetEntry() == nagrandWagonsHorde[i])
            {
                // update roost states
                UpdateWyvernsWorldState(WORLD_STATE_REMOVE);
                m_roostWorldState[i] = nagrandRoostStatesAllianceNeutral[i];
                UpdateWyvernsWorldState(WORLD_STATE_ADD);

                // spawn the broken roost and despawn the other one
                RespawnGO(go, m_roostsAlliance[i], false);
                RespawnGO(go, m_roostsBrokenAlliance[i], true);

                // no need to iterate the other roosts
                return false;
            }
            if (go->GetEntry() == nagrandRoostsBrokenHorde[i])
            {
                // update roost states
                UpdateWyvernsWorldState(WORLD_STATE_REMOVE);
                m_roostWorldState[i] = nagrandRoostStatesHorde[i];
                UpdateWyvernsWorldState(WORLD_STATE_ADD);

                // spawn the repaired one along with the explosive wagon - the broken one despawns by self
                RespawnGO(go, m_wagonsAlliance[i], true);
                RespawnGO(go, m_roostsHorde[i], true);

                // no need to iterate the other roosts
                return false;
            }
            if (go->GetEntry() == nagrandRoostsHorde[i])
            {
                // mark player as pvp
                player->UpdatePvP(true);

                // prevent despawning after go use
                go->SetRespawnTime(0);

                // no need to iterate the other roosts
                return false;
            }
        }
    }

    return false;
}

// [2026-09-19] 这里原来是"卫兵复活"那一套（Update 计时器 + RespawnSoldier 在原位把死掉的卫兵
//   复活/临时召回）。按站长要求【整段删除】：战死的卫兵不再补回来 —— 卫兵是永久 DB 刷点
//   （dev/093，spawntimesecs = 2592000 = 30 天），谁死谁就没，直到有阵营重新占领。
//   删掉它的同时也就带走了"临时召唤"这套机制（TEMPSPAWN + 死亡位置队列 + 复活计时器），
//   于是不再有"网格卸载丢卫兵 / 网格重载多卫兵 / 计数器与实际人数对不上"这些问题。

// Lock Halaa when captured
void OutdoorPvPNA::LockHalaa(const WorldObject* objRef)
{
    if (GameObject* go = objRef->GetMap()->GetGameObject(m_capturePoint))
        go->SetLootState(GO_JUST_DEACTIVATED);
    else
    {
        // if grid is unloaded, changing the saved slider value is enough
        CapturePointSlider value(m_zoneOwner == ALLIANCE ? CAPTURE_SLIDER_ALLIANCE : CAPTURE_SLIDER_HORDE, true);
        sOutdoorPvPMgr.SetCapturePointSlider(GO_HALAA_BANNER, value);
    }
}

// Unlock Halaa when all the soldiers are killed
void OutdoorPvPNA::UnlockHalaa(const WorldObject* objRef)
{
    if (GameObject* go = objRef->GetMap()->GetGameObject(m_capturePoint))
        go->SetLootState(GO_ACTIVATED);
    else
    {
        // if grid is unloaded, changing the saved slider value is enough
        CapturePointSlider value(m_zoneOwner == ALLIANCE ? CAPTURE_SLIDER_ALLIANCE : CAPTURE_SLIDER_HORDE, false);
        sOutdoorPvPMgr.SetCapturePointSlider(GO_HALAA_BANNER, value);
    }
}
