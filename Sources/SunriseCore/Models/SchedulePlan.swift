import Foundation

/// When the sunrise starts, derived from the wake-up time and duration.
/// The Shortcuts automation runs at this moment.
public struct SchedulePlan: Equatable, Sendable {
    public struct Moment: Equatable, Sendable {
        public let hour: Int
        public let minute: Int
        public let days: Set<Weekday>

        public var timeText: String { String(format: "%02d:%02d", hour, minute) }
    }

    public let start: Moment
    public let durationMinutes: Int

    public init(schedule: SunriseSchedule) {
        let end = Moment(hour: schedule.wakeHour, minute: schedule.wakeMinute, days: schedule.weekdays)
        start = Self.shift(end, byMinutes: -schedule.durationMinutes)
        durationMinutes = schedule.durationMinutes
    }

    /// Shifts a time of day backwards, moving the days back when it crosses midnight.
    static func shift(_ moment: Moment, byMinutes delta: Int) -> Moment {
        var total = moment.hour * 60 + moment.minute + delta
        var days = moment.days
        if total < 0 {
            total += 24 * 60
            days = Set(days.map(\.previous))
        }
        return Moment(hour: total / 60, minute: total % 60, days: days)
    }
}
