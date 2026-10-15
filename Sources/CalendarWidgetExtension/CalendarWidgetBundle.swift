import CalendarCore
import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let options: DisplayOptions
    let marks: HolidayMarks
    var monthOffset = 0
    var direction = 0
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
            let cal = Calendar.current
            let year = cal.component(.year, from: now)
            var marks = loadMarks(around: now)
            // 今年的数据缺失（例如宿主 App 未运行且内置数据不含今年）时，自己下载一次
            if !marks.keys.contains(where: { $0.hasPrefix("\(year)-") })
                && HolidayData.cacheAge(year: year, in: ownCacheDir) > 24 * 3600,
               await HolidayData.fetch(year: year, into: ownCacheDir, timeout: 8) != nil {
                marks = loadMarks(around: now)
            }
            let options = DisplayOptions(defaults: settings)
            let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
            let current = CalendarEntry(date: now, options: options, marks: marks,
                                        monthOffset: WidgetMonthState.offset(now: now),
                                        direction: WidgetMonthState.direction(now: now))

            if let expiry = WidgetMonthState.expiry(now: now) {
                // 翻页中：只渲染当前这一条，点击翻页时响应更快；到期回到本月（或过零点）时再要新的时间线
                completion(Timeline(entries: [current], policy: .after(min(expiry, midnight))))
            } else {
                // 本月：今天一条、明天零点一条
                let tomorrow = CalendarEntry(date: midnight, options: options, marks: marks)
                completion(Timeline(entries: [current, tomorrow], policy: .after(midnight.addingTimeInterval(60))))
            }
        }
    }
}

struct CalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarEntry

    var body: some View {
        CalendarWidgetContent(size: size, today: entry.date, options: entry.options, marks: entry.marks,
                              monthOffset: entry.monthOffset, direction: entry.direction)
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
