import SwiftUI
import UIKit

/// The Mac app's tokens, sized for touch: slate surfaces, warm amber accent,
/// a light and a dark value for every colour.
enum Palette {
    static let background = Color(light: 0xF8FAFC, dark: 0x0F172A)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1E293B)
    static let surfaceMuted = Color(light: 0xF1F5F9, dark: 0x272F42)
    static let border = Color(light: 0xE2E8F0, dark: 0x334155)
    static let textPrimary = Color(light: 0x0F172A, dark: 0xF8FAFC)
    static let textSecondary = Color(light: 0x475569, dark: 0x94A3B8)
    static let accent = Color(light: 0xB45309, dark: 0xF59E0B)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0F172A)
    static let success = Color(light: 0x15803D, dark: 0x22C55E)
    static let danger = Color(light: 0xB91C1C, dark: 0xF87171)

    /// The same colours the lamp goes through, red dawn to daylight.
    static let sunrise = LinearGradient(
        colors: [Color(hex: 0xFF1E00), Color(hex: 0xFF4500), Color(hex: 0xFF8C00), Color(hex: 0xFFD8A0), Color(hex: 0xFFF6E5)],
        startPoint: .leading, endPoint: .trailing
    )
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum Radius {
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
}

enum Typography {
    static let wakeTime = Font.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit()
    static let title = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.footnote, design: .rounded)
    static let label = Font.system(.callout, design: .rounded).weight(.medium)
}

enum Motion {
    static let standard = Animation.easeOut(duration: 0.2)
}

enum Layout {
    static let touchTarget: CGFloat = 44
    static let actionHeight: CGFloat = 56
    static let timelineHeight: CGFloat = 8
    static let statusDot: CGFloat = 8
    static let stepBadge: CGFloat = 24
    static let maxContentWidth: CGFloat = 560
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

/// A rounded card on the page background.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.border))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// The one filled button on the page.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.label)
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: Layout.touchTarget + 6)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.md))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

/// A tile for the lamp controls: icon over a label.
struct TileButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.label)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Layout.actionHeight)
            .background(configuration.isPressed ? Palette.border : Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radius.md))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}
