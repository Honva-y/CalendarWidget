import Foundation

struct DayCell: Identifiable {
    let date: Date
    let day: Int
    let inMonth: Bool
    let isToday: Bool
    let isWeekend: Bool
    let subtitle: String
    let subtitleKind: SubtitleKind
    let holiday: HolidayMark?
    let tooltip: String
    var id: Date { date }
}

struct WeekRow: Identifiable {
    let weekNumber: Int
    let days: [DayCell]
    var id: Date { days[0].date }
}

struct MonthGrid {
    let year: Int
    let month: Int
    let weekdays: [Int]       // 表头的 weekday（1=周日…7=周六），按开始日排列
    let rows: [WeekRow]       // 固定 6 行，保证尺寸稳定
}

/// 当前显示的月份和"今天"，供界面与菜单共享
@MainActor
final class ViewState: ObservableObject {
    static let shared = ViewState()

    @Published var year: Int
    @Published var month: Int
    @Published private(set) var today = Date()

    private init() {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        year = c.year!
        month = c.month!
    }

    func shift(months: Int) {
        var total = year * 12 + (month - 1) + months
        total = max(1901 * 12, min(2099 * 12 + 11, total))
        year = total / 12
        month = total % 12 + 1
    }

    func goToday() {
        refreshToday()
        let c = Calendar.current.dateComponents([.year, .month], from: today)
        year = c.year!
        month = c.month!
    }

    /// 跨天时调用；若正在看"今天所在的月"，则自动跟随到新月份
    func refreshToday() {
        let old = Calendar.current.dateComponents([.year, .month], from: today)
        today = Date()
        let new = Calendar.current.dateComponents([.year, .month], from: today)
        if old != new && old.year == year && old.month == month {
            year = new.year!
            month = new.month!
        }
    }
}

enum CalendarModel {
    static func calendar(firstWeekday: Int, rule: WeekRule) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = .current
        c.firstWeekday = firstWeekday
        c.minimumDaysInFirstWeek = rule.minimumDaysInFirstWeek
        return c
    }

    @MainActor
    static func grid(year: Int, month: Int, today: Date, calendar cal: Calendar, holidays: HolidayStore) -> MonthGrid {
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first)!

        var rows: [WeekRow] = []
        for r in 0..<6 {
            var days: [DayCell] = []
            for i in 0..<7 {
                let date = cal.date(byAdding: .day, value: r * 7 + i, to: start)!
                days.append(cell(for: date, month: month, today: today, calendar: cal, holidays: holidays))
            }
            rows.append(WeekRow(weekNumber: cal.component(.weekOfYear, from: days[0].date), days: days))
        }
        let weekdays = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        return MonthGrid(year: year, month: month, weekdays: weekdays, rows: rows)
    }

    @MainActor
    private static func cell(for date: Date, month: Int, today: Date, calendar cal: Calendar, holidays: HolidayStore) -> DayCell {
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let sub = Lunar.subtitle(for: date, calendar: cal)
        let mark = holidays.mark(year: c.year!, month: c.month!, day: c.day!)

        let ld = Lunar.date(for: date)
        var tip = "\(c.year!)年\(c.month!)月\(c.day!)日 星期\(weekdayNames[c.weekday! - 1])\n"
        tip += "农历\(Lunar.monthName(ld.month, leap: ld.isLeap))\(Lunar.dayName(ld.day))"
        tip += " · 第\(cal.component(.weekOfYear, from: date))周"
        let fests = Lunar.allFestivals(for: date, calendar: cal)
        if !fests.isEmpty { tip += "\n" + fests.joined(separator: " · ") }
        if let mark { tip += "\n\(mark.name) · \(mark.isOffDay ? "放假" : "调休上班")" }

        return DayCell(
            date: date,
            day: c.day!,
            inMonth: c.month == month,
            isToday: cal.isDate(date, inSameDayAs: today),
            isWeekend: cal.isDateInWeekend(date),
            subtitle: sub.text,
            subtitleKind: sub.kind,
            holiday: mark,
            tooltip: tip
        )
    }

    /// 今天的统计：第几周、第几天、全年天数
    static func todayStats(_ today: Date, calendar cal: Calendar) -> (week: Int, dayOfYear: Int, daysInYear: Int) {
        let week = cal.component(.weekOfYear, from: today)
        let doy = cal.ordinality(of: .day, in: .year, for: today) ?? 1
        let days = cal.range(of: .day, in: .year, for: today)?.count ?? 365
        return (week, doy, days)
    }
}
