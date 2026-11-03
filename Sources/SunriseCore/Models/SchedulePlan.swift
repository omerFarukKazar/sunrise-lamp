import Foundation

/// When the sunrise starts, derived from the wake-up time and duration.
/// The Mac is woken (`pmset`) at the same moment so the app can send the
/// command even if the Mac was asleep.
public struct SchedulePlan: Equatable, Sendable {
    public struct Moment: Equatable, Sendable {
        public let hour: Int
        public let minute: Int
        public let days: Set<Weekday>

        public var timeText: String { String(format: "%02d:%02d", hour, minute) }
    }

    /// How late a missed start may still fire, e.g. when the Mac wakes slowly.
    public static let fireWindow: TimeInterval = 10 * 60

    public let start: Moment
    public let durationMinutes: Int

    public init(schedule: SunriseSchedule) {
        let end = Moment(hour: schedule.wakeHour, minute: schedule.wakeMinute, days: schedule.weekdays)
        start = Self.shift(end, byMinutes: -schedule.durationMinutes)
        durationMinutes = schedule.durationMinutes
    }

    /// Argument for `pmset repeat wakeorpoweron <days> <time>`.
    public var pmsetDays: String {
        start.days.sorted().map(\.pmsetLetter).joined()
    }

    public var pmsetTime: String { start.timeText + ":00" }

    /// The start time on the given day, or nil when the alarm is off that day.
    public func startDate(on day: Date, calendar: Calendar = .current) -> Date? {
        guard let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day)),
              start.days.contains(weekday)
        else { return nil }
        return calendar.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day)
    }

    /// True once per day, from the start time until `fireWindow` has passed.
    public func shouldFire(at now: Date, lastFired: Date?, calendar: Calendar = .current) -> Bool {
        guard let startDate = startDate(on: now, calendar: calendar) else { return false }
        let alreadyFired = (lastFired ?? .distantPast) >= startDate
        return !alreadyFired && now >= startDate && now < startDate.addingTimeInterval(Self.fireWindow)
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
