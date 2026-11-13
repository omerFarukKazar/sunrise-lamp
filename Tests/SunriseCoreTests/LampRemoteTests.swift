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
        #expect(client.sent == [.sunrise(minutes: 45, endKelvin: SunriseSchedule.defaultEndKelvin)])
        guard case .success = remote.status else {
            Issue.record("expected .success, got \(remote.status)")
            return
        }
    }

    @Test("Each action maps to its lamp command", arguments: [
        (LampRemote.Action.test, LampCommand.sunrise(minutes: 1, endKelvin: SunriseSchedule.defaultEndKelvin)),
        (.sunset, .sunset(minutes: LampRemote.sunsetMinutes)),
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

    @Test("Sunrise ends on the chosen colour temperature")
    func sunriseEndKelvin() {
        store.schedule.endKelvin = 4000
        #expect(makeRemote().command(for: .sunrise) == .sunrise(minutes: 30, endKelvin: 4000))
    }

    @Test("Quick light edits reach the lamp once, with the last value")
    func lightIsDebounced() async throws {
        store.lamp = bulb
        let remote = LampRemote(client: client, store: store, lightDelay: .milliseconds(20))
        remote.light.brightness = 30
        remote.light.brightness = 60
        remote.light.kelvin = 2700
        try await Task.sleep(for: .milliseconds(300))
        #expect(client.sent == [.temperature(kelvin: 2700, brightness: 60)])
        #expect(store.light.kelvin == 2700)
    }

    @Test("A light change that cannot reach the lamp is reported")
    func lightFailure() async {
        client.discovered = nil
        let remote = makeRemote()
        await remote.applyLight()
        guard case .failure = remote.status else {
            Issue.record("expected .failure, got \(remote.status)")
            return
        }
    }
}
