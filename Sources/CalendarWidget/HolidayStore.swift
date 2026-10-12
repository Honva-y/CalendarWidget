import CalendarCore
import Foundation
import WidgetKit

/// App 端的节假日数据：内置兜底 + 本地缓存 + 网络更新；更新后通知小组件刷新
@MainActor
final class HolidayStore: ObservableObject {
    static let shared = HolidayStore()

    @Published private(set) var marks = HolidayMarks()

    private var loadedYears = Set<Int>()
    private var fetchingYears = Set<Int>()
    private var lastAttempt: [Int: Date] = [:]
    private let cacheMaxAge: TimeInterval = 3 * 24 * 3600
    private let dir = HolidayData.hostCacheDir

    /// 确保某年的数据已加载；缓存过期或缺失时在后台拉取
    func ensure(year: Int) {
        if !loadedYears.contains(year) {
            loadedYears.insert(year)
            if let m = HolidayData.load(year: year, cacheDirs: [dir]) { apply(m, year: year) }
        }
        let recentlyTried = lastAttempt[year].map { -$0.timeIntervalSinceNow < 3600 } ?? false
        if HolidayData.cacheAge(year: year, in: dir) > cacheMaxAge && !recentlyTried { fetch(year: year) }
    }

    /// 强制重新拉取已加载的年份
    func refreshAll() {
        for y in loadedYears { fetch(year: y) }
    }

    private func fetch(year: Int) {
        guard !fetchingYears.contains(year) else { return }
        fetchingYears.insert(year)
        lastAttempt[year] = Date()
        Task {
            defer { fetchingYears.remove(year) }
            // 尚未公布的年份（如次年）数据为空，属于正常情况
            guard let m = await HolidayData.fetch(year: year, into: dir), !m.isEmpty else { return }
            apply(m, year: year)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func apply(_ m: HolidayMarks, year: Int) {
        var all = marks.filter { !$0.key.hasPrefix("\(year)-") }
        all.merge(m) { $1 }
        marks = all
    }
}
