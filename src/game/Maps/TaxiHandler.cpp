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

#include "Common.h"
#include "Database/DatabaseEnv.h"
#include "Server/WorldPacket.h"
#include "Server/WorldSession.h"
#include "Server/Opcodes.h"
#include "Log/Log.h"
#include "Globals/ObjectMgr.h"
#include "Entities/Player.h"
#include "MotionGenerators/Path.h"
#include "MotionGenerators/WaypointMovementGenerator.h"

#include <sstream>
#include <algorithm>

namespace
{
    /////////////////////////////////////////////////////////////////////////////////////
    // [TAXI-DIAG 2026-09-24] Logging only: dump every incoming taxi activation request
    // together with the state the player is in. Needed to explain the client toast
    // "unknown server error" (ERR_TAXIUNSPECIFIEDSERVERERROR) which the server only
    // sends when the tracker refuses to build ANY leg - the most likely case being a
    // second request while a flight is already active (player riding the taxi mount).
    // Enabled per player by the GM command ".debug taxi" (default off => zero cost).
    /////////////////////////////////////////////////////////////////////////////////////
    // [TAXI-DIAG 2026-09-24] Request logging is gated by the player's ".debug taxi" switch.
    // ASCII only on purpose: this file is compiled under codepage 936.

    void TaxiDiagRequest(Player const& player, char const* opcode, ObjectGuid npcGuid, uint32 const* nodes, uint32 nodeCount)
    {
        std::ostringstream d;
        d << opcode << " request | player " << player.GetName() << " (guid " << player.GetGUIDLow()
          << ", map " << player.GetMapId() << ") | npc " << npcGuid.GetString()
          << " | chain: ";
        for (uint32 i = 0; i < nodeCount; ++i)
            d << (i ? " -> " : "") << nodes[i];
        d << " (" << nodeCount << " nodes)";
        d << " | mounted display " << player.GetMountID()
          << ", taxi flight state " << (player.hasUnitState(UNIT_STAT_TAXI_FLIGHT) ? "YES" : "no")
          << ", client control lost " << (player.HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_CLIENT_CONTROL_LOST) ? "YES" : "no")
          << " (tracker state is logged by Taxi.cpp right after)";
        sLog.outString("[TAXI-DIAG] %s", d.str().c_str());
    }
}

void WorldSession::HandleTaxiNodeStatusQueryOpcode(WorldPacket& recv_data)
{
    DEBUG_LOG("WORLD: Received opcode CMSG_TAXINODE_STATUS_QUERY");

    ObjectGuid guid;

    recv_data >> guid;
    SendTaxiStatus(guid);
}

namespace
{
    // [TAXI-DIAG 2026-09-25] logging only: what the server answers as "current node" for the flight
    // master the player is talking to. Needed to tell a bad client chain (chain starts at a station
    // 1600+ yd away) apart from a bad server answer. Changes nothing.
    void TaxiDiagCurLoc(Player* player, Creature* unit, char const* where, uint32 curloc, uint32 build)
    {
        if (!player || !unit || !player->IsTaxiDebug())
            return;
        sLog.outString("[TAXI-DIAG] %s curloc %u | npc %u at (%.1f, %.1f, %.1f) map %u, team %u | player %s (guid %u, map %u, client build %u)",
                       where, curloc, unit->GetEntry(), unit->GetPositionX(), unit->GetPositionY(), unit->GetPositionZ(),
                       unit->GetMapId(), uint32(player->GetTeam()), player->GetName(), player->GetGUIDLow(),
                       player->GetMapId(), build);
    }
}

void WorldSession::SendTaxiStatus(ObjectGuid guid) const
{
    // cheating checks
    Creature* unit = GetPlayer()->GetMap()->GetCreature(guid);
    if (!unit)
    {
        DEBUG_LOG("WorldSession::SendTaxiStatus - %s not found or you can't interact with it.", guid.GetString().c_str());
        return;
    }

    uint32 curloc = sObjectMgr.GetNearestTaxiNode(unit->GetPositionX(), unit->GetPositionY(), unit->GetPositionZ(), unit->GetMapId(), GetPlayer()->GetTeam());

    // not found nearest
    if (curloc == 0)
        return;

    TaxiDiagCurLoc(GetPlayer(), unit, "SMSG_TAXINODE_STATUS", curloc, GetGameBuild());

    DEBUG_LOG("WORLD: current location %u ", curloc);

    WorldPacket data(SMSG_TAXINODE_STATUS, 9);
    data << ObjectGuid(guid);
    data << uint8(GetPlayer()->m_taxi.IsTaximaskNodeKnown(curloc) ? 1 : 0);
    SendPacket(data);

    DEBUG_LOG("WORLD: Sent SMSG_TAXINODE_STATUS");
}

void WorldSession::HandleTaxiQueryAvailableNodes(WorldPacket& recv_data)
{
    DEBUG_LOG("WORLD: Received opcode CMSG_TAXIQUERYAVAILABLENODES");

    ObjectGuid guid;
    recv_data >> guid;

    // cheating checks
    Creature* unit = GetPlayer()->GetNPCIfCanInteractWith(guid, UNIT_NPC_FLAG_FLIGHTMASTER);
    if (!unit)
    {
        DEBUG_LOG("WORLD: HandleTaxiQueryAvailableNodes - %s not found or you can't interact with him.", guid.GetString().c_str());
        return;
    }

    // unknown taxi node case
    if (SendLearnNewTaxiNode(unit))
        return;

    // known taxi node case
    SendTaxiMenu(unit);
}

void WorldSession::SendTaxiMenu(Creature* unit) const
{
    // find current node
    uint32 curloc = sObjectMgr.GetNearestTaxiNode(unit->GetPositionX(), unit->GetPositionY(), unit->GetPositionZ(), unit->GetMapId(), GetPlayer()->GetTeam());

    if (curloc == 0)
        return;

    DEBUG_LOG("WORLD: CMSG_TAXINODE_STATUS_QUERY %u ", curloc);

    TaxiDiagCurLoc(GetPlayer(), unit, "SMSG_SHOWTAXINODES", curloc, GetGameBuild());

    WorldPacket data(SMSG_SHOWTAXINODES, (4 + 8 + 4 + 8 * 4));
    data << uint32(1);
    data << unit->GetObjectGuid();
    data << uint32(curloc);
    GetPlayer()->m_taxi.AppendTaximaskTo(data, GetPlayer()->isTaxiCheater());
    SendPacket(data);

    DEBUG_LOG("WORLD: Sent SMSG_SHOWTAXINODES");
}

bool WorldSession::SendLearnNewTaxiNode(Creature* unit) const
{
    // find current node
    uint32 curloc = sObjectMgr.GetNearestTaxiNode(unit->GetPositionX(), unit->GetPositionY(), unit->GetPositionZ(), unit->GetMapId(), GetPlayer()->GetTeam());

    if (curloc == 0)
        return true;                                        // `true` send to avoid WorldSession::SendTaxiMenu call with one more curlock seartch with same false result.

    TaxiDiagCurLoc(GetPlayer(), unit, "SMSG_NEW_TAXI_PATH(mask add)", curloc, GetGameBuild());

    if (GetPlayer()->m_taxi.SetTaximaskNode(curloc))
    {
        WorldPacket msg(SMSG_NEW_TAXI_PATH, 0);
        SendPacket(msg);

        WorldPacket update(SMSG_TAXINODE_STATUS, 9);
        update << ObjectGuid(unit->GetObjectGuid());
        update << uint8(1);
        SendPacket(update);

        return true;
    }
    return false;
}

void WorldSession::SendActivateTaxiReply(ActivateTaxiReply reply) const
{
    WorldPacket data(SMSG_ACTIVATETAXIREPLY, 4);
    data << uint32(reply);
    SendPacket(data);

    DEBUG_LOG("WORLD: Sent SMSG_ACTIVATETAXIREPLY");
}

void WorldSession::HandleActivateTaxiExpressOpcode(WorldPacket& recv_data)
{
    DEBUG_LOG("WORLD: Received opcode CMSG_ACTIVATETAXIEXPRESS");

    ObjectGuid guid;
    uint32 node_count, _totalcost;

    recv_data >> guid >> _totalcost >> node_count;

    // [TAXI-DIAG 2026-09-25] logging only: raw packet of the multi-hop request. A chain that looks
    // shifted by one node (e.g. "124 -> 159 -> 140" while the player stands at 140) must be told
    // apart from what the client really put on the wire, so dump the raw words. The read position is
    // restored afterwards and no behaviour depends on this block.
    if (_player && _player->IsTaxiDebug())
    {
        std::ostringstream d;
        d << "CMSG_ACTIVATETAXIEXPRESS raw packet: size " << recv_data.size() << " rpos " << recv_data.rpos()
          << ", totalcost " << _totalcost << ", node_count " << node_count << ", raw words:";
        size_t const save = recv_data.rpos();
        recv_data.rpos(0);
        uint32 const words = uint32(std::min<size_t>(10, recv_data.size() / 4));
        for (uint32 i = 0; i < words; ++i)
        {
            uint32 w = 0;
            recv_data >> w;
            d << " " << w;
        }
        recv_data.rpos(save);
        d << " | player " << _player->GetName() << " (guid " << _player->GetGUIDLow()
          << ", map " << _player->GetMapId() << ", client build " << GetGameBuild() << ")";
        sLog.outString("[TAXI-DIAG] %s", d.str().c_str());
    }

    Creature* npc = GetPlayer()->GetNPCIfCanInteractWith(guid, UNIT_NPC_FLAG_FLIGHTMASTER);
    if (!npc)
    {
        DEBUG_LOG("WORLD: HandleActivateTaxiExpressOpcode - %s not found or you can't interact with it.", guid.GetString().c_str());
        return;
    }
    std::vector<uint32> nodes;

    for (uint32 i = 0; i < node_count; ++i)
    {
        uint32 node;
        recv_data >> node;

        if (!_player->m_taxi.IsTaximaskNodeKnown(node) && !_player->isTaxiCheater())
        {
            SendActivateTaxiReply(ERR_TAXINOTVISITED);
            recv_data.rpos(recv_data.wpos()); // prevent additional spam at rejected packet
            return;
        }

        nodes.push_back(node);
    }

    if (nodes.empty())
        return;

    DEBUG_LOG("WORLD: Received opcode CMSG_ACTIVATETAXIEXPRESS from %d to %d", nodes.front(), nodes.back());

    // [TAXI-DIAG] logging only
    if (_player->IsTaxiDebug())
        TaxiDiagRequest(*_player, "CMSG_ACTIVATETAXIEXPRESS", guid, nodes.data(), uint32(nodes.size()));

    GetPlayer()->ActivateTaxiPathTo(nodes, npc);
}

void WorldSession::HandleMoveSplineDoneOpcode(WorldPacket& recv_data)
{
    DEBUG_LOG("WORLD: Received opcode CMSG_MOVE_SPLINE_DONE");

    MovementInfo movementInfo;                              // used only for proper packet read
    uint32 movementCounter;                                 // spline counter

    recv_data >> movementInfo;
    recv_data >> movementCounter;

    // TODO: Add checking for correct point end for correct spline
}

void WorldSession::HandleActivateTaxiOpcode(WorldPacket& recv_data)
{
    DEBUG_LOG("WORLD: Received opcode CMSG_ACTIVATETAXI");

    ObjectGuid guid;
    std::vector<uint32> nodes;
    nodes.resize(2);

    recv_data >> guid >> nodes[0] >> nodes[1];
    DEBUG_LOG("WORLD: Received opcode CMSG_ACTIVATETAXI from %d to %d", nodes[0], nodes[1]);
    Creature* npc = GetPlayer()->GetNPCIfCanInteractWith(guid, UNIT_NPC_FLAG_FLIGHTMASTER);
    if (!npc)
    {
        DEBUG_LOG("WORLD: HandleActivateTaxiOpcode - %s not found or you can't interact with it.", guid.GetString().c_str());
        return;
    }

    if (!_player->isTaxiCheater())
    {
        if (!_player->m_taxi.IsTaximaskNodeKnown(nodes[0]) || !_player->m_taxi.IsTaximaskNodeKnown(nodes[1]))
        {
            SendActivateTaxiReply(ERR_TAXINOTVISITED);
            return;
        }
    }

    // [TAXI-DIAG] logging only
    if (_player->IsTaxiDebug())
        TaxiDiagRequest(*_player, "CMSG_ACTIVATETAXI", guid, nodes.data(), uint32(nodes.size()));

    GetPlayer()->ActivateTaxiPathTo(nodes, npc);
}
