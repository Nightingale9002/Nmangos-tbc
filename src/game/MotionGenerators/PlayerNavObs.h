#pragma once

// ---------------------------------------------------------------------------
// [2026-10-19 站长口径] 真人跳跃 / 电梯标注观测
//
// 站长原话："在服务器上部署一个日志，抓客户端真人跳跃的动作，以及起点和落点，
//   和起点落点的方块，做人工标注。还有电梯的标注。"
//
// 做法：在**客户端移动包处理处**（WorldSession::HandleMovementOpcodes）打点：
//   ① 跳跃：MSG_MOVE_JUMP（起跳，记起点）→ MSG_MOVE_FALL_LAND（落地，记落点），
//      同时记录起点/落点所在 mmap tile（"方块" = tile_x/tile_y）与位移/落差/耗时；
//   ② 电梯：没有客户端"电梯包"，用竖移特征近似——不动水平、持续上下移动、非下落/游泳，
//      累计 |dz| >= 4 码视为一次"升降台乘坐"，记录上/下点与所在 tile。
// 落库（世界库）：ai_playerbot_jump_obs / ai_playerbot_lift_obs，`verified=0` 等人工标注。
// 服务端发起的跳跃（bot MoveJump）也记一份（is_bot=1），本地仿真可验证同一套表。
// ---------------------------------------------------------------------------

#include "Globals/SharedDefines.h"

class Player;
class Unit;
class MovementInfo;

namespace navobs
{
    // 启动日志（World::SetInitialWorldSettings 调）：确认云端跑的是带观测的二进制
    void Init();

    // 真人客户端移动包（MovementHandler.cpp → HandleMovementOpcodes 调）
    void OnClientMove(Player* player, Unit* mover, uint32 opcode, MovementInfo const& info);

    // 服务端发起的跳跃（MotionMaster::MoveJump）：bot 的跳跃也记一份（is_bot=1）
    void OnServerJump(Unit* unit, float srcX, float srcY, float srcZ,
                      float dstX, float dstY, float dstZ);
}
