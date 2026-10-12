// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CalendarWidget",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CalendarWidget", path: "Sources/CalendarWidget")
    ]
)
