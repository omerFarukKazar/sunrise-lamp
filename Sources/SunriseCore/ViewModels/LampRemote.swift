import Foundation
import Observation

/// Drives the lamp directly, without the Mac's wake schedule: the iPhone app
/// and its Shortcuts actions use this. The bulb runs each colour flow itself,
/// so one command is enough.
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

    /// How long the sunset fades the light out.
    public nonisolated static let sunsetMinutes = 30

    /// Wake time and sunrise length; the automation time follows from them.
    public var schedule: SunriseSchedule {
        didSet { store.schedule = schedule }
    }

    public private(set) var status: Status = .idle
    public private(set) var lampState: LampState

    @ObservationIgnored private let client: LampClientProtocol
    @ObservationIgnored private let store: SettingsStoreProtocol

    public init(client: LampClientProtocol, store: SettingsStoreProtocol) {
        self.client = client
        self.store = store
        schedule = store.schedule
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

    /// When the Shortcuts automation should run: the wake time minus the sunrise.
    public var automationTime: String { SchedulePlan(schedule: schedule).start.timeText }

    /// The wake-up time as a `Date` for `DatePicker`; only hour and minute matter.
    public var wakeTime: Date {
        get {
            Calendar.current.date(from: DateComponents(hour: schedule.wakeHour, minute: schedule.wakeMinute)) ?? .now
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            schedule.wakeHour = components.hour ?? schedule.wakeHour
            schedule.wakeMinute = components.minute ?? schedule.wakeMinute
        }
    }

    public func command(for action: Action) -> LampCommand {
        switch action {
        case .sunrise: .sunrise(minutes: schedule.durationMinutes)
        case .test: .sunrise(minutes: 1)
        case .sunset: .sunset(minutes: LampRemote.sunsetMinutes)
        case .on: .powerOn
        case .off: .powerOff
        }
    }

    public func message(for action: Action) -> String {
        switch action {
        case .sunrise: "Güneş doğuyor, \(schedule.durationMinutes) dakikada gün ışığına ulaşacak."
        case .test: "1 dakikalık test gönderildi, lambaya bak."
        case .sunset: "Işık \(LampRemote.sunsetMinutes) dakikada kızıla dönüp sönecek."
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
        status = .working("Lambaya gönderiliyor…")
        let command = command(for: action)
        if let lamp, (try? await client.send(command, to: lamp)) != nil {
            status = .success(message(for: action))
            return true
        }
        await findLamp()
        guard let lamp else {
            status = .failure("Lamba bulunamadı. Aynı Wi-Fi'da mısın, lamba açık mı?")
            return false
        }
        do {
            try await client.send(command, to: lamp)
            status = .success(message(for: action))
            return true
        } catch {
            status = .failure(error.localizedDescription)
            return false
        }
    }
}
