import Foundation

/// 农历、节气与传统节日
public enum Lunar {
    public struct LunarDate {
        public let cycleYear: Int   // 六十甲子中的序号 1…60
        public let month: Int
        public let day: Int
        public let isLeap: Bool
    }

    private static let chinese: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.timeZone = .current
        return c
    }()

    private static let stems = Array("甲乙丙丁戊己庚辛壬癸")
    private static let branches = Array("子丑寅卯辰巳午未申酉戌亥")
    private static let zodiacs = Array("鼠牛虎兔龙蛇马羊猴鸡狗猪")
    private static let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    private static let dayNames: [String] = {
        let digits = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        return (1...30).map { d in
            switch d {
            case 1...10: return "初" + digits[d - 1]
            case 11...19: return "十" + digits[d - 11]
            case 20: return "二十"
            case 21...29: return "廿" + digits[d - 21]
            default: return "三十"
            }
        }
    }()

    public static func date(for date: Date) -> LunarDate {
        let c = chinese.dateComponents([.year, .month, .day], from: date)
        return LunarDate(cycleYear: c.year ?? 1, month: c.month ?? 1, day: c.day ?? 1, isLeap: c.isLeapMonth ?? false)
    }

    public static func dayName(_ d: Int) -> String { dayNames[max(1, min(30, d)) - 1] }

    public static func monthName(_ m: Int, leap: Bool) -> String {
        (leap ? "闰" : "") + monthNames[max(1, min(12, m)) - 1] + "月"
    }

    /// 例如 "丙午马年"
    public static func yearName(cycleYear: Int) -> String {
        let i = cycleYear - 1
        return "\(stems[i % 10])\(branches[i % 12])\(zodiacs[i % 12])年"
    }

    /// 某天显示在格子里的副标题：农历节日 > 公历节日 > 节气 > 农历日（初一显示月份）
    public static func subtitle(for date: Date, calendar: Calendar) -> (text: String, kind: SubtitleKind) {
        let ld = self.date(for: date)
        if let f = lunarFestival(for: date, lunar: ld) { return (f, .festival) }
        if let f = solarFestival(for: date, calendar: calendar) { return (f, .festival) }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        if let t = SolarTerms.term(year: c.year!, month: c.month!, day: c.day!) { return (t, .term) }
        if ld.day == 1 { return (monthName(ld.month, leap: ld.isLeap), .lunarMonth) }
        return (dayName(ld.day), .lunar)
    }

    /// 某天所有的节日（用于悬停提示）
    public static func allFestivals(for date: Date, calendar: Calendar) -> [String] {
        let ld = self.date(for: date)
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return [lunarFestival(for: date, lunar: ld),
                solarFestival(for: date, calendar: calendar),
                SolarTerms.term(year: c.year!, month: c.month!, day: c.day!)].compactMap { $0 }
    }

    /// 今天之后最近的一个法定节日（按公历/农历推算，不依赖放假安排数据）
    public static func nextMajorFestival(after today: Date, calendar cal: Calendar) -> (name: String, date: Date, days: Int)? {
        let majors: Set<String> = ["元旦", "春节", "清明", "劳动节", "端午节", "中秋节", "国庆节"]
        let start = cal.startOfDay(for: today)
        for offset in 1...400 {
            guard let d = cal.date(byAdding: .day, value: offset, to: start) else { break }
            if let name = allFestivals(for: d, calendar: cal).first(where: majors.contains) {
                return (name == "清明" ? "清明节" : name, d, offset)
            }
        }
        return nil
    }

    public static func lunarFestival(for date: Date, lunar ld: LunarDate) -> String? {
        if !ld.isLeap {
            switch (ld.month, ld.day) {
            case (1, 1): return "春节"
            case (1, 15): return "元宵节"
            case (2, 2): return "龙抬头"
            case (5, 5): return "端午节"
            case (7, 7): return "七夕"
            case (7, 15): return "中元节"
            case (8, 15): return "中秋节"
            case (9, 9): return "重阳节"
            case (12, 8): return "腊八节"
            case (12, 23): return "小年"
            default: break
            }
        }
        // 除夕：次日为正月初一（腊月可能只有 29 天）
        if ld.month == 12, ld.day >= 29, let next = chinese.date(byAdding: .day, value: 1, to: date) {
            let n = self.date(for: next)
            if n.month == 1 && n.day == 1 && !n.isLeap { return "除夕" }
        }
        return nil
    }

    public static func solarFestival(for date: Date, calendar: Calendar) -> String? {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let m = c.month!, d = c.day!
        switch (m, d) {
        case (1, 1): return "元旦"
        case (2, 14): return "情人节"
        case (3, 8): return "妇女节"
        case (3, 12): return "植树节"
        case (4, 1): return "愚人节"
        case (5, 1): return "劳动节"
        case (5, 4): return "青年节"
        case (6, 1): return "儿童节"
        case (7, 1): return "建党节"
        case (8, 1): return "建军节"
        case (9, 10): return "教师节"
        case (10, 1): return "国庆节"
        case (12, 24): return "平安夜"
        case (12, 25): return "圣诞节"
        default: break
        }
        // 母亲节：5 月第 2 个周日；父亲节：6 月第 3 个周日
        if c.weekday == 1 {
            let nth = (d - 1) / 7 + 1
            if m == 5 && nth == 2 { return "母亲节" }
            if m == 6 && nth == 3 { return "父亲节" }
        }
        return nil
    }
}

public enum SubtitleKind { case lunar, lunarMonth, term, festival }

/// 二十四节气（寿星通式，适用于 2000–2099 年，含已知修正）
public enum SolarTerms {
    private static let names = ["小寒", "大寒", "立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
                                "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑",
                                "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"]
    private static let c21: [Double] = [5.4055, 20.12, 3.87, 18.73, 5.63, 20.646, 4.81, 20.1,
                                        5.52, 21.04, 5.678, 21.37, 7.108, 22.83, 7.5, 23.13,
                                        7.646, 23.042, 8.318, 23.438, 7.438, 22.36, 7.18, 21.94]
    /// 年份 → [节气索引: 偏移天数]
    private static let corrections: [Int: [Int: Int]] = [
        2002: [14: 1], 2008: [9: 1], 2016: [12: 1], 2019: [0: -1], 2026: [3: -1],
        2082: [1: 1], 2084: [5: 1], 2089: [19: 1, 20: 1],
    ]

    public static func day(year: Int, index: Int) -> Int? {
        guard (2000...2099).contains(year) else { return nil }
        let y = year % 100
        // 1、2 月的四个节气使用 (Y-1)/4 计算闰年数
        let leaps = index < 4 ? (y - 1) / 4 : y / 4
        let d = Int(floor(Double(y) * 0.2422 + c21[index])) - leaps
        return d + (corrections[year]?[index] ?? 0)
    }

    public static func term(year: Int, month: Int, day: Int) -> String? {
        for i in [(month - 1) * 2, (month - 1) * 2 + 1] where self.day(year: year, index: i) == day {
            return names[i]
        }
        return nil
    }
}
