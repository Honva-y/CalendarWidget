import Foundation

struct HolidayMark: Equatable {
    let name: String
    let isOffDay: Bool   // true=放假，false=调休上班
}

/// 中国法定节假日（含调休）数据：内置兜底 + 本地缓存 + 网络更新
@MainActor
final class HolidayStore: ObservableObject {
    static let shared = HolidayStore()

    @Published private(set) var marks: [String: HolidayMark] = [:]   // "yyyy-MM-dd" → 标记
    @Published private(set) var lastError: String?

    private var loadedYears = Set<Int>()
    private var fetchingYears = Set<Int>()
    private var lastAttempt: [Int: Date] = [:]
    private let cacheMaxAge: TimeInterval = 3 * 24 * 3600

    private static let sources = [
        "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
        "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json",
    ]

    private var cacheDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CalendarWidget/holidays", isDirectory: true)
    }

    static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func mark(year: Int, month: Int, day: Int) -> HolidayMark? {
        marks[Self.key(year: year, month: month, day: day)]
    }

    /// 确保某年的数据已加载；缓存过期或缺失时在后台拉取
    func ensure(year: Int) {
        if !loadedYears.contains(year) {
            loadedYears.insert(year)
            if let cached = try? Data(contentsOf: cacheFile(year)), let entries = Self.parse(json: cached) {
                apply(entries, year: year)
            } else if let builtin = BuiltinHolidays.data[year] {
                apply(Self.parse(lines: builtin), year: year)
            }
        }
        let age = (try? cacheFile(year).resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate.map { -$0.timeIntervalSinceNow } ?? .infinity
        let recentlyTried = lastAttempt[year].map { -$0.timeIntervalSinceNow < 3600 } ?? false
        if age > cacheMaxAge && !recentlyTried { fetch(year: year) }
    }

    /// 强制重新拉取已加载的年份
    func refreshAll() {
        for y in loadedYears { fetch(year: y) }
    }

    private func cacheFile(_ year: Int) -> URL { cacheDir.appendingPathComponent("\(year).json") }

    private func fetch(year: Int) {
        guard !fetchingYears.contains(year) else { return }
        fetchingYears.insert(year)
        lastAttempt[year] = Date()
        Task {
            defer { fetchingYears.remove(year) }
            for template in Self.sources {
                guard let url = URL(string: String(format: template, year)) else { continue }
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                req.setValue("CalendarWidget", forHTTPHeaderField: "User-Agent")
                guard let (data, resp) = try? await URLSession.shared.data(for: req),
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let entries = Self.parse(json: data) else { continue }
                try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                try? data.write(to: cacheFile(year))
                apply(entries, year: year)
                lastError = nil
                return
            }
            // 尚未公布的年份（如次年）会 404，属于正常情况
            lastError = "\(year) 年节假日数据暂不可用"
        }
    }

    private func apply(_ entries: [(String, HolidayMark)], year: Int) {
        var m = marks.filter { !$0.key.hasPrefix("\(year)-") }
        for (k, v) in entries { m[k] = v }
        marks = m
    }

    private struct Remote: Decodable {
        struct Day: Decodable { let name: String; let date: String; let isOffDay: Bool }
        let days: [Day]
    }

    private static func parse(json: Data) -> [(String, HolidayMark)]? {
        guard let r = try? JSONDecoder().decode(Remote.self, from: json) else { return nil }
        return r.days.map { ($0.date, HolidayMark(name: $0.name, isOffDay: $0.isOffDay)) }
    }

    private static func parse(lines: String) -> [(String, HolidayMark)] {
        lines.split(separator: "\n").compactMap { line in
            let p = line.split(separator: " ")
            guard p.count == 3 else { return nil }
            return (String(p[0]), HolidayMark(name: String(p[1]), isOffDay: p[2] == "1"))
        }
    }
}
