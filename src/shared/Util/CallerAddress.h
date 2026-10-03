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

// [DIAG 2026-10-03] "who drove this?" helper for the corpse/grid/socket investigations.
//
// The macros below MUST be evaluated inside the function whose CALLER we want to name, so they
// are macros and not inline functions (an inline helper would report the helper's own caller).
//
//   MANGOS_CALLER_ADDR()  - return address of the caller of the current function
//   MANGOS_IMAGE_BASE()   - base to subtract to get a value that can be looked up in the linker
//                           map (MSVC /MAP prints "Rva+Base" relative to the preferred base;
//                           the Linux mangosd/realmd binaries are non-PIE, so raw == map value)
//
// Resolution workflows:
//   Windows: python _agent_tmp/resolve_map_addr.py build1\bin\x64_Release\mangosd.map \
//                --rva <(caller - base)>
//   Linux:   addr2line -f -C -e /opt/mangos/bin/mangosd <caller>          (non-PIE: raw address)

#ifndef MANGOS_CALLER_ADDRESS_H
#define MANGOS_CALLER_ADDRESS_H

#include "Platform/Define.h"

#include <cstdio>
#include <string>

#if defined(_MSC_VER)
#  include <intrin.h>
// linker-provided symbol: its address is this module's load base (works with ASLR)
extern "C" char __ImageBase;
#  define MANGOS_CALLER_ADDR()  (reinterpret_cast<uintptr_t>(_ReturnAddress()))
#  define MANGOS_IMAGE_BASE()   (reinterpret_cast<uintptr_t>(&__ImageBase))
#  define MANGOS_HAVE_STACK     1
#elif defined(__GNUC__)
#  include <execinfo.h>
#  define MANGOS_CALLER_ADDR()  (reinterpret_cast<uintptr_t>(__builtin_return_address(0)))
#  define MANGOS_IMAGE_BASE()   (uintptr_t(0))
#  define MANGOS_HAVE_STACK     1
#else
#  define MANGOS_CALLER_ADDR()  (uintptr_t(0))
#  define MANGOS_IMAGE_BASE()   (uintptr_t(0))
#  define MANGOS_HAVE_STACK     0
#endif

namespace MaNGOS
{
    /// [DIAG 2026-10-03] Capture up to maxFrames return addresses.  Frame 0 is the caller of this
    /// function, so a caller that wants frame 0 == its own hook site skips the first two entries
    /// (this helper + itself).  Deliberately not inlined so that skip count stays stable.
    /// Raw addresses: subtract MANGOS_IMAGE_BASE() (0 on the non-PIE Linux binaries) before looking
    /// them up in the linker map / addr2line.
#if MANGOS_HAVE_STACK && defined(_MSC_VER)
    __declspec(noinline) inline size_t CaptureStack(void** frames, size_t maxFrames)
    {
        return static_cast<size_t>(::CaptureStackBackTrace(0, static_cast<DWORD>(maxFrames), frames, nullptr));
    }
#elif MANGOS_HAVE_STACK
    __attribute__((noinline)) inline size_t CaptureStack(void** frames, size_t maxFrames)
    {
        return static_cast<size_t>(::backtrace(frames, static_cast<int>(maxFrames)));
    }
#else
    inline size_t CaptureStack(void**, size_t) { return 0; }
#endif

    /// [DIAG 2026-10-03] Format the current backtrace as "0xAAAA,0xBBBB,..." with the innermost `skip`
    /// frames dropped (skip = 2 makes the first printed address the CALLER of the reporting function) and
    /// MANGOS_IMAGE_BASE() subtracted, so the values can be fed straight into the linker map (Windows) or
    /// addr2line (Linux).  Never throws, never allocates more than the returned string; returns "-" when no
    /// frame could be captured.
    inline std::string FormatBacktrace(size_t skip = 2, size_t maxFrames = 12)
    {
        if (maxFrames > 12)
            maxFrames = 12;

        void* frames[12];
        size_t const n = CaptureStack(frames, maxFrames);
        uintptr_t const base = MANGOS_IMAGE_BASE();

        std::string out;
        for (size_t i = skip; i < n; ++i)
        {
            char buf[32];
            snprintf(buf, sizeof(buf), "%s0x%llX", out.empty() ? "" : ",",
                     static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(frames[i]) - base));
            out += buf;
        }
        return out.empty() ? std::string("-") : out;
    }
}

#endif // MANGOS_CALLER_ADDRESS_H
