import SwiftUI

private let holidayRed = Color(nsColor: .systemRed)
private let workGray = Color(nsColor: .systemGray)
private let termGreen = Color(nsColor: .systemTeal)

private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }

struct CalendarView: View {
    @ObservedObject private var state = ViewState.shared
    @ObservedObject private var holidays = HolidayStore.shared

    @AppStorage(Keys.firstWeekday) private var firstWeekday = 2
    @AppStorage(Keys.weekRule) private var weekRuleRaw = WeekRule.iso.rawValue
    @AppStorage(Keys.showWeekNumbers) private var showWeekNumbers = true
    @AppStorage(Keys.showLunar) private var showLunar = true
    @AppStorage(Keys.showHolidays) private var showHolidays = true

    private var cal: Calendar {
        CalendarModel.calendar(firstWeekday: firstWeekday, rule: WeekRule(rawValue: weekRuleRaw) ?? .iso)
    }

    var body: some View {
        GeometryReader { geo in
            let cal = self.cal
            let grid = CalendarModel.grid(year: state.year, month: state.month, today: state.today,
                                          calendar: cal, holidays: holidays)
            let w = geo.size.width, h = geo.size.height
            let pad = clamp(min(w, h) * 0.045, 8, 22)
            let innerW = w - pad * 2, innerH = h - pad * 2
            let headerH = clamp(innerH * 0.14, 26, 72)
            let weekdayH = clamp(innerH * 0.07, 14, 30)
            let cellH = (innerH - headerH - weekdayH) / 6
            let weekColW = showWeekNumbers ? clamp(innerW * 0.075, 16, 38) : 0
            let cellW = (innerW - weekColW) / 7

            VStack(spacing: 0) {
                header(grid: grid, cal: cal, height: headerH)
                weekdayRow(grid: grid, cal: cal, height: weekdayH, cellW: cellW, weekColW: weekColW)
                ForEach(grid.rows) { row in
                    HStack(spacing: 0) {
                        if showWeekNumbers {
                            weekNumber(row, cal: cal, width: weekColW, height: cellH)
                        }
                        ForEach(row.days) { day in
                            DayCellView(cell: day, width: cellW, height: cellH,
                                        showLunar: showLunar, showHolidays: showHolidays)
                        }
                    }
                }
            }
            .padding(pad)
        }
        .onAppear(perform: loadHolidays)
        .onChange(of: state.year) { loadHolidays() }
    }

    private func loadHolidays() {
        // 月历首尾可能露出相邻年份的日期
        for y in state.year - 1...state.year + 1 { holidays.ensure(year: y) }
    }

    // MARK: - 头部

    @ViewBuilder
    private func header(grid: MonthGrid, cal: Calendar, height: CGFloat) -> some View {
        let stats = CalendarModel.todayStats(state.today, calendar: cal)
        let mid = cal.date(from: DateComponents(year: grid.year, month: grid.month, day: 15))!
        let lunarYear = Lunar.yearName(cycleYear: Lunar.date(for: mid).cycleYear)
        let twoLines = height >= 40
        let titleSize = clamp(height * (twoLines ? 0.46 : 0.62), 13, 34)
        let infoSize = clamp(height * 0.21, 9, 15)

        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(grid.month)月")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    Text(String(grid.year))
                        .font(.system(size: titleSize * 0.62, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    if !twoLines {
                        Text("第\(stats.week)周")
                            .font(.system(size: titleSize * 0.55, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
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
            .help("\(lunarYear)\n今天是 \(cal.component(.yearForWeekOfYear, from: state.today)) 年第 \(stats.week) 周，第 \(stats.dayOfYear) 天，还剩 \(stats.daysInYear - stats.dayOfYear) 天")

            Spacer(minLength: 4)
            navButtons(size: clamp(height * 0.28, 10, 18), isCurrentMonth: isCurrentMonth(cal))
        }
        .frame(height: height)
    }

    private func isCurrentMonth(_ cal: Calendar) -> Bool {
        let c = cal.dateComponents([.year, .month], from: state.today)
        return c.year == state.year && c.month == state.month
    }

    private func navButtons(size: CGFloat, isCurrentMonth: Bool) -> some View {
        HStack(spacing: size * 0.5) {
            NavButton(symbol: "chevron.left", size: size, help: "上个月") { state.shift(months: -1) }
            NavButton(symbol: isCurrentMonth ? "circle" : "circle.fill", size: size * 0.7, help: "回到今天") { state.goToday() }
            NavButton(symbol: "chevron.right", size: size, help: "下个月") { state.shift(months: 1) }
        }
    }

    // MARK: - 星期表头与周数

    private func weekdayRow(grid: MonthGrid, cal: Calendar, height: CGFloat, cellW: CGFloat, weekColW: CGFloat) -> some View {
        let size = clamp(height * 0.55, 9, 15)
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

    private func weekNumber(_ row: WeekRow, cal: Calendar, width: CGFloat, height: CGFloat) -> some View {
        let isCurrent = row.days.contains { $0.isToday }
        return Text("\(row.weekNumber)")
            .font(.system(size: clamp(min(width * 0.5, height * 0.3), 8, 14), weight: isCurrent ? .bold : .regular, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isCurrent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
            .frame(width: width, height: height)
            .help("第 \(row.weekNumber) 周")
    }
}

private struct NavButton: View {
    let symbol: String
    let size: CGFloat
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: size * 1.8, height: size * 1.8)
                .background(Circle().fill(Color.primary.opacity(hover ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { hover = $0 }
        .help(help)
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
        let gap = clamp(unit * 0.05, 1, 4)
        let showSub = showLunar && height >= 30 && width >= 26
        let dayFont = clamp(min(height * (showSub ? 0.36 : 0.46), width * 0.44), 9, 40)
        let subFont = clamp(dayFont * 0.46, 7, 17)
        let mark = showHolidays ? cell.holiday : nil

        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: unit * 0.2, style: .continuous)
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

            if let mark {
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
        return mark.isOffDay ? holidayRed.opacity(0.13) : workGray.opacity(0.15)
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
