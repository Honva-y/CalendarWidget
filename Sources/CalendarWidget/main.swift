import AppKit
import CalendarCore
import SwiftUI

Keys.registerDefaults()

// 调试用：CalendarWidget --snapshot out.png [宽x高] [yyyy-MM] [dark]，把界面渲染成图片
let args = CommandLine.arguments

// 调试用：CalendarWidget --widget small|medium|large|extraLarge out.png [dark]，渲染小组件的样子
if let i = args.firstIndex(of: "--widget"), i + 2 < args.count, let size = WidgetSize(rawValue: args[i + 1]) {
    MainActor.assumeIsolated {
        let frames: [WidgetSize: CGSize] = [.small: CGSize(width: 170, height: 170), .medium: CGSize(width: 364, height: 170),
                                            .large: CGSize(width: 364, height: 382), .extraLarge: CGSize(width: 766, height: 382)]
        let y = Calendar.current.component(.year, from: Date())
        var marks = HolidayMarks()
        for yy in y - 1...y + 1 { marks.merge(HolidayData.load(year: yy, cacheDirs: [HolidayData.hostCacheDir]) ?? [:]) { $1 } }
        let dark = args.contains("dark")
        let view = CalendarWidgetContent(size: size, today: Date(), options: DisplayOptions(defaults: .standard), marks: marks)
            .padding(14)
            .frame(width: frames[size]!.width, height: frames[size]!.height)
            .background(dark ? Color(white: 0.12) : .white, in: RoundedRectangle(cornerRadius: 22))
            .padding(10)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { exit(1) }
        try! png.write(to: URL(fileURLWithPath: args[i + 2]))
    }
    exit(0)
}
if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
    MainActor.assumeIsolated {
        let out = URL(fileURLWithPath: args[i + 1])
        var size = CGSize(width: 340, height: 320)
        if i + 2 < args.count {
            let p = args[i + 2].split(separator: "x").compactMap { Double($0) }
            if p.count == 2 { size = CGSize(width: p[0], height: p[1]) }
        }
        if i + 3 < args.count {
            let p = args[i + 3].split(separator: "-").compactMap { Int($0) }
            if p.count == 2 { ViewState.shared.year = p[0]; ViewState.shared.month = p[1] }
        }
        let y = ViewState.shared.year
        for yy in y - 1...y + 1 { HolidayStore.shared.ensure(year: yy) }
        let dark = args.contains("dark")
        let view = CalendarView()
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { exit(1) }
        try! png.write(to: out)
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
