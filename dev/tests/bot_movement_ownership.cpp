// Standalone: g++ -std=c++17 -Isrc/game dev/tests/bot_movement_ownership.cpp -o /tmp/bot-movement-test
#include "MotionGenerators/MovementOwnership.h"
#include <cstdlib>
#include <iostream>

static void Require(bool condition)
{
    if (!condition) std::abort();
}

int main()
{
    MovementOwnership movement;
    movement.Commit(MovementOwner::Follow);
    Require(movement.MaySubmit(MovementOwner::Combat));
    movement.Commit(MovementOwner::Combat);
    Require(!movement.MaySubmit(MovementOwner::Follow));
    Require(!movement.MaySubmit(MovementOwner::Ordinary));

    // A stale combat release must never cancel the escape that replaced it.
    Require(movement.MaySubmit(MovementOwner::Escape));
    movement.Commit(MovementOwner::Escape);
    movement.Release(MovementOwner::Combat);
    Require(movement.Owns(MovementOwner::Escape));
    movement.BeginUpdate();
    Require(!movement.MaySubmit(MovementOwner::Combat));
    movement.InvalidateMotion();
    Require(movement.MaySubmit(MovementOwner::Combat));

    // Finishing motion must preserve the stationary hold until the next update.
    movement.Commit(MovementOwner::TrackedCone);
    movement.InvalidateMotion();
    Require(!movement.MaySubmit(MovementOwner::Combat));
    Require(movement.MaySubmit(MovementOwner::TrackedCone));
    Require(movement.MaySubmit(MovementOwner::CastAvoidance));
    Require(!movement.Reserve(MovementOwner::Combat));
    movement.BeginUpdate();
    Require(movement.MaySubmit(MovementOwner::Follow));

    // Manual pullback cancellation must not release automatic pullback.
    movement.Commit(MovementOwner::Pullback);
    movement.Release(MovementOwner::ManualPullback);
    Require(movement.Owns(MovementOwner::Pullback));
    Require(movement.MaySubmit(MovementOwner::ManualPullback));

    // Death/teleport/reset releases both in-flight motion and stationary holds.
    movement.Commit(MovementOwner::AuraSeparation);
    movement.Reset();
    Require(!movement.Owns(MovementOwner::AuraSeparation));
    Require(movement.MaySubmit(MovementOwner::Ordinary));
    movement.Commit(MovementOwner::Seat);
    Require(!movement.MaySubmit(MovementOwner::Arena));
    Require(movement.Owns(MovementOwner::Seat));
    Require(movement.MaySubmit(MovementOwner::Seat));
    Require(movement.MaySubmit(MovementOwner::Native));
    std::cout << "movement ownership scenarios passed\n";
}
