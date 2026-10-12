#!/bin/bash
# 构建 日历小组件.app；加 --install 会安装到 ~/Applications 并启动
set -euo pipefail
cd "$(dirname "$0")"

APP="build/日历小组件.app"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CalendarWidget "$APP/Contents/MacOS/CalendarWidget"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CalendarWidget</string>
    <key>CFBundleIdentifier</key><string>local.calendarwidget</string>
    <key>CFBundleName</key><string>日历小组件</string>
    <key>CFBundleDisplayName</key><string>日历小组件</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"
echo "已生成：$APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CalendarWidget || true
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/日历小组件.app"
    cp -R "$APP" "$HOME/Applications/"
    open "$HOME/Applications/日历小组件.app"
    echo "已安装到 ~/Applications 并启动"
fi
