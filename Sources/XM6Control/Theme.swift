import AppKit
import CoreText
import SwiftUI

enum Theme {
    static let accent = Color(hex: 0x5865F2)
    static let accentForeground = Color(hex: 0xFCFCFC)
    static let background = dynamic(light: 0xF3F5FC, dark: 0x050609)
    static let border = dynamic(light: 0xDCDEE5, dark: 0x27292E)
    static let danger = dynamic(light: 0xDA373C, dark: 0xED4245)
    static let `default` = dynamic(light: 0xE9EBF2, dark: 0x26272C)
    static let defaultForeground = dynamic(light: 0x17181B, dark: 0xFCFCFC)
    static let field = dynamic(light: 0xFEFFFF, dark: 0x151822)
    static let foreground = dynamic(light: 0x17181D, dark: 0xFAFCFF)
    static let muted = dynamic(light: 0x6E717E, dark: 0x9C9FAD)
    static let segment = dynamic(light: 0xFDFFFF, dark: 0x45464C)
    static let separator = dynamic(light: 0xE2E4EB, dark: 0x202127)
    static let success = dynamic(light: 0x248046, dark: 0x57F287)
    static let surface = dynamic(light: 0xFEFFFF, dark: 0x151822)
    static let surfaceSecondary = dynamic(light: 0xEDEFF5, dark: 0x21232B)
    static let warning = Color(hex: 0xFEE75C)
    static let warningForeground = Color(hex: 0x100B00)

    static let radius: CGFloat = 4
    static let cardRadius = radius * 2
    static let controlRadius = radius * 1.5
    static let fieldRadius: CGFloat = 12

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Inter", size: size).weight(weight)
    }

    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "InterVariable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(12, .medium))
            .foregroundStyle(Theme.accentForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).fill(Theme.accent))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(11, .medium))
            .foregroundStyle(Theme.defaultForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).fill(Theme.default))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
