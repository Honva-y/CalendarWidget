import CalendarCore
import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let options: DisplayOptions
    let marks: HolidayMarks
    var monthOffset = 0
}

struct Provider: TimelineProvider {
    /// 宿主 App 的设置（通过只读的共享偏好例外权限读取）
    private var settings: UserDefaults {
        let d = UserDefaults(suiteName: Keys.hostDomain) ?? .standard
        Keys.registerDefaults(in: d)
        return d
    }

    /// 小组件自己的缓存目录（沙盒容器内），宿主 App 没运行时用来兜底
    private var ownCacheDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("holidays", isDirectory: true)
    }

    private func loadMarks(around date: Date) -> HolidayMarks {
        let y = Calendar.current.component(.year, from: date)
        var marks = HolidayMarks()
        for year in y - 1...y + 1 {
            if let m = HolidayData.load(year: year, cacheDirs: [HolidayData.hostCacheDir, ownCacheDir]) {
                marks.merge(m) { $1 }
            }
        }
        return marks
    }

    private func entry(at date: Date, monthOffset: Int = 0) -> CalendarEntry {
        CalendarEntry(date: date, options: DisplayOptions(defaults: settings), marks: loadMarks(around: date),
                      monthOffset: monthOffset)
    }

    func placeholder(in context: Context) -> CalendarEntry { entry(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(entry(at: Date(), monthOffset: WidgetMonthState.offset()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        Task {
            let now = Date()
            let year = Calendar.current.component(.year, from: now)
            // 今年的数据缺失（例如宿主 App 未运行且内置数据不含今年）时，自己下载一次
            let hasYear = loadMarks(around: now).keys.contains { $0.hasPrefix("\(year)-") }
            if !hasYear && HolidayData.cacheAge(year: year, in: ownCacheDir) > 24 * 3600 {
                _ = await HolidayData.fetch(year: year, into: ownCacheDir, timeout: 8)
            }
            // 当前一条（可能翻到了别的月份）；翻页闲置到期时回到本月；明天零点再一条
            let cal = Calendar.current
            let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
            var entries = [entry(at: now, monthOffset: WidgetMonthState.offset(now: now))]
            if let expiry = WidgetMonthState.expiry(now: now), expiry < midnight {
                entries.append(entry(at: expiry))
            }
            entries.append(entry(at: midnight))
            completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
        }
    }
}

struct CalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarEntry

    var body: some View {
        CalendarWidgetContent(size: size, today: entry.date, options: entry.options, marks: entry.marks,
                              monthOffset: entry.monthOffset)
            .containerBackground(.background, for: .widget)
    }

    private var size: WidgetSize {
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemExtraLarge: return .extraLarge
        default: return .large
        }
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalendarWidget", provider: Provider()) { entry in
            CalendarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("日历")
        .description("月历、农历、节假日（休/班）与周数。设置在菜单栏的日历图标中修改。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct CalendarWidgetBundle: WidgetBundle {
    var body: some Widget { CalendarWidget() }
}
