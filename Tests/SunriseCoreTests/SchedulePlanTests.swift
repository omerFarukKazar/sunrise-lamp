import Foundation
import Testing
@testable import SunriseCore

@Suite("SchedulePlan")
struct SchedulePlanTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        return calendar
    }

    /// Tuesday 3 November 2026 at the given time.
    private func tuesday(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: hour, minute: minute)) ?? .distantPast
    }

    private func plan(_ hour: Int, _ minute: Int, duration: Int = 30, days: Set<Weekday> = Set(Weekday.allCases)) -> SchedulePlan {
        SchedulePlan(schedule: SunriseSchedule(wakeHour: hour, wakeMinute: minute, durationMinutes: duration, weekdays: days, isEnabled: true))
    }

    @Test("08:00 with 30 minutes starts at 07:30 every day")
    func startsBeforeWake() {
        let plan = plan(8, 0)
        #expect(plan.start.timeText == "07:30")
        #expect(plan.pmsetTime == "07:30:00")
        #expect(plan.pmsetDays == "MTWRFSU")
    }

    @Test("A start before midnight moves to the previous day")
    func crossesMidnight() {
        let plan = plan(0, 15, days: [.monday])
        #expect(plan.start.timeText == "23:45")
        #expect(plan.start.days == [.sunday])
        #expect(plan.pmsetDays == "U")
    }

    @Test("pmset days are listed Monday first")
    func pmsetDayOrder() {
        #expect(plan(8, 0, days: [.sunday, .monday, .thursday]).pmsetDays == "MRU")
    }

    @Test("Calendar weekday maps Sunday = 1 to .sunday")
    func calendarWeekday() {
        #expect(Weekday(calendarWeekday: 1) == .sunday)
        #expect(Weekday(calendarWeekday: 2) == .monday)
        #expect(Weekday(calendarWeekday: 7) == .saturday)
    }

    @Test("Fires inside the window and not before or after it")
    func fireWindow() {
        let plan = plan(8, 0)
        #expect(!plan.shouldFire(at: tuesday(7, 29), lastFired: nil, calendar: calendar))
        #expect(plan.shouldFire(at: tuesday(7, 30), lastFired: nil, calendar: calendar))
        #expect(plan.shouldFire(at: tuesday(7, 39), lastFired: nil, calendar: calendar))
        #expect(!plan.shouldFire(at: tuesday(7, 40), lastFired: nil, calendar: calendar))
    }

    @Test("Fires only once per day")
    func firesOnce() {
        let plan = plan(8, 0)
        #expect(!plan.shouldFire(at: tuesday(7, 31), lastFired: tuesday(7, 30), calendar: calendar))
        #expect(plan.shouldFire(at: tuesday(7, 31), lastFired: tuesday(7, 30).addingTimeInterval(-86_400), calendar: calendar))
    }

    @Test("Does not fire on a day that is not selected")
    func skipsUnselectedDay() {
        #expect(!plan(8, 0, days: [.monday]).shouldFire(at: tuesday(7, 30), lastFired: nil, calendar: calendar))
    }
}

@Suite("LampCommand")
struct LampCommandTests {
    @Test("Sunset scene runs once and turns the light off at the end")
    func sunsetTurnsOff() {
        let json = LampCommand.sunset(minutes: 20).json
        let steps = LampCommand.sunsetFlow(minutes: 20)
        #expect(json.contains(#""cf",4,2,"#))
        #expect(steps.map(\.duration).reduce(0, +) == 20 * 60_000)
        #expect(steps.last?.brightness == 1)
    }

    @Test("Sunrise scene count matches the number of steps")
    func sunriseCount() {
        let json = LampCommand.sunrise(minutes: 30).json
        let steps = LampCommand.sunriseFlow(minutes: 30)
        #expect(json.contains(#""cf",\#(steps.count),1,"#))
        #expect(json.hasPrefix(#"{"id":1,"method":"set_scene""#))
    }

    @Test("Sunrise starts deep red and ends at daylight, phases fill the duration")
    func sunriseFlow() {
        let steps = LampCommand.sunriseFlow(minutes: 30)
        #expect(steps.first == .init(duration: 50, mode: 1, value: 0xFF1E00, brightness: 1))
        #expect(steps.last?.brightness == 100)
        #expect(steps.last?.mode == 2 && steps.last?.value == 6500)
        #expect(steps.dropFirst().map(\.duration).reduce(0, +) == 30 * 60_000)
    }

    @Test("Discovery response is parsed into a lamp")
    func parseDiscovery() {
        let response = "HTTP/1.1 200 OK\r\nCache-Control: max-age=3600\r\nLocation: yeelight://192.168.1.9:55443\r\nid: 0x000000001b375de2\r\nmodel: colorb\r\npower: on\r\n"
        #expect(Lamp(discoveryResponse: response) == Lamp(id: "0x000000001b375de2", ip: "192.168.1.9", model: "colorb"))
    }

    @Test("Unrelated SSDP answers are ignored")
    func ignoreOtherDevices() {
        #expect(Lamp(discoveryResponse: "HTTP/1.1 200 OK\r\nLocation: http://192.168.1.1/desc.xml\r\n") == nil)
    }
}
