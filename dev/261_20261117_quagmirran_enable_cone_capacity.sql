-- Character database (tbccharacters). 启用夸格米拉的锥形容量与点名后临时跑位。
--
-- `cone_max_targets=2`：任一完整酸液锥窗口内**计划**最多暴露 2 人（站长口径：一人一位不够分时取 n=2）。
-- `cone_react_on_target=1`：引导目标确定后触发临时跑位（Evade/SafeHold/Recover），非点名者去最近可达锥外点。
-- 只影响 profile id=1（547/17942、549/19894 绑定到它），其它 boss 的 profile 不受影响。
-- encounter strategy 快照 5 秒刷新，落库即生效，不需要重启。

UPDATE `ai_playerbot_strategy_profile`
   SET `cone_max_targets`=2, `cone_react_on_target`=1
 WHERE `id`=1 AND `executor`='tracked_cone';

SELECT `id`,`name`,`cone_degrees`,`separation_degrees`,`cone_max_targets`,`cone_react_on_target`
  FROM `ai_playerbot_strategy_profile` WHERE `id`=1;
