import SwiftUI

public let holidayRed = Color(nsColor: .systemRed)
private let workGray = Color(nsColor: .systemGray)
private let termGreen = Color(nsColor: .systemTeal)

public func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }

// MARK: - 标题

/// "10月 2026" + "丙午马年 · 今天 第42周 · 第285/365天"，右侧可放自定义内容（如翻页按钮）
public struct MonthHeader<Trailing: View>: View {
    let year: Int
    let month: Int
    let today: Date
    let calendar: Calendar
    let height: CGFloat
    let trailing: Trailing

    public init(year: Int, month: Int, today: Date, calendar: Calendar, height: CGFloat,
                @ViewBuilder trailing: () -> Trailing) {
        self.year = year
        self.month = month
        self.today = today
        self.calendar = calendar
        self.height = height
        self.trailing = trailing()
    }

    public var body: some View {
        let stats = CalendarModel.todayStats(today, calendar: calendar)
        let mid = calendar.date(from: DateComponents(year: year, month: month, day: 15))!
        let lunarYear = Lunar.yearName(cycleYear: Lunar.date(for: mid).cycleYear)
        let twoLines = height >= 40
        let titleSize = clamp(height * (twoLines ? 0.46 : 0.62), 12, 34)
        let infoSize = clamp(height * 0.21, 9, 15)

        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(month)月")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    Text(String(year))
                        .font(.system(size: titleSize * 0.62, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    if !twoLines {
                        Text("第\(stats.week)周")
                            .font(.system(size: titleSize * 0.62, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .lineLimit(1)
                if twoLines {
                    HStack(spacing: 0) {
                        Text("\(lunarYear) · 今天 ")
                        Text("第\(stats.week)周").foregroundStyle(Color.accentColor).fontWeight(.semibold)
                        Text(" · 第\(stats.dayOfYear)/\(stats.daysInYear)天")
                    }
                    .font(.system(size: infoSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }
            .help("\(lunarYear)\n今天是第 \(stats.week) 周，第 \(stats.dayOfYear) 天，还剩 \(stats.daysInYear - stats.dayOfYear) 天")

            Spacer(minLength: 4)
            trailing
        }
        .frame(height: height)
    }
}

// MARK: - 月历网格

/// 星期表头 + 6 行日期，按自身尺寸自动决定是否显示农历、休/班角标
public struct MonthGridView: View {
    let grid: MonthGrid
    let showWeekNumbers: Bool
    let showLunar: Bool
    let showHolidays: Bool

    public init(grid: MonthGrid, showWeekNumbers: Bool, showLunar: Bool, showHolidays: Bool) {
        self.grid = grid
        self.showWeekNumbers = showWeekNumbers
        self.showLunar = showLunar
        self.showHolidays = showHolidays
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let weekdayH = clamp(h * 0.085, 11, 30)
            let cellH = (h - weekdayH) / 6
            let weekColW = showWeekNumbers ? clamp(w * 0.075, 13, 38) : 0
            let cellW = (w - weekColW) / 7

            VStack(spacing: 0) {
                weekdayRow(height: weekdayH, cellW: cellW, weekColW: weekColW)
                ForEach(grid.rows) { row in
                    HStack(spacing: 0) {
                        if showWeekNumbers {
                            weekNumber(row, width: weekColW, height: cellH)
                        }
                        ForEach(row.days) { day in
                            DayCellView(cell: day, width: cellW, height: cellH,
                                        showLunar: showLunar, showHolidays: showHolidays)
                        }
                    }
                }
            }
        }
    }

    private func weekdayRow(height: CGFloat, cellW: CGFloat, weekColW: CGFloat) -> some View {
        let size = clamp(height * 0.62, 8, 15)
        return HStack(spacing: 0) {
            if showWeekNumbers {
                Text("周").frame(width: weekColW).foregroundStyle(.tertiary)
            }
            ForEach(grid.weekdays, id: \.self) { wd in
                Text(weekdayNames[wd - 1])
                    .frame(width: cellW)
                    .foregroundStyle(wd == 1 || wd == 7 ? AnyShapeStyle(holidayRed.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
        }
        .font(.system(size: size, weight: .medium))
        .frame(height: height)
    }

    private func weekNumber(_ row: WeekRow, width: CGFloat, height: CGFloat) -> some View {
        let isCurrent = row.days.contains { $0.isToday }
        return Text("\(row.weekNumber)")
            .font(.system(size: clamp(min(width * 0.55, height * 0.32), 7, 14), weight: isCurrent ? .bold : .regular, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .foregroundStyle(isCurrent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
            .frame(width: width, height: height)
            .help("第 \(row.weekNumber) 周")
    }
}

// MARK: - 日期格子

struct DayCellView: View {
    let cell: DayCell
    let width: CGFloat
    let height: CGFloat
    let showLunar: Bool
    let showHolidays: Bool

    var body: some View {
        let unit = min(width, height)
        let gap = clamp(unit * 0.05, 0.5, 4)
        let showSub = showLunar && height >= 30 && width >= 26
        let showBadge = unit >= 26
        let dayFont = clamp(min(height * (showSub ? 0.36 : 0.5), width * 0.46), 8, 40)
        let subFont = clamp(dayFont * 0.46, 7, 17)
        let mark = showHolidays ? cell.holiday : nil

        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: unit * 0.22, style: .continuous)
                .fill(background(mark))
            VStack(spacing: 0) {
                Text("\(cell.day)")
                    .font(.system(size: dayFont, weight: cell.isToday ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dayColor(mark))
                if showSub {
                    Text(cell.subtitle)
                        .font(.system(size: subFont, weight: cell.subtitleKind == .lunar ? .regular : .medium))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let mark, showBadge {
                let badge = clamp(unit * 0.22, 7, 13)
                Text(mark.isOffDay ? "休" : "班")
                    .font(.system(size: badge, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, badge * 0.18)
                    .padding(.vertical, badge * 0.05)
                    .background(RoundedRectangle(cornerRadius: badge * 0.3).fill(mark.isOffDay ? holidayRed : workGray))
                    .offset(x: gap * 0.5, y: -gap * 0.5)
            }
        }
        .padding(gap)
        .frame(width: width, height: height)
        .opacity(cell.inMonth ? 1 : 0.32)
        .contentShape(Rectangle())
        .help(cell.tooltip)
    }

    private func background(_ mark: HolidayMark?) -> Color {
        if cell.isToday { return .accentColor }
        guard let mark else { return .clear }
        return mark.isOffDay ? holidayRed.opacity(0.14) : workGray.opacity(0.18)
    }

    private func dayColor(_ mark: HolidayMark?) -> Color {
        if cell.isToday { return .white }
        if let mark { return mark.isOffDay ? holidayRed : .primary }
        return cell.isWeekend ? holidayRed.opacity(0.85) : .primary
    }

    private var subtitleColor: Color {
        if cell.isToday { return .white.opacity(0.9) }
        switch cell.subtitleKind {
        case .festival: return holidayRed
        case .term: return termGreen
        case .lunarMonth: return .primary.opacity(0.75)
        case .lunar: return .secondary
        }
    }
}
