-- dev/rollback/124_回滚_挂单量还原.sql
-- 把 dev/124 改过的 target/capacity 还原成改动前的值（静态写死；按新值分组做守卫）。
-- 幂等：带 `AND target = <dev/124 设的新值>` 守卫 ⇒ 重跑 0 行。

UPDATE `tbccharacters`.`ahbot_market_state` SET `target` = 400, `capacity` = 1200 WHERE `auction_house` = 2 AND `item` IN (10938,10939,10998,11082,11134,11135,11174,11175,16202,16203,22446,22447) AND `target` = 100 AND `capacity` = 300;
UPDATE `tbccharacters`.`ahbot_market_state` SET `target` = 400, `capacity` = 1200 WHERE `auction_house` = 2 AND `item` IN (10978,11084,11138,11139,11177,11178,14343,14344,20725,22448,22449,22450) AND `target` = 200 AND `capacity` = 600;
UPDATE `tbccharacters`.`ahbot_market_state` SET `target` = 800, `capacity` = 2400 WHERE `auction_house` = 2 AND `item` IN (3857,22572,22573,22574,22575,22576,22577,22578) AND `target` = 100 AND `capacity` = 300;
UPDATE `tbccharacters`.`ahbot_market_state` SET `target` = 800, `capacity` = 2400 WHERE `auction_house` = 2 AND `item` IN (7911,13468,21884,21885,21886,22451,22452,22456,22457,23426,23427) AND `target` = 200 AND `capacity` = 600;
UPDATE `tbccharacters`.`ahbot_market_state` SET `target` = 1600, `capacity` = 4800 WHERE `auction_house` = 2 AND `item` IN (765,785,2318,2319,2447,2449,2450,2452,2453,2589,2592,2770,2771,2772,2775,2776,2835,2836,2838,2840,2841,2842,3356,3357,3358,3575,3576,3577,3818,3819,3820,3821,3858,3859,3860,4234,4304,4306,4338,4625,6037,7912,8153,8170,8831,8836,8838,8839,8845,8846,10620,10940,11083,11137,11176,12359,12365,13463,13464,13465,13466,13467,14047,16204,21877,21887,22445,22710,22785,22786,22787,22788,22789,22790,22791,22792,22793,22794,22797,23424,23425,23445,23446,23447,23448,23449,23573) AND `target` = 200 AND `capacity` = 600;
