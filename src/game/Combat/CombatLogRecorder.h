#pragma once

// ---------------------------------------------------------------------------
// [副本数据采集 2026-10-18 站长口径] 服务端"战斗日志"（与客户端 CombatLog 同口径的事件流）。
//
// 站长原话："我们直接记录和读取战斗日志就行了" / "用客户端/combatlog 相同的功能"。
//
// 做法：不自己发明"拉怪"判据，而是在核心的伤害/治疗/施法/死亡路径上打点，
//   产出与客户端战斗日志同类的事件（SWING_DAMAGE / SPELL_DAMAGE / SPELL_PERIODIC_DAMAGE /
//   SPELL_HEAL / SPELL_CAST_START / SPELL_CAST_SUCCESS / UNIT_DIED），
//   落 `logs/combatlog_instances.csv`（CSV，一行一个事件；含 map/instance，便于按场次复盘）。
//
// 只记**副本图**（5 人本/团本）里"至少一方是玩家（含宠物，追溯主人）"的事件：
//   - 真人玩家数据是主要目标，bot 也一起记（`*_bot` 列区分，离线可只看 is_bot=0）；
//   - 非副本、非玩家事件一律不记（日志量可控、且不会污染 Server.log）。
//
// 读取侧：`dev/analyzers/analyze_combatlog.py`（按场次还原拉怪顺序/战斗指标/敌方读条）。
// 失败/无法建文件 ⇒ 全模块静默失效，不影响战斗。
// ---------------------------------------------------------------------------

#include "Globals/SharedDefines.h"

class SpellEntry;
class Unit;

namespace combatlog
{
    // [Unit.cpp → Unit::DealDamage()] 伤害（含近战/法术/DoT/伤害盾）
    void OnDamage(Unit* dealer, Unit* victim, uint32 damage, DamageEffectType type,
                  SpellSchoolMask schoolMask, SpellEntry const* spell);

    // [Unit.cpp → Unit::DealHeal()] 有效治疗
    void OnHeal(Unit* healer, Unit* victim, int32 gain, SpellEntry const* spell);

    // [Spell.cpp → Spell::SendSpellStart()] 开始读条（castTime > 0 才记）
    void OnCastStart(Unit* caster, Unit* target, SpellEntry const* spell, int32 castTime);

    // [Spell.cpp → Spell::SendSpellGo()] 施法成功
    void OnCastSuccess(Unit* caster, Unit* target, SpellEntry const* spell);

    // [Unit.cpp → Unit::Kill()] 死亡
    void OnDeath(Unit* killer, Unit* victim, SpellEntry const* spell);

    // [仿真 2026-10-19] 指定地图上最近一次"玩家（含 bot）对敌对单位造成伤害"的世界时间
    //   （毫秒，0=还没记过）。SimScenario 用它判断"在战斗里但 15 秒没有任何伤害"= 打不动/不可达
    //   ⇒ 跳过当前波继续推进。按 map 分开记，多组并发时互不掩盖。
    uint32 LastPlayerDamageMs(uint32 mapId);
}
