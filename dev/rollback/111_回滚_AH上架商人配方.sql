-- =============================================================
-- dev/rollback/111 回滚：删除 dev/111 新增的 292 条 category=2 operator 行
-- 说明：全静态、幂等；需重启 mangosd 生效（AHBot 启动时载入该表）
-- =============================================================

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (5788, 5789, 7361, 7451, 8409, 13287, 13288, 9301, 14634, 23574, 33209, 6342);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (6346, 6377, 11039, 11101, 11163, 11223, 23147, 23151, 23153, 28291, 5786, 5787);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (5973, 6474, 6475, 7289, 7290, 7362, 7613, 8385, 14635, 15724, 15725, 15726);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (15729, 15734, 15735, 15740, 15741, 15751, 15758, 15759, 15762, 18239, 18731, 18949);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (20576, 25720, 25725, 25726, 4355, 5771, 5772, 6270, 6272, 6274, 6275, 6401);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (7087, 7088, 7089, 7114, 10311, 10314, 10317, 10318, 10321, 10323, 10325, 10326);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (10728, 14468, 14469, 14483, 14526, 14627, 14630, 18487, 21358, 21892, 21893, 21894);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (21895, 21896, 21897, 21898, 21899, 21900, 21901, 21902, 22307, 22308, 24316, 30483);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (37915, 38327, 38328, 7560, 7561, 7742, 10602, 10607, 10609, 13308, 13309, 13310);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (13311, 14639, 16046, 16050, 18647, 18648, 18649, 18650, 18652, 18656, 23799, 23803);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (23805, 23807, 23811, 23815, 23816, 32381, 6047, 7995, 10858, 12162, 12163, 12164);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (23590, 23591, 23592, 23593, 23594, 23595, 23596, 23638, 25846, 25847, 728, 2697);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (2698, 2699, 2700, 2701, 2889, 3678, 3679, 3680, 3681, 3682, 3683, 3734);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (3735, 4609, 5483, 5484, 5485, 5486, 5488, 5489, 5528, 6039, 6325, 6326);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (6328, 6329, 6330, 6368, 6369, 6892, 12226, 12228, 12229, 12231, 12232, 12233);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (12239, 12240, 13939, 13940, 13941, 13942, 13943, 13945, 13946, 13947, 13948, 13949);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (16072, 16110, 16111, 16767, 17062, 17200, 17201, 18046, 20075, 21099, 21219, 22647);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (27685, 27687, 27688, 27689, 27690, 27691, 27692, 27693, 27694, 27695, 27696, 27697);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (27698, 27699, 27700, 27736, 30156, 35564, 35566, 5640, 5642, 5643, 6053, 6054);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (6055, 6056, 6057, 6068, 9300, 9302, 9303, 9304, 9305, 12958, 13478, 22900);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (22901, 22902, 22907, 22909, 22911, 16084, 16112, 16113, 21992, 21993, 22012, 6349);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (16221, 16224, 16243, 20752, 20753, 20754, 20755, 20758, 22539, 22562, 22563, 22565);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (25848, 25849, 28282, 16083, 27532, 20854, 20855, 20856, 20970, 20971, 20973, 20975);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (21941, 21942, 21943, 21948, 21952, 21954, 21957, 23131, 23135, 23137, 23140, 23141);

DELETE FROM `tbccharacters`.`ahbot_market_state`
WHERE `auction_house` = 2 AND `category` = 2 AND `item` IN (23144, 23148, 23152, 28596);

