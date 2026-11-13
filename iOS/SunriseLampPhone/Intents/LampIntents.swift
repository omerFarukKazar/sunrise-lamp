import AppIntents
import SunriseCore

// Shortcuts and Siri actions. They run in the background: the bulb plays the
// colour flow on its own, so each one only sends a single command.

struct StartSunriseIntent: AppIntent {
    static let title: LocalizedStringResource = "Gün doğumunu başlat"
    static let description = IntentDescription("Lamba kızıl ışıkla başlar, uygulamada seçtiğin sürede gün ışığına ulaşır.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await LampIntentRunner.run(.sunrise)
    }
}

struct StartSunsetIntent: AppIntent {
    static let title: LocalizedStringResource = "Gün batımını başlat"
    static let description = IntentDescription("Işık yavaşça turuncuya, sonra kızıla döner ve söner.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await LampIntentRunner.run(.sunset)
    }
}

struct TurnLampOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Işığı aç"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await LampIntentRunner.run(.on)
    }
}

struct TurnLampOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Işığı kapat"

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await LampIntentRunner.run(.off)
    }
}

enum LampIntentRunner {
    @MainActor
    static func run(_ action: LampRemote.Action) async throws -> some IntentResult & ProvidesDialog {
        let remote = LampRemote(client: YeelightClient(), store: SettingsStore())
        guard await remote.perform(action) else {
            if case .failure(let message) = remote.status { throw LampIntentError(message: message) }
            throw LampIntentError(message: "Lambaya ulaşılamadı.")
        }
        return .result(dialog: IntentDialog(stringLiteral: remote.message(for: action)))
    }
}

struct LampIntentError: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

struct SunriseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSunriseIntent(),
            phrases: ["\(.applicationName) ile gün doğumunu başlat", "\(.applicationName) gün doğumu"],
            shortTitle: "Gün doğumu",
            systemImageName: "sunrise"
        )
        AppShortcut(
            intent: StartSunsetIntent(),
            phrases: ["\(.applicationName) ile gün batımını başlat", "\(.applicationName) gün batımı"],
            shortTitle: "Gün batımı",
            systemImageName: "sunset"
        )
        AppShortcut(
            intent: TurnLampOffIntent(),
            phrases: ["\(.applicationName) ile ışığı kapat", "\(.applicationName) kapat"],
            shortTitle: "Işığı kapat",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: TurnLampOnIntent(),
            phrases: ["\(.applicationName) ile ışığı aç", "\(.applicationName) aç"],
            shortTitle: "Işığı aç",
            systemImageName: "lightbulb"
        )
    }
}
