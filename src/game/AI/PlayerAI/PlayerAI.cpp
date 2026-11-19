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

#include "PlayerAI.h"
#include "Entities/Player.h"
#include "Spells/SpellMgr.h"
#include "World/World.h"
#include <limits>

// Blackheart the Inciter (Shadow Labyrinth): "Incite Chaos" charm. The charm aura (33684,
// SPELL_AURA_MOD_CHARM) is applied by the inciter trigger NPCs 19300-19304 that the players
// summon themselves. Only that charm gets a start delay - every other charm source keeps the
// old immediate behaviour, which is why the scope is keyed on the trigger entry.
enum PlayerAICharmHold
{
    CHARM_START_DELAY_MS        = 3000,
    SPELL_INCITE_CHAOS_CHARM    = 33684,
};

static const uint32 InciteChaosTriggerEntries[] = { 19300, 19301, 19302, 19303, 19304 };

static bool IsInciteChaosTrigger(Unit* charmer)
{
    if (!charmer || charmer->GetTypeId() != TYPEID_UNIT)
        return false;

    for (uint32 entry : InciteChaosTriggerEntries)
        if (charmer->GetEntry() == entry)
            return true;

    return false;
}

enum GenericPlayerAIActions
{
    GENERIC_ACTION_RESET = 1000,
    GENERIC_THREAT_CHANGE = 1001,
};

PlayerAI::PlayerAI(Player* player) : UnitAI(player), m_player(player), m_spellsDisabled(false),
    m_executeTargetChange(false), m_charmHoldEndTime(0), m_charmHoldSpellId(0)
{
    AddCustomAction(GENERIC_ACTION_RESET, true, [&]() { m_spellsDisabled = false; });
    AddCustomAction(GENERIC_THREAT_CHANGE, true, [&]() { m_executeTargetChange = true; });
}

void PlayerAI::ExecuteActions()
{
    ExecuteSpells();
}

void PlayerAI::AddPlayerSpellAction(uint32 spellId, std::function<Unit*()> selector)
{
    bool failureOnNoTarget = false;
    if (!selector)
    {
        SpellEntry const* spellInfo = sSpellTemplate.LookupEntry<SpellEntry>(spellId);
        if (spellInfo)
        {
            if (IsNextMeleeSwingSpell(spellInfo))
                selector = [&]()->Unit* { return m_player->GetVictim(); };
            else if (HasSpellTarget(spellInfo, TARGET_UNIT_ENEMY) || (spellInfo->Targets & TARGET_FLAG_DEST_LOCATION)) // always random
                selector = [&, spellId = spellInfo->Id]()->Unit* { return m_player->SelectAttackingTarget(ATTACKING_TARGET_RANDOM, 0, spellId, SELECT_FLAG_IN_LOS); };
            if (HasSpellTarget(spellInfo, TARGET_UNIT_FRIEND) || HasSpellTarget(spellInfo, TARGET_UNIT_FRIEND_CHAIN_HEAL)) // heals only target self
                selector = [&]()->Unit* { return m_player; };

            failureOnNoTarget = (spellInfo->Targets & TARGET_FLAG_DEST_LOCATION) != 0;
        }
        if (!selector) // fallback
            selector = [&]()->Unit* { return nullptr; };
    }
    m_playerSpellActions.emplace_back(spellId, failureOnNoTarget, selector);
}

void PlayerAI::ExecuteSpells()
{
    if (m_executeTargetChange && CanExecuteCombatAction())
    {
        if (Unit* target = m_player->SelectAttackingTarget(ATTACKING_TARGET_RANDOM, 0, nullptr, SELECT_FLAG_PLAYER))
            AttackStart(target);

        ResetTimer(GENERIC_THREAT_CHANGE, urand(10000, 20000));
        m_executeTargetChange = false;
    }

    if (m_spellsDisabled)
        return;

    std::shuffle(m_playerSpellActions.begin(), m_playerSpellActions.end(), *GetRandomGenerator());

    bool success = false;
    for (auto& data : m_playerSpellActions)
    {
        Unit* target = data.targetFinder();
        if (data.failureOnNoTarget && target == nullptr)
            continue;
        if (DoCastSpellIfCan(target, data.spellId) == CAST_OK)
            success = true;  
    }          

    if (success)
    {
        uint32 randomInterval = urand(0, 5);
        if (randomInterval != 0)
        {
            m_spellsDisabled = true;
            ResetTimer(GENERIC_ACTION_RESET, urand(6000, 12000));
        }
    }
}

void PlayerAI::JustGotCharmed(Unit* charmer)
{
    // Blackheart the Inciter: hold the charmed player completely still for a moment before the
    // charmed-player AI takes over (matches the reference behaviour).
    if (IsInciteChaosTrigger(charmer))
    {
        StartCharmHold(SPELL_INCITE_CHAOS_CHARM);
        return;
    }

    TakeOverCharmedActions(charmer);
}

// Everything the charmed player normally starts doing right away: follow the charmer and fight.
void PlayerAI::TakeOverCharmedActions(Unit* charmer)
{
    if (charmer && charmer->GetFormationSlot())
        charmer->GetFormationSlot()->GetFormationData()->Add(m_player);
    else if (charmer)
        m_player->GetMotionMaster()->MoveFollow(charmer, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE, true);

    AttackClosestEnemy();
}

void PlayerAI::StartCharmHold(uint32 uiSpellId)
{
    m_charmHoldEndTime = WorldTimer::getMSTime() + CHARM_START_DELAY_MS;
    m_charmHoldSpellId = uiSpellId;

    // freeze whatever the player was doing when the charm landed
    m_player->AttackStop();
    m_player->InterruptNonMeleeSpells(false);
    m_player->GetMotionMaster()->Clear(false, true);
    m_player->GetMotionMaster()->MoveIdle();

    sLog.outString("[CHARM-HOLD] guid=%u spell=%u remain_ms=%u", m_player->GetGUIDLow(),
        m_charmHoldSpellId, CHARM_START_DELAY_MS);
}

void PlayerAI::FinishCharmHold(bool bTakeOver)
{
    sLog.outString("[CHARM-HOLD] guid=%u spell=%u remain_ms=0", m_player->GetGUIDLow(),
        m_charmHoldSpellId);

    m_charmHoldEndTime = 0;
    m_charmHoldSpellId = 0;

    // bTakeOver is false when the charm ended before the delay was over - then there is nothing
    // left to take over and the player simply gets control back.
    if (bTakeOver)
        TakeOverCharmedActions(m_player->GetCharmer());
}

void PlayerAI::UpdateAI(const uint32 diff)
{
    if (m_charmHoldEndTime)
    {
        // the charm can end early (dispel, death, trigger despawn): never leave the player frozen
        if (!m_player->HasCharmer())
        {
            FinishCharmHold(false);
            return;
        }

        // stay completely still: no movement, facing, target selection, casting or melee
        if (WorldTimer::getMSTime() < m_charmHoldEndTime)
            return;

        FinishCharmHold(true);
    }

    UnitAI::UpdateAI(diff);
}

void PlayerAI::EnterEvadeMode()
{
    // never leave the player frozen when the charm encounter ends while the start delay is pending
    if (m_charmHoldEndTime)
        FinishCharmHold(false);

    m_player->CombatStopWithPets(true);
    if (Unit* charmer = m_player->GetCharmer())
    {
        if (charmer->GetFormationSlot())
        {
            charmer->GetFormationSlot()->GetFormationData()->Add(m_player);
        }
        else
            m_player->GetMotionMaster()->MoveFollow(charmer, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE, true);
    }
}

void PlayerAI::AttackClosestEnemy()
{
    // the Blackheart inciter trigger calls this straight after the charm lands; keep it inert
    // while the start delay is still running
    if (IsCharmHolding())
        return;

    float distance = std::numeric_limits<float>::max();
    AttackSpecificEnemy([&](Unit* enemy, Unit*& closestEnemy) mutable
    {
        float curDistance = enemy->GetDistance(m_unit, true, DIST_CALC_NONE);
        if (!closestEnemy || (!closestEnemy->IsPlayer() && enemy->IsPlayer()) || curDistance < distance)
        {
            closestEnemy = enemy;
            distance = curDistance;
        }
    });
}

void PlayerAI::RequestFollow(Unit* followee)
{
    m_unit->GetMotionMaster()->MoveFollow(followee, PET_FOLLOW_DIST, PET_FOLLOW_ANGLE, false, !m_unit->IsPlayerControlled());
}
