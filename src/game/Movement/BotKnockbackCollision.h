#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <initializer_list>

namespace Movement
{
    struct KnockbackLanding
    {
        float x, y, z;
        bool blocked;
    };

    // Sweep the body along the ballistic displacement, rather than raycasting
    // only the final ground segment. The callback resolves real map geometry
    // and moves its destination to just before the first collision.
    template<class Trace>
    KnockbackLanding TraceKnockbackLanding(float x, float y, float z, float angle,
        float horizontalSpeed, float verticalSpeed, float bodyHeight, Trace&& trace)
    {
        float constexpr gravity = 19.291105f;
        if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(z) || !std::isfinite(angle)
            || !std::isfinite(horizontalSpeed) || !std::isfinite(verticalSpeed) || !std::isfinite(bodyHeight))
            return {x, y, z, true};
        float const horizontal = std::max(0.1f, horizontalSpeed);
        float const vertical = std::max(0.1f, verticalSpeed);
        float const flight = 2.0f * vertical / gravity;
        uint32_t const steps = uint32_t(std::max(1.0f, std::min(4096.0f, std::ceil(flight / 0.025f))));
        float const dx = std::cos(angle) * horizontal, dy = std::sin(angle) * horizontal;
        KnockbackLanding previous{x, y, z, false};
        for (uint32_t step = 1; step <= steps; ++step)
        {
            float const time = flight * float(step) / float(steps);
            KnockbackLanding next{x + dx * time, y + dy * time,
                z + vertical * time - 0.5f * gravity * time * time, false};
            KnockbackLanding nearest = next;
            float nearestDistance = 1.0e30f;
            for (float offset : {0.25f, std::max(0.5f, bodyHeight * 0.9f)})
            {
                float hitX = next.x, hitY = next.y, hitZ = next.z + offset;
                if (!trace(previous.x, previous.y, previous.z + offset, hitX, hitY, hitZ)) continue;
                hitZ -= offset;
                float const hx = hitX - previous.x, hy = hitY - previous.y, hz = hitZ - previous.z;
                float const distance = hx * hx + hy * hy + hz * hz;
                if (distance >= nearestDistance) continue;
                nearestDistance = distance;
                nearest = {hitX, hitY, hitZ, true};
            }
            if (nearest.blocked) return nearest;
            previous = next;
        }
        return previous;
    }
}
