import AppIntents
import Foundation

/// 小组件当前翻到的月份（相对本月的偏移），保存在小组件自己的沙盒里。
/// 一段时间没有操作后自动回到本月，避免下次打开时还停在别的月份。
public enum WidgetMonthState {
    public static let idleReset: TimeInterval = 5 * 60

    private static let offsetKey = "widgetMonthOffset"
    private static let changedAtKey = "widgetMonthChangedAt"
    private static let directionKey = "widgetMonthDirection"

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

    /// 最近一次翻页的方向：1=往后，-1=往前，用于翻页动画。闲置到期自动回到本月时，方向与之前的偏移相反
    public static func direction(now: Date = Date()) -> Int {
        let d = UserDefaults.standard
        let raw = d.integer(forKey: offsetKey)
        if raw != 0 && offset(now: now) == 0 { return raw > 0 ? -1 : 1 }
        return d.integer(forKey: directionKey)
    }

    static func set(_ offset: Int) {
        let d = UserDefaults.standard
        let old = self.offset()
        d.set(offset == old ? 0 : (offset > old ? 1 : -1), forKey: directionKey)
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

/// 串行处理小组件上的点击，并在连点结束后才让意图返回。
///
/// 意图一返回，系统就会刷新小组件；新内容刚换上的约 0.1 秒内，通知中心收不到按钮点击，
/// 这时的点击会被当成点击小组件本身，打开 App 并关闭通知中心。连点（尤其是双击）的第二下
/// 很容易落进这个空档。所以每次点击先立即更新状态，再等到最后一次点击之后 `quietPeriod`
/// 秒再一起返回：连点期间画面不刷新，所有点击都落在仍可点击的旧画面上，停手后只刷新一次。
actor WidgetTapCoordinator {
    static let shared = WidgetTapCoordinator()
    static let quietPeriod: TimeInterval = 0.25

    private var lastTap = Date.distantPast

    func shift(by delta: Int) async {
        WidgetMonthState.set(WidgetMonthState.offset() + delta)
        await settle()
    }

    func reset() async {
        WidgetMonthState.set(0)
        await settle()
    }

    /// 记录这次点击，等到最后一次点击之后安静 quietPeriod 秒再返回
    func settle() async {
        lastTap = Date()
        while true {
            let remaining = lastTap.addingTimeInterval(Self.quietPeriod).timeIntervalSinceNow
            if remaining <= 0 { return }
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}

// 以下意图供小组件按钮使用。没有 Xcode 时意图元数据由 tools/make-intents-metadata.py 生成，
// 新增或改名意图后需要同步修改那个脚本。

public struct PreviousMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "上个月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WidgetTapCoordinator.shared.shift(by: -1)
        return .result()
    }
}

public struct NextMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "下个月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WidgetTapCoordinator.shared.shift(by: 1)
        return .result()
    }
}

public struct ThisMonthIntent: AppIntent {
    public static let title: LocalizedStringResource = "回到本月"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WidgetTapCoordinator.shared.reset()
        return .result()
    }
}

/// 点在按钮以外的地方时执行，不改变任何状态。
/// 小组件默认被点击时会打开 App 并关闭通知中心，点偏了也会这样，所以用它把空白处的点击接住
public struct IgnoreTapIntent: AppIntent {
    public static let title: LocalizedStringResource = "日历"
    public static let isDiscoverable = false
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WidgetTapCoordinator.shared.settle()
        return .result()
    }
}
