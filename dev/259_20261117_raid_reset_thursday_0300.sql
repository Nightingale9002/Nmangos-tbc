-- Character database (tbccharacters). 团队副本重置时间 → **每周四 03:00（北京时间）**。
--
-- 机制（`MapPersistentStateMgr.cpp → DungeonResetScheduler::LoadResetTimes()`）：
--   1. 启动时读 `instance_reset.resettime`，然后强制归一化：
--        newresettime = (oldresettime / DAY) * DAY + Instance.ResetTimeHour * HOUR
--      即"UTC 当日零点 + 配置小时"，所以**重置小时必须由配置决定**，改库里的时刻会被抹掉。
--   2. 周周期保留星期几（按 period 加 7 天），所以要把星期挪到周四，只能改这里的日期。
--
-- 现状：`Instance.ResetTimeHour = 0` ⇒ 00:00 UTC = 08:00 北京时间；周常团本在周二 08:00。
-- 目标：周四 03:00 北京时间 = 周三 19:00 UTC ⇒ 配置改成 19，行值写成周三 19:00 UTC 的 epoch。
--   目标 epoch：1795028400  = 2026-11-19 03:00:00 +08:00（首次生效），之后每次 +7 天。
--
-- 影响范围：只改**周常团本**（当前 resettime=1795478400 的那批，周二组）。
--   3 天重置的团本（ZA 568、ZG 309、AQ20 509）不动；日/英雄副本的重置小时会跟着配置一起变成 03:00。
--
-- 幂等：重复执行结果相同。

UPDATE `instance_reset`
   SET `resettime` = 1795028400
 WHERE `mapid` IN (409,469,531,532,533,534,544,548,550,564,565,580);

SELECT `mapid`, `resettime`, FROM_UNIXTIME(`resettime`) AS reset_local, DAYNAME(FROM_UNIXTIME(`resettime`)) AS dow
  FROM `instance_reset` WHERE `mapid` IN (409,469,531,532,533,534,544,548,550,564,565,580) ORDER BY `mapid`;
