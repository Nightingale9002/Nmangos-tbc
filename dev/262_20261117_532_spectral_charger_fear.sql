-- [2026-11-17] 532（卡拉赞）鬼灵战马登记为“会恐惧”的怪，让萨满插战栗图腾。
--
-- 现象：云端萨满对鬼灵战马（Spectral Charger, entry 15547）不插战栗图腾。
-- 根因：DpsFsm.cpp → ShUpdateFoeFlags() 判“有恐惧敌人”只有两条路：
--   ① ai_playerbot_cc_creature 里该 map/entry 的 has_fear=1；
--   ② 当场看到该怪在读恐惧（CURRENT_GENERIC_SPELL/CHANNELED 里带 MOD_FEAR）。
--   鬼灵战马的恐惧不是读条，而是 EventAI：被冲锋(29320)命中后直接触发
--   creature_ai_scripts 1554702 → action 11 cast 29321（Fear）⇒ ② 基本抓不到。
--   而 532 图在 ai_playerbot_cc_creature 里一行都没有 ⇒ 判定恒为 false。
--
-- 处理：只补数据，不改代码；幂等（PRIMARY KEY map,entry）。生效无需重启：
--   ShUpdateFoeFlags() 每 60 秒（按 map 缓存）重新读一次该表。
INSERT INTO `ai_playerbot_cc_creature` (`map`, `entry`, `has_fear`, `has_spell`) VALUES
  (532, 15547, 1, 1)
ON DUPLICATE KEY UPDATE `has_fear` = VALUES(`has_fear`), `has_spell` = VALUES(`has_spell`);
