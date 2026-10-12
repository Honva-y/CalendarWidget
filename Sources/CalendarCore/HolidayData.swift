import Foundation

public struct HolidayMark: Equatable, Sendable {
    public let name: String
    public let isOffDay: Bool   // true=放假，false=调休上班

    public init(name: String, isOffDay: Bool) {
        self.name = name
        self.isOffDay = isOffDay
    }
}

/// "yyyy-MM-dd" → 节假日标记
public typealias HolidayMarks = [String: HolidayMark]

/// 中国法定节假日数据的解析、缓存与下载（数据源：NateScarlet/holiday-cn）
public enum HolidayData {
    private static let sources = [
        "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%d.json",
        "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%d.json",
    ]

    public static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 宿主 App 的缓存目录。沙盒中的小组件也用真实的用户主目录拼出同一路径（需要只读例外权限）
    public static var hostCacheDir: URL {
        let home: String
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            home = String(cString: dir)
        } else {
            home = NSHomeDirectory()
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/CalendarWidget/holidays", isDirectory: true)
    }

    public static func cacheFile(year: Int, in dir: URL) -> URL {
        dir.appendingPathComponent("\(year).json")
    }

    /// 读取缓存（依次尝试多个目录），没有时使用内置数据
    public static func load(year: Int, cacheDirs: [URL]) -> HolidayMarks? {
        for dir in cacheDirs {
            if let data = try? Data(contentsOf: cacheFile(year: year, in: dir)),
               let marks = parse(json: data), !marks.isEmpty {
                return marks
            }
        }
        return builtin(year: year)
    }

    public static func cacheAge(year: Int, in dir: URL) -> TimeInterval {
        let date = (try? cacheFile(year: year, in: dir).resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        return date.map { -$0.timeIntervalSinceNow } ?? .infinity
    }

    /// 下载某年数据并写入缓存目录，成功时返回解析结果
    public static func fetch(year: Int, into dir: URL, timeout: TimeInterval = 15) async -> HolidayMarks? {
        for template in sources {
            guard let url = URL(string: String(format: template, year)) else { continue }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
            req.setValue("CalendarWidget", forHTTPHeaderField: "User-Agent")
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let marks = parse(json: data) else { continue }
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: cacheFile(year: year, in: dir))
            return marks
        }
        return nil
    }

    private struct Remote: Decodable {
        struct Day: Decodable { let name: String; let date: String; let isOffDay: Bool }
        let days: [Day]
    }

    public static func parse(json: Data) -> HolidayMarks? {
        guard let r = try? JSONDecoder().decode(Remote.self, from: json) else { return nil }
        var m = HolidayMarks()
        for d in r.days { m[d.date] = HolidayMark(name: d.name, isOffDay: d.isOffDay) }
        return m
    }

    public static func builtin(year: Int) -> HolidayMarks? {
        guard let text = BuiltinHolidays.data[year] else { return nil }
        var m = HolidayMarks()
        for line in text.split(separator: "\n") {
            let p = line.split(separator: " ")
            guard p.count == 3 else { continue }
            m[String(p[0])] = HolidayMark(name: String(p[1]), isOffDay: p[2] == "1")
        }
        return m
    }

    /// 今天之后最近一个法定假期的第一天
    public static func nextHoliday(after today: Date, marks: HolidayMarks, calendar cal: Calendar) -> (name: String, date: Date, days: Int)? {
        let c = cal.dateComponents([.year, .month, .day], from: today)
        let todayKey = key(year: c.year!, month: c.month!, day: c.day!)
        let todayName = marks[todayKey].flatMap { $0.isOffDay ? $0.name : nil }
        let candidates = marks
            .filter { $0.key > todayKey && $0.value.isOffDay && $0.value.name != todayName }
            .sorted { $0.key < $1.key }
        guard let first = candidates.first else { return nil }
        let p = first.key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, let date = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { return nil }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: today), to: date).day ?? 0
        return (first.value.name, date, days)
    }
}
