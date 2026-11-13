import SunriseCore
import SwiftUI

@main
struct SunriseLampPhoneApp: App {
    @State private var remote = LampRemote(client: YeelightClient(), store: SettingsStore())

    var body: some Scene {
        WindowGroup {
            ContentView(remote: remote)
        }
    }
}
