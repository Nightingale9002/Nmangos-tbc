#ifndef MANGOS_MOVEMENT_OWNERSHIP_H
#define MANGOS_MOVEMENT_OWNERSHIP_H

#include <cstdint>

// Bot intent, not a replacement for the core's physical movement/control rules.
// Native operations (outside the bot update scope) remain authoritative.
enum class MovementOwner : std::uint8_t
{
    Native, Ordinary, Follow, Combat, Stay, Opening, Pullback, ManualPullback, Arena, Formation,
    Seat, Mechanic, Reaction, TrackedCone, CastAvoidance, AuraSeparation, Escape
};

constexpr unsigned MovementPriority(MovementOwner owner)
{
    switch (owner)
    {
        case MovementOwner::Native: return 1000;
        case MovementOwner::Ordinary: return 10;
        case MovementOwner::Follow: return 20;
        case MovementOwner::Combat: return 30;
        case MovementOwner::Stay: return 32;
        case MovementOwner::Opening: return 35;
        case MovementOwner::Pullback: return 40;
        case MovementOwner::ManualPullback: return 41;
        case MovementOwner::Arena: return 45;
        case MovementOwner::Formation: return 50;
        case MovementOwner::Seat: return 60;
        case MovementOwner::Mechanic: return 70;
        case MovementOwner::Reaction: return 75;
        case MovementOwner::TrackedCone: return 80;
        case MovementOwner::CastAvoidance: return 90;
        case MovementOwner::AuraSeparation: return 95;
        case MovementOwner::Escape: return 100;
    }
    return 0;
}

// Stored with the MotionMaster, never in a global or thread-local bot map.
// A frame reservation also protects a stationary mechanic slot, without
// suppressing unrelated spell/healing decisions for the rest of that tick.
class MovementOwnership
{
public:
    bool MaySubmit(MovementOwner requested) const
    {
        return requested == MovementOwner::Native
            || (Allows(active, requested) && Allows(reserved, requested));
    }
    void BeginUpdate() { reserved = MovementOwner::Native; }
    void InvalidateMotion() { active = MovementOwner::Native; }
    void Reset() { active = reserved = MovementOwner::Native; }
    bool Reserve(MovementOwner owner)
    {
        if (!MaySubmit(owner)) return false;
        reserved = owner;
        return true;
    }
    void Commit(MovementOwner owner)
    {
        active = owner;
        reserved = owner;
    }
    void Release(MovementOwner owner)
    {
        if (active == owner) active = MovementOwner::Native;
        if (reserved == owner) reserved = MovementOwner::Native;
    }
    bool Owns(MovementOwner owner) const
    {
        return owner != MovementOwner::Native && active == owner;
    }
    MovementOwner Active() const { return active; }

private:
    static bool Allows(MovementOwner existing, MovementOwner requested)
    {
        return existing == MovementOwner::Native || existing == requested
            || MovementPriority(requested) > MovementPriority(existing);
    }
    MovementOwner active = MovementOwner::Native;
    MovementOwner reserved = MovementOwner::Native;
};

#endif
