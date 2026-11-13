import Foundation

/// What the app decides about the morning: how long the sunrise lasts and
/// which light it ends on. When it starts, and on which days, lives in the
/// user's Shortcuts automation.
public struct SunriseSchedule: Codable, Equatable, Sendable {
    public var durationMinutes: Int
    /// The colour temperature the sunrise ends on.
    public var endKelvin: Int
    /// How long the sunset fades the light out.
    public var sunsetMinutes: Int

    public init(
        durationMinutes: Int = 30,
        endKelvin: Int = SunriseSchedule.defaultEndKelvin,
        sunsetMinutes: Int = 30
    ) {
        self.durationMinutes = durationMinutes
        self.endKelvin = endKelvin
        self.sunsetMinutes = sunsetMinutes
    }

    /// Older saves also hold a wake time and days; those keys are ignored and
    /// any missing value falls back to its default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SunriseSchedule()
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? fallback.durationMinutes
        endKelvin = try container.decodeIfPresent(Int.self, forKey: .endKelvin) ?? fallback.endKelvin
        sunsetMinutes = try container.decodeIfPresent(Int.self, forKey: .sunsetMinutes) ?? fallback.sunsetMinutes
    }

    /// Morning sun is about 4000 to 5000 K; 6500 K reads as cold office light.
    public static let defaultEndKelvin = 5000
    public static let endKelvinRange = 2700...6500

    public static let `default` = SunriseSchedule()

    public static let durationOptions = [15, 30, 45, 60]

    public var endLight: EndLight { EndLight.closest(to: endKelvin) }
}

/// The four lights a sunrise can end on.
public struct EndLight: Identifiable, Equatable, Sendable {
    public let kelvin: Int
    /// Short label under the swatch, e.g. "Sabah".
    public let name: String
    /// Completes "kızıldan 5000 K …", e.g. "gün ışığına".
    public let phrase: String
    public var id: Int { kelvin }

    public static let all: [EndLight] = [
        EndLight(kelvin: 3000, name: "Sıcak", phrase: "sıcak beyaza"),
        EndLight(kelvin: 4000, name: "Sabah", phrase: "sabah güneşine"),
        EndLight(kelvin: 5000, name: "Gün ışığı", phrase: "gün ışığına"),
        EndLight(kelvin: 6500, name: "Soğuk", phrase: "soğuk beyaza"),
    ]

    public static func closest(to kelvin: Int) -> EndLight {
        all.min { abs($0.kelvin - kelvin) < abs($1.kelvin - kelvin) } ?? all[2]
    }
}

/// What the user still has to do in Shortcuts. The app cannot read or change
/// the automation, so it remembers the sunrise length the automation was last
/// set up for and compares it with the current one.
public enum AutomationReminder: Equatable, Sendable {
    /// No automation yet: it should run this many minutes before waking.
    case setup(minutes: Int)
    /// The sunrise length changed; the automation has to move by the difference
    /// so the wake-up time stays the same.
    case shift(from: Int, to: Int)

    public init?(confirmedMinutes: Int?, currentMinutes: Int) {
        guard let confirmedMinutes else {
            self = .setup(minutes: currentMinutes)
            return
        }
        guard confirmedMinutes != currentMinutes else { return nil }
        self = .shift(from: confirmedMinutes, to: currentMinutes)
    }

    /// Minutes the automation has to move: positive means earlier.
    public var shiftMinutes: Int {
        switch self {
        case .setup: 0
        case .shift(let from, let to): to - from
        }
    }
}
