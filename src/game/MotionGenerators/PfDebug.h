/*
 * PfDebug.h - unified pathfinding debug-log filter.
 *
 * Every pathfinding log (PathFinder / TargetedMovementGenerator /
 * MoveSplineInit / WaypointMovementGenerator / HomeMovementGenerator ...)
 * uses IsPfDbg(unit) so only creatures carrying aura 10909 (Mind Vision)
 * print anything - avoids log spam. Kept in code (local + cloud deploy)
 * to diagnose all pathfinding issues at once (creature clipping up floors,
 * falling into deep water, ...). Unified prefix "[PFDBG] ".
 */
#ifndef CMANGOS_MOTIONGENERATORS_PFDEBUG_H
#define CMANGOS_MOTIONGENERATORS_PFDEBUG_H

#include "Entities/Unit.h"
#include "Log/Log.h"

// Unified gate: only creatures carrying aura 10909 (Mind Vision) emit PFDBG logs.
static inline bool IsPfDbg(Unit const* u)
{
    return u && u->GetTypeId() == TYPEID_UNIT && u->HasAura(10909);
}

// Emit one pathfinding debug line (aura 10909 gated). Single-line macro.
#define PFDBG_MSG(u, ...) do { if (IsPfDbg(u)) sLog.outError("[PFDBG] " __VA_ARGS__); } while (false)

#endif // CMANGOS_MOTIONGENERATORS_PFDEBUG_H
