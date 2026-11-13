import Foundation

public enum Weekday: Int, CaseIterable, Codable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// `Calendar` counts from Sunday = 1.
    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday == 1 ? 7 : calendarWeekday - 1)
    }

    public var shortName: String {
        switch self {
        case .monday: "Pt"
        case .tuesday: "Sa"
        case .wednesday: "Ça"
        case .thursday: "Pe"
        case .friday: "Cu"
        case .saturday: "Ct"
        case .sunday: "Pz"
        }
    }

    public var fullName: String {
        switch self {
        case .monday: "Pazartesi"
        case .tuesday: "Salı"
        case .wednesday: "Çarşamba"
        case .thursday: "Perşembe"
        case .friday: "Cuma"
        case .saturday: "Cumartesi"
        case .sunday: "Pazar"
        }
    }

    public var previous: Weekday {
        Weekday(rawValue: rawValue - 1) ?? .sunday
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// What the user picks: the time they want to be fully awake and how long
/// the sunrise before it should last.
public struct SunriseSchedule: Codable, Equatable, Sendable {
    public var wakeHour: Int
    public var wakeMinute: Int
    public var durationMinutes: Int
    public var weekdays: Set<Weekday>
    public var isEnabled: Bool
    /// The colour temperature the sunrise ends on.
    public var endKelvin: Int

    public init(
        wakeHour: Int, wakeMinute: Int, durationMinutes: Int, weekdays: Set<Weekday>, isEnabled: Bool,
        endKelvin: Int = SunriseSchedule.defaultEndKelvin
    ) {
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.durationMinutes = durationMinutes
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.endKelvin = endKelvin
    }

    /// Schedules saved before `endKelvin` existed decode with the default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wakeHour = try container.decode(Int.self, forKey: .wakeHour)
        wakeMinute = try container.decode(Int.self, forKey: .wakeMinute)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        weekdays = try container.decode(Set<Weekday>.self, forKey: .weekdays)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        endKelvin = try container.decodeIfPresent(Int.self, forKey: .endKelvin) ?? Self.defaultEndKelvin
    }

    /// Morning sun is about 4000 to 5000 K; 6500 K reads as cold office light.
    public static let defaultEndKelvin = 5000
    public static let endKelvinRange = 2700...6500

    public static let `default` = SunriseSchedule(
        wakeHour: 8, wakeMinute: 0, durationMinutes: 30,
        weekdays: Set(Weekday.allCases), isEnabled: false
    )

    public static let durationOptions = [15, 30, 45, 60]

    public var wakeTimeText: String { String(format: "%02d:%02d", wakeHour, wakeMinute) }
}
