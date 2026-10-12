// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CalendarWidget",
    platforms: [.macOS(.v14)],
    targets: [
        // App 与小组件共用的日历逻辑和视图
        .target(
            name: "CalendarCore",
            swiftSettings: [.unsafeFlags(["-application-extension"])]
        ),
        // 菜单栏 + 桌面窗口 App（小组件的宿主）
        .executableTarget(name: "CalendarWidget", dependencies: ["CalendarCore"]),
        // 通知中心 / 桌面小组件扩展
        .executableTarget(
            name: "CalendarWidgetExtension",
            dependencies: ["CalendarCore"],
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-application_extension", "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain", "-Xlinker", "-exported_symbol", "-Xlinker", "_main"])]
        ),
    ]
)
