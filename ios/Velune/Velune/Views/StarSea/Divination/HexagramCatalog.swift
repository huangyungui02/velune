import Foundation

private func getTrigram(lines: [YaoType]) -> Trigram {
    switch lines {
    case [.yang, .yang, .yang]: return Trigram(name: "乾", symbol: "天")
    case [.yin, .yin, .yin]: return Trigram(name: "坤", symbol: "地")
    case [.yang, .yin, .yin]: return Trigram(name: "震", symbol: "雷")
    case [.yin, .yang, .yang]: return Trigram(name: "巽", symbol: "风")
    case [.yin, .yang, .yin]: return Trigram(name: "坎", symbol: "水")
    case [.yang, .yin, .yang]: return Trigram(name: "离", symbol: "火")
    case [.yin, .yin, .yang]: return Trigram(name: "艮", symbol: "山")
    case [.yang, .yang, .yin]: return Trigram(name: "兑", symbol: "泽")
    default: return Trigram(name: "乾", symbol: "天")
    }
}

// Complete 64 I Ching hexagrams lookup table based on (Upper Trigram Symbol + Lower Trigram Symbol)
private let hexagramMap: [String: (name: String, character: String, judgment: String, desc: String)] = [
    "天天": ("乾为天", "乾", "元亨利贞。", "天行健，君子以自强不息。象征纯粹的阳刚与创造力。"),
    "地地": ("坤为地", "坤", "利牝马之贞。", "地势坤，君子以厚德载物。象征包容、承载与滋养。"),
    "水雷": ("水雷屯", "屯", "元亨利贞，勿用有攸往。", "万物始生，艰难创业。象征初生的艰难与积蓄力量。"),
    "山水": ("山水蒙", "蒙", "亨。匪我求童蒙，童蒙求我。", "智慧初开，启蒙教育。象征迷茫探索，宜虚心求学。"),
    "水天": ("水天需", "需", "有孚，光亨，贞吉。", "云上于天，需。象征等待与筹备，宜耐心蓄势。"),
    "天水": ("天水讼", "讼", "有孚，窒惕，中吉，终凶。", "争执诉讼，和为贵。象征冲突，宜克制退让以求和解。"),
    "地水": ("地水师", "师", "贞，丈人吉，无咎。", "行军打仗，纪律严明。象征组织领导，宜坚守正道。"),
    "水地": ("水地比", "比", "吉。原筮，元永贞，无咎。", "亲密比辅，相亲相爱. 象征团结协作，诚信相待。"),
    "风天": ("风天小畜", "小畜", "亨。密云不雨，自我西郊。", "力量尚微，积蓄待时。象征微小的积累与以柔克刚。"),
    "天泽": ("天泽履", "履", "履虎尾，不咥人，亨。", "如履薄冰，防微杜渐。象征践行礼仪，宜小心谨慎。"),
    "地天": ("地天泰", "泰", "小往大来，吉亨。", "天地交泰，万物通顺。象征和谐、通畅、安宁。"),
    "天地": ("天地否", "否", "否之匪人，不利君子贞。", "天地不交，闭塞不通。象征阻碍与不顺，宜守持正道。"),
    "天火": ("天火同人", "同人", "同人于野，亨。", "志同道合，大公无私. 象征团结合作与大同世界。"),
    "火天": ("火天大有", "大有", "元亨。", "如日中天，富强富有。象征收获昌盛，宜谦逊顺天。"),
    "地山": ("地山谦", "谦", "亨，君子有终。", "虚怀若谷，谦逊有礼。君子以谦退为美，方能长久。"),
    "雷地": ("雷地豫", "豫", "利建侯行师。", "顺时依势，愉悦和乐。象征喜悦与顺应规律。"),
    "泽雷": ("泽雷随", "随", "元亨利贞，无咎。", "顺其自然，随机应变。象征随和顺从，宜随缘自适。"),
    "山风": ("山风蛊", "蛊", "元亨，利涉大川。", "整治积弊，革新创造。象征整顿，宜正视问题大刀阔斧。"),
    "地泽": ("地泽临", "临", "元亨利贞，至于八月有凶。", "居高临下，步步推进。象征上面对，宜关怀大众。"),
    "风地": ("风地观", "观", "盥而不荐，有孚颙若。", "观察省视，感化世人。象征观察，宜反求诸己。"),
    "火雷": ("火雷噬嗑", "噬嗑", "亨。利用狱。", "咬碎阻碍，公正执法。象征消除障碍，宜法度分明。"),
    "山火": ("山火贲", "贲", "亨。小利有攸往。", "文饰点缀，质朴归真。象征美化，宜重质轻文。"),
    "山地": ("山地剥", "剥", "不利有攸往。", "小人得势，剥落衰退。象征危机，宜顺时隐退，静守待变。"),
    "地雷": ("地雷复", "复", "亨。出入无疾，朋来无咎。", "一阳复始，万物回春。象征复归与新生，宜循序渐进。"),
    "天雷": ("天雷无妄", "无妄", "元亨利贞。其匪正有眚。", "真实无妄，顺应天命。象征不妄动，宜守正自然。"),
    "山天": ("山天大畜", "大畜", "利贞。不家食吉。", "大有积蓄，笃实辉光。象征丰厚积累，宜蓄势待发。"),
    "山雷": ("山雷颐", "颐", "贞吉。观颐，自求口实。", "颐养天年，注意言行。象征养生调理，宜谨言慎行。"),
    "泽风": ("泽风大过", "大过", "栋桡，利有攸往，亨。", "栋梁弯曲，承受重载。象征过度与挑战，宜刚毅果断。"),
    "水水": ("坎为水", "坎", "有孚，维心亨，行有尚。", "重重险阻，坚守诚信。象征险难，宜以诚化险。"),
    "火火": ("离为火", "离", "利贞，亨。畜牝牛，吉。", "光明附着，柔顺中正。象征光明与依附，宜持之以恒。"),
    "泽山": ("泽山咸", "咸", "亨，利贞，取女吉。", "心灵感应，默契配合。象征吸引与感应，宜真诚交流。"),
    "雷风": ("雷风恒", "恒", "亨，无咎，利贞。", "雷风相与，恒常持久。象征坚持，君子以立不易方。"),
    "天山": ("天山遁", "遁", "亨，小利贞。", "退避隐遁，保存实力。象征退避，宜韬光养晦。"),
    "雷天": ("雷天大壮", "大壮", "利贞。", "声势浩大，壮大昌盛。象征强盛，宜坚守正道勿骄狂。"),
    "火地": ("火地晋", "晋", "康侯用锡马蕃庶，昼日三接。", "如日东升，前进光明。象征上升，宜显扬德行。"),
    "地火": ("地火明夷", "明夷", "利艰贞。", "光明受损，韬光养晦。象征挫折，宜内藏智慧保全自身。"),
    "风火": ("风火家人", "家人", "利女贞。", "家庭与本分，女主内男主外。宜各尽其责，严于律己。"),
    "火泽": ("火泽睽", "睽", "小事吉。", "乖异矛盾，求同存异。象征疏离分歧，宜寻求共识。"),
    "水山": ("水山蹇", "蹇", "利西南，不利东北。", "步履维艰，反求诸己。象征困难重重，宜谋定后动。"),
    "雷水": ("雷水解", "解", "利西南，无所往，其来复吉。", "缓解消除，冰雪消融。象征解除危机，宜轻装前行。"),
    "山泽": ("山泽损", "损", "损，有孚，元吉，无咎。", "损下益上，减损欲望。象征适当放弃，宜诚意沟通。"),
    "风雷": ("风雷益", "益", "利有攸往，利涉大川。", "损上益下，大有作为。象征增益与进步，宜改过迁善。"),
    "泽天": ("泽天夬", "夬", "扬于王庭，孚号，有厉。", "果断决裂，清除阻碍。象征决断，宜光明磊落。"),
    "天风": ("天风姤", "姤", "女壮，勿用取女。", "不期而遇，邂逅生机。象征防微杜渐，宜谨慎交往。"),
    "泽地": ("泽地萃", "萃", "亨。王假有庙，利见大人。", "荟萃聚集，团结一致。象征汇聚，宜凝聚核心力量。"),
    "地风": ("地风升", "升", "元亨，用见大人，勿恤。", "积小成大，步步高升。象征上升与成长，宜不懈努力。"),
    "泽水": ("泽水困", "困", "亨，贞，大人吉，无咎。", "困境求生，坚守信念。象征穷困，宜身处困境而不失正道.及。"),
    "水风": ("水风井", "井", "改邑不改井，无丧无得。", "源源不断，静水流深。象征供养，宜坚守本职惠及他人。"),
    "泽火": ("泽火革", "革", "己日乃孚，元亨利贞，悔亡。", "顺天应人，变革创新。象征破旧立新，宜把握时机。"),
    "火风": ("火风鼎", "鼎", "元吉，亨。", "稳重鼎立，贤能治国。象征更新，宜稳重行事聚贤纳才。"),
    "雷雷": ("震为雷", "震", "亨。震来虩虩，笑言哑哑。", "雷声震动，警示世人。象征震动，宜反省自身消除懈怠。"),
    "山山": ("艮为山", "艮", "艮其背，不获其身。", "动静得宜，知止不殆。象征静止与分寸，宜安守本分。"),
    "风山": ("风山渐", "渐", "女归吉，利贞。", "循序渐进，顺理成章。象征渐进，宜脚踏实地行稳致远。"),
    "雷泽": ("雷泽归妹", "归妹", "征凶，无攸利。", "关系错位，行为失当。象征结合，宜防范风险坚守原则。"),
    "雷火": ("雷火丰", "丰", "亨，王假之，勿忧，宜日中。", "盛大丰满，如日中天。象征收获，宜居安思危持守光明。"),
    "火山": ("火山旅", "旅", "小亨，旅贞吉。", "客居他乡，流转不定。象征客旅行旅，宜谦逊守正。"),
    "风风": ("巽为风", "巽", "小亨，利攸往，利见大人。", "谦逊柔顺，无孔不入。象征顺从宣导，宜温和行事。"),
    "泽泽": ("兑为泽", "兑", "亨，利贞。", "喜悦和乐，以诚感人。象征沟通与喜悦，宜与人友善。"),
    "风水": ("风水涣", "涣", "亨。王假有庙，利涉大川。", "人心涣散，凝聚共识。象征涣散与拯救，宜重构信任。"),
    "水泽": ("水泽节", "节", "亨。苦节不可贞。", "适当节制，安守节度。象征节制，宜合理约束防过犹不及。"),
    "风泽": ("风泽中孚", "中孚", "豚鱼吉，利涉大川，利贞。", "心中诚信，感通万物。象征真诚，宜诚信立身化解隔阂。"),
    "雷山": ("雷山小过", "小过", "亨，利贞。可小事，不可大事。", "小有过度，宜下不宜上。象征微小过度，宜谨言慎行。"),
    "水火": ("水火既济", "既济", "亨，小利贞。", "水在火上，完美平衡。象征成功，宜居安思危防盛极而衰。"),
    "火水": ("火水未济", "未济", "亨，小狐汔济，濡其尾。", "火在水上，尚未成功。象征希望，宜逆流而上开启新局。")
]

func lookupHexagram(lines: [YaoType]) -> Hexagram {
    let lower = getTrigram(lines: Array(lines[0...2]))
    let upper = getTrigram(lines: Array(lines[3...5]))
    let key = upper.symbol + lower.symbol
    if let match = hexagramMap[key] {
        let localizedName = localizedHexagramName(for: key, fallback: match.name)
        return Hexagram(
            name: localizedName.name,
            subtitle: localizedName.subtitle,
            character: match.character,
            lines: lines,
            judgment: match.judgment,
            description: match.desc
        )
    }
    return Hexagram(
        name: Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "未知卦" : "Unknown Hexagram",
        subtitle: nil,
        character: "卦",
        lines: lines,
        judgment: "乾坤未定。",
        description: "天地运行，妙理无穷。静待因缘际会。"
    )
}

private let englishHexagramNames: [String: (name: String, subtitle: String)] = [
    "天天": ("Qian", "The Creative"),
    "地地": ("Kun", "The Receptive"),
    "水雷": ("Zhun", "Difficulty at the Beginning"),
    "山水": ("Meng", "Youthful Folly"),
    "水天": ("Xu", "Waiting"),
    "天水": ("Song", "Conflict"),
    "地水": ("Shi", "The Army"),
    "水地": ("Bi", "Holding Together"),
    "风天": ("Xiao Xu", "Small Taming"),
    "天泽": ("Lu", "Treading"),
    "地天": ("Tai", "Peace"),
    "天地": ("Pi", "Standstill"),
    "天火": ("Tong Ren", "Fellowship"),
    "火天": ("Da You", "Great Possession"),
    "地山": ("Qian", "Modesty"),
    "雷地": ("Yu", "Enthusiasm"),
    "泽雷": ("Sui", "Following"),
    "山风": ("Gu", "Repair"),
    "地泽": ("Lin", "Approach"),
    "风地": ("Guan", "Contemplation"),
    "火雷": ("Shi He", "Biting Through"),
    "山火": ("Bi", "Grace"),
    "山地": ("Bo", "Splitting Apart"),
    "地雷": ("Fu", "Return"),
    "天雷": ("Wu Wang", "Innocence"),
    "山天": ("Da Xu", "Great Taming"),
    "山雷": ("Yi", "Nourishment"),
    "泽风": ("Da Guo", "Great Preponderance"),
    "水水": ("Kan", "The Abysmal"),
    "火火": ("Li", "The Clinging"),
    "泽山": ("Xian", "Influence"),
    "雷风": ("Heng", "Duration"),
    "天山": ("Dun", "Retreat"),
    "雷天": ("Da Zhuang", "Great Power"),
    "火地": ("Jin", "Progress"),
    "地火": ("Ming Yi", "Darkening of the Light"),
    "风火": ("Jia Ren", "The Family"),
    "火泽": ("Kui", "Opposition"),
    "水山": ("Jian", "Obstruction"),
    "雷水": ("Jie", "Deliverance"),
    "山泽": ("Sun", "Decrease"),
    "风雷": ("Yi", "Increase"),
    "泽天": ("Guai", "Breakthrough"),
    "天风": ("Gou", "Coming to Meet"),
    "泽地": ("Cui", "Gathering Together"),
    "地风": ("Sheng", "Pushing Upward"),
    "泽水": ("Kun", "Oppression"),
    "水风": ("Jing", "The Well"),
    "泽火": ("Ge", "Revolution"),
    "火风": ("Ding", "The Cauldron"),
    "雷雷": ("Zhen", "The Arousing"),
    "山山": ("Gen", "Keeping Still"),
    "风山": ("Jian", "Development"),
    "雷泽": ("Gui Mei", "The Marrying Maiden"),
    "雷火": ("Feng", "Abundance"),
    "火山": ("Lu", "The Wanderer"),
    "风风": ("Xun", "The Gentle"),
    "泽泽": ("Dui", "The Joyous"),
    "风水": ("Huan", "Dispersion"),
    "水泽": ("Jie", "Limitation"),
    "风泽": ("Zhong Fu", "Inner Truth"),
    "雷山": ("Xiao Guo", "Small Preponderance"),
    "水火": ("Ji Ji", "After Completion"),
    "火水": ("Wei Ji", "Before Completion")
]

private func localizedHexagramName(for key: String, fallback: String) -> (name: String, subtitle: String?) {
    guard Locale.preferredLanguages.first?.hasPrefix("zh") != true else {
        return (fallback, nil)
    }
    guard let english = englishHexagramNames[key] else {
        return (fallback, nil)
    }
    return (english.name, english.subtitle)
}
