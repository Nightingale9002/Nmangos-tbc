-- =====================================================================
-- 回滚 dev/126（★编号文件，可被 /root/apply_dev_sql.sh 之外手工执行）
-- dev/126_矿锭成对定价_12组矿石与锭.sql
--
-- 作用：撤掉 12 组"矿石 ↔ 锭"的商品对与配套虚拟商品（virtual_item 101-112），
--       让这些物品回到 dev/126 之前的定价方式（各自的 price_ref 自行发现）。
-- 说明：**不回滚价格**。price_ref / flow 是运行期市场状态，dev/126 生效期间已经
--       被虚拟商品机制写过，按原值还原没有意义（也无法还原）。
--       本脚本只负责让机制停止生效。
--
-- 执行对象：character 库（tbccharacters）
-- 幂等：是（DELETE 不存在的行无副作用）
-- =====================================================================

-- 1) 商品对（12 组：铜/锡/银/金/铁/秘银/真银/瑟银/魔铁/精金/恒金/氪金）
DELETE FROM ahbot_price_pair WHERE virtual_item BETWEEN 101 AND 112;

-- 2) 配套虚拟商品行
DELETE FROM ahbot_virtual_price WHERE virtual_item BETWEEN 101 AND 112;

-- 3) 复核（应为 0 行）
-- SELECT COUNT(*) AS pairs_left FROM ahbot_price_pair WHERE virtual_item BETWEEN 101 AND 112;
-- SELECT COUNT(*) AS virtual_left FROM ahbot_virtual_price WHERE virtual_item BETWEEN 101 AND 112;
