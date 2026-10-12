import SwiftUI

public enum WidgetSize: String, CaseIterable {
    case small, medium, large, extraLarge
}

/// 通知中心/桌面小组件的内容（按尺寸选择布局）
public struct CalendarWidgetContent: View {
    let size: WidgetSize
    let today: Date
    let options: DisplayOptions
    let marks: HolidayMarks

    public init(size: WidgetSize, today: Date, options: DisplayOptions, marks: HolidayMarks) {
        self.size = size
        self.today = today
        self.options = options
        self.marks = marks
    }

    public var body: some View {
        let cal = options.calendar
        let c = cal.dateComponents([.year, .month], from: today)
        let grid = CalendarModel.grid(year: c.year!, month: c.month!, today: today, calendar: cal, holidays: marks)

        switch size {
        case .small:
            VStack(spacing: 2) {
                compactTitle(grid: grid, cal: cal)
                MonthGridView(grid: grid, showWeekNumbers: false, showLunar: false, showHolidays: options.showHolidays)
            }
        case .medium:
            HStack(spacing: 12) {
                TodayPanel(today: today, calendar: cal, marks: marks, showHolidays: options.showHolidays, compact: true)
                    .frame(width: 112)
                VStack(spacing: 2) {
                    compactTitle(grid: grid, cal: cal, showWeek: false)
                    MonthGridView(grid: grid, showWeekNumbers: options.showWeekNumbers, showLunar: false,
                                  showHolidays: options.showHolidays)
                }
            }
        case .large:
            VStack(spacing: 2) {
                MonthHeader(year: grid.year, month: grid.month, today: today, calendar: cal, height: 42) { EmptyView() }
                MonthGridView(grid: grid, showWeekNumbers: options.showWeekNumbers, showLunar: options.showLunar,
                              showHolidays: options.showHolidays)
            }
        case .extraLarge:
            HStack(spacing: 18) {
                TodayPanel(today: today, calendar: cal, marks: marks, showHolidays: options.showHolidays, compact: false)
                    .frame(width: 200)
                VStack(spacing: 2) {
                    MonthHeader(year: grid.year, month: grid.month, today: today, calendar: cal, height: 42) { EmptyView() }
                    MonthGridView(grid: grid, showWeekNumbers: options.showWeekNumbers, showLunar: options.showLunar,
                                  showHolidays: options.showHolidays)
                }
            }
        }
    }

    /// 小尺寸用的单行标题："10月" …… "第42周"
    private func compactTitle(grid: MonthGrid, cal: Calendar, showWeek: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(grid.month)月")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(holidayRed)
            Spacer(minLength: 2)
            if showWeek {
                Text("第\(CalendarModel.todayStats(today, calendar: cal).week)周")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                Text(String(grid.year))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 3)
    }
}

/// 左侧的"今天"信息：星期、日期、农历、周数、最近的假期
struct TodayPanel: View {
    let today: Date
    let calendar: Calendar
    let marks: HolidayMarks
    let showHolidays: Bool
    let compact: Bool

    var body: some View {
        let cal = calendar
        let c = cal.dateComponents([.year, .month, .day, .weekday], from: today)
        let ld = Lunar.date(for: today)
        let stats = CalendarModel.todayStats(today, calendar: cal)
        let festivals = Lunar.allFestivals(for: today, calendar: cal)
        let mark = showHolidays ? marks[HolidayData.key(year: c.year!, month: c.month!, day: c.day!)] : nil
        let next = (showHolidays ? HolidayData.nextHoliday(after: today, marks: marks, calendar: cal) : nil)
            ?? Lunar.nextMajorFestival(after: today, calendar: cal)
        let s: CGFloat = compact ? 1 : 1.35

        VStack(alignment: .leading, spacing: 2 * s) {
            Text("星期\(weekdayNames[c.weekday! - 1])")
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundStyle(holidayRed)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(c.day!)")
                    .font(.system(size: 40 * s, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("\(c.month!)月")
                    .font(.system(size: 13 * s, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, -4 * s)
            Text("\(Lunar.monthName(ld.month, leap: ld.isLeap))\(Lunar.dayName(ld.day)) · \(Lunar.yearName(cycleYear: ld.cycleYear))")
                .font(.system(size: 11 * s))
                .foregroundStyle(.secondary)
            if let f = festivals.first ?? mark?.name {
                Text(mark.map { "\(f) · \($0.isOffDay ? "休" : "班")" } ?? f)
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(mark?.isOffDay == false ? Color.secondary : holidayRed)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Text("第\(stats.week)周").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                Text(" · 第\(stats.dayOfYear)天").foregroundStyle(.secondary)
            }
            .font(.system(size: 11 * s))
            if let next {
                Text("距\(next.name)还有 \(next.days) 天")
                    .font(.system(size: 11 * s))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
