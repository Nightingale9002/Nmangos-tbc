-- 179_重点小怪优先级表.sql
-- 名单唯一来源：dev/tbc五人本攻略.md 的 13 处「重点小怪」章节（人工校订）
-- 站长口径（2026-10-17）：'并不是每个有技能的怪都是高威胁'
--   => 静态扫描（有治疗/召唤/控制技能）**不作为**判定依据，只用来给已点名的 entry
--      补一句'它凭什么'（写在 reason 的 '静态证据:' 之后）
-- 口径：priority 1 = 攻略把它的技能标了 [打断]/[重要]；2 = 攻略列为重点小怪
-- 全部为静态写死值（无 JOIN / 无子查询 / 幂等）

CREATE TABLE IF NOT EXISTS `tbccharacters`.`ai_playerbot_priority_target` (
  `entry`    INT UNSIGNED     NOT NULL,
  `priority` TINYINT UNSIGNED NOT NULL,
  `source`   VARCHAR(16)      NOT NULL,
  `reason`   VARCHAR(255)     NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (7136,1,'guide','攻略点名（地狱火哨兵）可打断技能: 治疗, 暗言术, 恢复')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16507,2,'guide','会 [冲锋] 随机目标，而且会抓潜行。 ｜静态证据: Charge')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16594,2,'guide','[心灵震爆] 造成中等伤害，可打断；给自己和周围的怪施放 [真言术盾]、[抵抗暗影] 提高暗抗，对小怪施放 [治疗祷言] 造成 5000 左右群疗；注意进攻驱散和打断。 ｜静态证据: Prayer of Healing')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16699,2,'guide','[上勾拳]、[顺劈斩]、[激怒] 提高攻速与伤害。 ｜静态证据: Uppercut')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16700,2,'guide','同常站在一大组怪 (4 只以上) 面前、来回走动，免疫所有控场。与一群怪一起进入战斗时，会在其他小怪死亡时召唤 [邪兽人转化者]，因此在每一组怪中通常都默认第一优先击杀。给自己和周围的怪 [戒律光环] 提高招架格档机率，自身也会 [激怒] 提高攻速与伤害。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16704,2,'guide','会对法系玩家施放抽蓝的 [蝰蛇钉刺]。 ｜静态证据: Incendiary Shot')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (16874,2,'guide','频繁 [灼烧] 目标造成中等火焰伤害并范围性 [火焰之雨]；注意打断，或干脆离开 [火焰之雨] 范围。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17269,2,'guide','频繁 [灼烧] 目标造成中等火焰伤害并范围性 [火焰之雨]；注意打断，或干脆离开 [火焰之雨] 范围。 ｜静态证据: Rain of Fire')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17280,2,'guide','[血肉撕咬] 会产生流血 dot，且 [狂怒嚎叫] 会提升自身伤害。 ｜静态证据: Carnivorous Bite, Furious Howl')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17309,1,'guide','攻略点名（地狱火哨兵）可打断技能: 治疗, 暗言术, 恢复 ｜静态证据: Heal, Shadow Word: Pain')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17370,2,'guide','对当前目标 [盾牌猛击]，造成中等物理伤害并带附带 2 秒击晕效果，并驱散一个增益效果，坦克要留意补 buff。 ｜静态证据: Shield Slam')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17371,2,'guide','频繁的 [腐蚀术] 和高额伤害的 [暗影箭]，还会以 [邪魔之能] 强化自己的宠物恶魔，尤其尾王前的两波，最好等 [邪魔之能] 消散了再开，免得控场成功前先被打死。 ｜静态证据: Corruption')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17395,2,'guide','会施放 [烈焰风暴] 造成大范围的地板伤害；还会召唤恶魔犬与魅魔，分别对玩家施放 [沉默]、[法力吸取] 和 [魅惑]。 ｜静态证据: Flamestrike, Summon Felhound Manastalker, Summon Seductress')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17397,2,'guide','会对坦克施放 [痛击]，这是二段三连击，可能对坦克造成瞬间大量伤害。由于本身就是双持速攻怪，瞬间七连击秒坦的事屡见不鲜，尽量风筝不要扛。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17398,1,'guide','攻略点名（初生的邪兽人）可打断技能: 震荡猛击, 践踏 ｜静态证据: Concussion Blow, Stomp')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17414,2,'guide','影月技师 ｜静态证据: Silence')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17427,2,'guide','在往血卫士伯鲁恩的天堂路上持续投放 [烈焰箭]，在地上生成一摊火焰。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17429,1,'guide','会对自身施放 [狂乱]，使攻速提高 60%；[冲锋] 随机目标、[失控] 清空仇恨转移目标。 ｜静态证据: Charge, Enrage')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17464,2,'guide','伤害很高但可被缓速，[致死打击]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17465,2,'guide','免疫所有控场，对目标 [破甲攻击]、对周围小怪 [战斗怒吼] 增伤。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17478,2,'guide','固定组合，前者对随机目标施放 [暗影箭] 和 [恐惧] 使玩家逃跑，后者免疫控场。 ｜静态证据: Fear')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17491,2,'guide','以潜行状态存在，脆皮职业务必永远走在坦克后方以免被 [肾击] 后一套秒杀。 ｜静态证据: Kidney Shot, Poison')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17670,2,'guide','这两种怪是固定组合，驯犬者免疫控场，会 [多重射击]，并周期性驱散周围小怪的减益效果；军犬则会 [狂怒嚎叫] 增伤，[血肉撕咬] 造成高额物理伤害，清这波怪时注意注意维持控场缓速的减益效果。 ｜静态证据: Volley')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17671,2,'guide','免疫控场但可缓速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17693,2,'guide','会 [冲锋] 随机目标，而且会抓潜行。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17694,2,'guide','会 [恐惧]，还有大范围的 [火焰之雨] 务必打断或躲开范围。 ｜静态证据: Fear, Rain of Fire')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17695,2,'guide','以潜行状态存在，会 [闷棍]、[背刺] 偷袭。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17721,2,'guide','[投网] 定身玩家后，对他所在位置投掷炸弹 [轰炸]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17722,2,'guide','[冰霜新星] 可驱散；寒冰箭、[暴风雪] 可打断。 ｜静态证据: Blizzard')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17723,2,'guide','门神，[击退] 附带高额物理伤害、[蘑菇凋零] 缓速目标，是疾病可驱散、[生长] 每 20 秒提高 15% 伤害，能叠加 10 次。幽暗沼泽领主的伤害尤其高，可以用 [击退] 风筝一下。 ｜静态证据: Fungal Decay, Trample')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17725,2,'guide','本身伤害就高，还自带狂暴 [野性成长]，提高 50% 物理伤害，但可缓速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17729,2,'guide','[蝰蛇钉刺] 抽蓝，即时驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17730,2,'guide','[圣光术]、[治疗祷言] 造成巨额治疗，务必打断。[恢复] 可进攻驱散。 ｜静态证据: Holy Light, Prayer of Healing')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17731,2,'guide','对非当前目标 [惊骇]，可以打断驱散，这个恐惧跑的飞快，小心引怪。 ｜静态证据: Psychic Horror')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17732,2,'guide','不停地 [毒液喷吐]，是中毒可驱散或打断。 ｜静态证据: Poison Spit')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17771,2,'guide','分成三种法系，读条都会造成中等魔法伤害，其中火法型威胁最大。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17801,2,'guide','[闪电箭] 可打断；[奥术闪耀] 造成中等奥术伤害的魔法 DOT，[恐惧] 20 码范围的玩家施放 4 秒群恐，皆为魔法可驱散。副本里有大量盘牙海妖，注意聚怪的位置、法系保持距离。 ｜静态证据: Arcane Flare, Fear')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17803,2,'guide','[冰霜震击] 会造成单体高额冰霜伤害并缓速 8 秒，[音素爆破] 对近战范围小额 AOE 且沉默 10 秒，两者都是魔法、皆可驱散；[治疗术] 注意打断。 ｜静态证据: Heal, Sonic Burst')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17815,2,'guide','虽然是黄名怪，但会主动攻击萨尔，而且不给声望。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17816,2,'guide','小的会 [穿刺] 目标，使受到的物理伤害提高 15%，可叠加；大的会 [力量衰减] 使力量降低 25%。 ｜静态证据: Piercing Jab')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17819,2,'guide','对目标 [致死打击]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17820,2,'guide','[多重射击] AOE 和对当前目标 [驱散射击] 使其困惑 4 秒。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17833,1,'guide','攻略点名（敦霍尔德看守）可打断技能: 治疗, 暗言术, 心灵尖啸 ｜静态证据: Heal, Psychic Scream, Shadow Word: Pain')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17860,2,'guide','随机施放 [暗言术痛] 造成中等伤害，是魔法要驱散；[驱散魔法] 替其他小怪驱散减益效果。[心灵尖啸] 10 码范围群恐 4 秒，打断 [治疗]。 ｜静态证据: Backstab')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17871,2,'guide','对玩家施放 [疼痒孢子] 疾病可驱散；会以 [蘑菇再生] 治疗小怪，可打断，漏断也可以偷取或进攻驱散；[过敏] 使玩家打喷嚏，造成法术中断与击退。 ｜静态证据: Fungal Regrowth')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17893,2,'guide','位于尾王房右手边的友方 NPC，完成营救事件后对话给予 [拜特的印记] 增益效果，提高 110 自然抗性与 5% 所有属性。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17938,2,'guide','施放 [献祭]，可驱散；丢掷 [烈性炸药]，使 30 码内玩家受到火焰伤害。 ｜静态证据: Immolate')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17940,2,'guide','[火焰之雨] 造成中等火焰伤害，可以打断或干脆躲开。 ｜静态证据: Rain of Fire')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17957,2,'guide','[破甲攻击]、[顺劈斩]；对 10 码内的玩家 [破胆怒吼] 群恐 6 秒，然后转头攻击未被恐惧的最高威胁值玩家。 ｜静态证据: Frightening Shout')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17958,2,'guide','门神怪，免疫控场但可缓速，对坦克造成高额伤害，一般会风筝走一个。[盾牌猛击] 会使目标昏迷 2 秒，[法术反射] 有 50% 机率反弹受到的法术。 ｜静态证据: Shield Slam')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17960,2,'guide','[智力衰减] 使智力降低 25%、以 [支配] 心控一名玩家十秒。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17961,2,'guide','[闪电箭] 可打断；群体定身 8 秒的 [纠缠根须] 和指定一个区域施放的 [落雷之云] 两者连招会死人，务必及时驱散定身。 ｜静态证据: Entangling Roots')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17962,2,'guide','[残废术] 降低攻速与移速，可以打断或驱散。低血量时会 [激怒] 提高攻速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17964,2,'guide','当盘牙纳迦进入战斗，会驱使附近的黄名荒土怪也一起参战；荒土工人会对目标叠加流血 dot [撕裂]，荒土奴隶会施放 [寒冰箭] 和 [冰霜新星]，不过一但盘牙监工死亡，他们就会脱战离开。 ｜静态证据: Rend')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17993,2,'guide','[水晶打击] 是近战攻击但是造成奥术伤害，所以对坦也不低；[法术反射] 可以在 8 秒内反射 4 次法术。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (17994,2,'guide','标记一名玩家 [猎鹰的召唤] 使血鹰无视仇恨锁定攻击，[冲锋] 击倒然后 [猛扑] 击晕正面玩家、[摔拌] 缓速锁定目标。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18058,1,'guide','攻略点名（地狱火哨兵）可打断技能: 治疗, 暗言术, 恢复 ｜静态证据: Heal, Shadow Word: Pain')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18092,2,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18093,2,'guide','[震荡猛击] 重击目标使其昏迷 5 秒；[清洁术] 替其他小怪驱散减益效果。[快速治疗] 其实不快，可打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18094,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18309,2,'guide','周期性无视仇恨目标，跑去对法系 [盾击] 造成 2 秒反制沉默。 ｜静态证据: Singe')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18311,2,'guide','[灵魂打击] 附带致死效果，对远处玩家 [冲锋] 击倒昏迷 2 秒，低血量时还会 [激怒] 提高伤害与攻速。 ｜静态证据: Charge')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18312,2,'guide','施放造成中等伤害的 [献祭] DOT，且虚灵巫师相似，会召唤 [虚灵怨魂]。 ｜静态证据: Immolate, Summon Ethereal Wraith')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18313,2,'guide','[减速]、[奥术飞弹]、召唤会 [魔爆术] 的虚数魔。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18314,2,'guide','会 [凿击] 当前目标，并且在凿击昏迷期间内无视被凿击的目标转而攻击其他人。 ｜静态证据: Gouge, Phantom Strike')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18315,2,'guide','会使用 [变羊术]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18317,2,'guide','会对小怪施放治疗量极高的 [治疗术]。 ｜静态证据: Heal, Holy Nova')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18318,2,'guide','[法术反射] 持续 6 秒。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18321,2,'guide','[击晕] 当前仇恨目标并转移仇恨。 ｜静态证据: Talon of Justice')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18322,2,'guide','门神怪，对坦伤害极高，只吃昏迷控场。场上同时存在二只时，一只死亡另一只 [激怒]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18323,2,'guide','对坦伤害偏高，免疫缴械和昏迷以外的控场，并会 [雷霆一击] 近战范围缓速，是魔法可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18325,2,'guide','死后生成一个 [幽灵]，移动速度缓慢，但近身后造成高额伤害，免疫攻击，几秒后自动消失；被盯上绕道走。 ｜静态证据: Fear')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18328,2,'guide','对目标与其正面施放 [奥术闪电]，可以弹射五次，被击中的还会被 [群体沉默]，坦克务必使这种怪背对队友。 ｜静态证据: Arcane Lightning')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18331,2,'guide','会施放造成中等伤害的 [暗言术痛] DOT，并对 30 有码内的蓝职业施放 [法力燃烧]，点一次最高能烧掉一万点法力值。除此之外，虚灵暗法师还自带一个 [吸血光环]，会在造成近战攻击的同时治疗自身。后二者法术的存在导致他们必需被优先击杀，而且最好全程晕缓控制，让他放不出法术也无法攻击坦克。 ｜静态证据: Shadow Word: Pain')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18404,2,'guide','[奥术飓风] 是一个 30 码范围的奥术版旋风斩。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18405,2,'guide','[奥术冲击] 对目标造成中等伤害并击退；[奥术箭雨] 和 [魔爆术] 两者皆为范围 AOE 且可打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18419,2,'guide','[管理员之怒] 造成高额伤害，但可打断，被反制后会改用瞬发的 [自然震击] 但伤害就低得多；[昏迷迫近] 会使移速降低 70%，是中毒可驱散，持续时间结束后会使该玩家沉睡 5 秒。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18422,2,'guide','植物学家会对魔花施放 [自然之怒]，使它的攻速伤害翻倍；还会施放 [枯木逢春]、[愈合] 治疗小怪，可打断或驱散。 ｜静态证据: Regrowth')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18431,1,'guide','攻略点名（虚灵航标）可打断技能: 奥术箭, 虚灵学徒, 火球术')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18497,2,'guide','免疫控场，并以 [飓风打击] 造成中等物理伤害并击退附近的玩家。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18498,2,'guide','[防护光环] 提供周围小怪极高护甲、并会使用有法术反制效果的 [盾击]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18500,2,'guide','[特效治疗] 治疗小怪，可打断。 ｜静态证据: Major Heal')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18501,2,'guide','对怪施放 [灵魂复仇]，提高攻速与移速，还会 [蝰蛇钉刺] 抽蓝。 ｜静态证据: Serpent Sting, Spirit Vengeance')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18503,2,'guide','免疫控场，出现后立即引导 5 秒施法，对一名玩家施放 [占据] 心控他，持续一分钟、或将被心控的玩家的血量削减到 50% 以下方能脱控。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18506,2,'guide','桥上的隐形怪，现形后 5 秒会 [暴怒] 自爆击退 8 码内玩家，小心别被弹下桥。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18521,2,'guide','周期性地清空威胁值列表、转移仇恨目标，另外因为掉落附魔靴子敏捷配方而成为单刷热门。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18524,2,'guide','周期性地 [发怒] 提高攻速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18633,2,'guide','[治疗术]，可打断。 ｜静态证据: Heal')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18636,2,'guide','击败一王后刷新，以潜行状态存在，在一二王的大厅来回巡游，小心被 [偷袭]、[凿击]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18637,2,'guide','[精神鞭笞] 和 [暗言术痛] 的伤害相当高，后者务必驱散。 ｜静态证据: Mind Flay, Shadow Word: Pain')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18638,2,'guide','当血量降至 20% 时会施放 [野兽之形] 变身为怪兽，可进攻驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18639,2,'guide','会 [洗脑] 心控玩家，可打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18640,2,'guide','自带 [魔甲术] 吸收暗影伤害，可進攻驱散；对玩家施放 [暗影箭]、[腐蚀之种]，后者应当尽早驱散或爆炸前远离队友。 ｜静态证据: Seed of Corruption')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18702,2,'guide','奥金尼通灵师 ｜静态证据: Seed of Corruption, Shadow Mend')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18794,2,'guide','这种怪分成三种类型，高危的是背圆头法杖丢奥术飞弹的那种，会施 [降服人类]，引导一个 6 秒的昏迷，可以驱散或打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18796,2,'guide','门神免疫控场，惯例 [上勾拳]、[致死打击]；并对 15 码内的玩家 [破胆怒吼] 群恐 6 秒，然后转头攻击未被恐惧的最高威胁值玩家。 ｜静态证据: Frightening Shout, Uppercut')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18830,2,'guide','无视仇恨目标，[凝视] 特定玩家追击他并提高攻速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18848,2,'guide','会对当前目标施放 [缴械] 和造成额外伤害的 [恶意印记]、对近战范围 [暗影新星] AOE。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18894,2,'guide','可控场缓速但无法被奴役，对坦高额物理伤害，务必一次只拉一只；而且还会 [冲锋] 和 [上勾拳]，一套连招巨额伤害，脆皮职业直接升天。另外要注意这种怪的攻击范围很大，似乎有 15 码。 ｜静态证据: Uppercut')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (18934,2,'guide','只在萨尔离开牢房到二王之间的那几波刷新怪出现。会 [霜甲术]、[冰锥术]、[火球术] 和 [变羊术]，后二可以打断，且 [变羊术] 可以驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19166,2,'guide','[击倒] 当前目标并昏迷 2 秒。半血时会呼救引怪，要拉至与其他怪距离 30 码以上的地方击杀。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19167,2,'guide','本身伤害就高，还会 [旋风斩]、对当前目标 [恒星之击] 重击造成高额伤害并附带致死效果。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19168,2,'guide','[灼烧]、[灼热日光] 造成火焰伤害，并会使其目标 [熔化护甲]；对自身施加 [火焰之盾] 持续地 5 码范围 AOE，可进攻驱散或偷取，法师偷取它们能增加不少伤害。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19218,1,'guide','攻略点名（看守者盖罗基尔）可打断技能: 锯齿利刃, 暗影能量, 流动机蒸汽')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19306,2,'guide','会 [法力燃烧] 抽取 30 码内玩家的蓝，死亡时会 [魔爆术] 10 码爆炸，近战远离。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19307,2,'guide','会以 [心灵尖啸] 群恐玩家 4 秒，[无力诅咒] 使法术伤害降低，是诅咒可驱散；[暗影之拥] 带 DOT 的沉默效果，是魔法可驱散。 ｜静态证据: Curse of Impotence, Death Coil, Psychic Scream, Shadows Embrace')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19428,2,'guide','正面群体攻击，坦克使其保持背对人群。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19429,2,'guide','[冲锋] 第二仇恨并击倒，造成中等伤害。 ｜静态证据: Carnivorous Bite, Sonic Charge')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19486,2,'guide','不停在脚下丢掷 [毒性之瓶]，近战要持续移动；[火息药水] 会正面喷火造成高額火焰傷害。 ｜静态证据: Vial of Poison')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19507,2,'guide','[死亡凋零] 对一名玩家所在地点指定 8 码范围的高额伤害 AOE，要尽速离开。与收割员、草药学家的小怪组合能组成一套秒杀。 ｜静态证据: Summon Lasher Beast')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19508,2,'guide','[纠缠根须] 缓速，魔法可驱散。 ｜静态证据: Entangling Roots')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19509,2,'guide','[变形术] 把玩家变花、[枯萎之触] 降低 75% 爆击率，皆为魔法可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19511,2,'guide','[肾击] 使目标昏迷，[致命药膏] 中毒可驱散。 ｜静态证据: Deadly Poison, Kidney Shot')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19512,2,'guide','[顺劈斩]、[白鬼死亡] 使耐力降低 35%，诅咒可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19632,2,'guide','周期性地 [钉刺狂暴] 提高 75% 攻速。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19633,1,'guide','[神圣愤怒] 使小怪提高 295 法伤，可进攻驱散或偷取；[心灵震爆]、[强效治疗术] 均可打断，务必打断后者。 ｜静态证据: Greater Heal')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19710,1,'guide','攻略点名（看守者埃隆汉）可打断技能: 锤击, 风钻, 暗影能量')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19735,2,'guide','物理伤害偏高但走路较慢，同样会 [击倒]，并会以 [充能之拳] 强化自身，使每次近战攻击都附加造成中等奥术伤害的近战范围 AOE，务必打断，如果没打断就风筝起来吧。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (19843,2,'guide','以潜行状态存在，会 [背刺]。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (20059,2,'guide','[奥术新星] 对 10 码内玩家造成中等奥术伤害，并治疗小怪。[驱散魔法] 能主动驱散小怪身上的 debuff。并且召唤会 [奥术箭雨] 的 [奥术仆从]，其死亡时会 [魔爆术]，人宠都是单技能伤害不高、但叠加起来就可观了。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (20988,2,'guide','[超级缩小射线] 降低攻强、[死亡射线] 随机点名一名玩家造成高额伤害。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (20990,2,'guide','[神圣震击]、对一名玩家丢掷 [麻醉剂] 昏迷 6 秒，魔法可驱散。[绷带] 治疗小怪。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (21126,2,'guide','会使用 [治疗术]，可打断。 ｜静态证据: Heal, Holy Nova')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (21127,2,'guide','双持速攻，对当前目标 [影袭]、[致命药膏]。 ｜静态证据: Deadly Poison')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (21128,2,'guide','施放 [惊骇] 一名玩家，使其逃跑 3 秒。 ｜静态证据: Psychic Horror')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (21695,2,'guide','一般不打这群水元素，大的会 [冰霜新星]、[水柱喷射] 正面 AOE 带击退，小的频繁 [水箭]，造成中等伤害。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (22081,2,'guide','会 [恐惧]，还有大范围的 [火焰之雨] 务必打断或躲开范围。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23175,2,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23176,2,'guide','[致死打击]、[冲锋] 远处玩家，造成轻微伤害并击退。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23177,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23178,2,'guide','[毒蛇钉刺] 中毒可驱散；[震荡射击] 3 秒 50% 缓速，是魔法可驱散。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23179,2,'guide','[震荡猛击] 重击目标使其昏迷 5 秒；[清洁术] 替其他小怪驱散减益效果。[快速治疗] 其实不快，可打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
INSERT INTO `ai_playerbot_priority_target` (`entry`,`priority`,`source`,`reason`)
  VALUES (23180,2,'guide','[震荡猛击] 重击目标使其昏迷 5 秒；[清洁术] 替其他小怪驱散减益效果。[快速治疗] 其实不快，可打断。')
  ON DUPLICATE KEY UPDATE `priority`=VALUES(`priority`),`source`=VALUES(`source`),`reason`=VALUES(`reason`);
