-- =====================================================================================
-- 157_暗影迷宫沃尔皮尔_intro喊话补中文.sql
-- 日期：2026-10-06        适用库：tbcmangos        类型：静态 / 幂等
-- -------------------------------------------------------------------------------------
-- 【现象】暗影迷宫（map 555）最终首领「高阶术士沃尔皮尔」(Grandmaster Vorpil, npc 18732)
--   进场喊话是英文。站长 2026-10-06 反馈。
-- 【定位】沃尔皮尔一共 8 条台词（boss_grandmaster_vorpil.cpp:30-37）：
--     SAY_INTRO      = -1555028  ← script_texts（注释写明"没有 bct，只有语音"）
--     SAY_AGGRO_1..3 = 17868/17869/17870
--     SAY_HELP       = 17867
--     SAY_SLAY_1/2   = 17871/17872
--     SAY_DEATH      = 17873
--   后 7 条是 broadcast_text，broadcast_text_locale 里 zhCN 译文**齐全**（已核对 21 条
--   暗影迷宫台词：Hellmaw 17859-17866、Blackheart 16433/17563/17565/17569/17573/19528、
--   Vorpil 17867-17873、Murmur 18799 全部有 zhCN），发送链
--   DoDisplayText(ObjectMgr.cpp:10774) → WorldObject::MonsterText(Object.cpp:1984)
--   → 组包时按玩家 loc_idx 取 i_content[loc_idx+1]（Object.cpp:1956）⇒ 这些是对的。
--   唯一没有译文的就是 intro 这一条：script_texts 的 content_loc1..loc8 全为 NULL
--   （tbcmangos / tbcmangos_orig / tbcdb_ref / wotlkmangos 四个库完全一致，不是我们改坏的）。
--   它是玩家走近 50 码时触发的那句（boss_grandmaster_vorpil.cpp:117-124）。
-- 【修复】给 script_texts -1555028 补 content_loc4（zhCN），文本用**官方中文台词**
--   （站长 2026-10-06 提供，与中文语音一致）：
--     集中注意力，复仇的时刻就要到来了。很快，诸界的毁灭者就要归来，并履行他的诺言。很快毁灭一切的伟大行动，就要开始啦！
--   已核对：该文本不在任何本机数据源里 —— tbcmangos / tbcmangos_orig / tbcdb_ref / wotlkmangos
--   四库 script_texts 的 content_loc1..8 全为 NULL；broadcast_text 也没有对应行
--   （按 sound 10522 与英文关键词 'minds focused' / 'days of reckoning' / 'destroyer of worlds'
--   在 tbcmangos、wotlkmangos、tbcdb_ref、acore_world 全查过，均无命中；acore_world 的
--   broadcast_text_locale 只有 1326 条 zhCN，也不含这句）。
-- 【生效】script_texts 经 ObjectMgr::LoadMangosStrings(ObjectMgr.cpp:9087/9125) 在启动时载入
--   ⇒ 需重启生效（云端随下一次夜间重启）。
-- 【回滚】dev/rollback/157_回滚_沃尔皮尔intro中文.sql
-- =====================================================================================

UPDATE `tbcmangos`.`script_texts`
   SET `content_loc4` = '集中注意力，复仇的时刻就要到来了。很快，诸界的毁灭者就要归来，并履行他的诺言。很快毁灭一切的伟大行动，就要开始啦！'
 WHERE `entry` = -1555028;

-- ---------- 核对 ----------
-- 期望：一行，content_loc4 为上面的中文，content_default 仍是英文原文
SELECT `entry`, `content_default`, `content_loc4`, `sound`, `type`, `comment`
  FROM `tbcmangos`.`script_texts` WHERE `entry` = -1555028;
-- 旁证：暗影迷宫全部台词的中文覆盖（应无 NULL）
SELECT b.`Id`, LEFT(b.`Text`, 40) AS en, LEFT(l.`Text_lang`, 20) AS zhcn
  FROM `tbcmangos`.`broadcast_text` b
  LEFT JOIN `tbcmangos`.`broadcast_text_locale` l ON l.`Id` = b.`Id` AND l.`Locale` = 'zhCN'
 WHERE b.`Id` IN (17859,17860,17861,17863,17864,17865,17866,17563,17565,17573,19528,16433,17569,
                  17867,17868,17869,17870,17871,17872,17873,18799)
 ORDER BY b.`Id`;
