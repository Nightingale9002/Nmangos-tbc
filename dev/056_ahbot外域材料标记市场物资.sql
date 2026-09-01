-- ============================================================
-- [ahbot] Mark Outland craft materials as market goods (policy=1)
-- Target database: tbccharacters. Run after 055_ahbot市场做市商_表结构.sql
-- (or via dev/run_dev_sql.ps1 -Database tbccharacters).
--
-- Policy: profession recipes requiring skill >= 301 are Outland (TBC) recipes.
-- Their Class-7 materials are real market goods -> policy=1 (normal supply
-- depth regulation). ItemLevel >= 60 keeps Earth (old-world) auxiliary
-- materials (dyes, Thorium, essences...) out - they stay transition goods
-- (abundant welfare supply). Adjust later as operations dictate.
-- ============================================================
USE tbccharacters;

INSERT INTO ahbot_catalog (item, enabled, target, capacity, policy)
SELECT DISTINCT x.reagent, 1, 0, 0, 1
FROM (SELECT st.Reagent1 reagent FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent1 > 0
UNION ALL SELECT st.Reagent2 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent2 > 0
UNION ALL SELECT st.Reagent3 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent3 > 0
UNION ALL SELECT st.Reagent4 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent4 > 0
UNION ALL SELECT st.Reagent5 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent5 > 0
UNION ALL SELECT st.Reagent6 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent6 > 0
UNION ALL SELECT st.Reagent7 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent7 > 0
UNION ALL SELECT st.Reagent8 FROM (SELECT spellid_2 AS craft_spell FROM tbcmangos.item_template WHERE class=9 AND RequiredSkillRank >= 301 AND spellid_2 > 0) r JOIN tbcmangos.spell_template st ON st.Id = r.craft_spell WHERE st.Reagent8 > 0) x
JOIN tbcmangos.item_template it ON it.entry = x.reagent
WHERE it.class = 7 AND it.ItemLevel >= 60
ON DUPLICATE KEY UPDATE policy = IF(policy = 0, 1, policy);

-- housekeeping: ensure no policy=1 row is an Earth material (ItemLevel < 60)
UPDATE ahbot_catalog c JOIN tbcmangos.item_template it ON it.entry = c.item
SET c.policy = 0 WHERE c.policy = 1 AND it.ItemLevel < 60;
