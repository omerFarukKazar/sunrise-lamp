import Foundation

public enum Weekday: Int, CaseIterable, Codable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// `Calendar` counts from Sunday = 1.
    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday == 1 ? 7 : calendarWeekday - 1)
    }

    /// `pmset repeat` day letters: M T W R F S U.
    public var pmsetLetter: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "R"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "U"
        }
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

    public init(wakeHour: Int, wakeMinute: Int, durationMinutes: Int, weekdays: Set<Weekday>, isEnabled: Bool) {
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.durationMinutes = durationMinutes
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }

    public static let `default` = SunriseSchedule(
        wakeHour: 8, wakeMinute: 0, durationMinutes: 30,
        weekdays: Set(Weekday.allCases), isEnabled: false
    )

    public static let durationOptions = [15, 30, 45, 60]

    public var wakeTimeText: String { String(format: "%02d:%02d", wakeHour, wakeMinute) }
}
