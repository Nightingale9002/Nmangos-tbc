/*
 * [副本数据采集 2026-10-18 站长口径] 服务端战斗日志（与客户端 CombatLog 同口径）
 * 见 Combat/CombatLogRecorder.h 顶部注释；读取侧 dev/analyzers/analyze_combatlog.py。
 */

#include "Combat/CombatLogRecorder.h"

#include "Config/Config.h"
#include "Entities/Creature.h"
#include "Entities/Player.h"
#include "Log/Log.h"
#include "Maps/Map.h"
#include "Spells/SpellMgr.h"
#include "Util/Timer.h"

#include <atomic>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <mutex>
#include <string>
#include <unordered_map>

namespace
{
    const char* kLogFileName = "combatlog_instances.csv";
    // [2026-10-18 仿真] 只按行数刷盘时，短场景（<256 事件）被 kill/关服会**整段丢日志**（实测跑完 0 字节）。
    //   加"每 2 秒至少刷一次"，线上下副本本来事件量就小，最多丢 2 秒。
    const uint32 kFlushEveryLines = 256;
    const uint32 kFlushEverySeconds = 2;

    std::mutex fileMutex;
    std::ofstream file;
    bool openTried = false;
    bool openFailed = false;
    uint32 linesSinceFlush = 0;
    time_t lastFlushTime = 0;
    bool headerWritten = false;

    // [仿真 2026-10-19] "玩家对敌对单位造成伤害"的最近时间（按 map 分开记）；SimScenario 的 15 秒零伤害守卫用
    std::mutex lastDamageMutex;
    std::unordered_map<uint32, uint32> lastPlayerDamageMsByMap;

    // 宠物/图腾/召唤物 → 追溯主人（本轮只看一层：宠物 → 主人）
    Player* AsPlayer(Unit* unit)
    {
        if (!unit)
            return nullptr;

        if (unit->GetTypeId() == TYPEID_PLAYER)
            return static_cast<Player*>(unit);

        if (Unit* owner = unit->GetOwner())
            if (owner->GetTypeId() == TYPEID_PLAYER)
                return static_cast<Player*>(owner);

        return nullptr;
    }

    bool IsInstanceMap(Unit* unit)
    {
        Map* map = unit ? unit->GetMap() : nullptr;
        return map && (map->IsDungeon() || map->IsRaid());
    }

    // 只记"副本里、至少一方是玩家（含宠物主人）"的事件
    bool ShouldLog(Unit* src, Unit* dst)
    {
        Unit* any = src ? src : dst;
        if (!IsInstanceMap(any))
            return false;

        return AsPlayer(src) || AsPlayer(dst);
    }

    char UnitType(Unit* unit)
    {
        if (!unit)
            return '-';
        return unit->GetTypeId() == TYPEID_PLAYER ? 'P' : 'C';
    }

    // 1 = bot（模块机器人），0 = 真人 / 非玩家
    int UnitBot(Unit* unit)
    {
#ifdef ENABLE_PLAYERBOTS
        if (Player* player = AsPlayer(unit))
            return player->isRealPlayer() ? 0 : 1;
#else
        (void)unit;
#endif
        return 0;
    }

    std::string EscapeName(Unit* unit)
    {
        if (!unit)
            return std::string();

        const char* name = unit->GetName();
        std::string out;
        for (const char* p = name; p && *p; ++p)
        {
            if (*p == '"')
                out += "\"\"";
            else
                out += (*p == '\n' || *p == '\r' || *p == ',') ? ' ' : *p;
        }
        return out;
    }

    std::ofstream* GetFile()
    {
        if (openTried)
            return openFailed ? nullptr : &file;

        openTried = true;

        std::string dir = sConfig.GetStringDefault("LogsDir");
        if (!dir.empty() && dir[dir.size() - 1] != '/' && dir[dir.size() - 1] != '\\')
            dir += '/';

        const std::string path = dir + kLogFileName;
        file.open(path.c_str(), std::ios::out | std::ios::app);
        if (!file.is_open())
        {
            openFailed = true;
            sLog.outString("[CLOG] 打不开战斗日志 %s —— 战斗日志关闭", path.c_str());
            return nullptr;
        }

        sLog.outString("[CLOG] 战斗日志: %s", path.c_str());

        // 新文件先写表头（旧文件按内容判断）
        file.seekp(0, std::ios::end);
        if (file.tellp() == std::streampos(0))
        {
            file << "ts,map,inst,event,src_guid,src_name,src_entry,src_type,src_bot,"
                    "dst_guid,dst_name,dst_entry,dst_type,dst_bot,spell,amount,school,cast_ms\n";
            headerWritten = true;
        }

        return &file;
    }

    void WriteLine(char const* event, Unit* src, Unit* dst, uint32 spellId,
                   int32 amount, uint32 school, int32 castMs)
    {
        if (!ShouldLog(src, dst))
            return;

        std::lock_guard<std::mutex> lock(fileMutex);

        std::ofstream* out = GetFile();
        if (!out)
            return;

        Map* map = (src && src->GetMap()) ? src->GetMap() : (dst ? dst->GetMap() : nullptr);
        if (!map)
            return;

        char buf[1024];
        snprintf(buf, sizeof(buf),
            "%u,%u,%u,%s,%u,\"%s\",%u,%c,%d,%u,\"%s\",%u,%c,%d,%u,%d,%u,%d\n",
            uint32(time(nullptr)), map->GetId(), map->GetInstanceId(), event,
            src ? src->GetGUIDLow() : 0, EscapeName(src).c_str(), src ? src->GetEntry() : 0,
            UnitType(src), UnitBot(src),
            dst ? dst->GetGUIDLow() : 0, EscapeName(dst).c_str(), dst ? dst->GetEntry() : 0,
            UnitType(dst), UnitBot(dst),
            spellId, amount, school, castMs);

        *out << buf;

        time_t const now = time(nullptr);
        if (++linesSinceFlush >= kFlushEveryLines ||
            lastFlushTime == 0 || now - lastFlushTime >= (time_t)kFlushEverySeconds)
        {
            out->flush();
            linesSinceFlush = 0;
            lastFlushTime = now;
        }
    }
}

namespace combatlog
{
    void OnDamage(Unit* dealer, Unit* victim, uint32 damage, DamageEffectType type,
                  SpellSchoolMask schoolMask, SpellEntry const* spell)
    {
        if (!damage || !victim)
            return;

        // [仿真 2026-10-19] 只记"玩家/宠物/图腾 打 敌对单位"的时间戳（不受日志开关影响）
        if (AsPlayer(dealer) && victim->GetTypeId() == TYPEID_UNIT)
        {
            std::lock_guard<std::mutex> guard(lastDamageMutex);
            lastPlayerDamageMsByMap[victim->GetMapId()] = WorldTimer::getMSTime();
        }

        const char* event = "SWING_DAMAGE";
        if (spell)
            event = (type == DOT) ? "SPELL_PERIODIC_DAMAGE" : "SPELL_DAMAGE";

        WriteLine(event, dealer, victim, spell ? spell->Id : 0, int32(damage),
                  uint32(schoolMask), 0);
    }

    void OnHeal(Unit* healer, Unit* victim, int32 gain, SpellEntry const* spell)
    {
        if (!victim || gain <= 0)
            return;

        WriteLine("SPELL_HEAL", healer, victim, spell ? spell->Id : 0, gain, 0, 0);
    }

    void OnCastStart(Unit* caster, Unit* target, SpellEntry const* spell, int32 castTime)
    {
        if (!caster || !spell)
            return;

        // 与客户端一致：只有"有读条时间"的才发 SPELL_CAST_START（瞬发只有 CAST_SUCCESS）
        if (castTime <= 0)
            return;

        WriteLine("SPELL_CAST_START", caster, target, spell->Id, 0, 0, castTime);
    }

    void OnCastSuccess(Unit* caster, Unit* target, SpellEntry const* spell)
    {
        if (!caster || !spell)
            return;

        WriteLine("SPELL_CAST_SUCCESS", caster, target, spell->Id, 0, 0, 0);
    }

    void OnDeath(Unit* killer, Unit* victim, SpellEntry const* spell)
    {
        if (!victim)
            return;

        WriteLine("UNIT_DIED", killer, victim, spell ? spell->Id : 0, 0, 0, 0);
    }

    uint32 LastPlayerDamageMs(uint32 mapId)
    {
        std::lock_guard<std::mutex> guard(lastDamageMutex);
        auto it = lastPlayerDamageMsByMap.find(mapId);
        return it == lastPlayerDamageMsByMap.end() ? 0 : it->second;
    }
}
