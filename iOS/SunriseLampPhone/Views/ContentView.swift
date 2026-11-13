import SunriseCore
import SwiftUI

struct ContentView: View {
    @Bindable var remote: LampRemote

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    AlarmCard(remote: remote)
                    LampCard(remote: remote)
                    LightCard(remote: remote)
                    StatusBanner(status: remote.status)
                    AutomationCard(remote: remote)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .animation(Motion.standard, value: remote.status)
            }
            .background(Palette.background)
            .navigationTitle("Sunrise Lamp")
            .task {
                if remote.lamp == nil { await remote.findLamp() }
            }
            .sensoryFeedback(trigger: remote.status) { _, status in
                switch status {
                case .success: .success
                case .failure: .error
                case .idle, .working: nil
                }
            }
        }
        .tint(Palette.accent)
    }
}

// MARK: - Alarm

private struct AlarmCard: View {
    @Bindable var remote: LampRemote

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Uyanma")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(remote.schedule.wakeTimeText)
                        .font(Typography.wakeTime)
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                DatePicker("Uyanma saati", selection: $remote.wakeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            Capsule()
                .fill(Palette.sunrise(endKelvin: remote.schedule.endKelvin))
                .frame(height: Layout.timelineHeight)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Doğuş süresi")
                    .font(Typography.label)
                    .foregroundStyle(Palette.textPrimary)
                Picker("Doğuş süresi", selection: $remote.schedule.durationMinutes) {
                    ForEach(SunriseSchedule.durationOptions, id: \.self) { minutes in
                        Text("\(minutes) dk").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Bitiş ışığı")
                        .font(Typography.label)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(String(remote.schedule.endKelvin)) K · \(endLightName)")
                        .font(Typography.label.monospacedDigit())
                        .foregroundStyle(Palette.textSecondary)
                        .contentTransition(.numericText())
                }
                Slider(value: endKelvin, in: Double(SunriseSchedule.endKelvinRange.lowerBound)...Double(SunriseSchedule.endKelvinRange.upperBound), step: 100) {
                    Text("Bitiş ışığı")
                }
                .accessibilityValue("\(String(remote.schedule.endKelvin)) Kelvin, \(endLightName)")
            }

            Text("\(remote.automationTime)'da kızıl ışıkla başlar, \(remote.schedule.wakeTimeText)'da \(String(remote.schedule.endKelvin)) K beyaza ulaşır.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var endKelvin: Binding<Double> {
        Binding(
            get: { Double(remote.schedule.endKelvin) },
            set: { remote.schedule.endKelvin = Int($0.rounded()) }
        )
    }

    private var endLightName: String {
        switch remote.schedule.endKelvin {
        case ..<3500: "sıcak beyaz"
        case ..<4600: "sabah güneşi"
        case ..<5600: "gün ışığı"
        default: "soğuk beyaz"
        }
    }
}

// MARK: - Lamp

private struct LampCard: View {
    let remote: LampRemote

    private let columns = [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                tile("Aç", icon: "lightbulb", action: .on)
                tile("Kapat", icon: "lightbulb.slash", action: .off)
                tile("Gün batımı", icon: "sunset", action: .sunset)
                tile("Test · 1 dk", icon: "sunrise", action: .test)
            }
            .disabled(remote.isWorking || remote.lampState == .searching)

            if case .notFound = remote.lampState {
                Text("Lamba açık ve telefonla aynı Wi-Fi'da olmalı. Yerel ağ izni sorulduysa izin ver: Ayarlar › Gizlilik ve Güvenlik › Yerel Ağ.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lightbulb.led.fill")
                .font(.title2)
                .foregroundStyle(remote.lamp == nil ? Palette.textSecondary : Palette.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Yeelight")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: Layout.statusDot, height: Layout.statusDot)
                        .accessibilityHidden(true)
                    Text(statusText)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            Spacer()

            if case .searching = remote.lampState {
                ProgressView()
                    .frame(width: Layout.touchTarget, height: Layout.touchTarget)
            } else {
                Button {
                    Task { await remote.findLamp() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .frame(width: Layout.touchTarget, height: Layout.touchTarget)
                        .background(Palette.surfaceMuted, in: Circle())
                }
                .foregroundStyle(Palette.textPrimary)
                .accessibilityLabel("Lambayı yeniden ara")
            }
        }
    }

    private func tile(_ title: String, icon: String, action: LampRemote.Action) -> some View {
        Button {
            Task { await remote.perform(action) }
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                Text(title)
            }
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(TileButtonStyle())
    }

    private var statusText: String {
        switch remote.lampState {
        case .unknown: "Henüz aranmadı"
        case .searching: "Ağda aranıyor…"
        case .found(let lamp): "Bağlı · \(lamp.ip)"
        case .notFound: "Bulunamadı"
        }
    }

    private var dotColor: Color {
        switch remote.lampState {
        case .found: Palette.success
        case .notFound: Palette.danger
        case .unknown, .searching: Palette.textSecondary
        }
    }
}

// MARK: - Status

private struct StatusBanner: View {
    let status: LampRemote.Status

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .working(let text):
            row(text, icon: nil, color: Palette.textSecondary)
        case .success(let text):
            row(text, icon: "checkmark.circle.fill", color: Palette.success)
        case .failure(let text):
            row(text, icon: "exclamationmark.triangle.fill", color: Palette.danger)
        }
    }

    private func row(_ text: String, icon: String?, color: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon).foregroundStyle(color)
            } else {
                ProgressView()
            }
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Automation

private struct AutomationCard: View {
    let remote: LampRemote
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Her sabah kendiliğinden")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text("iPhone, Kısayollar otomasyonuyla lambayı kendisi başlatır. Mac gerekmez.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                step(1, "Kısayollar › Otomasyon › Yeni Otomasyon › Günün Saati")
                step(2, "Saati **\(remote.automationTime)** yap, günleri seç, **Hemen Çalıştır**'ı işaretle")
                step(3, "**Gün doğumunu başlat** eylemini ekle (Sunrise Lamp)")
                step(4, "İstersen ardına **Müzik Çal** ekle")
            }

            Button {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("Kısayollar'ı aç", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(PrimaryButtonStyle())

            Label("Siri'ye de söyleyebilirsin: “Sunrise Lamp ile ışığı kapat”", systemImage: "waveform")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text("\(number)")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(Palette.accent)
                .frame(width: Layout.stepBadge, height: Layout.stepBadge)
                .background(Palette.accent.opacity(0.16), in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
