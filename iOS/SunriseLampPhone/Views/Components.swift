import SunriseCore
import SwiftUI

enum Shortcuts {
    /// Opens the Shortcuts app on its Automation tab.
    static let url = URL(string: "shortcuts://automations")
}

/// Lamp connection in a pill; tapping it searches again.
struct LampPill: View {
    let remote: LampRemote

    var body: some View {
        Button {
            Task { await remote.findLamp() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if remote.lampState == .searching {
                    ProgressView().controlSize(.mini)
                } else {
                    Circle().fill(color).frame(width: Layout.statusDot, height: Layout.statusDot)
                }
                Text(text)
            }
            .font(Typography.small.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 30)
            .background(color.opacity(0.14), in: Capsule())
            .frame(minHeight: Layout.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(remote.lampState == .searching)
        .accessibilityHint("Lambayı yeniden arar")
    }

    private var text: String {
        switch remote.lampState {
        case .found: "Lamba bağlı"
        case .searching: "Aranıyor"
        case .notFound: "Lamba yok"
        case .unknown: "Lamba"
        }
    }

    private var color: Color {
        switch remote.lampState {
        case .found: Palette.success
        case .notFound: Palette.danger
        case .searching, .unknown: Palette.textSecondary
        }
    }
}

/// Stays on the sunrise screen until the user confirms the Shortcuts
/// automation matches the app.
struct ReminderCard: View {
    let reminder: AutomationReminder
    let onSetup: () -> Void
    let onDone: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                IconTile(systemName: "square.on.square", background: Palette.shortcuts, foreground: .white)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(message)
                        .font(Typography.callout)
                        .foregroundStyle(Palette.reminderBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Spacing.sm) {
                Button(primaryLabel, action: primary)
                    .buttonStyle(CompactButtonStyle(prominent: true))
                Button(doneLabel, action: onDone)
                    .buttonStyle(CompactButtonStyle())
            }
        }
        .padding(Spacing.lg)
        .background(Palette.reminderFill, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.reminderBorder))
    }

    private var title: String {
        switch reminder {
        case .setup: "Her sabah otomasyon başlatır"
        case .shift(let from, let to):
            "Otomasyonu \(abs(to - from)) dk \(to > from ? "erkene" : "geçe") al"
        }
    }

    private var message: String {
        switch reminder {
        case .setup(let minutes): "Kısayollar’da uyanmak istediğin saatten \(minutes) dk önceye kur."
        case .shift(let from, let to):
            "Süre \(from) dk’dan \(to) dk’ya \(to > from ? "çıktı" : "indi"). Uyanma saatin aynı kalsın."
        }
    }

    private var primaryLabel: String {
        if case .setup = reminder { return "Kur" }
        return "Otomasyonu aç"
    }

    private var doneLabel: String {
        if case .setup = reminder { return "Kurdum" }
        return "Yaptım"
    }

    private func primary() {
        if case .setup = reminder {
            onSetup()
        } else if let url = Shortcuts.url {
            openURL(url)
        }
    }
}

/// The steps to create the morning automation, with a way to open Shortcuts.
struct AutomationGuideSheet: View {
    let minutes: Int
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    step(1, "Kısayollar’da **Yeni Otomasyon › Günün Saati**")
                    step(2, "Uyanmak istediğin saatten **\(minutes) dk önceyi** ve günleri seç, **Hemen Çalıştır**")
                    step(3, "**Gün doğumunu başlat** eylemini ekle")
                }
                Spacer(minLength: 0)
                VStack(spacing: Spacing.sm) {
                    Button {
                        if let url = Shortcuts.url { openURL(url) }
                    } label: {
                        Label("Otomasyonu aç", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Kurdum") {
                        onDone()
                        dismiss()
                    }
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity, minHeight: Layout.touchTarget)
                }
            }
            .padding(Spacing.xl)
            .background(Palette.sheet)
            .navigationTitle("Otomasyonu kur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Palette.sheet)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text("\(number)")
                .font(Typography.label.weight(.bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28, height: 28)
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

/// Shows only failures; success is felt as a haptic instead.
struct FailureBanner: View {
    let status: LampRemote.Status

    var body: some View {
        if case .failure(let text) = status {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.danger)
                    .accessibilityHidden(true)
                Text(text)
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(Palette.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.md))
            .accessibilityElement(children: .combine)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
