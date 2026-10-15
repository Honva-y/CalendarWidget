// 生成 App 图标：swift tools/make-icon.swift 输出.png
import AppKit
import SwiftUI

private let red = Color(red: 1.0, green: 0.27, blue: 0.23)
private let redDeep = Color(red: 0.88, green: 0.16, blue: 0.14)
private let blue = Color(red: 0.04, green: 0.52, blue: 1.0)
private let cellGray = Color(red: 0.91, green: 0.91, blue: 0.93)
private let weekendTint = Color(red: 1.0, green: 0.88, blue: 0.86)
private let holidayFill = Color(red: 1.0, green: 0.42, blue: 0.37)

struct Icon: View {
    // 1024 画布，主体 824×824（与系统图标规范一致）
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack {
            ZStack(alignment: .top) {
                LinearGradient(colors: [.white, Color(white: 0.95)], startPoint: .top, endPoint: .bottom)
                header
                grid.padding(.top, 312)
            }
            .frame(width: 824, height: 824)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 2))
            .compositingGroup()
            .shadow(color: .black.opacity(0.28), radius: 14, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }

    private var header: some View {
        ZStack {
            LinearGradient(colors: [red, redDeep], startPoint: .top, endPoint: .bottom)
            HStack(spacing: 34) {
                Text("农历")
                    .font(.system(size: 132, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "moon.fill")
                    .font(.system(size: 104, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .rotationEffect(.degrees(-18))
            }
            .offset(y: 4)
        }
        .frame(height: 248)
    }

    private var grid: some View {
        let cell: CGFloat = 76, gap: CGFloat = 20
        return VStack(spacing: gap) {
            ForEach(0..<5, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { c in
                        cellView(r, c, size: cell)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ r: Int, _ c: Int, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        if r == 0 && c >= 3 {
            // 连休
            shape.fill(holidayFill).frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    if c == 6 {
                        Text("休")
                            .font(.system(size: 78, weight: .black))
                            .foregroundStyle(.white)
                            .fixedSize()
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(redDeep))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 7))
                            .fixedSize()
                            .offset(x: 40, y: -50)
                    }
                }
                .zIndex(c == 6 ? 1 : 0)
        } else if r == 2 && c == 0 {
            // 今天
            shape.fill(blue).frame(width: size, height: size)
                .shadow(color: blue.opacity(0.45), radius: 8, y: 4)
        } else {
            shape.fill(c >= 5 ? weekendTint : cellGray).frame(width: size, height: size)
        }
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "icon.png")
MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Icon().environment(\.colorScheme, .light))
    renderer.scale = 1
    guard let cg = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { exit(1) }
    try! png.write(to: out)
}
