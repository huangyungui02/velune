import Foundation

struct DivinationData: Hashable, Codable {
    var castedLines: [Int]
    var date: Date
}

enum YaoType {
    case yang
    case yin
}

enum YaoState {
    case stableYang
    case stableYin
    case movingYang
    case movingYin
    
    var primaryType: YaoType {
        switch self {
        case .stableYang, .movingYang: return .yang
        case .stableYin, .movingYin: return .yin
        }
    }
    
    var changedType: YaoType {
        switch self {
        case .stableYang, .movingYin: return .yang
        case .stableYin, .movingYang: return .yin
        }
    }

    init(code: Int) {
        switch code {
        case 0: self = .stableYang
        case 1: self = .stableYin
        case 2: self = .movingYang
        case 3: self = .movingYin
        default: self = .stableYang
        }
    }
}

struct Hexagram {
    let name: String
    let subtitle: String?
    let character: String
    let lines: [YaoType]
    let judgment: String
    let description: String
}

struct Trigram {
    let name: String
    let symbol: String
}
