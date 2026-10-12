import Foundation

/// UserDefaults 键名（不能含 "."，否则 @AppStorage 的 KVO 失效）
enum Keys {
    static let firstWeekday = "firstWeekday"        // 1=周日 … 7=周六，默认 2=周一
    static let weekRule = "weekRule"                // WeekRule.rawValue
    static let showWeekNumbers = "showWeekNumbers"
    static let showLunar = "showLunar"
    static let showHolidays = "showHolidays"
    static let windowLevel = "windowLevel"          // WindowLevelOption.rawValue
    static let appearance = "appearance"            // AppearanceOption.rawValue
    static let locked = "locked"
    static let opacity = "backgroundOpacity"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            firstWeekday: 2,
            weekRule: WeekRule.iso.rawValue,
            showWeekNumbers: true,
            showLunar: true,
            showHolidays: true,
            windowLevel: WindowLevelOption.desktop.rawValue,
            appearance: AppearanceOption.system.rawValue,
            locked: false,
            opacity: 1.0,
        ])
    }
}

/// 第 1 周的判定规则
enum WeekRule: String, CaseIterable {
    case iso        // 包含至少 4 天的那一周为第 1 周（ISO 8601）
    case jan1       // 1 月 1 日所在的那一周为第 1 周

    var title: String {
        switch self {
        case .iso: return "ISO 8601（首周至少含 4 天）"
        case .jan1: return "1 月 1 日所在周为第 1 周"
        }
    }

    var minimumDaysInFirstWeek: Int { self == .iso ? 4 : 1 }
}

enum WindowLevelOption: String, CaseIterable {
    case desktop, normal, floating

    var title: String {
        switch self {
        case .desktop: return "嵌入桌面（像小组件）"
        case .normal: return "普通窗口"
        case .floating: return "始终置顶"
        }
    }
}

enum AppearanceOption: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]   // 索引 = weekday - 1
