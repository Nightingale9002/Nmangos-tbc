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

#include "Entities/Taxi.h"
#include "Entities/Player.h"
#include "Globals/ObjectMgr.h"
#include "World/World.h"

#include <sstream>

/////////////////////////////////////////////////
/// @file       Taxi.cpp
/// @date       May, 2018
/// @brief      Helper containers implementations for updated player taxi system.
/////////////////////////////////////////////////

using namespace Taxi;

namespace
{
    //////////////////////////////////////////////////////////////////////////////////////
    // [TAXI-DIAG 2026-09-24] Taxi flight "straight line through terrain" diagnostics.
    // Logging only: no flight behaviour is changed anywhere in this block.
    //
    // Why: players report occasional clipping near Nethergarde Keep (node 45) but not
    // always. Raw .map terrain cannot decide whether a point is inside rock or inside a
    // WMO interior (cities carved out of mountains), so this uses the server's own
    // height query (terrain + vmap) to get ground truth on a real flight.
    //
    // Sampled per point on the segment:
    //   low  = GetHeight(x, y, z)        - what the server normally uses
    //   high = GetHeight(x, y, z + 100)  - probe 100yd above, detects rock overhead
    // If "high - z" is clearly positive the segment point sits under solid geometry.
    //
    // Enabled per player by the GM command ".debug taxi" (default off => zero cost).
    //////////////////////////////////////////////////////////////////////////////////////

    void TaxiDiagLog(Player& owner, std::string const& msg)
    {
        sLog.outString("[TAXI-DIAG] %s | player %s (guid %u, map %u)",
                       msg.c_str(), owner.GetName(), owner.GetGUIDLow(), owner.GetMapId());
    }

    // [TAXI-DIAG 2026-09-24] Always-on logging (owner request: cannot predict which flight breaks).
    // To go back to ".debug taxi" only, change the return below to "return m_debug".
    // ASCII only: this file is compiled under codepage 936, non-ASCII comments here break parsing.
    inline bool TaxiDiagEnabled() { return true; }

    /// Sample terrain height along one straight segment. Cross-map segments only report length.
    std::string TaxiDiagSegment(Player& owner, bool detailed, char const* tag, PathID pathA, Index idxA, TaxiPathNodeEntry const* a,
                                PathID pathB, Index idxB, TaxiPathNodeEntry const* b)
    {
        if (!a || !b)
            return "";

        std::ostringstream out;
        const float dx = b->x - a->x, dy = b->y - a->y, dz = b->z - a->z;
        const float dist = std::sqrt(dx * dx + dy * dy + dz * dz);

        out.setf(std::ios::fixed);
        out.precision(1);
        out << tag << ": path " << pathA << " idx " << idxA << " -> path " << pathB << " idx " << idxB
            << " | len " << dist << " yd, dZ " << (b->z - a->z);

        if (a->mapid != b->mapid)
        {
            out << " | cross-map segment (map " << a->mapid << "->" << b->mapid << "), no height sample";
            return out.str();
        }
        if (a->mapid != owner.GetMapId())
        {
            out << " | sample skipped: segment on map " << a->mapid << ", player on map " << owner.GetMapId();
            return out.str();
        }

        // always-on uses coarse sampling (every 25yd, max 40 points); ".debug taxi" uses fine sampling
        const uint32 steps = detailed ? uint32(std::min(200.0f, std::max(2.0f, dist / 10.0f)))
                                      : uint32(std::min(40.0f, std::max(2.0f, dist / 25.0f)));
        float worstLow = 0.0f, worstHigh = 0.0f, worstAt = 0.0f;
        for (uint32 i = 0; i <= steps; ++i)
        {
            const float t = float(i) / float(steps);
            const float x = a->x + dx * t;
            const float y = a->y + dy * t;
            const float z = a->z + dz * t;

            const float hLow  = owner.GetMap()->GetHeight(x, y, z, false);
            const float hHigh = owner.GetMap()->GetHeight(x, y, z + 100.0f, false);

            if (hLow - z > worstLow)
                worstLow = hLow - z;
            if (hHigh - z > worstHigh)
            {
                worstHigh = hHigh - z;
                worstAt = dist * t;
            }
        }

        out << " | height above point: low-query " << worstLow << " yd, +100yd-probe " << worstHigh
            << " yd (worst at " << worstAt << " yd from segment start)";

        // Endpoint clearance above the ground surface (negative = endpoint itself is underground)
        const float cA = a->z - owner.GetMap()->GetHeight(a->x, a->y, a->z, false);
        const float cB = b->z - owner.GetMap()->GetHeight(b->x, b->y, b->z, false);
        out << " | endpoint clearance " << cA << " / " << cB << " yd";

        return out.str();
    }
}


std::string Tracker::Save()
{
    // Writes in modified format.

    // Original numbers format: "src dest dest dest "                   variable amount of destinations in the string, dangling destinations possible, trailing space @ the end)
    // Updated  numbers format: "resumenode:src:dest:dest:dest"         strictly formatted, introduced in taxi system rewrite
    // Modified numbers format: "resumenode#pathid#pathid#pathid"       strictly formatted, directly uses flights, introduced in an update for redesigned taxi system

    if (m_state < TRACKER_FLIGHT)
        return "";

    // Bugcheck: container continuity error
    MANGOS_ASSERT(!m_routes.empty() && !m_atlas.empty());

    std::ostringstream stream;

    // Save resume node for the current route
    uint32 node = GetMap().at(size_t(m_locationIndex))->index;
    // Make sure resume node is not the very first one or the very last one - saving and loading those makes no practical sense to us
    node = std::max(std::min(node, (GetRoute().nodeEnd - 1)), (GetRoute().nodeStart + 1));
    stream << node;

    const size_t count = (sWorld.getConfig(CONFIG_BOOL_LONG_TAXI_PATHS_PERSISTENCE) ? m_routes.size() : 1);

    for (size_t i = 0; i < count; ++i)
        stream << "#" << m_routes[i].pathID;

    return stream.str();
}

bool Tracker::Load(std::string& string, DestID &destOrphan)
{
    if (!Clear())
        return false;

    // Read a modified format. All old entries were converted to orphaned taxi node records via DB update for failsafe loading.

    // Original numbers format: "src dest dest dest "                   variable amount of destinations in the string, dangling destinations possible, trailing space @ the end)
    // Updated  numbers format: "resumenode:src:dest:dest:dest"         strictly formatted, introduced in taxi system rewrite
    // Modified numbers format: "resumenode#pathid#pathid#pathid"       strictly formatted, directly uses flights, introduced in an update for redesigned taxi system

    Tokens tokens = StrSplit(string, "#");

    std::deque<PathID> numbers;

    for (auto& token : tokens)
        numbers.push_back(uint32(std::stoi(token)));

    // Try to parse as robustly as possible
    switch (numbers.size())
    {
        case 0:             // No routes
            return true;
        case 1:             // Orphaned: probably loading from an outdated format, just dangling destination node
            destOrphan = numbers.front();
            return false;
        default:
        {
            // Extract and verify last known flight path node index
            uint32 nodeResume = numbers.front();
            numbers.pop_front();

            // On successful load, prepares the container right away, otherwise does all the housekeeping
            if (!AddRoutes(numbers, 0.0f, false) || !Prepare(nodeResume))
            {
                Clear();
                return false;
            }
        }
    }
    return true;
}

bool Tracker::SetState(TrackerState state)
{
    switch (state)
    {
        case TRACKER_FLIGHT:
            m_state = ((m_state == TRACKER_STANDBY || m_state == TRACKER_TRANSFER) ? state : m_state);
            return (m_state == state);
        case TRACKER_TRANSFER:
            m_state = ((m_state == TRACKER_FLIGHT) ? state : m_state);
            return (m_state == state);
        // The rest can't be set outside of the container under any circumstances
        default:
            break;
    }
    return false;
}

bool Tracker::AddRoute(const TaxiPathEntry *entry, float discountMulti /*= 0.0f*/, bool requireModel /*= true*/)
{
    // Cant be altered while taxi ride is prepared
    if (m_state > TRACKER_STAGING)
    {
        // [TAXI-DIAG] logging only: this is the path that makes the client show
        // "unknown server error" (ERR_TAXIUNSPECIFIEDSERVERERROR) via AddRoutes() == false
        if (TaxiDiagEnabled())
        {
            std::ostringstream d;
            d << "AddRoute REFUSED: tracker busy (state " << uint32(m_state) << " > STAGING)"
              << " path " << (entry ? entry->ID : 0);
            TaxiDiagLog(m_owner, d.str());
        }
        return false;
    }

    // Verify input
    if (!entry)
        return false;

    uint32 cost = entry->price;

    const bool commercial = int32(discountMulti) != 0;

    // Can't add taxi path without mount display id unless specified otherwise
    uint32 displayId = sObjectMgr.GetTaxiMountDisplayId(entry->from, m_owner.GetTeam());
    if (requireModel && !displayId)
    {
        // [TAXI-DIAG] logging only
        if (TaxiDiagEnabled())
        {
            std::ostringstream d;
            d << "AddRoute REFUSED: no taxi mount display for source node " << entry->from
              << " (team " << uint32(m_owner.GetTeam()) << "), path " << entry->ID;
            TaxiDiagLog(m_owner, d.str());
        }
        return false;
    }

    // Use first route's mount appearance for the entirety of the flight
    if (!m_displayId)
        m_displayId = displayId;

    if (commercial)
    {
        cost = uint32(cost * discountMulti);
        m_cost += cost;
        // If global preference is set, do not record individual flight costs
        if (sWorld.getConfig(CONFIG_BOOL_LONG_TAXI_PATHS_PERSISTENCE))
            cost = 0;
    }

    TaxiPathNodeList const& nodes = sTaxiPathNodesByPath[entry->ID];
    m_routes.push_back(Route(entry->ID, entry->from, entry->to, nodes.front()->index, nodes.back()->index, cost));

    const size_t count = m_routes.size();

    // Multi-route taxi path: set shortcut
    if (count > 1)
    {
        // [TAXI-DIAG 2026-09-24] Logging only. Trim() stays static and untouched, so the diagnostic
        // works out afterwards what kind of junction was used by comparing the node ranges before
        // and after the call against the taxi_shortcuts data (data / fallback / none).
        const Index oldEnd = m_routes[count - 2].nodeEnd;
        const Index oldStart = m_routes[count - 1].nodeStart;

        Trim(m_routes[count - 2], m_routes[count - 1]);

        if (TaxiDiagEnabled())
        {
            Route const& first = m_routes[count - 2];
            Route const& second = m_routes[count - 1];

            uint32 scLanding = 0, scTakeoff = 0;
            TaxiShortcutData scData;
            if (sObjectMgr.GetTaxiShortcut(first.pathID, scData))
                scLanding = std::min(scData.lengthLanding, (oldEnd - 1));
            if (sObjectMgr.GetTaxiShortcut(second.pathID, scData))
                scTakeoff = std::min(scData.lengthTakeoff, (second.nodeEnd - 1));

            const Index cutEnd = oldEnd - first.nodeEnd;         // nodes dropped from the first route's tail
            const Index cutStart = second.nodeStart - oldStart;  // nodes dropped from the second route's head

            char const* kind = "none (junction kept untrimmed, mount flies into the hub and back out)";
            if (cutEnd && cutStart)
                kind = (scLanding && scTakeoff) ? "shortcut-data" : "FALLBACK-trimmer";

            std::ostringstream d;
            d << "junction: path " << first.pathID << " (" << first.destStart << " -> " << first.destEnd
              << ") landing-cut " << cutEnd << " (table " << scLanding << ")"
              << " + path " << second.pathID << " (" << second.destStart << " -> " << second.destEnd
              << ") takeoff-cut " << cutStart << " (table " << scTakeoff << ")"
              << " | kind = " << kind;

            if (cutEnd && cutStart)
            {
                TaxiPathNodeList const& wp1 = sTaxiPathNodesByPath[first.pathID];
                TaxiPathNodeList const& wp2 = sTaxiPathNodesByPath[second.pathID];
                d << " | " << TaxiDiagSegment(m_owner, m_debug, "junction-chord",
                        first.pathID, first.nodeEnd, wp1[first.nodeEnd],
                        second.pathID, second.nodeStart, wp2[second.nodeStart]);
            }

            TaxiDiagLog(m_owner, d.str());
        }
    }

    return true;
}

bool Tracker::AddRoute(PathID pathID, float discountMulti /*= 0.0f*/, bool requireModel /*= true*/)
{
    // Cant be altered while taxi ride is prepared
    if (m_state > TRACKER_STAGING)
        return false;

    TaxiPathEntry const* entry = sTaxiPathStore.LookupEntry(pathID);

    return (entry && AddRoute(entry, discountMulti, requireModel));
}

bool Tracker::AddRoute(DestID start, DestID end, float discountMulti /*= 0.0f*/, bool requireModel /*= true*/)
{
    // Cant be altered while taxi ride is prepared
    if (m_state > TRACKER_STAGING)
        return false;

    uint32 pathID, cost;
    sObjectMgr.GetTaxiPath(start, end, pathID, cost);

    // [TAXI-DIAG] logging only (always on since 2026-09-24)
    if (!pathID)
    {
        std::ostringstream d;
        d << "AddRoute REFUSED: no DBC taxi path for pair (" << start << " -> " << end << ")";
        TaxiDiagLog(m_owner, d.str());
    }

    return (pathID && AddRoute(pathID, discountMulti, requireModel));
}

bool Tracker::AddRoutes(const std::vector<DestID>& destinations, float discountMulti /*= 0.0f*/, bool requireModel /*= true*/)
{
    if (!Clear())
    {
        // [TAXI-DIAG] logging only: Clear() refuses when a ride is already being tracked
        if (TaxiDiagEnabled())
        {
            std::ostringstream d;
            d << "AddRoutes FAILED at Clear(): tracker busy (state " << uint32(m_state)
              << ") => caller sends ERR_TAXIUNSPECIFIEDSERVERERROR";
            TaxiDiagLog(m_owner, d.str());
        }
        return false;
    }

    // [TAXI-DIAG] Record the full node chain requested by the client (this is what decides
    // whether the same destination is flown via different hub nodes / different routes)
    if (TaxiDiagEnabled())
    {
        std::ostringstream d;
        d << "itinerary (client request): ";
        for (size_t i = 0; i < destinations.size(); ++i)
            d << (i ? " -> " : "") << destinations[i];
        d << " | " << destinations.size() << " nodes, "
          << (destinations.size() > 1 ? (destinations.size() - 1) : 0) << " legs";
        TaxiDiagLog(m_owner, d.str());
    }

    uint32 attempted = 0;
    for (uint32 i = 1; i < destinations.size(); ++i)
    {
        ++attempted;
        // Stop on bad input
        if (!AddRoute(destinations.at(i - 1), destinations.at(i), discountMulti, requireModel))
            break;
    }

    // [TAXI-DIAG] logging only: how many legs made it (partial plans end the flight early)
    if (TaxiDiagEnabled())
    {
        std::ostringstream d;
        d << "AddRoutes result: " << m_routes.size() << " leg(s) added, " << attempted << " attempted, "
          << "return " << (!m_routes.empty() ? "TRUE" : "FALSE (client will show 'unknown server error')");
        TaxiDiagLog(m_owner, d.str());
    }

    // If at least one insertion was accepted, return true
    return !m_routes.empty();
}

bool Tracker::AddRoutes(const std::deque<PathID>& paths, float discountMulti /*= 0.0f*/, bool requireModel /*= true*/)
{
    if (!Clear())
        return false;

    for (auto i = paths.begin(); i != paths.end(); ++i)
    {
        // Stop on bad input
        if (!AddRoute(*i, discountMulti, requireModel))
            break;
    }

    // If at least one insertion was accepted, return true
    return !m_routes.empty();
}

bool Tracker::Prepare(Index nodeResume /*= 0*/)
{
    // Cant be altered while taxi ride is prepared
    if (m_state > TRACKER_STAGING)
        return false;

    // Cant be finalized when no routes added
    if (m_routes.empty())
        return false;

    Route& current = m_routes.front();

    // If global preference is set, we will charge total cost for the entire ride on first flight at once
    if (sWorld.getConfig(CONFIG_BOOL_LONG_TAXI_PATHS_PERSISTENCE))
        current.cost = m_cost;

    // Sanity check: make sure that resume node for current route hasn't gotten cut off or out of bounds
    nodeResume = std::min(nodeResume, current.nodeEnd);

    m_atlas.clear();
    // Open a new map in the atlas
    m_atlas.push_back(Map());
    // Start populating map(s)
    const TaxiPathNodeEntry* prev = nullptr;
    for (auto i = m_routes.begin(); i != m_routes.end(); ++i)
    {
        const TaxiPathNodeList& nodes = sTaxiPathNodesByPath[(*i).pathID];
        for (auto j = nodes.begin(); j != nodes.end(); ++j)
        {
            // Abide route trimmed routes when building a spline
            if ((*j)->index > (*i).nodeEnd || (*j)->index < (*i).nodeStart)
                continue;

            // Resume node defined: we are loading, additional care is required
            if (nodeResume && (*i).pathID == current.pathID)
            {
                // Internal algorithm sanity check: make sure resume node for current route will end up on the same map
                // Dont build spline for preceding nodes which are located on another map
                if ((*j)->index < nodes[nodeResume]->index && (*j)->mapid != nodes[nodeResume]->mapid)
                    continue;
                // When resume node reached on the route: calculate resume location index on the spline (which will be equal to the current size on push)
                if ((*j)->index == nodeResume)
                {
                    m_resumeIndex = m_atlas.back().size();
                    m_locationIndex = m_resumeIndex;
                }
            }
            // Detect level change and insert a new map
            if ((*j)->index >= (*i).nodeStart && (*j)->index <= (*i).nodeEnd)
            {
                if (prev && (*j)->mapid != prev->mapid)
                {
                    // Detect map change and advance atlas by adding a new map
                    if (sMapStore.LookupEntry((*j)->mapid))
                    {
                        // Bugcheck: latest finished map spline is suspiciously short
                        MANGOS_ASSERT(m_atlas.back().size() > 2);
                        m_atlas.push_back(Map());
                    }
                    else
                    {
                        sLog.outError("TAXI: Malformed flight path node detected and ignored. Node %u on flight path id %u refers non-existent mapid %u",
                                      (*j)->index, (*j)->path, (*j)->mapid);
                        continue;
                    }
                }
            }
            // Add entry to the latest Map
            m_atlas.back().push_back((*j));
            if ((*j)->index > (*i).nodeStart)
                prev = (*j);
        }
    }
    // Bugcheck: latest finished map spline is suspiciously short
    MANGOS_ASSERT(m_atlas.back().size() > 2);

    // [TAXI-DIAG] Dump what will actually be flown: first the trimmed node range of every leg,
    // then only the straight segments longer than 120yd with their ground clearance.
    // Both plain DBC long segments and invented junction chords show up here, which is what
    // tells us which of the two kinds a reported clipping happened on.
    if (TaxiDiagEnabled())
    {
        for (Roadmap::const_iterator r = m_routes.begin(); r != m_routes.end(); ++r)
        {
            std::ostringstream d;
            d << "leg: path " << (*r).pathID << " (" << (*r).destStart << " -> " << (*r).destEnd
              << ") node range " << (*r).nodeStart << ".." << (*r).nodeEnd;
            TaxiDiagLog(m_owner, d.str());
        }

        for (Atlas::const_iterator itr = m_atlas.begin(); itr != m_atlas.end(); ++itr)
        {
            Map const& spline = (*itr);
            for (size_t i = 1; i < spline.size(); ++i)
            {
                TaxiPathNodeEntry const* a = spline[i - 1];
                TaxiPathNodeEntry const* b = spline[i];
                const float dx = b->x - a->x, dy = b->y - a->y, dz = b->z - a->z;
                if (std::sqrt(dx * dx + dy * dy + dz * dz) < 120.0f)
                    continue;
                TaxiDiagLog(m_owner, TaxiDiagSegment(m_owner, m_debug, "long-segment", a->path, a->index, a, b->path, b->index, b));
            }
        }
    }

    m_state = TRACKER_STANDBY;
    return true;
}

bool Tracker::Clear(bool forced)
{
    // Cant be cleared while taxi ride is prepared, unless forced
    if (m_state > TRACKER_STAGING && !forced)
        return false;
    m_routes.clear();
    m_cost = 0;
    m_displayId = 0;
    m_atlas.clear();
    m_location = nullptr;
    m_locationIndex = 0;
    m_resumeIndex = 0;
    m_state = TRACKER_EMPTY;
    return true;
}

bool Tracker::UpdateRoute(const TaxiPathNodeEntry* entry, PathID& start, PathID& end)
{
    if (!entry)
        return false;

    // Cant be advanced when no taxi flight is being tracked
    if (m_state != TRACKER_FLIGHT)
        return false;

    // Bugcheck: continuity error - either routes or splines are missing
    MANGOS_ASSERT(!m_atlas.empty() && !m_routes.empty())

    const Map& map = GetMap();

    // Advance internal spline node counter only if not on the first waypoint
    if (m_location)
    {
        ++m_locationIndex;
        m_resumeIndex = m_locationIndex;
    }

    m_location = entry;

    // Bugcheck: internal spline node counter overflow
    MANGOS_ASSERT(size_t(m_locationIndex) < map.size())

    if (entry == map.back())
    {
        // Acknowledge spline end: nuke current map in the atlas, reset location index
        // That does not mean, however, that taxi ride was completed right away, as it can be a multimap flight route
        m_atlas.pop_front();
        m_location = nullptr;
        m_locationIndex = 0;
        m_resumeIndex = 0;
    }

    const Route& route = GetRoute();

    if (entry->index == route.nodeEnd)
    {
        // Acknowledge the end of the current route to other systems
        end = route.pathID;
        // Nuke the route from the container
        m_cost -= route.cost;
        m_routes.pop_front();
        if (m_routes.empty())
        {
            m_state = TRACKER_EMPTY;
            m_displayId = 0;
        }
        return true;
    }
    if (entry->index == route.nodeStart)
    {
        // Acknowledge the start of the current route to other systems
        start = route.pathID;
        return true;
    }

    return false;
}

bool Tracker::Trim(Route& first, Route& second)
{
    if (first.destEnd != second.destStart || first.pathID == second.pathID)
        return false;

    // Retail uses serverside pre-definied junction points for all interconnected flight paths.
    // We have a fallback custom automatic runtime trimmer. The result will not match retail and can be visually unpleasing at times.
    // For best experience, the taxi shortcuts table needs to be populated with faithful data.

    // Lookup known shortcuts first
    uint32 lengthTakeoff = 0;
    uint32 lengthLanding = 0;

    TaxiShortcutData data;

    // Get the landing range of the first route if exists
    if (sObjectMgr.GetTaxiShortcut(first.pathID, data))
        lengthLanding = data.lengthLanding;

    // Get the takeoff range of the second route if exists
    if (sObjectMgr.GetTaxiShortcut(second.pathID, data))
        lengthTakeoff = data.lengthTakeoff;

    // Sanity check for bounds
    lengthLanding = std::min(lengthLanding, (first.nodeEnd - 1));
    lengthTakeoff = std::min(lengthTakeoff, (second.nodeEnd - 1));

    // Both landing and takeoff data is present
    if (lengthLanding && lengthTakeoff)
    {
        first.nodeEnd -= lengthLanding;
        second.nodeStart += lengthTakeoff;
        return true;
    }

    // Try to trim dynamically if data is not available or incomplete
    TaxiPathNodeList const& waypoints1 = sTaxiPathNodesByPath[first.pathID];
    TaxiPathNodeList const& waypoints2 = sTaxiPathNodesByPath[second.pathID];
    TaxiNodesEntry const* destination = sTaxiNodesStore.LookupEntry(first.destEnd);

    if (destination && waypoints1 != waypoints2)
    {
        // Linear complexity for better performance
        const TaxiPathNodeEntry* last1 = nullptr;
        const TaxiPathNodeEntry* last2 = nullptr;
        const double refdistsq = double(48.0f * 48.0f);
        auto i1 = (waypoints1.rbegin() + lengthLanding);
        auto i2 = (waypoints2.begin() + lengthTakeoff);
        for (; (i1 != waypoints1.rend() && i2 != waypoints2.end()); (++i1, ++i2))
        {
            // Verify that both paths are on the same map
            if ((*i1)->mapid != (*i2)->mapid)
                break;
            // Verify that there are no transitions between maps on either end
            if ((last1 && last1->mapid != (*i1)->mapid) || (last2 && last2->mapid != (*i2)->mapid))
                break;
            // Quick check for distance to destination on 2d plane
            auto distsq = [&destination] (TaxiPathNodeEntry const* node) {
                return (std::pow((destination->x - node->x), 2) + std::pow((destination->y - node->y), 2));
            };
            if (distsq(*i1) > refdistsq && distsq(*i2) > refdistsq)
            {
                first.nodeEnd = (*i1)->index;
                second.nodeStart = (*i2)->index;
                return true;
            }
            last1 = (*i1);
            last2 = (*i2);
        }
    }
    return false;
}
