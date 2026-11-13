import AppKit
import SunriseCore
import SwiftUI

@main
struct SunriseLampApp: App {
    @State private var model: SunriseModel
    @State private var monitor: AlarmMonitor

    init() {
        let model = SunriseModel(
            lampClient: YeelightClient(),
            wakeService: PmsetWakeService(),
            loginItem: LoginItemService(),
            mediaPlayer: MediaPlayer(),
            store: SettingsStore()
        )
        let monitor = AlarmMonitor(model: model)
        monitor.start()
        _model = State(wrappedValue: model)
        _monitor = State(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra {
            SunriseView(model: model)
        } label: {
            Image(systemName: model.savedSchedule.isEnabled ? "sun.horizon.fill" : "sun.horizon")
                .accessibilityLabel("Sunrise Lamp")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Keeps the app awake enough to start the sunrise on time: checks every
/// 20 seconds and right after the Mac wakes from sleep.
@MainActor
final class AlarmMonitor {
    private let model: SunriseModel
    private var loop: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var activity: NSObjectProtocol?
    private var mediaActivity: NSObjectProtocol?

    init(model: SunriseModel) {
        self.model = model
    }

    func start() {
        // A menu bar app with no window would otherwise be App Napped and miss the time.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Güneş doğuşu saatini bekliyor"
        )
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private func check() async {
        // Hold the Mac awake while the command goes out, in case it woke only for this.
        let busy = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Lambaya komut gönderiliyor")
        defer { ProcessInfo.processInfo.endActivity(busy) }
        await model.tick()
        holdAwakeForMedia(model.isFadingInMedia())
    }

    /// Keeps the Mac from idling back to sleep while the wake media fades in,
    /// so the volume keeps rising.
    private func holdAwakeForMedia(_ needed: Bool) {
        switch (needed, mediaActivity) {
        case (true, nil):
            mediaActivity = ProcessInfo.processInfo.beginActivity(options: .idleSystemSleepDisabled, reason: "Uyandırma müziğinin sesi açılıyor")
        case (false, let activity?):
            ProcessInfo.processInfo.endActivity(activity)
            mediaActivity = nil
        default:
            break
        }
    }
}
