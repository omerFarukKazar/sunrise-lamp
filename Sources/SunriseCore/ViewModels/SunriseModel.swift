import Foundation
import Observation

/// Owns the alarm: the editable schedule, the lamp, and the check that starts
/// the sunrise when its time comes.
@MainActor
@Observable
public final class SunriseModel {
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

    /// The schedule being edited; `savedSchedule` is what the alarm runs on.
    public var schedule: SunriseSchedule
    public private(set) var savedSchedule: SunriseSchedule
    public private(set) var status: Status = .idle
    public private(set) var lampState: LampState
    public private(set) var activity: [ActivityEntry]
    public private(set) var wakeMedia: WakeMedia?
    /// When the wake media reaches full volume; the Mac stays awake until then.
    public private(set) var mediaFadeEndsAt: Date?

    @ObservationIgnored private let lampClient: LampClientProtocol
    @ObservationIgnored private let wakeService: WakeServiceProtocol
    @ObservationIgnored private let loginItem: LoginItemServiceProtocol
    @ObservationIgnored private let mediaPlayer: MediaPlayerProtocol
    @ObservationIgnored private let store: SettingsStoreProtocol

    public init(
        lampClient: LampClientProtocol,
        wakeService: WakeServiceProtocol,
        loginItem: LoginItemServiceProtocol,
        mediaPlayer: MediaPlayerProtocol,
        store: SettingsStoreProtocol
    ) {
        self.lampClient = lampClient
        self.wakeService = wakeService
        self.loginItem = loginItem
        self.mediaPlayer = mediaPlayer
        self.store = store
        schedule = store.schedule
        savedSchedule = store.schedule
        lampState = store.lamp.map(LampState.found) ?? .unknown
        activity = store.activity
        wakeMedia = store.wakeMedia
    }

    public var plan: SchedulePlan { SchedulePlan(schedule: schedule) }
    public var hasChanges: Bool { schedule != savedSchedule }

    /// Saving asks for the admin password only when the Mac's wake time changes.
    public var saveNeedsPassword: Bool { wakeChanged }

    /// True while the wake media is still fading in, so the Mac must not sleep.
    public func isFadingInMedia(at now: Date = .now) -> Bool {
        mediaFadeEndsAt.map { now < $0 } ?? false
    }

    public var isWorking: Bool {
        if case .working = status { return true }
        return false
    }

    public var lamp: Lamp? {
        if case .found(let lamp) = lampState { return lamp }
        return nil
    }

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

    public func toggle(_ day: Weekday) {
        if schedule.weekdays.contains(day) {
            schedule.weekdays.remove(day)
        } else {
            schedule.weekdays.insert(day)
        }
    }

    public func save() async {
        guard !schedule.isEnabled || !schedule.weekdays.isEmpty else {
            status = .failure("En az bir gün seç.")
            return
        }
        status = .working("Kaydediliyor…")
        if wakeChanged {
            do {
                if schedule.isEnabled {
                    try await wakeService.schedule(plan)
                } else {
                    try await wakeService.cancel()
                }
            } catch {
                status = .failure(error.localizedDescription)
                return
            }
        }

        savedSchedule = schedule
        store.schedule = schedule
        do {
            try loginItem.setEnabled(schedule.isEnabled)
            status = .success(schedule.isEnabled ? "Kaydedildi. Lamba \(plan.start.timeText)'da doğmaya başlayacak." : "Alarm kapatıldı.")
        } catch {
            status = .failure("Kaydedildi, ama açılışta başlatma ayarlanamadı: \(error.localizedDescription)")
        }
    }

    public func findLamp() async {
        lampState = .searching
        if let lamp = await lampClient.discover(preferredIP: store.lamp?.ip) {
            store.lamp = lamp
            lampState = .found(lamp)
        } else {
            lampState = .notFound
        }
    }

    public func runTest() async {
        status = .working("1 dakikalık test gönderiliyor…")
        if await send(.sunrise(minutes: 1), kind: .test, message: "1 dakikalık test gönderildi") {
            status = .success("Test gönderildi, lambaya bak.")
        }
    }

    public func turnOn() async {
        status = .working("Işık açılıyor…")
        if await send(.powerOn, kind: .info, message: "Işık açıldı") {
            status = .success("Işık açıldı.")
        }
    }

    /// How long the sunset button takes to fade the light out.
    public nonisolated static let sunsetMinutes = 30

    public func sunset(minutes: Int = sunsetMinutes) async {
        status = .working("Gün batımı başlıyor…")
        if await send(.sunset(minutes: minutes), kind: .info, message: "Gün batımı başladı (\(minutes) dk)") {
            status = .success("Işık \(minutes) dakikada kızıla dönüp sönecek.")
        }
    }

    public func turnOff() async {
        status = .working("Işık kapatılıyor…")
        if await send(.powerOff, kind: .info, message: "Işık kapatıldı") {
            status = .success("Işık kapatıldı. Alarm saatinde yine yanacak.")
        }
    }

    public func setWakeMedia(_ media: WakeMedia?) {
        wakeMedia = media
        store.wakeMedia = media
    }

    public func previewWakeMedia() {
        guard let wakeMedia else { return }
        status = mediaPlayer.play(wakeMedia, fadeIn: 0) ? .idle : .failure("\(wakeMedia.title) açılamadı.")
    }

    public func stopWakeMedia() {
        mediaPlayer.stop()
        mediaFadeEndsAt = nil
    }

    /// Called periodically and on wake; starts the sunrise once per scheduled
    /// day, with the wake media fading in alongside the light.
    public func tick(now: Date = .now) async {
        guard savedSchedule.isEnabled else { return }
        let savedPlan = SchedulePlan(schedule: savedSchedule)
        guard savedPlan.shouldFire(at: now, lastFired: store.lastFired) else { return }
        store.lastFired = now
        let fade = TimeInterval(savedPlan.durationMinutes * 60)
        _ = await send(
            .sunrise(minutes: savedPlan.durationMinutes),
            kind: .sunrise,
            message: "Güneş doğuşu başladı (\(savedPlan.durationMinutes) dk)"
        )
        guard let wakeMedia else { return }
        if mediaPlayer.play(wakeMedia, fadeIn: fade) {
            mediaFadeEndsAt = now.addingTimeInterval(fade)
            record(.sunrise, "Müzik başladı: \(wakeMedia.title)")
        } else {
            record(.failure, "\(wakeMedia.title) açılamadı")
        }
    }

    /// Whether saving changes what `pmset` wakes the Mac for.
    private var wakeChanged: Bool {
        guard schedule.isEnabled == savedSchedule.isEnabled else { return true }
        guard schedule.isEnabled else { return false }
        let saved = SchedulePlan(schedule: savedSchedule)
        return plan.pmsetDays != saved.pmsetDays || plan.pmsetTime != saved.pmsetTime
    }

    /// Sends to the known lamp, searching the network again if that fails.
    private func send(_ command: LampCommand, kind: ActivityEntry.Kind, message: String) async -> Bool {
        if let lamp, (try? await lampClient.send(command, to: lamp)) != nil {
            record(kind, message)
            return true
        }
        await findLamp()
        guard let lamp else {
            record(.failure, "Lamba ağda bulunamadı")
            status = .failure("Lamba ağda bulunamadı. Açık ve Wi-Fi'a bağlı mı?")
            return false
        }
        do {
            try await lampClient.send(command, to: lamp)
            record(kind, message)
            return true
        } catch {
            record(.failure, error.localizedDescription)
            status = .failure(error.localizedDescription)
            return false
        }
    }

    private func record(_ kind: ActivityEntry.Kind, _ message: String) {
        activity = Array(([ActivityEntry(date: .now, kind: kind, message: message)] + activity).prefix(10))
        store.activity = activity
    }
}
