import Foundation
import Observation

/// Drives the lamp for the iPhone app and its Shortcuts actions. The bulb runs
/// each colour flow itself, so one command is enough.
@MainActor
@Observable
public final class LampRemote {
    public enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)
    }

    public enum LampState: Equatable {
        case unknown
        case searching
        case found(Lamp)
        case notFound
    }

    public enum Action: Equatable, Sendable {
        case sunrise
        case test
        case sunset
        case on
        case off
    }

    /// Sunrise length, end light and sunset length.
    public var schedule: SunriseSchedule {
        didSet { store.schedule = schedule }
    }

    /// The manual light controls. Every change reaches the lamp shortly after
    /// the last edit, so dragging a control does not flood the bulb.
    public var light: LightSetting {
        didSet {
            guard light != oldValue else { return }
            store.light = light
            isOn = true
            scheduleSend { $0.light.command }
        }
    }

    /// The sunrise length the Shortcuts automation was last set up for.
    public private(set) var automationMinutes: Int? {
        didSet { store.automationMinutes = automationMinutes }
    }

    /// The last power state this app asked for. The bulb is never asked, so a
    /// change from the Yeelight app or the wall switch is not seen.
    public private(set) var isOn = true
    public private(set) var status: Status = .idle
    public private(set) var lampState: LampState

    @ObservationIgnored private let client: LampClientProtocol
    @ObservationIgnored private let store: SettingsStoreProtocol
    @ObservationIgnored private var pendingSend: Task<Void, Never>?
    @ObservationIgnored private let sendDelay: Duration
    @ObservationIgnored private var isPreviewing = false

    public init(client: LampClientProtocol, store: SettingsStoreProtocol, lightDelay: Duration = .milliseconds(250)) {
        self.client = client
        self.store = store
        self.sendDelay = lightDelay
        schedule = store.schedule
        light = store.light
        automationMinutes = store.automationMinutes
        lampState = store.lamp.map(LampState.found) ?? .unknown
    }

    public var lamp: Lamp? {
        if case .found(let lamp) = lampState { return lamp }
        return nil
    }

    public var isWorking: Bool {
        if case .working = status { return true }
        return false
    }

    // MARK: - Automation

    /// What the user still has to do in Shortcuts, or nil when nothing.
    public var automationReminder: AutomationReminder? {
        AutomationReminder(confirmedMinutes: automationMinutes, currentMinutes: schedule.durationMinutes)
    }

    /// The user says the automation matches the current sunrise length.
    public func confirmAutomation() {
        automationMinutes = schedule.durationMinutes
    }

    // MARK: - Actions

    public func command(for action: Action) -> LampCommand {
        switch action {
        case .sunrise: .sunrise(minutes: schedule.durationMinutes, endKelvin: schedule.endKelvin)
        case .test: .sunrise(minutes: 1, endKelvin: schedule.endKelvin)
        case .sunset: .sunset(minutes: schedule.sunsetMinutes)
        case .on: .powerOn
        case .off: .powerOff
        }
    }

    public func message(for action: Action) -> String {
        switch action {
        case .sunrise: "Güneş doğuyor, \(schedule.durationMinutes) dakikada \(schedule.endLight.phrase) ulaşacak."
        case .test: "1 dakikalık test gönderildi, lambaya bak."
        case .sunset: "Işık \(schedule.sunsetMinutes) dakikada kızıla dönüp sönecek."
        case .on: "Işık açıldı."
        case .off: "Işık kapatıldı."
        }
    }

    public func findLamp() async {
        lampState = .searching
        if let lamp = await client.discover(preferredIP: store.lamp?.ip) {
            store.lamp = lamp
            lampState = .found(lamp)
        } else {
            lampState = .notFound
        }
    }

    /// Sends the action, searching the network again if the known address fails.
    @discardableResult
    public func perform(_ action: Action) async -> Bool {
        pendingSend?.cancel()
        status = .working("Lambaya gönderiliyor…")
        if let failure = await deliver(command(for: action)) {
            status = .failure(failure)
            return false
        }
        isOn = action != .off
        // A sunrise that arrives with no automation on record came from one the
        // user already set up, so the setup reminder can go.
        if action == .sunrise, automationMinutes == nil {
            automationMinutes = schedule.durationMinutes
        }
        status = .success(message(for: action))
        return true
    }

    /// Turns the lamp off, or back on with the manual light setting.
    public func setPower(_ on: Bool) async {
        isOn = on
        if on {
            await applyLight()
        } else {
            await perform(.off)
        }
    }

    /// Sends the current manual light setting. Success stays quiet; only a
    /// failure shows up in the status.
    public func applyLight() async {
        await sendQuietly(light.command)
        isOn = true
    }

    // MARK: - Sunrise preview

    /// Shows a sunrise end light on the lamp while the user picks it.
    public func preview(endKelvin: Int) {
        isPreviewing = true
        scheduleSend { _ in .temperature(kelvin: endKelvin, brightness: 100) }
    }

    /// Puts the lamp back the way it was before the preview.
    public func endPreview() async {
        guard isPreviewing else { return }
        isPreviewing = false
        pendingSend?.cancel()
        await sendQuietly(isOn ? light.command : .powerOff)
    }

    // MARK: - Sending

    private func scheduleSend(_ command: @escaping @MainActor (LampRemote) -> LampCommand) {
        pendingSend?.cancel()
        pendingSend = Task { [sendDelay] in
            try? await Task.sleep(for: sendDelay)
            guard !Task.isCancelled else { return }
            await sendQuietly(command(self))
        }
    }

    private func sendQuietly(_ command: LampCommand) async {
        if let failure = await deliver(command) {
            status = .failure(failure)
        } else if case .failure = status {
            status = .idle
        }
    }

    /// Returns nil on success, otherwise the message to show.
    private func deliver(_ command: LampCommand) async -> String? {
        if let lamp, (try? await client.send(command, to: lamp)) != nil { return nil }
        await findLamp()
        guard let lamp else { return "Lamba bulunamadı. Aynı Wi-Fi'da mısın, lamba açık mı?" }
        do {
            try await client.send(command, to: lamp)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
