-- ============================================================================
-- 097_至尊二戒掉率提高_0.1改为0.5.sql（2026-09-20）
--
-- 站长诉求：让「至尊二戒」（The 2 Ring，entry 34837）这个奖励**更容易出**。
--
-- ── 它现在怎么来的（实测链路，全通）──
--   NPC 25580 Old Man Barlo（沙塔斯，map 530，1 个刷点）
--     → 5 个钓鱼日常：11665 奖 35348 / 11666~11669 奖 34863
--     → 每次完成奖 1 个「钓鱼宝藏袋」
--     → 开袋走 item_loot_template → 参考组 10000
--     → 组内 groupid=2 的竞争组里，至尊二戒几率 **0.1%**
--   组内档位对照（它是组内垫底）：
--     实用件：食谱·拉姆瑟船长特酿 4% / 暗影珍珠 3% / 真银渔线 2%
--     收藏件：酒杯·婚戒·义眼·雕像·硬币·日志·手铐·眼镜·剃须刀 各 1.5%；海洋之眼·渔帽·日记 各 1%
--     至尊二戒 **0.1%**   ← 比组内任何东西都稀有 10~40 倍
--
-- ── 改动 ──
--   reference_loot_template（entry=10000, item=34837）的 ChanceOrQuestChance：
--   **0.1 → 0.5**（提高 5 倍）。
--   * 只动这一行 —— 组内另外 25 件、5 个任务、袋子本身都不碰。
--   * 0.5 仍低于组内"收藏档"的 1%，保住"至尊"的定位。
--   * 无连带影响：它不进任何掉落表；也不影响 AHBot
--     （钓鱼宝藏袋不在 bot 的开袋候选池里 —— 见 KNOWN_ISSUES 第 6 节）。
--   * 竞争组的代价：groupid=2 是"最多出一件"的竞争组，至尊二戒从 0.1% 提到 0.5%
--     会让同组其他件理论上各少一点点（合计约 0.4 个百分点），量级可忽略。
--
-- ⚠️ 该列类型是 **float**：0.5 能被二进制精确表示（不像 0.1 会存成 0.10000000149），
--    所以本次没有浮点误差。但**以后再用小数阈值比较这一列，务必加容差**（KNOW_ISSUES 记过这个坑）。
--
-- 幂等：绝对赋值，重复执行结果一致。
-- 回滚：UPDATE reference_loot_template r
--         JOIN reference_loot_template_bak_20260920_ring b
--           ON b.entry = r.entry AND b.item = r.item
--         SET r.ChanceOrQuestChance = b.ChanceOrQuestChance;
-- 生效：掉落模板由 mangosd 在启动时载入 → **需重启**（随夜间重启；不要热 reload，会卡）。
-- ============================================================================

USE tbcmangos;

-- 备份改前值（首次执行时创建；已存在则不动）
CREATE TABLE IF NOT EXISTS reference_loot_template_bak_20260920_ring AS
SELECT entry, item, ChanceOrQuestChance, groupid, mincountOrRef, maxcount
  FROM reference_loot_template WHERE entry = 10000 AND item = 34837;

UPDATE reference_loot_template
   SET ChanceOrQuestChance = 0.5
 WHERE entry = 10000 AND item = 34837;

-- ---------------------------------------------------------------------------
-- 校验 1：改后值（期望 0.5），并跟备份对照
-- ---------------------------------------------------------------------------
SELECT r.entry, r.item, b.ChanceOrQuestChance AS before_val, r.ChanceOrQuestChance AS after_val
  FROM reference_loot_template r
  JOIN reference_loot_template_bak_20260920_ring b
    ON b.entry = r.entry AND b.item = r.item;

-- ---------------------------------------------------------------------------
-- 校验 2：组内档位（至尊二戒应升到 0.5%，仍低于 1% 的收藏档）
-- ---------------------------------------------------------------------------
SELECT item, ChanceOrQuestChance, groupid FROM reference_loot_template
 WHERE entry = 10000 ORDER BY ChanceOrQuestChance DESC;

-- ---------------------------------------------------------------------------
-- 校验 3：确认只改了目标那一行（期望 1）
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS rows_changed FROM reference_loot_template
 WHERE entry = 10000 AND item = 34837 AND ChanceOrQuestChance = 0.5;
