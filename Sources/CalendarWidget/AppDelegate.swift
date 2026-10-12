import AppKit
import CalendarCore
import ServiceManagement
import SwiftUI
import WidgetKit

/// 右键时弹出与菜单栏相同的设置菜单
private final class WidgetHostingView: NSHostingView<CalendarView> {
    var menuProvider: (() -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: NSWindow!
    private var effectView: NSVisualEffectView!
    private var statusItem: NSStatusItem!
    private var scrollAccum: CGFloat = 0
    private var scrollConsumed = false
    private var widgetReload: DispatchWorkItem?
    private let defaults = UserDefaults.standard

    private static let sizePresets: [(String, NSSize)] = [
        ("小", NSSize(width: 240, height: 230)),
        ("中", NSSize(width: 340, height: 320)),
        ("大", NSSize(width: 460, height: 430)),
        ("特大", NSSize(width: 640, height: 580)),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupStatusItem()
        applySettings()

        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applySettings()
                self?.scheduleWidgetReload()
            }
        }
        // 跨天、唤醒、时区变化时刷新"今天"
        let refresh: @Sendable (Notification) -> Void = { _ in MainActor.assumeIsolated { ViewState.shared.refreshToday() } }
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: refresh)
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main, using: refresh)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh)

        // 在日历上滚动滚轮/触控板切换月份
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.handleScroll(event)
            return nil
        }
    }

    // MARK: - 窗口

    private func setupWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 320),
                          styleMask: [.titled, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(b)?.isHidden = true
        }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentMinSize = NSSize(width: 200, height: 190)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("CalendarWidgetWindow")

        let container = NSView()
        effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active

        let hosting = WidgetHostingView(rootView: CalendarView())
        hosting.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }

        for v in [effectView!, hosting] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                v.topAnchor.constraint(equalTo: container.topAnchor),
                v.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        window.contentView = container
    }

    /// 设置变化后刷新通知中心/桌面小组件（合并短时间内的多次变化）
    private func scheduleWidgetReload() {
        widgetReload?.cancel()
        let work = DispatchWorkItem { WidgetCenter.shared.reloadAllTimelines() }
        widgetReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击小组件或再次打开 App 时：显示桌面日历，若已关闭则弹出设置菜单
        if defaults.bool(forKey: Keys.showDesktopWindow) {
            ViewState.shared.goToday()
            window.orderFrontRegardless()
        } else {
            statusItem.button?.performClick(nil)
        }
        return false
    }

    private func applySettings() {
        let level = WindowLevelOption(rawValue: defaults.string(forKey: Keys.windowLevel) ?? "") ?? .desktop
        switch level {
        case .desktop:
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        case .normal:
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenNone]
        case .floating:
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }

        switch AppearanceOption(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }

        let locked = defaults.bool(forKey: Keys.locked)
        window.isMovable = !locked
        window.isMovableByWindowBackground = !locked
        if locked { window.styleMask.remove(.resizable) } else { window.styleMask.insert(.resizable) }

        effectView.alphaValue = CGFloat(defaults.double(forKey: Keys.opacity))

        let show = defaults.bool(forKey: Keys.showDesktopWindow)
        if show && !window.isVisible { window.orderFrontRegardless() }
        if !show && window.isVisible { window.orderOut(nil) }
    }

    private func handleScroll(_ event: NSEvent) {
        let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? event.scrollingDeltaY : event.scrollingDeltaX
        // 普通鼠标滚轮：每格翻一个月
        guard event.hasPreciseScrollingDeltas else {
            if delta != 0 { ViewState.shared.shift(months: delta > 0 ? -1 : 1) }
            return
        }
        // 触控板：每次手势最多翻一个月，忽略惯性滚动
        if event.phase == .began { scrollAccum = 0; scrollConsumed = false }
        guard event.momentumPhase.isEmpty, !scrollConsumed else { return }
        scrollAccum += delta
        if abs(scrollAccum) >= 30 {
            ViewState.shared.shift(months: scrollAccum > 0 ? -1 : 1)
            scrollConsumed = true
        }
    }

    // MARK: - 菜单栏与设置菜单

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "日历")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for item in buildMenu().items {
            item.menu?.removeItem(item)
            menu.addItem(item)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("回到今天", #selector(goToday)))
        menu.addItem(item("如何添加到通知中心…", #selector(showWidgetHelp)))
        menu.addItem(.separator())

        let fw = defaults.integer(forKey: Keys.firstWeekday)
        let order = [2, 3, 4, 5, 6, 7, 1]
        menu.addItem(submenu("每周开始于", order.map { wd in
            choice("周" + weekdayNames[wd - 1], key: Keys.firstWeekday, value: wd, checked: fw == wd)
        }))
        let rule = defaults.string(forKey: Keys.weekRule)
        menu.addItem(submenu("周数规则", WeekRule.allCases.map {
            choice($0.title, key: Keys.weekRule, value: $0.rawValue, checked: rule == $0.rawValue)
        }))
        menu.addItem(toggle("显示周数", Keys.showWeekNumbers))
        menu.addItem(toggle("显示农历、节气与节日", Keys.showLunar))
        menu.addItem(toggle("显示法定节假日（休/班）", Keys.showHolidays))
        menu.addItem(.separator())

        // 以下只影响桌面日历窗口
        menu.addItem(toggle("显示桌面日历窗口", Keys.showDesktopWindow))
        var windowItems: [NSMenuItem] = []
        let level = defaults.string(forKey: Keys.windowLevel)
        windowItems.append(submenu("窗口层级", WindowLevelOption.allCases.map {
            choice($0.title, key: Keys.windowLevel, value: $0.rawValue, checked: level == $0.rawValue)
        }))
        let appearance = defaults.string(forKey: Keys.appearance)
        windowItems.append(submenu("外观", AppearanceOption.allCases.map {
            choice($0.title, key: Keys.appearance, value: $0.rawValue, checked: appearance == $0.rawValue)
        }))
        let opacity = defaults.double(forKey: Keys.opacity)
        windowItems.append(submenu("背景不透明度", [1.0, 0.8, 0.6, 0.4, 0.0].map { v in
            choice(v == 0 ? "完全透明" : "\(Int(v * 100))%", key: Keys.opacity, value: v, checked: abs(opacity - v) < 0.01)
        }))
        windowItems.append(submenu("尺寸（也可拖动边缘调整）", Self.sizePresets.enumerated().map { i, p -> NSMenuItem in
            let it = item("\(p.0)（\(Int(p.1.width))×\(Int(p.1.height))）", #selector(applySizePreset(_:)))
            it.tag = i
            return it
        }))
        windowItems.append(toggle("锁定位置和大小", Keys.locked))
        menu.addItem(submenu("桌面日历窗口设置", windowItems))
        menu.addItem(.separator())

        menu.addItem(item("更新节假日数据", #selector(refreshHolidays)))
        let login = item("开机自动启动", #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: "")
        it.target = self
        return it
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu()
        items.forEach(sub.addItem)
        it.submenu = sub
        return it
    }

    private func choice(_ title: String, key: String, value: Any, checked: Bool) -> NSMenuItem {
        let it = item(title, #selector(setChoice(_:)))
        it.representedObject = [key: value]
        it.state = checked ? .on : .off
        return it
    }

    private func toggle(_ title: String, _ key: String) -> NSMenuItem {
        let it = item(title, #selector(toggleSetting(_:)))
        it.representedObject = key
        it.state = defaults.bool(forKey: key) ? .on : .off
        return it
    }

    @objc private func setChoice(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String: Any], let (k, v) = pair.first else { return }
        defaults.set(v, forKey: k)
    }

    @objc private func toggleSetting(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(!defaults.bool(forKey: key), forKey: key)
    }

    @objc private func goToday() {
        ViewState.shared.goToday()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @objc private func showWidgetHelp() {
        let alert = NSAlert()
        alert.messageText = "添加到通知中心"
        alert.informativeText = """
        1. 点击屏幕右上角的日期时间，打开通知中心
        2. 滚动到底部，点击「编辑小组件」
        3. 在左侧列表中找到「日历小组件」，选择小、中、大尺寸后拖到通知中心

        想换尺寸：右键点击小组件，选择小、中或大。
        也可以把小组件直接拖到桌面上。
        每周开始日等设置在此菜单中修改，小组件会自动同步。
        """
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func applySizePreset(_ sender: NSMenuItem) {
        let size = Self.sizePresets[sender.tag].1
        var frame = window.frame
        frame.origin.y += frame.height - size.height   // 保持左上角不动
        frame.size = size
        window.setFrame(frame, display: true, animate: true)
    }

    @objc private func refreshHolidays() {
        HolidayStore.shared.refreshAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法设置开机启动"
            alert.informativeText = "\(error.localizedDescription)\n\n请先把应用放到「应用程序」文件夹再试，或在「系统设置 › 通用 › 登录项」中手动添加。"
            alert.runModal()
        }
    }
}
