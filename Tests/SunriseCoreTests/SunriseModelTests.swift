import Foundation
import Testing
@testable import SunriseCore

let bulb = Lamp(id: "0x1", ip: "192.168.1.9", model: "colorb")

final class MockLampClient: LampClientProtocol, @unchecked Sendable {
    var discovered: Lamp? = bulb
    var failSends = 0
    private(set) var sent: [LampCommand] = []

    func discover(preferredIP: String?) async -> Lamp? { discovered }

    func send(_ command: LampCommand, to lamp: Lamp) async throws {
        if failSends > 0 {
            failSends -= 1
            throw LampError.timedOut
        }
        sent.append(command)
    }
}

final class MockWakeService: WakeServiceProtocol, @unchecked Sendable {
    var error: WakeError?
    private(set) var scheduled: [SchedulePlan] = []
    private(set) var cancelled = false

    func schedule(_ plan: SchedulePlan) async throws {
        if let error { throw error }
        scheduled.append(plan)
    }

    func cancel() async throws {
        if let error { throw error }
        cancelled = true
    }
}

final class MockLoginItem: LoginItemServiceProtocol, @unchecked Sendable {
    private(set) var enabled: Bool?
    func setEnabled(_ enabled: Bool) throws { self.enabled = enabled }
}

@MainActor
final class MockStore: SettingsStoreProtocol {
    var schedule: SunriseSchedule = .default
    var lamp: Lamp?
    var lastFired: Date?
    var activity: [ActivityEntry] = []
}

@MainActor
@Suite("SunriseModel")
struct SunriseModelTests {
    let client = MockLampClient()
    let wake = MockWakeService()
    let login = MockLoginItem()
    let store = MockStore()

    private func makeModel() -> SunriseModel {
        SunriseModel(lampClient: client, wakeService: wake, loginItem: login, store: store)
    }

    private func enabledSchedule() -> SunriseSchedule {
        var schedule = SunriseSchedule.default
        schedule.isEnabled = true
        return schedule
    }

    @Test("save() schedules the Mac wake and turns on the login item")
    func saveEnabled() async {
        let model = makeModel()
        model.schedule.isEnabled = true
        await model.save()
        #expect(wake.scheduled.first?.pmsetTime == "07:30:00")
        #expect(login.enabled == true)
        #expect(store.schedule.isEnabled)
        #expect(!model.hasChanges)
    }

    @Test("A cancelled admin prompt keeps the old schedule and reports it")
    func saveCancelled() async {
        wake.error = .cancelled
        let model = makeModel()
        model.schedule.isEnabled = true
        await model.save()
        #expect(!store.schedule.isEnabled)
        #expect(model.hasChanges)
        #expect(model.status == .failure(WakeError.cancelled.localizedDescription))
    }

    @Test("Turning the alarm off cancels the wake")
    func saveDisabled() async {
        store.schedule = enabledSchedule()
        let model = makeModel()
        model.schedule.isEnabled = false
        await model.save()
        #expect(wake.cancelled)
        #expect(login.enabled == false)
    }

    @Test("tick() sends the sunrise once at the start time")
    func tickFires() async {
        store.schedule = enabledSchedule()
        store.lamp = bulb
        let model = makeModel()
        let start = SchedulePlan(schedule: store.schedule).startDate(on: .now) ?? .now
        await model.tick(now: start)
        await model.tick(now: start.addingTimeInterval(60))
        #expect(client.sent == [.sunrise(minutes: 30)])
        #expect(model.activity.first?.kind == .sunrise)
    }

    @Test("tick() does nothing while the alarm is off")
    func tickIdleWhenDisabled() async {
        store.lamp = bulb
        let model = makeModel()
        let start = SchedulePlan(schedule: enabledSchedule()).startDate(on: .now) ?? .now
        await model.tick(now: start)
        #expect(client.sent.isEmpty)
    }

    @Test("A failed send searches the network again and retries")
    func retryAfterRediscovery() async {
        store.lamp = Lamp(id: "0x1", ip: "192.168.1.50", model: "colorb")
        client.failSends = 1
        let model = makeModel()
        await model.runTest()
        #expect(client.sent == [.sunrise(minutes: 1)])
        #expect(model.lamp == bulb)
    }

    @Test("A lamp that cannot be found is reported as a failure")
    func lampMissing() async {
        client.discovered = nil
        let model = makeModel()
        await model.runTest()
        #expect(model.lampState == .notFound)
        #expect(model.activity.first?.kind == .failure)
        guard case .failure = model.status else {
            Issue.record("expected .failure, got \(model.status)")
            return
        }
    }
}
