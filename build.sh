#!/bin/bash
# 构建 日历小组件.app（含通知中心小组件扩展）；加 --install 会安装到 ~/Applications、注册小组件并启动
set -euo pipefail
cd "$(dirname "$0")"

APP="build/日历小组件.app"
APPEX="$APP/Contents/PlugIns/CalendarWidgetExtension.appex"
HOST_ID="local.calendarwidget"
VERSION="$(date +%Y%m%d%H%M%S)"   # 每次构建递增，促使系统重新加载小组件

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS"
[[ -f Resources/AppIcon.icns ]] || ./tools/make-icns.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/CalendarWidget "$APP/Contents/MacOS/CalendarWidget"
cp .build/release/CalendarWidgetExtension "$APPEX/Contents/MacOS/LunarCalendarWidget"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CalendarWidget</string>
    <key>CFBundleIdentifier</key><string>$HOST_ID</string>
    <key>CFBundleName</key><string>日历小组件</string>
    <key>CFBundleDisplayName</key><string>日历小组件</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>LunarCalendarWidget</string>
    <key>CFBundleIdentifier</key><string>$HOST_ID.widget</string>
    <key>CFBundleName</key><string>日历小组件</string>
    <key>CFBundleDisplayName</key><string>日历小组件</string>
    <key>CFBundlePackageType</key><string>XPC!</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST

# 小组件必须在沙盒中运行：允许联网，并只读访问宿主 App 的设置和节假日缓存
ENT="$(mktemp -t widget-entitlements)"
cat > "$ENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.temporary-exception.shared-preference.read-only</key>
    <array><string>$HOST_ID</string></array>
    <key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
    <array><string>/Library/Application Support/CalendarWidget/</string></array>
</dict>
</plist>
PLIST
codesign --force --sign - --entitlements "$ENT" "$APPEX"
codesign --force --sign - "$APP"
rm -f "$ENT"
echo "已生成：$APP"

if [[ "${1:-}" == "--install" ]]; then
    DEST="$HOME/Applications/日历小组件.app"
    pkill -x CalendarWidget || true
    pkill -x LunarCalendarWidget || true
    mkdir -p "$HOME/Applications"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
    pluginkit -a "$DEST/Contents/PlugIns/CalendarWidgetExtension.appex"
    killall chronod 2>/dev/null || true   # 让小组件服务重新读取小组件列表
    open "$DEST"
    echo "已安装到 ~/Applications 并启动"
fi
