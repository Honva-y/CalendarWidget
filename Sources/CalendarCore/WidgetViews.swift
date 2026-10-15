import AppIntents
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
    let monthOffset: Int   // 相对本月翻了几个月
    let direction: Int     // 最近一次翻页方向，决定翻页动画从哪边推入

    public init(size: WidgetSize, today: Date, options: DisplayOptions, marks: HolidayMarks,
                monthOffset: Int = 0, direction: Int = 0) {
        self.size = size
        self.today = today
        self.options = options
        self.marks = marks
        self.monthOffset = monthOffset
        self.direction = direction
    }

    public var body: some View {
        layout
            .background {
                // 接住按钮以外的点击，避免点偏时打开 App、关闭通知中心
                Button(intent: IgnoreTapIntent()) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(NoFeedbackStyle())
            }
    }

    @ViewBuilder
    private var layout: some View {
        let cal = options.calendar
        let shown = WidgetMonthState.month(adding: monthOffset, to: today, calendar: cal)
        let grid = CalendarModel.grid(year: shown.year, month: shown.month, today: today, calendar: cal,
                                      holidays: marks, tooltips: false)

        switch size {
        case .small:
            VStack(spacing: 2) {
                compactTitle(grid: grid, cal: cal)
                pagedGrid(grid, showWeekNumbers: false, showLunar: false)
            }
        case .medium:
            HStack(spacing: 12) {
                TodayPanel(today: today, calendar: cal, marks: marks, showHolidays: options.showHolidays, compact: true)
                    .frame(width: 112)
                VStack(spacing: 2) {
                    compactTitle(grid: grid, cal: cal, showWeek: false)
                    pagedGrid(grid, showWeekNumbers: options.showWeekNumbers, showLunar: false)
                }
            }
        case .large:
            VStack(spacing: 2) {
                header(grid: grid, cal: cal)
                pagedGrid(grid, showWeekNumbers: options.showWeekNumbers, showLunar: options.showLunar)
            }
        case .extraLarge:
            HStack(spacing: 18) {
                TodayPanel(today: today, calendar: cal, marks: marks, showHolidays: options.showHolidays, compact: false)
                    .frame(width: 200)
                VStack(spacing: 2) {
                    header(grid: grid, cal: cal)
                    pagedGrid(grid, showWeekNumbers: options.showWeekNumbers, showLunar: options.showLunar)
                }
            }
        }
    }

    /// 月历网格：换月时从翻页方向推入新月份；点击翻页后、新内容出来前，系统会把它显示为"刷新中"
    private func pagedGrid(_ grid: MonthGrid, showWeekNumbers: Bool, showLunar: Bool) -> some View {
        ZStack {
            MonthGridView(grid: grid, showWeekNumbers: showWeekNumbers, showLunar: showLunar,
                          showHolidays: options.showHolidays, tooltips: false)
                .id(grid.year * 12 + grid.month)
                .transition(.push(from: direction < 0 ? .leading : .trailing))
        }
        .clipped()
        .invalidatableContent()
    }

    private func header(grid: MonthGrid, cal: Calendar) -> some View {
        MonthHeader(year: grid.year, month: grid.month, today: today, calendar: cal, height: 42) {
            MonthNavButtons(size: 15, isCurrentMonth: monthOffset == 0)
        }
    }

    /// 小尺寸用的单行标题："10月 第42周 …… ‹ ›"
    private func compactTitle(grid: MonthGrid, cal: Calendar, showWeek: Bool = true) -> some View {
        let thisYear = cal.component(.year, from: today)
        return HStack(alignment: .center, spacing: 5) {
            Text(grid.year == thisYear ? "\(grid.month)月" : "\(String(grid.year))年\(grid.month)月")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(holidayRed)
                .contentTransition(.numericText(value: Double(grid.year * 12 + grid.month)))
                .invalidatableContent()
            if showWeek {
                Text("第\(CalendarModel.todayStats(today, calendar: cal).week)周")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            } else if grid.year == thisYear {
                Text(String(grid.year))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            MonthNavButtons(size: 11, isCurrentMonth: monthOffset == 0)
        }
        .lineLimit(1)
        .padding(.horizontal, 3)
    }
}

/// 翻页按钮：‹ 上个月、今（不在本月时出现）、› 下个月。点击由小组件扩展执行对应的意图
struct MonthNavButtons: View {
    let size: CGFloat
    let isCurrentMonth: Bool

    var body: some View {
        // 三个按钮位置固定：「今」不在本月时才显示，但始终占位，避免「‹」跟着左右移动导致点空
        HStack(spacing: size * 0.35) {
            Button(intent: PreviousMonthIntent()) { icon("chevron.left") }
            ZStack {
                if !isCurrentMonth {
                    Button(intent: ThisMonthIntent()) {
                        Text("今")
                            .font(.system(size: size * 0.95, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: size * 1.75, height: size * 1.75)
                            .background(Circle().fill(Color.accentColor))
                            .contentShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size * 1.75, height: size * 1.75)
            Button(intent: NextMonthIntent()) { icon("chevron.right") }
        }
        .buttonStyle(PressFeedbackStyle())
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: size * 1.75, height: size * 1.75)
            .background(Circle().fill(Color.primary.opacity(0.07)))
            .contentShape(Circle())
    }
}

/// 不显示任何按下效果（用于铺在底层的空白点击区域）
struct NoFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// 按下时缩小变淡，松开恢复，让人知道点到了
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
