import SunriseCore
import SwiftUI

struct RootView: View {
    let remote: LampRemote

    var body: some View {
        // The light is what people reach for most, so the app opens on it.
        TabView {
            LightView(remote: remote)
                .tabItem { Label("Işık", systemImage: "lightbulb") }
            SunriseView(remote: remote)
                .tabItem { Label("Gündoğumu", systemImage: "sunrise") }
            SettingsView(remote: remote)
                .tabItem { Label("Ayarlar", systemImage: "slider.horizontal.3") }
        }
        .tint(Palette.accent)
        .task {
            if remote.lamp == nil { await remote.findLamp() }
        }
    }
}

extension View {
    /// Puts a control at the top right without the glass capsule iOS 26
    /// draws behind toolbar items.
    @ViewBuilder
    func trailingBarItem<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            toolbar {
                ToolbarItem(placement: .topBarTrailing) { content() }
                    .sharedBackgroundVisibility(.hidden)
            }
        } else {
            toolbar {
                ToolbarItem(placement: .topBarTrailing) { content() }
            }
        }
    }
}
