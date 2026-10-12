import AppKit
import SwiftUI

Keys.registerDefaults()

// 调试用：CalendarWidget --snapshot out.png [宽x高] [yyyy-MM] [dark]，把界面渲染成图片
let args = CommandLine.arguments
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
