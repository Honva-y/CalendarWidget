# 日历小组件（macOS）

可以放进**通知中心**或**桌面**的月历小组件，同时附带一个可自由缩放的桌面日历窗口。用 SwiftUI 和 WidgetKit 编写，不需要 Xcode。

## 下载安装

到 [Releases](https://github.com/Honva-y/CalendarWidget/releases/latest) 下载 `CalendarWidget-<版本>.dmg`，打开后把「日历小组件」拖进「应用程序」文件夹。支持 macOS 14 及以上，Apple 芯片和 Intel 芯片的 Mac 都能用。

这个 App 没有 Apple 开发者签名，第一次打开会被系统拦截。放行方法任选一种，只需做一次：

- 先双击打开一次，看到提示后点「完成」；再到「系统设置 › 隐私与安全性」，点「日历小组件」旁边的「仍要打开」。
- 或者在终端运行：`xattr -dr com.apple.quarantine /Applications/日历小组件.app`

打开后，在通知中心底部点「编辑小组件」，搜索「日历小组件」添加即可。

## 功能

- 小组件有小、中、大、特大四种尺寸（特大只能放在桌面）：
  - 小：整月日历和周数
  - 中：今天的信息（星期、农历、第几周、距下个假期的天数）和整月日历
  - 大 / 特大：带农历、节气、节日和休/班角标的完整月历
- 小组件标题右侧有翻页按钮（‹ ›），翻到别的月份后可点「今」回到本月；5 分钟没操作会自动回到本月
- 中国法定节假日（休）和调休上班（班）：数据来自 [holiday-cn](https://github.com/NateScarlet/holiday-cn)，自动联网更新，并内置 2025–2026 年数据作为离线兜底
- 农历、二十四节气、传统节日和公历节日
- 每周开始日可选，默认周一
- 显示周数；周数规则可选 ISO 8601（默认）或「1 月 1 日所在周为第 1 周」
- 桌面日历窗口：拖动边缘可任意缩放，用滚轮切换月份；可调窗口层级、外观和不透明度

## 构建与安装

需要 macOS 14 及以上，并安装 Command Line Tools（`xcode-select --install`）。

```bash
./build.sh --install   # 构建，安装到 ~/Applications，注册小组件并启动
./build.sh --dmg       # 构建 Apple 芯片 + Intel 通用版，打包成 build/CalendarWidget-<版本>.dmg
```

发布新版本：修改 `build.sh` 开头的 `APP_VERSION`，运行 `./build.sh --dmg`，再把生成的 dmg 上传到 GitHub Release。

## 添加到通知中心

1. 点击屏幕右上角的日期时间，打开通知中心
2. 滚动到底部，点击「编辑小组件」
3. 搜索或找到「日历小组件」，选择尺寸后拖进通知中心

修改设置：点击菜单栏中的日历图标，小组件会自动同步。没有 Xcode 无法生成小组件自带的「编辑小组件」配置界面，所以设置统一放在菜单栏中。

不需要桌面窗口时，在菜单中取消勾选「显示桌面日历窗口」。菜单栏 App 需要保持运行，用来同步设置和更新节假日数据。

## 没有 Xcode 时的构建要点

这个项目只用 Command Line Tools 构建，以下几件事平时由 Xcode 自动完成，这里需要手动处理：

- 小组件扩展以 `_NSExtensionMain` 作为入口（见 `Package.swift` 的链接参数）。少了它，系统读取小组件列表时扩展会立刻退出，小组件列表里就找不到它。
- 翻页按钮用的 App Intents 元数据由 `tools/make-intents-metadata.py` 生成。在 `MonthIntents.swift` 里增删或改名意图后，要同步修改这个脚本。
- 应用图标由 `tools/make-icon.swift` 绘制，`tools/make-icns.sh` 打包成 `Resources/AppIcon.icns`。
- 项目目录移动后，先删除 `.build` 再构建，否则会报模块缓存路径不一致。
