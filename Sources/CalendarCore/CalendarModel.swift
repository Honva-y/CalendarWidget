import Foundation

public struct DayCell: Identifiable {
    public let date: Date
    public let day: Int
    public let inMonth: Bool
    public let isToday: Bool
    public let isWeekend: Bool
    public let subtitle: String
    public let subtitleKind: SubtitleKind
    public let holiday: HolidayMark?
    public let tooltip: String?   // 鼠标悬停提示；小组件里不需要，为 nil
    public var id: Date { date }
}

public struct WeekRow: Identifiable {
    public let weekNumber: Int
    public let days: [DayCell]
    public var id: Date { days[0].date }
}

public struct MonthGrid {
    public let year: Int
    public let month: Int
    public let weekdays: [Int]       // 表头的 weekday（1=周日…7=周六），按开始日排列
    public let rows: [WeekRow]       // 固定 6 行，保证尺寸稳定
}

public enum CalendarModel {
    public static func calendar(firstWeekday: Int, rule: WeekRule) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = .current
        c.firstWeekday = firstWeekday
        c.minimumDaysInFirstWeek = rule.minimumDaysInFirstWeek
        return c
    }

    public static func grid(year: Int, month: Int, today: Date, calendar cal: Calendar, holidays: HolidayMarks,
                            tooltips: Bool = true) -> MonthGrid {
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let offset = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first)!

        var rows: [WeekRow] = []
        for r in 0..<6 {
            var days: [DayCell] = []
            for i in 0..<7 {
                let date = cal.date(byAdding: .day, value: r * 7 + i, to: start)!
                days.append(cell(for: date, month: month, today: today, calendar: cal, holidays: holidays, tooltip: tooltips))
            }
            rows.append(WeekRow(weekNumber: cal.component(.weekOfYear, from: days[0].date), days: days))
        }
        let weekdays = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        return MonthGrid(year: year, month: month, weekdays: weekdays, rows: rows)
    }

    private static func cell(for date: Date, month: Int, today: Date, calendar cal: Calendar, holidays: HolidayMarks,
                             tooltip: Bool) -> DayCell {
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let sub = Lunar.subtitle(for: date, calendar: cal)
        let mark = holidays[HolidayData.key(year: c.year!, month: c.month!, day: c.day!)]

        var tip: String?
        if tooltip {
            let ld = Lunar.date(for: date)
            var t = "\(c.year!)年\(c.month!)月\(c.day!)日 星期\(weekdayNames[c.weekday! - 1])\n"
            t += "农历\(Lunar.monthName(ld.month, leap: ld.isLeap))\(Lunar.dayName(ld.day))"
            t += " · 第\(cal.component(.weekOfYear, from: date))周"
            let fests = Lunar.allFestivals(for: date, calendar: cal)
            if !fests.isEmpty { t += "\n" + fests.joined(separator: " · ") }
            if let mark { t += "\n\(mark.name) · \(mark.isOffDay ? "放假" : "调休上班")" }
            tip = t
        }

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
    public static func todayStats(_ today: Date, calendar cal: Calendar) -> (week: Int, dayOfYear: Int, daysInYear: Int) {
        let week = cal.component(.weekOfYear, from: today)
        let doy = cal.ordinality(of: .day, in: .year, for: today) ?? 1
        let days = cal.range(of: .day, in: .year, for: today)?.count ?? 365
        return (week, doy, days)
    }
}
