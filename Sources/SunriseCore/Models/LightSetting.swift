import Foundation

/// What the manual light controls set: white at a colour temperature, or a colour.
public struct LightSetting: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case white
        case color
    }

    public var mode: Mode
    public var kelvin: Int
    /// 0xRRGGBB.
    public var rgb: Int
    public var brightness: Int

    public init(mode: Mode, kelvin: Int, rgb: Int, brightness: Int) {
        self.mode = mode
        self.kelvin = kelvin
        self.rgb = rgb
        self.brightness = brightness
    }

    /// The Yeelight colour bulb's white range.
    public static let kelvinRange = 1700...6500
    public static let brightnessRange = 1...100

    public static let `default` = LightSetting(mode: .white, kelvin: 4000, rgb: 0xFF8C00, brightness: 80)

    public var command: LampCommand {
        switch mode {
        case .white: .temperature(kelvin: kelvin, brightness: brightness)
        case .color: .color(rgb: rgb, brightness: brightness)
        }
    }

    /// The colour shown on screen: the RGB itself, or an approximation of the white.
    public var displayRGB: Int {
        mode == .white ? Self.rgb(forKelvin: kelvin) : rgb
    }

    /// Approximate sRGB of a black body at the given temperature (Tanner Helland's fit).
    public static func rgb(forKelvin kelvin: Int) -> Int {
        let t = Double(min(max(kelvin, 1000), 40_000)) / 100
        let red = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let green = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let blue = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        func byte(_ value: Double) -> Int { Int(min(max(value, 0), 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}

/// One-tap light settings.
public struct LightPreset: Identifiable, Equatable, Sendable {
    public let name: String
    public let symbol: String
    public let setting: LightSetting
    public var id: String { name }

    public static let all: [LightPreset] = [
        LightPreset(name: "Mum", symbol: "flame", setting: .init(mode: .white, kelvin: 1900, rgb: 0xFF8C00, brightness: 20)),
        LightPreset(name: "Okuma", symbol: "book", setting: .init(mode: .white, kelvin: 4000, rgb: 0xFF8C00, brightness: 85)),
        LightPreset(name: "Gün ışığı", symbol: "sun.max", setting: .init(mode: .white, kelvin: 5000, rgb: 0xFF8C00, brightness: 100)),
    ]

    /// The white tones offered as one-tap circles on the light screen.
    public static let tones = [1900, 2700, 3500, 4000, 5000, 6500]
}

extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}
