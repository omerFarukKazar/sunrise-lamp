import Foundation
import Testing
@testable import SunriseCore

@MainActor
@Suite("LampRemote")
struct LampRemoteTests {
    let client = MockLampClient()
    let store = MockStore()

    private func makeRemote() -> LampRemote {
        LampRemote(client: client, store: store)
    }

    @Test("Sunrise uses the saved duration")
    func sunriseUsesDuration() async {
        store.lamp = bulb
        store.schedule.durationMinutes = 45
        let remote = makeRemote()
        #expect(await remote.perform(.sunrise))
        #expect(client.sent == [.sunrise(minutes: 45)])
        guard case .success = remote.status else {
            Issue.record("expected .success, got \(remote.status)")
            return
        }
    }

    @Test("Each action maps to its lamp command", arguments: [
        (LampRemote.Action.test, LampCommand.sunrise(minutes: 1)),
        (.sunset, .sunset(minutes: SunriseModel.sunsetMinutes)),
        (.on, .powerOn),
        (.off, .powerOff),
    ])
    func actionCommands(_ action: LampRemote.Action, _ command: LampCommand) {
        #expect(makeRemote().command(for: action) == command)
    }

    @Test("Automation time is the wake time minus the sunrise")
    func automationTime() {
        store.schedule.wakeHour = 7
        store.schedule.wakeMinute = 30
        store.schedule.durationMinutes = 30
        #expect(makeRemote().automationTime == "07:00")
    }

    @Test("Schedule edits are saved")
    func savesSchedule() {
        let remote = makeRemote()
        remote.schedule.durationMinutes = 15
        #expect(store.schedule.durationMinutes == 15)
    }

    @Test("A failed send searches again and retries")
    func retries() async {
        store.lamp = Lamp(id: "0x1", ip: "192.168.1.50", model: "colorb")
        client.failSends = 1
        let remote = makeRemote()
        #expect(await remote.perform(.off))
        #expect(client.sent == [.powerOff])
        #expect(remote.lamp == bulb)
    }

    @Test("A missing lamp is reported")
    func missingLamp() async {
        client.discovered = nil
        let remote = makeRemote()
        #expect(await remote.perform(.on) == false)
        #expect(remote.lampState == .notFound)
        guard case .failure = remote.status else {
            Issue.record("expected .failure, got \(remote.status)")
            return
        }
    }
}
