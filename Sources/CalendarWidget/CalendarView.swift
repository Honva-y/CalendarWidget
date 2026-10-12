import CalendarCore
import SwiftUI

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

/// 桌面窗口里的日历：标题 + 翻页按钮 + 月历网格
struct CalendarView: View {
    @ObservedObject private var state = ViewState.shared
    @ObservedObject private var holidays = HolidayStore.shared

    @AppStorage(Keys.firstWeekday) private var firstWeekday = 2
    @AppStorage(Keys.weekRule) private var weekRuleRaw = WeekRule.iso.rawValue
    @AppStorage(Keys.showWeekNumbers) private var showWeekNumbers = true
    @AppStorage(Keys.showLunar) private var showLunar = true
    @AppStorage(Keys.showHolidays) private var showHolidays = true

    var body: some View {
        GeometryReader { geo in
            let cal = CalendarModel.calendar(firstWeekday: firstWeekday, rule: WeekRule(rawValue: weekRuleRaw) ?? .iso)
            let grid = CalendarModel.grid(year: state.year, month: state.month, today: state.today,
                                          calendar: cal, holidays: holidays.marks)
            let pad = clamp(min(geo.size.width, geo.size.height) * 0.045, 8, 22)
            let headerH = clamp((geo.size.height - pad * 2) * 0.14, 26, 72)

            VStack(spacing: 0) {
                MonthHeader(year: state.year, month: state.month, today: state.today, calendar: cal, height: headerH) {
                    navButtons(size: clamp(headerH * 0.28, 10, 18), isCurrentMonth: isCurrentMonth(cal))
                }
                MonthGridView(grid: grid, showWeekNumbers: showWeekNumbers, showLunar: showLunar, showHolidays: showHolidays)
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
