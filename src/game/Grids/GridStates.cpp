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

#include "Grids/GridStates.h"
#include "Log/Log.h"

void
InvalidState::Update(Map&, NGridType&, GridInfo&, const uint32& /*x*/, const uint32& /*y*/, const uint32&) const
{
}

void
ActiveState::Update(Map& m, NGridType& grid, GridInfo& info, const uint32& x, const uint32& y, const uint32& t_diff) const
{
    // Only check grid activity every (grid_expiry/10) ms, because it's really useless to do it every cycle
    info.UpdateTimeTracker(t_diff);
    if (info.getTimeTracker().Passed())
    {
        // [MEMFIX] Grid transitions to IDLE based on players (and transports) only;
        // active creatures no longer keep the grid alive (full lazy-load, prevents
        // memory growth from active-creature events with no player around).
        if (!m.ActiveObjectsNearGrid(x, y))
        {
            grid.SetGridState(GRID_STATE_IDLE);
        }
        else
        {
            m.ResetGridExpiry(grid, 0.1f);
        }
    }
}

void
IdleState::Update(Map& m, NGridType& grid, GridInfo&, const uint32& x, const uint32& y, const uint32&) const
{
    m.ResetGridExpiry(grid);
    grid.SetGridState(GRID_STATE_REMOVAL);
    DEBUG_LOG("Grid[%u,%u] on map %u moved to IDLE state", x, y, m.GetId());
}

void
RemovalState::Update(Map& m, NGridType& grid, GridInfo& info, const uint32& x, const uint32& y, const uint32& t_diff) const
{
    // [MEMFIX-A 2026-10-02] A grid that is only pinned by active-object spawn locks is no
    // longer stuck forever. Removal used to be skipped whenever getUnloadLock() was set, but
    // the only code releasing that lock runs *inside* the unload (ObjectGridUnloader ->
    // RemoveFromActive), so any grid that ever loaded a creature with
    // CREATURE_EXTRA_FLAG_ACTIVE stayed resident until the process restarted - that is what
    // the measured daily RSS growth (30 MB/h, 540MB -> 1.25GB) was made of.
    // Now, once the cleanup timer has expired with no player near, the active objects living
    // in this grid are unbound (Map::ReleaseActiveGridLocks) and the unload runs in this same
    // tick, so the lock is never released for an object the unload does not take care of.
    if (info.getUnloadLock())
    {
        if (m.ActiveObjectsNearGrid(x, y))
            return;

        info.UpdateTimeTracker(t_diff);
        if (!info.getTimeTracker().Passed())
            return;

        if (!m.ReleaseActiveGridLocks(x, y))
        {
            // a holder outside this grid (an active object that wandered away) keeps its
            // lock: stay in removal state and retry on the next cleanup interval
            m.ResetGridExpiry(grid);
            return;
        }
    }
    else
    {
        info.UpdateTimeTracker(t_diff);
        if (!info.getTimeTracker().Passed())
            return;
    }

    if (!m.UnloadGrid(x, y, false))
    {
        DEBUG_LOG("Grid[%u,%u] for map %u differed unloading due to players or active objects nearby", x, y, m.GetId());
        m.ResetGridExpiry(grid);
    }
}
