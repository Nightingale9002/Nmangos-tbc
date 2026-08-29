-- =============================================================
-- 卡布奇诺 TBC 任务目标数量修正 (WLK 文本污染 -> TBC 正确数量)
-- 来源: Questie/pfQuest 数据库 + quest_template 三方核对
-- 修复: 任务文本中错误的数量改为实际需求数量
-- 附带: locales_quest 去重 + 加主键 (修复 INSERT 幂等失效)
-- 生成: 2026-08-30, 幂等可重放
-- =============================================================

-- 1. locales_quest 去重 + 加主键 (若已有主键则跳过)
SET @has_pk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='locales_quest' AND CONSTRAINT_TYPE='PRIMARY KEY');
SET @dup_count := (SELECT COUNT(*)-COUNT(DISTINCT entry) FROM locales_quest);

-- 去重: 每 entry 保留内容最完整的一行 (需先备份!)
-- 如无主键且存在重复, 手动执行以下(注意先备份):
-- CREATE TABLE locales_quest_bak_20260830 AS SELECT * FROM locales_quest;

-- 2. 任务数量修正 (幂等 UPDATE)

UPDATE `locales_quest` SET `Objectives_loc4`='杀死10只狗头人歹徒，然后向治安官玛克布莱德复命。' WHERE `entry`=7;
UPDATE `locales_quest` SET `Objectives_loc4`='给北郡的维里副队长带回12个红色粗麻面罩。' WHERE `entry`=18;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死12只狗头人苦力，然后向北郡修道院里的治安官玛克布莱德复命。' WHERE `entry`=21;
UPDATE `locales_quest` SET `Objectives_loc4`='萨尔玛·萨丁需要3块秃鹫肉条、3只血牙野猪的头、3颗鱼人的眼睛和3棵秋葵。' WHERE `entry`=38;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10块狼肋排和1份暴风城特产调料，再回夜色镇去找厨师格鲁奥。' WHERE `entry`=90;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10颗食尸鬼的牙齿、10根骷髅的手指和5瓶蜘蛛毒液，把它们交给夜色镇的伊瓦夫人。' WHERE `entry`=101;
UPDATE `locales_quest` SET `Objectives_loc4`='格瑞林·白须要你去杀掉14个霜鬃巨魔幼崽。' WHERE `entry`=182;
UPDATE `locales_quest` SET `Objectives_loc4`='塔林·锐眼让你去杀掉12只规模峭壁野猪。' WHERE `entry`=183;
UPDATE `locales_quest` SET `Objectives_loc4`='收集4大块野猪肉和2张厚熊皮，把它们交给钢架补给站的驾驶员贝隆·风箱。' WHERE `entry`=317;
UPDATE `locales_quest` SET `Objectives_loc4`='暗影牧师萨维斯让你杀掉8个无脑的僵尸和8个丑陋的僵尸。' WHERE `entry`=364;
UPDATE `locales_quest` SET `Objectives_loc4`='执行官阿伦要你去杀掉10只小夜行蜘蛛和8只夜行蜘蛛。' WHERE `entry`=380;
UPDATE `locales_quest` SET `Objectives_loc4`='收集6份湖岸爬行者苔藓的样本、6份湖岸潜藏者苔藓的样本和1块硬瘤，把它们交给幽暗城的大药剂师法拉尼尔。' WHERE `entry`=451;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死7只夜刃豹幼崽和4只草刺野猪幼崽，然后向管理员伊尔萨莱恩复命。' WHERE `entry`=456;
UPDATE `locales_quest` SET `Objectives_loc4`='管理员伊尔萨莱恩要求你杀死7只癞皮夜刃豹和7只草刺野猪。' WHERE `entry`=457;
UPDATE `locales_quest` SET `Objectives_loc4`='给多兰纳尔外面的赛恩·腐蹄带去3颗夜刃豹的牙齿、3根巨翼枭的羽毛和3份树林蜘蛛丝。' WHERE `entry`=488;
UPDATE `locales_quest` SET `Objectives_loc4`='把泥头花水、1瓶强力巨魔之血药水、5块刺脊纳迦的鳞片和5颗碎鳍鱼人的眼球交给塔伦米尔的药剂师林度恩。' WHERE `entry`=515;
UPDATE `locales_quest` SET `Objectives_loc4`='杀掉10个辛迪加雇佣兵和6个辛迪加路霸，然后回到避难谷地去向尼艾丝队长复命。' WHERE `entry`=681;
UPDATE `locales_quest` SET `Objectives_loc4`='帮避难谷地中的学徒克里汀收集10个枯木巨魔的獠牙，4只枯木巨魔的医药包和1把暗影猎手的小刀。' WHERE `entry`=691;
UPDATE `locales_quest` SET `Objectives_loc4`='杀掉10只杂斑野猪，然后向大兽穴里的高内克报告。' WHERE `entry`=788;
UPDATE `locales_quest` SET `Objectives_loc4`='给大兽穴中的高内克带回10根工蝎的尾巴。' WHERE `entry`=789;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死12只邪灵劣魔，然后向大兽穴外的祖雷萨复命。' WHERE `entry`=792;
UPDATE `locales_quest` SET `Objectives_loc4`='把4个龙虾人的眼睛和8小瓶蟹胶带到森金村，交给沃纳尔大师。' WHERE `entry`=818;
UPDATE `locales_quest` SET `Objectives_loc4`='玛拉卡金的巫医金吉尔需要5瓶石爪苔液、5根夜行虎须、30颗巨角鹿的眼球和1块灵龙的鳞片。' WHERE `entry`=1058;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10个地狱犬的脑子、10对魔女之翼和10瓶末日看守之血，把它们交给凄凉之地的克雷迪格·安戈尔。' WHERE `entry`=1466;
UPDATE `locales_quest` SET `Objectives_loc4`='给洛克莫丹南部警戒塔的索瓦尔德带去6把铜斧和6条铜质链甲腰带。' WHERE `entry`=1578;
UPDATE `locales_quest` SET `Objectives_loc4`='托姆斯·深炉要你给赤脊山的弗纳·奥斯古带去4条铜质符文腰带和4把铜质大锤。' WHERE `entry`=1618;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死8个废土暗法师、6个废土游荡者和10个废土刺客，然后向加基森的总工程师比格维兹报告。' WHERE `entry`=1691;
UPDATE `locales_quest` SET `Objectives_loc4`='为索恩格瑞姆收集15根烟雾铁锭、10份蓝铜粉、10块铁锭和1瓶燃素。' WHERE `entry`=1838;
UPDATE `locales_quest` SET `Objectives_loc4`='给羽月要塞的普拉特·马克格鲁带去6片厚重护甲片和1株野葡萄。' WHERE `entry`=2848;
UPDATE `locales_quest` SET `Objectives_loc4`='给羽月要塞的普拉特·马克格鲁带去2件龟鳞胸甲、2副龟鳞手套和1株野葡萄。' WHERE `entry`=2849;
UPDATE `locales_quest` SET `Objectives_loc4`='给羽月要塞的普拉特·马克格鲁带去2条夜色裤、2双夜色靴和2株野葡萄。' WHERE `entry`=2851;
UPDATE `locales_quest` SET `Objectives_loc4`='给羽月要塞的普拉特·马克格鲁比带去2顶龟鳞头盔、2副龟鳞护腕和2株野葡萄。' WHERE `entry`=2852;
UPDATE `locales_quest` SET `Objectives_loc4`='给莫沙彻营地的杉多尔·迅蹄带去6块厚重护甲片和1株野葡萄。' WHERE `entry`=2855;
UPDATE `locales_quest` SET `Objectives_loc4`='给莫沙彻营地的杉多尔·迅蹄带去2件龟鳞胸甲、2副龟鳞手套和1株野葡萄。' WHERE `entry`=2856;
UPDATE `locales_quest` SET `Objectives_loc4`='给莫沙彻营地的杉多尔·迅蹄带去2件夜色外套、2条夜色头巾和1株野葡萄。' WHERE `entry`=2857;
UPDATE `locales_quest` SET `Objectives_loc4`='给莫沙彻营地的杉多尔·迅蹄带去2条夜色短裤、2双夜色长靴和2株野葡萄。' WHERE `entry`=2858;
UPDATE `locales_quest` SET `Objectives_loc4`='给莫沙彻营地的杉多尔·迅蹄带去2顶龟鳞头盔、2副龟鳞护腕和2株野葡萄。' WHERE `entry`=2859;
UPDATE `locales_quest` SET `Objectives_loc4`='去杀掉10头铁鬃熊或是长牙奔跑者，然后使用灵魂精华容器捕获它们的灵魂。$B$B将灵魂精华容器和10个野兽灵魂精华交给菲拉斯的巫医尤克里。' WHERE `entry`=3123;
UPDATE `locales_quest` SET `Objectives_loc4`='为莫沙彻营地的巫医尤克里收集2根断裂的原木、6颗包壳矿石、20片有弹性的肌腱和40块金属碎片。' WHERE `entry`=3128;
UPDATE `locales_quest` SET `Objectives_loc4`='将20颗重磅铁制炸弹、20颗实心炸弹和5只自爆绵羊交给加基森的尼克斯·斯普克斯宾。' WHERE `entry`=3639;
UPDATE `locales_quest` SET `Objectives_loc4`='将6根秘银管、1只精确瞄准镜和2个高级假人交给铁炉堡的工匠大师欧沃斯巴克。' WHERE `entry`=3641;
UPDATE `locales_quest` SET `Objectives_loc4`='将6根秘银管、1只精确瞄准镜和2个高级假人交给藏宝海湾的奥格索普·奥布诺提斯。' WHERE `entry`=3643;
UPDATE `locales_quest` SET `Objectives_loc4`='杀掉12个断骨骷髅，然后回到丧钟镇的暗影牧师萨维斯那里。' WHERE `entry`=3901;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10个仙人掌果，把它们交给戈加尔。你记得他说可以在仙人掌上收集到这种果子。' WHERE `entry`=4402;
UPDATE `locales_quest` SET `Objectives_loc4`='杀掉10只翼手龙和15只狂怒的翼手龙，然后向马绍尔营地的斯普拉格·弗劳克报告。' WHERE `entry`=4501;
UPDATE `locales_quest` SET `Objectives_loc4`='将6块魔化瑟银锭、2份火焰精华和4颗红宝石交给玛雷弗斯·暗锤。另外你还得把未淬火的板甲护手也交给他。' WHERE `entry`=5124;
UPDATE `locales_quest` SET `Objectives_loc4`='把4份符文布卷、8块硬甲皮、2卷符文线和一份食人魔鞣酸交给诺特·希姆加克。他现在被拴在厄运之槌的戈多克食人魔那边。' WHERE `entry`=5518;
UPDATE `locales_quest` SET `Objectives_loc4`='格拉兹要你去杀死5个死木守卫、5个死木复仇者和5个死木萨满祭司。' WHERE `entry`=6221;
UPDATE `locales_quest` SET `Objectives_loc4`='迪尔格·奎克里弗想要你收集这些原料：$B$B10只巨蛋。你可以在塔纳利斯的大鹏或是其它大型鸟类那里获得这种蛋。$B$B10块美味的蚌肉。你可以从任何蚌类身上获得这种原料！$B$B20块奥特兰克冷酪。去买就是了！$B$B收集好所有原料，然后把它们交给迪尔格。' WHERE `entry`=6610;
UPDATE `locales_quest` SET `Objectives_loc4`='辛特兰恶齿村的猎户马克霍尔要求你去杀掉10头银鬃捕猎者和10头银鬃嗥狼。完成任务之后就回到他那里复命。$B$B马克霍尔说过那些狼都躲在辛特兰的野外。' WHERE `entry`=7828;
UPDATE `locales_quest` SET `Objectives_loc4`='辛特兰恶齿村的猎户马克霍尔要求你去杀掉20头野蛮的枭兽。完成任务之后就回到他那里复命。$B$B马克霍尔说过那些野蛮的枭兽都躲在辛特兰的野外。' WHERE `entry`=7829;
UPDATE `locales_quest` SET `Objectives_loc4`='辛特兰恶齿村的奥索·莫吉克要你从辛特兰的狮鹫身上收集1根细长的狮鹫羽毛。任务完成之后回到他那里去复命。$B$B在辛特兰各处都有狮鹫出没。' WHERE `entry`=7842;
UPDATE `locales_quest` SET `Objectives_loc4`='辛特兰恶齿村的秘法师雅尔金要你去杀掉15个邪枝割颅者和10个邪枝占卜者。任务完成之后回到他那里去复命。$B$B秘法师雅尔金说过，你可以在辛特兰东北部的沙尔瓦萨和亚戈瓦萨神庙附近找到那些巨魔。' WHERE `entry`=7844;
UPDATE `locales_quest` SET `Objectives_loc4`='辛特兰恶齿村的断齿族长要你在辛萨罗找到5瓶腐化之血。任务完成之后就回到断齿族长那里。' WHERE `entry`=7850;
UPDATE `locales_quest` SET `Objectives_loc4`='你必须杀掉邪恶祭司海克斯和10名邪枝精英守卫。任务完成之后回到辛特兰的恶齿村，向断齿族长报告。$B$B你可以在辛特兰的邪枝巨魔城市辛萨罗的顶部找到他们。' WHERE `entry`=7861;
UPDATE `locales_quest` SET `Objectives_loc4`='塔纳利斯的纳瑞安要你给他带去20块奥金锭、10块源质矿石、10颗艾泽拉斯钻石，以及10颗蓝宝石。' WHERE `entry`=8728;
UPDATE `locales_quest` SET `Objectives_loc4`='把6份强力魔精、6份大瓶魔精和8份献祭之油交给希利苏斯地区的雷戈虫巢附近的暗影祭司沙艾。你还必须随身带着后勤任务简报 IV才能完成这个任务。' WHERE `entry`=8785;
UPDATE `locales_quest` SET `Objectives_loc4`='远行者营地的远行者塞蒂娜要求你杀死10只纺丝潜伏者和8只吸血迷雾蝠。' WHERE `entry`=9159;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死8个戴索姆侍僧和10个堕落游侠，然后向塔奎林的高级执行官玛尔伦复命。' WHERE `entry`=9173;
UPDATE `locales_quest` SET `Objectives_loc4`='地狱火半岛塔哈玛特神殿的斥候瓦努拉要你杀死4只石镰幼崽和8只石镰突击者。' WHERE `entry`=9398;
UPDATE `locales_quest` SET `Objectives_loc4`='将15张亚麻布和1个纺丝蜘蛛的丝囊交给奥术师范迪瑞尔。' WHERE `entry`=9488;
UPDATE `locales_quest` SET `Objectives_loc4`='取得5个阿塔莱神器，将它们交给悲伤沼泽避难营的霍拉鲁。' WHERE `entry`=9610;
UPDATE `locales_quest` SET `Objectives_loc4`='银月城的索拉纳·血怒要求你摧毁15台天灾绞肉车，并杀死3名天灾攻城技师。' WHERE `entry`=9725;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30头裂蹄牛，然后向纳格兰奈辛瓦里狩猎队营地的赫米特·奈辛瓦里复命。' WHERE `entry`=9789;
UPDATE `locales_quest` SET `Objectives_loc4`='将15颗挖出来的卡拉果交给纳格兰元素王座的元素师鲁艾普。' WHERE `entry`=9800;
UPDATE `locales_quest` SET `Objectives_loc4`='消灭12个湖水之魂，然后向纳格兰元素王座的元素师鲁艾普复命。' WHERE `entry`=9804;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死瓦图苏的污染精华和10个湖水涌动者，然后向纳格兰元素王座的元素师鲁艾普复命。' WHERE `entry`=9810;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰元素王座的戈达乌要你消灭15个被折磨的地灵。' WHERE `entry`=9819;
UPDATE `locales_quest` SET `Objectives_loc4`='将15块被激怒的碾压者的核心交给纳格兰元素王座的戈达乌。' WHERE `entry`=9821;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死5个安葛洛什食人魔和10个安葛洛什萨满祭司，然后返回奥雷柏尔营地向伊库提复命。' WHERE `entry`=9835;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30头裂蹄公牛，然后向纳格兰奈辛瓦里狩猎队营地的赫米特·奈辛瓦里复命。' WHERE `entry`=9850;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30只风鹏，然后向纳格兰奈辛瓦里狩猎队营地的“好儿子”沙度·远行者复命。' WHERE `entry`=9854;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30只饥饿的风鹏，然后向纳格兰奈辛瓦里狩猎队营地的“好儿子”沙度·远行者复命。' WHERE `entry`=9855;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30头塔布雄羊，然后向纳格兰奈辛瓦里狩猎队营地的哈罗德·兰恩复命。' WHERE `entry`=9857;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死30头塔布羊食棘者，然后向纳格兰奈辛瓦里狩猎队营地的哈罗德·兰恩复命。' WHERE `entry`=9858;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰元素王座的元素师莫格要你杀死8个暗血净化者。' WHERE `entry`=9862;
UPDATE `locales_quest` SET `Objectives_loc4`='将20个暗血神像交给纳格兰加拉达尔的先知古库斯。' WHERE `entry`=9863;
UPDATE `locales_quest` SET `Objectives_loc4`='消灭40个暗血清道夫和20个暗血掠夺者。' WHERE `entry`=9865;
UPDATE `locales_quest` SET `Objectives_loc4`='消灭20个暗血清道夫和10个暗血掠夺者，然后向纳格兰塔拉的智者普里鲁鲁克复命。' WHERE `entry`=9878;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰加拉达尔的约林·死眼要你杀死15个石拳打击者和15个石拳秘术师。' WHERE `entry`=9906;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰加拉达尔的约林·死眼要你杀死25个石拳战士和25个石拳法师。' WHERE `entry`=9907;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰加拉达尔的秘法师埃尔卡甘要你找回20个血环补给箱。' WHERE `entry`=9916;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死15个石拳打击者和15个石拳秘术师，然后向纳格兰塔拉的击碎者姆摩尔复命。' WHERE `entry`=9921;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死25个石拳战士和25个石拳法师，然后向纳格兰塔拉的击碎者姆摩尔复命。' WHERE `entry`=9922;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰埃瑞斯码头的瑟利德要求你杀死沃舒古附近的12个空灵爪牙。' WHERE `entry`=9925;
UPDATE `locales_quest` SET `Objectives_loc4`='转至基尔索罗堡垒，将20面战槌食人魔军旗插在基尔索罗成员的尸体上，然后返回纳格兰火刃废墟向兰特瑞索·火刃复命。$B$B将没有用完的战槌食人魔军旗还给兰特瑞索。' WHERE `entry`=9927;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰火刃废墟的兰特瑞索·火刃要你收集20份基尔索罗军备。' WHERE `entry`=9928;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰火刃废墟的兰特瑞索·火刃要你杀入嘲颅废墟，将20面基尔索罗军旗插在战槌食人魔的尸体上。$B$B将没有用完的基尔索罗军旗还给兰特瑞索。' WHERE `entry`=9931;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死巫婆吉塞尔达以及任意15名基尔索罗成员，完成任务后向加拉达尔的监护者布罗克复命。' WHERE `entry`=9935;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死巫婆吉塞尔达以及任意15名基尔索罗成员，完成任务后返回塔拉向监护者莫布吉尔复命。' WHERE `entry`=9936;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死顾问佐尔布、10个战槌萨满祭司和10个战槌劫掠者，完成任务后向监护者布罗克复命。' WHERE `entry`=9939;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死顾问佐尔布、10个战槌萨满祭司和10个战槌劫掠者，完成任务后向塔拉的监护者莫布吉尔复命。' WHERE `entry`=9940;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰玛格汉车队的长者尤尔雷要求你杀死15个战槌蛮兵和15个战槌术士。' WHERE `entry`=9945;
UPDATE `locales_quest` SET `Objectives_loc4`='纳格兰玛格汉车队的长者安格雷兹要求你去释放15个玛格汉俘虏。' WHERE `entry`=9948;
UPDATE `locales_quest` SET `Objectives_loc4`='收集20个塔拉补给箱，把它们交给塔拉的女猎手琪玛。' WHERE `entry`=9956;
UPDATE `locales_quest` SET `Objectives_loc4`='将5份扭曲猎者精华和30颗泰罗卡灌木交给迷雾里斯克的可可瑞克。' WHERE `entry`=9969;
UPDATE `locales_quest` SET `Objectives_loc4`='将5份扭曲猎者精华和30颗泰罗卡灌木交给迷雾里斯克的可可瑞克。' WHERE `entry`=9974;
UPDATE `locales_quest` SET `Objectives_loc4`='将20份沃舒古水晶尘样本交给哈兰的主研究员阿米蒂恩。' WHERE `entry`=10074;
UPDATE `locales_quest` SET `Objectives_loc4`='将20份沃舒古水晶尘样本交给哈兰的主研究员卡托斯。' WHERE `entry`=10076;
UPDATE `locales_quest` SET `Objectives_loc4`='卡舒尔宗母要求你让15个激动的兽人灵魂再次安息。' WHERE `entry`=10082;
UPDATE `locales_quest` SET `Objectives_loc4`='地狱火半岛机甲残骸的前线指挥官托尔克要求你杀死20个甘尔葛苦工和5个莫尔葛监工，并摧毁5门邪能火炮。' WHERE `entry`=10162;
UPDATE `locales_quest` SET `Objectives_loc4`='地狱火半岛破碎岗哨的空军指挥官格莱芬加尔要求你杀死20个甘尔葛苦工和5个莫尔葛监工，并摧毁5门邪能火炮。' WHERE `entry`=10163;
UPDATE `locales_quest` SET `Objectives_loc4`='将10块以太锂矩阵水晶交给虚空风暴52区的火箭主管弗斯拉格。' WHERE `entry`=10186;
UPDATE `locales_quest` SET `Objectives_loc4`='52区的间谍大师萨罗迪恩要你进入法力熔炉：布纳尔，杀死2名日怒空间主宰、6名日怒迁跃技师和8名日怒地质学家。$B$B为占星者完成任务将降低你在奥尔多阵营中的声望等级。' WHERE `entry`=10193;
UPDATE `locales_quest` SET `Objectives_loc4`='将5根虚空鳐的钉刺交给虚空风暴52区的布兹。' WHERE `entry`=10199;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10件虚灵科技的产品碎片，将它们交给虚空风暴52区的维勒老爹。' WHERE `entry`=10206;
UPDATE `locales_quest` SET `Objectives_loc4`='将7块法力怨魂精华交给虚空风暴52区的主工程师特雷普。' WHERE `entry`=10224;
UPDATE `locales_quest` SET `Objectives_loc4`='萃取5份元素能量，将它们交给虚空风暴52区的主工程师特雷普。' WHERE `entry`=10226;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死5名莫尔葛铁匠和15名甘尔葛工程师，然后向虚空风暴52区的维勒老爹复命。' WHERE `entry`=10232;
UPDATE `locales_quest` SET `Objectives_loc4`='使用燃烧的火把烧毁4台日怒弩车和4顶日怒帐篷，然后向肯瑞瓦村的巫师上尉莫尔兰复命。' WHERE `entry`=10233;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死8名日怒魔导师和8名日怒血卫士，然后向52区的大主教欧雷里斯复命。$B$B为奥尔多完成任务将降低你在占星者阵营中的声望等级。' WHERE `entry`=10241;
UPDATE `locales_quest` SET `Objectives_loc4`='前往法力熔炉：库鲁恩，杀死5名日怒奥术师和8名日怒研究员，完成任务后向大主教欧雷里斯复命。$B$B为奥尔多完成任务将降低你在占星者阵营中的声望等级。' WHERE `entry`=10246;
UPDATE `locales_quest` SET `Objectives_loc4`='收集10枚萨克希斯徽记，将它们交给虚空风暴52区的虚空猎手卡尔伊。' WHERE `entry`=10262;
UPDATE `locales_quest` SET `Objectives_loc4`='从恩卡特废墟的鬼魂身上收集4块无瑕的水晶碎片，将它们交给52区的拉文德维尔。' WHERE `entry`=10300;
UPDATE `locales_quest` SET `Objectives_loc4`='杀死8名日怒咒术师、6名日怒弓箭手和4名日怒百夫长。完成任务后返回52区向魔导师拉恩娜复命。$B$B为占星者完成任务将降低你在奥尔多阵营中的声望等级。' WHERE `entry`=10341;
UPDATE `locales_quest` SET `Objectives_loc4`='收集5块岩肤油块，将它们交给虚空风暴52区的布兹。' WHERE `entry`=10342;
UPDATE `locales_quest` SET `Objectives_loc4`='地狱火半岛破碎岗哨的狮鹫骑士维比洛要求你杀死20个甘尔葛苦工和5个莫尔葛监工，并摧毁5门邪能火炮。' WHERE `entry`=10346;
UPDATE `locales_quest` SET `Objectives_loc4`='地狱火半岛机甲残骸的空军指挥官布拉克要求你杀死20个甘尔葛苦工和5个莫尔葛监工，并摧毁5门邪能火炮。' WHERE `entry`=10347;
UPDATE `locales_quest` SET `Objectives_loc4`='在52区的主教欧瑞利斯要你去熔炉基地:遗忘和熔炉基地:苦难，并杀掉12个甘纳格锻造黑手，6个莫阿格锻造王和6个愤怒使者。$B$B为奥多尔完成任务会使你的占星者声望降低。' WHERE `entry`=10404;
UPDATE `locales_quest` SET `Objectives_loc4`='从法力熔炉：艾拉的恶魔手中夺得8份凯尔萨斯的命令，将它们交给52区的间谍大师萨罗迪恩。$B$B为占星者完成任务将降低你在奥尔多阵营中的声望等级。' WHERE `entry`=10432;
UPDATE `locales_quest` SET `Objectives_loc4`='使用极化电磁球从鳞翼飞蛇身上吸收25发闪电打击，再收集5份鳞翼闪电腺体。' WHERE `entry`=10657;
UPDATE `locales_quest` SET `Objectives_loc4`='影月谷影月村的奥巴洛恩大王要你去杀死20只影月谷的野生动物。$B$B地狱野猪、邪翼奇美拉和灼壳蝎均属于影月谷的野生动物。无论种类，杀满20只即可。' WHERE `entry`=10702;
UPDATE `locales_quest` SET `Objectives_loc4`='影月谷蛮锤要塞的大领主尤雷加尔要你去杀死20只影月谷的野生动物。$B$B地狱野猪、邪翼奇美拉和灼壳蝎均属于影月谷的野生动物。无论种类，杀满20只即可。' WHERE `entry`=10703;
UPDATE `locales_quest` SET `Objectives_loc4`='将4块魔铁锭、2份奥法之尘和4颗火焰微粒交给地狱火半岛萨尔玛的罗霍克。' WHERE `entry`=10757;
UPDATE `locales_quest` SET `Objectives_loc4`='战斗法师艾尔娜希望你去和艾雷·碎云谈一谈，飞往死亡之痕。用奥术炸弹杀死2个深渊霸主、3个艾瑞达巫师和12个天怒执行者。' WHERE `entry`=11532;
UPDATE `locales_quest` SET `Objectives_loc4`='战斗法师艾尔娜希望你去和艾雷·碎云谈一谈，飞往死亡之痕。用奥术炸弹杀死2个深渊霸主、3个艾瑞达巫师和12个天怒执行者。' WHERE `entry`=11533;
