import SunriseCore
import SwiftUI
import UIKit

/// Warm palette. Dark is the bedroom at night; light is the same warmth by
/// day. Every colour follows the system appearance.
enum Palette {
    static let background = Color(light: 0xF7F3EE, dark: 0x0D0A08)
    static let sheet = Color(light: 0xFBF8F4, dark: 0x16120F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1512)
    static let surfaceRaised = Color(light: 0xEFE8E0, dark: 0x241E1A)
    static let border = Color(light: 0xE8E0D6, dark: 0x2A231E)
    static let textPrimary = Color(light: 0x1F1A15, dark: 0xF5EFE8)
    static let textSecondary = Color(light: 0x6E655C, dark: 0xA39B92)
    static let textTertiary = Color(light: 0xADA49A, dark: 0x5A524B)
    static let accent = Color(light: 0xE08600, dark: 0xF59E0B)
    static let onAccent = Color(hex: 0x1A1206)
    static let success = Color(light: 0x16A34A, dark: 0x22C55E)
    static let danger = Color(light: 0xDC2626, dark: 0xF87171)
    static let shortcuts = Color(hex: 0x5856D6)

    static let reminderFill = Color(light: 0xFFF3DF, dark: 0x2A1E10)
    static let reminderBorder = Color(light: 0xF1CF95, dark: 0x5C3D12)
    static let reminderBody = Color(light: 0x7A5626, dark: 0xD6C3A5)

    static let dawnRed = Color(hex: 0xFF1E00)
    static let dawnOrange = Color(hex: 0xFF4500)
    static let dawnAmber = Color(hex: 0xFF932C)

    static func kelvin(_ kelvin: Int) -> Color { Color(rgb: LightSetting.rgb(forKelvin: kelvin)) }

    /// The same colours the lamp goes through, red dawn to the chosen white.
    static func sunrise(endKelvin: Int) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: dawnRed, location: 0),
                .init(color: dawnOrange, location: 0.22),
                .init(color: Color(hex: 0xFF8C00), location: 0.44),
                .init(color: dawnAmber, location: 0.64),
                .init(color: kelvin(endKelvin), location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    /// A sun with a hot white core fading to dawn red at the rim.
    static func sun(endKelvin: Int) -> RadialGradient {
        RadialGradient(
            stops: [
                .init(color: kelvin(endKelvin), location: 0),
                .init(color: dawnAmber, location: 0.38),
                .init(color: dawnOrange, location: 0.7),
                .init(color: dawnRed, location: 1),
            ],
            center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 130
        )
    }

    /// A glowing bulb of the given colour.
    static func orb(_ color: Color) -> RadialGradient {
        RadialGradient(
            stops: [.init(color: .white, location: 0), .init(color: color, location: 0.5), .init(color: color.opacity(0.8), location: 1)],
            center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 100
        )
    }
}

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
}

enum Typography {
    static let heroValue = Font.system(.largeTitle, design: .rounded).weight(.light).monospacedDigit()
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let headline = Font.system(.headline, design: .rounded)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let label = Font.system(.subheadline, design: .rounded).weight(.medium)
    static let caption = Font.system(.footnote, design: .rounded)
    static let small = Font.system(.caption, design: .rounded)
}

enum Motion {
    static let standard = Animation.easeOut(duration: 0.2)
    static let layout = Animation.spring(duration: 0.35, bounce: 0.15)
}

enum Layout {
    static let touchTarget: CGFloat = 44
    static let actionHeight: CGFloat = 56
    static let strip: CGFloat = 6
    static let statusDot: CGFloat = 8
    static let iconTile: CGFloat = 32
    static let maxContentWidth: CGFloat = 560
    static let heroHeight: CGFloat = 230
    static let heroCompactHeight: CGFloat = 150
    static let sun: CGFloat = 220
    static let sunGlowWidth: CGFloat = 760
    /// Tall enough that half of it reaches the top of the screen.
    static let sunGlowHeight: CGFloat = 1200
    static let lightOrb: CGFloat = 184
    static let previewOrb: CGFloat = 112
    static let tone: CGFloat = 44
    static let endSwatch: CGFloat = 52
    static let sceneHeight: CGFloat = 64
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A colour that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    init(rgb: Int) {
        self.init(hex: UInt32(truncatingIfNeeded: rgb))
    }

    /// 0xRRGGBB in sRGB, or nil if the colour cannot be read.
    var rgbValue: Int? {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func byte(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}

/// The one filled button on a screen. `muted` keeps it usable but lets
/// something more urgent take the eye.
struct PrimaryButtonStyle: ButtonStyle {
    var muted = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(muted ? Palette.textPrimary : Palette.onAccent)
            .frame(maxWidth: .infinity, minHeight: Layout.actionHeight)
            .background(muted ? Palette.surfaceRaised : Palette.accent, in: RoundedRectangle(cornerRadius: Radius.lg))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

/// A compact button for inside cards.
struct CompactButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout.weight(prominent ? .semibold : .medium))
            .foregroundStyle(prominent ? Palette.onAccent : Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Layout.touchTarget)
            .background(prominent ? Palette.accent : Palette.textPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.md))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

/// Presses a tappable card down slightly.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.standard, value: configuration.isPressed)
    }
}

/// A rounded icon tile, the way Settings shows app icons.
struct IconTile: View {
    let systemName: String
    let background: Color
    var foreground: Color = Palette.onAccent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(.callout).weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: Layout.iconTile, height: Layout.iconTile)
            .background(background, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityHidden(true)
    }
}
