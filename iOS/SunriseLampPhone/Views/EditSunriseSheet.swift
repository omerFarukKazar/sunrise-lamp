import SunriseCore
import SwiftUI

/// Changes the sunrise length and end light. While open, the lamp shows the
/// end light being picked; closing puts the lamp back as it was.
struct EditSunriseSheet: View {
    let remote: LampRemote

    @State private var draft: SunriseSchedule
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(remote: LampRemote) {
        self.remote = remote
        // An end light saved by an older version may sit between the options;
        // start from the nearest one so the lamp shows what is selected.
        var draft = remote.schedule
        draft.endKelvin = draft.endLight.kelvin
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    preview
                    endLightPicker
                    durationPicker
                }
                .padding(.horizontal, Spacing.xl - Spacing.xs)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
                .animation(Motion.standard, value: shiftHint)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.sheet)
            .navigationTitle("Gündoğumu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        remote.schedule = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationBackground(Palette.sheet)
        .onAppear { remote.preview(endKelvin: draft.endKelvin) }
        .onChange(of: draft.endKelvin) { _, kelvin in remote.preview(endKelvin: kelvin) }
        .onDisappear { Task { await remote.endPreview() } }
        .sensoryFeedback(.selection, trigger: draft)
    }

    private var preview: some View {
        VStack(spacing: Spacing.md) {
            Circle()
                .fill(Palette.orb(Palette.kelvin(draft.endKelvin)))
                .frame(width: Layout.previewOrb, height: Layout.previewOrb)
                .shadow(color: Palette.kelvin(draft.endKelvin).opacity(0.4), radius: 30)
                .animation(Motion.standard, value: draft.endKelvin)
                .accessibilityHidden(true)
            if remote.lamp != nil {
                HStack(spacing: Spacing.sm) {
                    PulsingDot(animated: !reduceMotion)
                    Text("Lambada önizleniyor")
                }
                .font(Typography.caption)
                .foregroundStyle(Palette.accent)
            }
        }
    }

    private var endLightPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("Bitiş ışığı")
            HStack(spacing: Spacing.sm) {
                ForEach(EndLight.all) { light in
                    let selected = draft.endLight == light
                    Button {
                        draft.endKelvin = light.kelvin
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(Palette.kelvin(light.kelvin))
                                .frame(width: Layout.endSwatch, height: Layout.endSwatch)
                                .overlay(Circle().strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2).padding(-5))
                                .padding(.vertical, Spacing.xs + 1)
                            Text(light.name)
                                .font(Typography.caption.weight(.medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(String(light.kelvin)) K")
                                .font(Typography.small.monospacedDigit())
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(light.name), \(light.kelvin) Kelvin")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("Süre")
            Picker("Gündoğumu süresi", selection: $draft.durationMinutes) {
                ForEach(SunriseSchedule.durationOptions, id: \.self) { minutes in
                    Text("\(minutes) dk").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)

            if let shiftHint {
                Label(shiftHint, systemImage: "clock")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.reminderBody)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md))
                    .transition(.opacity)
            }
        }
    }

    /// After saving, the sunrise screen asks the user to move the automation;
    /// this says so before they save.
    private var shiftHint: String? {
        guard case .shift(let from, let to) = AutomationReminder(
            confirmedMinutes: remote.automationMinutes, currentMinutes: draft.durationMinutes
        ) else { return nil }
        return "Kaydedince hatırlatacağım: otomasyonu \(abs(to - from)) dk \(to > from ? "erkene" : "geçe") almalısın."
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Typography.label.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PulsingDot: View {
    let animated: Bool
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(Palette.accent)
            .frame(width: 7, height: 7)
            .opacity(dim ? 0.35 : 1)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}
