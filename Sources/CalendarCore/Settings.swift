import Foundation

/// UserDefaults 键名（不能含 "."，否则 @AppStorage 的 KVO 失效）
public enum Keys {
    /// 宿主 App 的 bundle id，也是设置所在的偏好域；小组件以只读方式读取
    public static let hostDomain = "local.calendarwidget"

    public static let firstWeekday = "firstWeekday"        // 1=周日 … 7=周六，默认 2=周一
    public static let weekRule = "weekRule"                // WeekRule.rawValue
    public static let showWeekNumbers = "showWeekNumbers"
    public static let showLunar = "showLunar"
    public static let showHolidays = "showHolidays"
    public static let showDesktopWindow = "showDesktopWindow"
    public static let windowLevel = "windowLevel"          // WindowLevelOption.rawValue
    public static let appearance = "appearance"            // AppearanceOption.rawValue
    public static let locked = "locked"
    public static let opacity = "backgroundOpacity"

    public static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            firstWeekday: 2,
            weekRule: WeekRule.iso.rawValue,
            showWeekNumbers: true,
            showLunar: true,
            showHolidays: true,
            showDesktopWindow: true,
            windowLevel: WindowLevelOption.desktop.rawValue,
            appearance: AppearanceOption.system.rawValue,
            locked: false,
            opacity: 1.0,
        ])
    }
}

/// 与日历内容相关的显示选项（App 与小组件共用）
public struct DisplayOptions {
    public var firstWeekday: Int
    public var weekRule: WeekRule
    public var showWeekNumbers: Bool
    public var showLunar: Bool
    public var showHolidays: Bool

    public init(defaults: UserDefaults) {
        firstWeekday = (1...7).contains(defaults.integer(forKey: Keys.firstWeekday)) ? defaults.integer(forKey: Keys.firstWeekday) : 2
        weekRule = WeekRule(rawValue: defaults.string(forKey: Keys.weekRule) ?? "") ?? .iso
        showWeekNumbers = defaults.bool(forKey: Keys.showWeekNumbers)
        showLunar = defaults.bool(forKey: Keys.showLunar)
        showHolidays = defaults.bool(forKey: Keys.showHolidays)
    }

    public var calendar: Calendar { CalendarModel.calendar(firstWeekday: firstWeekday, rule: weekRule) }
}

/// 第 1 周的判定规则
public enum WeekRule: String, CaseIterable {
    case iso        // 包含至少 4 天的那一周为第 1 周（ISO 8601）
    case jan1       // 1 月 1 日所在的那一周为第 1 周

    public var title: String {
        switch self {
        case .iso: return "ISO 8601（首周至少含 4 天）"
        case .jan1: return "1 月 1 日所在周为第 1 周"
        }
    }

    public var minimumDaysInFirstWeek: Int { self == .iso ? 4 : 1 }
}

public enum WindowLevelOption: String, CaseIterable {
    case desktop, normal, floating

    public var title: String {
        switch self {
        case .desktop: return "嵌入桌面"
        case .normal: return "普通窗口"
        case .floating: return "始终置顶"
        }
    }
}

public enum AppearanceOption: String, CaseIterable {
    case system, light, dark

    public var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

public let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]   // 索引 = weekday - 1
