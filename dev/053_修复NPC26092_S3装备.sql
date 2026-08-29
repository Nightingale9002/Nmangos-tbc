-- =============================================================
-- 053 修复 NPC 26092 Soryn 出售装备错误（Merciless S2 -> Vengeful S3）
-- 问题：26092 在官服用太阳之井 Forgotten 套件换 Vengeful Gladiator's（S3），
--       但模板557被错误设为 Merciless（S2），导致 26091=26092。
-- 修复：item 从 Merciless(32xxx) 改为 Vengeful(33xxx)，保留 ExtendedCost(Forgotten代价)。
-- 依据：wowhead TBC Classic NPC 26092 实测（85件全为 Vengeful Gladiator's，1 Forgotten套件/件）
-- 回滚：见文件末尾
-- =============================================================
-- 执行前备份
CREATE TABLE IF NOT EXISTS npc_vendor_template_bak_557_20260830 AS SELECT * FROM npc_vendor_template WHERE entry=557;
-- 逐件替换 item（Merciless->Vengeful），ExtendedCost/slot/comments 对应更新
UPDATE npc_vendor_template SET item=33744, comments='Vengeful Gladiator\'s Satin Gloves' WHERE entry=557 AND item=32034;
UPDATE npc_vendor_template SET item=33747, comments='Vengeful Gladiator\'s Satin Mantle' WHERE entry=557 AND item=32037;
UPDATE npc_vendor_template SET item=33746, comments='Vengeful Gladiator\'s Satin Leggings' WHERE entry=557 AND item=32036;
UPDATE npc_vendor_template SET item=33745, comments='Vengeful Gladiator\'s Satin Hood' WHERE entry=557 AND item=32035;
UPDATE npc_vendor_template SET item=33748, comments='Vengeful Gladiator\'s Satin Robe' WHERE entry=557 AND item=32038;
UPDATE npc_vendor_template SET item=33717, comments='Vengeful Gladiator\'s Mooncloth Gloves' WHERE entry=557 AND item=32015;
UPDATE npc_vendor_template SET item=33720, comments='Vengeful Gladiator\'s Mooncloth Mantle' WHERE entry=557 AND item=32018;
UPDATE npc_vendor_template SET item=33719, comments='Vengeful Gladiator\'s Mooncloth Leggings' WHERE entry=557 AND item=32017;
UPDATE npc_vendor_template SET item=33718, comments='Vengeful Gladiator\'s Mooncloth Hood' WHERE entry=557 AND item=32016;
UPDATE npc_vendor_template SET item=33721, comments='Vengeful Gladiator\'s Mooncloth Robe' WHERE entry=557 AND item=32019;
UPDATE npc_vendor_template SET item=33676, comments='Vengeful Gladiator\'s Dreadweave Gloves' WHERE entry=557 AND item=31973;
UPDATE npc_vendor_template SET item=33679, comments='Vengeful Gladiator\'s Dreadweave Mantle' WHERE entry=557 AND item=31976;
UPDATE npc_vendor_template SET item=33678, comments='Vengeful Gladiator\'s Dreadweave Leggings' WHERE entry=557 AND item=31975;
UPDATE npc_vendor_template SET item=33677, comments='Vengeful Gladiator\'s Dreadweave Hood' WHERE entry=557 AND item=31974;
UPDATE npc_vendor_template SET item=33680, comments='Vengeful Gladiator\'s Dreadweave Robe' WHERE entry=557 AND item=31977;
UPDATE npc_vendor_template SET item=33684, comments='Vengeful Gladiator\'s Felweave Handguards' WHERE entry=557 AND item=31981;
UPDATE npc_vendor_template SET item=33682, comments='Vengeful Gladiator\'s Felweave Amice' WHERE entry=557 AND item=31979;
UPDATE npc_vendor_template SET item=33686, comments='Vengeful Gladiator\'s Felweave Trousers' WHERE entry=557 AND item=31983;
UPDATE npc_vendor_template SET item=33683, comments='Vengeful Gladiator\'s Felweave Cowl' WHERE entry=557 AND item=31980;
UPDATE npc_vendor_template SET item=33685, comments='Vengeful Gladiator\'s Felweave Raiment' WHERE entry=557 AND item=31982;
UPDATE npc_vendor_template SET item=33759, comments='Vengeful Gladiator\'s Silk Handguards' WHERE entry=557 AND item=32049;
UPDATE npc_vendor_template SET item=33757, comments='Vengeful Gladiator\'s Silk Amice' WHERE entry=557 AND item=32047;
UPDATE npc_vendor_template SET item=33761, comments='Vengeful Gladiator\'s Silk Trousers' WHERE entry=557 AND item=32051;
UPDATE npc_vendor_template SET item=33758, comments='Vengeful Gladiator\'s Silk Cowl' WHERE entry=557 AND item=32048;
UPDATE npc_vendor_template SET item=33760, comments='Vengeful Gladiator\'s Silk Raiment' WHERE entry=557 AND item=32050;
UPDATE npc_vendor_template SET item=33700, comments='Vengeful Gladiator\'s Leather Gloves' WHERE entry=557 AND item=31998;
UPDATE npc_vendor_template SET item=33703, comments='Vengeful Gladiator\'s Leather Spaulders' WHERE entry=557 AND item=32001;
UPDATE npc_vendor_template SET item=33702, comments='Vengeful Gladiator\'s Leather Legguards' WHERE entry=557 AND item=32000;
UPDATE npc_vendor_template SET item=33701, comments='Vengeful Gladiator\'s Leather Helm' WHERE entry=557 AND item=31999;
UPDATE npc_vendor_template SET item=33704, comments='Vengeful Gladiator\'s Leather Tunic' WHERE entry=557 AND item=32002;
UPDATE npc_vendor_template SET item=33671, comments='Vengeful Gladiator\'s Dragonhide Gloves' WHERE entry=557 AND item=31967;
UPDATE npc_vendor_template SET item=33674, comments='Vengeful Gladiator\'s Dragonhide Spaulders' WHERE entry=557 AND item=31971;
UPDATE npc_vendor_template SET item=33673, comments='Vengeful Gladiator\'s Dragonhide Legguards' WHERE entry=557 AND item=31969;
UPDATE npc_vendor_template SET item=33672, comments='Vengeful Gladiator\'s Dragonhide Helm' WHERE entry=557 AND item=31968;
UPDATE npc_vendor_template SET item=33675, comments='Vengeful Gladiator\'s Dragonhide Tunic' WHERE entry=557 AND item=31972;
UPDATE npc_vendor_template SET item=33690, comments='Vengeful Gladiator\'s Kodohide Gloves' WHERE entry=557 AND item=31987;
UPDATE npc_vendor_template SET item=33693, comments='Vengeful Gladiator\'s Kodohide Spaulders' WHERE entry=557 AND item=31990;
UPDATE npc_vendor_template SET item=33692, comments='Vengeful Gladiator\'s Kodohide Legguards' WHERE entry=557 AND item=31989;
UPDATE npc_vendor_template SET item=33691, comments='Vengeful Gladiator\'s Kodohide Helm' WHERE entry=557 AND item=31988;
UPDATE npc_vendor_template SET item=33694, comments='Vengeful Gladiator\'s Kodohide Tunic' WHERE entry=557 AND item=31991;
UPDATE npc_vendor_template SET item=33767, comments='Vengeful Gladiator\'s Wyrmhide Gloves' WHERE entry=557 AND item=32056;
UPDATE npc_vendor_template SET item=33770, comments='Vengeful Gladiator\'s Wyrmhide Spaulders' WHERE entry=557 AND item=32059;
UPDATE npc_vendor_template SET item=33769, comments='Vengeful Gladiator\'s Wyrmhide Legguards' WHERE entry=557 AND item=32058;
UPDATE npc_vendor_template SET item=33768, comments='Vengeful Gladiator\'s Wyrmhide Helm' WHERE entry=557 AND item=32057;
UPDATE npc_vendor_template SET item=33771, comments='Vengeful Gladiator\'s Wyrmhide Tunic' WHERE entry=557 AND item=32060;
UPDATE npc_vendor_template SET item=33665, comments='Vengeful Gladiator\'s Chain Gauntlets' WHERE entry=557 AND item=31961;
UPDATE npc_vendor_template SET item=33668, comments='Vengeful Gladiator\'s Chain Spaulders' WHERE entry=557 AND item=31964;
UPDATE npc_vendor_template SET item=33667, comments='Vengeful Gladiator\'s Chain Leggings' WHERE entry=557 AND item=31963;
UPDATE npc_vendor_template SET item=33666, comments='Vengeful Gladiator\'s Chain Helm' WHERE entry=557 AND item=31962;
UPDATE npc_vendor_template SET item=33664, comments='Vengeful Gladiator\'s Chain Armor' WHERE entry=557 AND item=31960;
UPDATE npc_vendor_template SET item=33739, comments='Vengeful Gladiator\'s Ringmail Gauntlets' WHERE entry=557 AND item=32030;
UPDATE npc_vendor_template SET item=33742, comments='Vengeful Gladiator\'s Ringmail Spaulders' WHERE entry=557 AND item=32033;
UPDATE npc_vendor_template SET item=33741, comments='Vengeful Gladiator\'s Ringmail Leggings' WHERE entry=557 AND item=32032;
UPDATE npc_vendor_template SET item=33740, comments='Vengeful Gladiator\'s Ringmail Helm' WHERE entry=557 AND item=32031;
UPDATE npc_vendor_template SET item=33738, comments='Vengeful Gladiator\'s Ringmail Armor' WHERE entry=557 AND item=32029;
UPDATE npc_vendor_template SET item=33707, comments='Vengeful Gladiator\'s Linked Gauntlets' WHERE entry=557 AND item=32005;
UPDATE npc_vendor_template SET item=33710, comments='Vengeful Gladiator\'s Linked Spaulders' WHERE entry=557 AND item=32008;
UPDATE npc_vendor_template SET item=33709, comments='Vengeful Gladiator\'s Linked Leggings' WHERE entry=557 AND item=32007;
UPDATE npc_vendor_template SET item=33708, comments='Vengeful Gladiator\'s Linked Helm' WHERE entry=557 AND item=32006;
UPDATE npc_vendor_template SET item=33706, comments='Vengeful Gladiator\'s Linked Armor' WHERE entry=557 AND item=32004;
UPDATE npc_vendor_template SET item=33712, comments='Vengeful Gladiator\'s Mail Gauntlets' WHERE entry=557 AND item=32010;
UPDATE npc_vendor_template SET item=33715, comments='Vengeful Gladiator\'s Mail Spaulders' WHERE entry=557 AND item=32013;
UPDATE npc_vendor_template SET item=33714, comments='Vengeful Gladiator\'s Mail Leggings' WHERE entry=557 AND item=32012;
UPDATE npc_vendor_template SET item=33713, comments='Vengeful Gladiator\'s Mail Helm' WHERE entry=557 AND item=32011;
UPDATE npc_vendor_template SET item=33711, comments='Vengeful Gladiator\'s Mail Armor' WHERE entry=557 AND item=32009;
UPDATE npc_vendor_template SET item=33729, comments='Vengeful Gladiator\'s Plate Gauntlets' WHERE entry=557 AND item=30487;
UPDATE npc_vendor_template SET item=33732, comments='Vengeful Gladiator\'s Plate Shoulders' WHERE entry=557 AND item=30490;
UPDATE npc_vendor_template SET item=33731, comments='Vengeful Gladiator\'s Plate Legguards' WHERE entry=557 AND item=30489;
UPDATE npc_vendor_template SET item=33730, comments='Vengeful Gladiator\'s Plate Helm' WHERE entry=557 AND item=30488;
UPDATE npc_vendor_template SET item=33728, comments='Vengeful Gladiator\'s Plate Chestpiece' WHERE entry=557 AND item=30486;
UPDATE npc_vendor_template SET item=33723, comments='Vengeful Gladiator\'s Ornamented Gloves' WHERE entry=557 AND item=32021;
UPDATE npc_vendor_template SET item=33726, comments='Vengeful Gladiator\'s Ornamented Spaulders' WHERE entry=557 AND item=32024;
UPDATE npc_vendor_template SET item=33725, comments='Vengeful Gladiator\'s Ornamented Legplates' WHERE entry=557 AND item=32023;
UPDATE npc_vendor_template SET item=33724, comments='Vengeful Gladiator\'s Ornamented Headcover' WHERE entry=557 AND item=32022;
UPDATE npc_vendor_template SET item=33722, comments='Vengeful Gladiator\'s Ornamented Chestguard' WHERE entry=557 AND item=32020;
UPDATE npc_vendor_template SET item=33750, comments='Vengeful Gladiator\'s Scaled Gauntlets' WHERE entry=557 AND item=32040;
UPDATE npc_vendor_template SET item=33753, comments='Vengeful Gladiator\'s Scaled Shoulders' WHERE entry=557 AND item=32043;
UPDATE npc_vendor_template SET item=33752, comments='Vengeful Gladiator\'s Scaled Legguards' WHERE entry=557 AND item=32042;
UPDATE npc_vendor_template SET item=33751, comments='Vengeful Gladiator\'s Scaled Helm' WHERE entry=557 AND item=32041;
UPDATE npc_vendor_template SET item=33749, comments='Vengeful Gladiator\'s Scaled Chestpiece' WHERE entry=557 AND item=32039;
UPDATE npc_vendor_template SET item=33696, comments='Vengeful Gladiator\'s Lamellar Gauntlets' WHERE entry=557 AND item=31993;
UPDATE npc_vendor_template SET item=33699, comments='Vengeful Gladiator\'s Lamellar Shoulders' WHERE entry=557 AND item=31996;
UPDATE npc_vendor_template SET item=33698, comments='Vengeful Gladiator\'s Lamellar Legguards' WHERE entry=557 AND item=31995;
UPDATE npc_vendor_template SET item=33697, comments='Vengeful Gladiator\'s Lamellar Helm' WHERE entry=557 AND item=31997;
UPDATE npc_vendor_template SET item=33695, comments='Vengeful Gladiator\'s Lamellar Chestpiece' WHERE entry=557 AND item=31992;

-- =============================================================
-- 回滚：恢复 557 原表
-- DELETE FROM npc_vendor_template WHERE entry=557;
-- INSERT INTO npc_vendor_template SELECT * FROM npc_vendor_template_bak_557_20260830;
-- =============================================================

