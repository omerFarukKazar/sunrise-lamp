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
        (.sunset, .sunset(minutes: 30)),
        (.on, .powerOn),
        (.off, .powerOff),
    ])
    func actionCommands(_ action: LampRemote.Action, _ command: LampCommand) {
        #expect(makeRemote().command(for: action) == command)
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

    // MARK: - Automation reminder

    @Test("With no automation on record the user is asked to set one up")
    func reminderSetup() {
        store.schedule.durationMinutes = 45
        #expect(makeRemote().automationReminder == .setup(minutes: 45))
    }

    @Test("Confirming clears the reminder and is saved")
    func reminderConfirm() {
        let remote = makeRemote()
        remote.confirmAutomation()
        #expect(remote.automationReminder == nil)
        #expect(store.automationMinutes == 30)
    }

    @Test("A longer sunrise asks to move the automation earlier by the difference")
    func reminderShift() {
        store.automationMinutes = 30
        let remote = makeRemote()
        remote.schedule.durationMinutes = 45
        #expect(remote.automationReminder == .shift(from: 30, to: 45))
        #expect(remote.automationReminder?.shiftMinutes == 15)
    }

    @Test("Going back to the confirmed length clears the reminder")
    func reminderRevert() {
        store.automationMinutes = 30
        let remote = makeRemote()
        remote.schedule.durationMinutes = 60
        remote.schedule.durationMinutes = 30
        #expect(remote.automationReminder == nil)
    }

    @Test("A sunrise run with no automation on record counts as set up")
    func sunriseConfirmsSetup() async {
        store.lamp = bulb
        let remote = makeRemote()
        await remote.perform(.sunrise)
        #expect(remote.automationReminder == nil)
    }

    @Test("A sunrise run does not hide a pending shift")
    func sunriseKeepsShift() async {
        store.lamp = bulb
        store.automationMinutes = 30
        store.schedule.durationMinutes = 15
        let remote = makeRemote()
        await remote.perform(.sunrise)
        #expect(remote.automationReminder == .shift(from: 30, to: 15))
    }

    // MARK: - Preview and power

    @Test("Picking end lights previews only the last one, then restores the light")
    func previewRestoresLight() async throws {
        store.lamp = bulb
        let remote = LampRemote(client: client, store: store, lightDelay: .milliseconds(20))
        remote.preview(endKelvin: 3000)
        remote.preview(endKelvin: 6500)
        try await Task.sleep(for: .milliseconds(200))
        await remote.endPreview()
        #expect(client.sent == [.temperature(kelvin: 6500, brightness: 100), LightSetting.default.command])
    }

    @Test("A preview of a lamp that was off turns it off again")
    func previewRestoresOff() async {
        store.lamp = bulb
        let remote = LampRemote(client: client, store: store, lightDelay: .milliseconds(20))
        await remote.setPower(false)
        remote.preview(endKelvin: 4000)
        await remote.endPreview()
        #expect(client.sent == [.powerOff, .powerOff])
        #expect(remote.isOn == false)
    }

    @Test("Ending without a preview sends nothing")
    func endPreviewWithoutPreview() async {
        store.lamp = bulb
        await makeRemote().endPreview()
        #expect(client.sent.isEmpty)
    }

    @Test("Turning the power back on restores the manual light")
    func powerOnRestoresLight() async {
        store.lamp = bulb
        let remote = makeRemote()
        await remote.setPower(false)
        await remote.setPower(true)
        #expect(client.sent == [.powerOff, LightSetting.default.command])
        #expect(remote.isOn)
    }
}
