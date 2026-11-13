import SunriseCore
import SwiftUI

/// The first tab: what tomorrow's sunrise looks like, a way to change it and
/// a one-minute test. Any pending Shortcuts step sits on top until done.
struct SunriseView: View {
    let remote: LampRemote

    @State private var isEditing = false
    @State private var isShowingGuide = false
    @State private var testEndsAt: Date?
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let reminder = remote.automationReminder {
                        ReminderCard(reminder: reminder, onSetup: { isShowingGuide = true }, onDone: confirm)
                            .padding(.top, Spacing.lg)
                            .transition(.opacity)
                    }
                    FailureBanner(status: remote.status)
                        .padding(.top, Spacing.lg)

                    SunHero(endKelvin: remote.schedule.endKelvin)
                        .frame(height: hasReminder ? Layout.heroCompactHeight : Layout.heroHeight)
                        .padding(.top, hasReminder ? Spacing.xl : Spacing.xxl)
                        // The glow reaches up behind the cards; draw it under them.
                        .zIndex(-1)

                    summary
                        .padding(.top, Spacing.xl)

                    editCard
                        .padding(.top, Spacing.xxl)
                }
                .padding(.horizontal, Spacing.xl - Spacing.xs)
                .frame(maxWidth: Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .animation(Motion.layout, value: hasReminder)
                .animation(Motion.standard, value: remote.status)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }
            .background(Palette.background)
            .navigationTitle("Gündoğumu")
            .trailingBarItem { LampPill(remote: remote) }
            .sheet(isPresented: $isEditing) {
                EditSunriseSheet(remote: remote)
            }
            .sheet(isPresented: $isShowingGuide) {
                AutomationGuideSheet(minutes: remote.schedule.durationMinutes, onDone: confirm)
            }
        }
    }

    private var hasReminder: Bool { remote.automationReminder != nil }

    private func confirm() {
        withAnimation(Motion.layout) { remote.confirmAutomation() }
    }

    private var summary: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(String(remote.schedule.durationMinutes))
                    .font(.system(size: heroSize, weight: .light, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text("dk")
                    .font(Typography.title.weight(.light))
            }
            .foregroundStyle(Palette.textPrimary)
            Text(description)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(remote.schedule.durationMinutes) dakikalık gündoğumu. \(description)")
    }

    private var description: String {
        let schedule = remote.schedule
        return "Kırmızı ışıkla başlar, \(schedule.endLight.phrase) (\(String(schedule.endKelvin)) K) kadar aydınlanır."
    }

    private var editCard: some View {
        Button {
            isEditing = true
        } label: {
            HStack(spacing: Spacing.md) {
                Capsule()
                    .fill(Palette.sunrise(endKelvin: remote.schedule.endKelvin))
                    .frame(height: Layout.strip)
                    .accessibilityHidden(true)
                Text("Düzenle")
                    .font(Typography.callout.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: Layout.actionHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.border))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Gündoğumunu düzenle")
    }

    /// The test button, and once the automation is set, a quiet note that
    /// Shortcuts takes care of the mornings.
    private var footer: some View {
        VStack(spacing: 0) {
            testButton
            if !hasReminder {
                Button {
                    if let url = Shortcuts.url { openURL(url) }
                } label: {
                    Label("Her sabah Kısayollar otomasyonu başlatır", systemImage: "checkmark.circle.fill")
                        .font(Typography.small)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(minHeight: Layout.touchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Kısayollar’da otomasyonu açar")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.xl - Spacing.xs)
        .padding(.bottom, hasReminder ? Spacing.lg : 0)
        .frame(maxWidth: Layout.maxContentWidth)
        .animation(Motion.layout, value: hasReminder)
    }

    private var testButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let playing = testEndsAt.map { $0 > context.date } ?? false
            Button {
                Task {
                    if await remote.perform(.test) { testEndsAt = .now.addingTimeInterval(60) }
                }
            } label: {
                Label(playing ? "Lambada oynatılıyor…" : "Şimdi dene · 1 dk", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(muted: hasReminder))
            .disabled(remote.isWorking || playing)
        }
        .sensoryFeedback(trigger: remote.status) { _, status in
            switch status {
            case .success: .success
            case .failure: .error
            case .idle, .working: nil
            }
        }
    }
}

/// A sun half below the horizon, its core the colour the sunrise ends on.
/// Its glow is not clipped: it reaches up behind everything above it, to
/// the top edge of the screen.
private struct SunHero: View {
    let endKelvin: Int

    var body: some View {
        // Both shapes hang off a flexible frame so their size never pushes
        // the layout; each is masked to its half above the horizon.
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                EllipticalGradient(
                    colors: [Palette.dawnAmber.opacity(0.38), Palette.dawnOrange.opacity(0.14), .clear],
                    center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5
                )
                .frame(width: Layout.sunGlowWidth, height: Layout.sunGlowHeight)
                .aboveHorizon(height: Layout.sunGlowHeight)
            }
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(Palette.sun(endKelvin: endKelvin))
                    .frame(width: Layout.sun, height: Layout.sun)
                    .shadow(color: Palette.dawnAmber.opacity(0.35), radius: 40)
                    .aboveHorizon(height: Layout.sun)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Palette.textPrimary.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            // The glow spreads far past this frame; it must not catch taps.
            .allowsHitTesting(false)
            .animation(Motion.layout, value: endKelvin)
            .accessibilityHidden(true)
    }
}

private extension View {
    /// Centres a shape on the bottom edge and shows only its top half, plus
    /// room above for its shadow.
    func aboveHorizon(height: CGFloat) -> some View {
        mask(alignment: .top) {
            Rectangle()
                .frame(width: height + 400, height: height / 2 + 200)
                .offset(y: -200)
        }
        .offset(y: height / 2)
    }
}
