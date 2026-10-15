import AppIntents
import Foundation

/// 小组件当前翻到的月份（相对本月的偏移），保存在小组件自己的沙盒里。
/// 一段时间没有操作后自动回到本月，避免下次打开时还停在别的月份。
public enum WidgetMonthState {
    public static let idleReset: TimeInterval = 5 * 60

    private static let offsetKey = "widgetMonthOffset"
    private static let changedAtKey = "widgetMonthChangedAt"

    /// 当前有效的偏移；超时则视为 0
    public static func offset(now: Date = Date()) -> Int {
        let d = UserDefaults.standard
        let changedAt = d.double(forKey: changedAtKey)
        guard changedAt > 0, now.timeIntervalSince1970 - changedAt < idleReset else { return 0 }
        return d.integer(forKey: offsetKey)
    }

    /// 偏移到期（回到本月）的时间；当前就是本月时返回 nil
    public static func expiry(now: Date = Date()) -> Date? {
        guard offset(now: now) != 0 else { return nil }
        return Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: changedAtKey) + idleReset)
    }

    static func set(_ offset: Int) {
        let d = UserDefaults.standard
        d.set(max(-1200, min(1200, offset)), forKey: offsetKey)
        d.set(Date().timeIntervalSince1970, forKey: changedAtKey)
    }

    /// 本月加上偏移后的年、月
    public static func month(adding offset: Int, to today: Date, calendar cal: Calendar) -> (year: Int, month: Int) {
        let c = cal.dateComponents([.year, .month], from: today)
        let total = c.year! * 12 + (c.month! - 1) + offset
        return (total / 12, total % 12 + 1)
    }
}

// 以下意图供小组件按钮使用。没有 Xcode 时意图元数据由 tools/make-intents-metadata.py 生成，
// 新增或改名意图后需要同步修改那个脚本。

public struct PreviousMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "上个月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        WidgetMonthState.set(WidgetMonthState.offset() - 1)
        return .result()
    }
}

public struct NextMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "下个月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        WidgetMonthState.set(WidgetMonthState.offset() + 1)
        return .result()
    }
}

public struct ThisMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "回到本月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        WidgetMonthState.set(0)
        return .result()
    }
}
