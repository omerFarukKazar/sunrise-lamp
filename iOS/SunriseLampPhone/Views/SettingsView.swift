import SunriseCore
import SwiftUI

/// The third tab: lamp connection, the Shortcuts automation, sunset length.
struct SettingsView: View {
    @Bindable var remote: LampRemote

    @State private var isShowingGuide = false
    @Environment(\.openURL) private var openURL

    private static let sourceURL = URL(string: "https://github.com/omerFarukKazar/sunrise-lamp")

    var body: some View {
        NavigationStack {
            List {
                Section("Lamba") {
                    Group {
                    HStack(spacing: Spacing.md) {
                        IconTile(systemName: "lightbulb.fill", background: Palette.accent)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Yeelight")
                                .font(Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                            HStack(spacing: Spacing.xs + 2) {
                                Circle().fill(lampColor).frame(width: 7, height: 7)
                                Text(lampText)
                            }
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        if remote.lampState == .searching { ProgressView() }
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)

                    Button("Yeniden ara") { Task { await remote.findLamp() } }
                        .disabled(remote.lampState == .searching)
                    }
                    .listRowBackground(Palette.surface)
                }

                Section {
                    Button {
                        if remote.automationReminder == nil, let url = Shortcuts.url {
                            openURL(url)
                        } else {
                            isShowingGuide = true
                        }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            IconTile(systemName: "square.on.square", background: Palette.shortcuts, foreground: .white)
                            Text("Kısayollar otomasyonu")
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(automationValue)
                                .foregroundStyle(remote.automationReminder == nil ? Palette.textSecondary : Palette.accent)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .listRowBackground(Palette.surface)
                } header: {
                    Text("Her sabah")
                } footer: {
                    Text("Saati ve günleri Kısayollar’da seç: uyanmak istediğin saatten \(remote.schedule.durationMinutes) dk önce.")
                }

                Section("Gün batımı") {
                    Picker(selection: $remote.schedule.sunsetMinutes) {
                        ForEach(SunriseSchedule.durationOptions, id: \.self) { minutes in
                            Text("\(minutes) dk").tag(minutes)
                        }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            IconTile(systemName: "sunset.fill", background: Color(hex: 0xFF6A2B))
                            Text("Sönme süresi")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.textSecondary)
                    .listRowBackground(Palette.surface)
                }

                Section {
                    if let url = Self.sourceURL {
                        Link(destination: url) {
                            HStack {
                                Text("Kaynak kodu (GitHub)").foregroundStyle(Palette.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Palette.textTertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .listRowBackground(Palette.surface)
                    }
                } footer: {
                    Text("Sunrise Lamp \(version)")
                }
            }
            .font(Typography.body)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $isShowingGuide) {
                AutomationGuideSheet(minutes: remote.schedule.durationMinutes) { remote.confirmAutomation() }
            }
        }
    }

    private var automationValue: String {
        switch remote.automationReminder {
        case nil: "Kurulu"
        case .setup: "Kur"
        case .shift: "Güncelle"
        }
    }

    private var lampText: String {
        switch remote.lampState {
        case .unknown: "Henüz aranmadı"
        case .searching: "Ağda aranıyor…"
        case .found(let lamp): "Bağlı · \(lamp.ip)"
        case .notFound: "Bulunamadı. Aynı Wi-Fi ve Yerel Ağ izni gerekli."
        }
    }

    private var lampColor: Color {
        switch remote.lampState {
        case .found: Palette.success
        case .notFound: Palette.danger
        case .unknown, .searching: Palette.textSecondary
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
