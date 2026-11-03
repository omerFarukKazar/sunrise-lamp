import AppKit
import SunriseCore
import SwiftUI

struct SunriseView: View {
    @Bindable var model: SunriseModel

    var body: some View {
        VStack(spacing: Spacing.md) {
            HeroCard(model: model)
            ScheduleCard(model: model)
            LampCard(model: model)
            StatusBanner(status: model.status)
            if model.hasChanges {
                SaveSection(model: model)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            ActivityList(entries: Array(model.activity.prefix(3)))
            Footer()
        }
        .padding(Spacing.lg)
        .frame(width: Layout.panelWidth)
        .background(Palette.background)
        .animation(Motion.standard, value: model.hasChanges)
        .animation(Motion.standard, value: model.status)
        .task {
            if model.lamp == nil { await model.findLamp() }
        }
    }
}

// MARK: - Hero

private struct HeroCard: View {
    @Bindable var model: SunriseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Uyanma")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(model.schedule.wakeTimeText)
                        .font(Typography.wakeTime)
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                Toggle(isOn: $model.schedule.isEnabled) {
                    Text(model.schedule.isEnabled ? "Açık" : "Kapalı")
                        .font(Typography.label)
                        .foregroundStyle(model.schedule.isEnabled ? Palette.accent : Palette.textSecondary)
                }
                .toggleStyle(.switch)
                .tint(Palette.accent)
                .accessibilityLabel("Alarm")
            }

            Capsule()
                .fill(Palette.sunrise)
                .frame(height: Layout.timelineHeight)
                .opacity(model.schedule.isEnabled ? 1 : 0.35)
                .accessibilityHidden(true)

            HStack {
                Label(model.plan.start.timeText, systemImage: "sunrise")
                Spacer()
                Text("\(model.schedule.durationMinutes) dk")
                Spacer()
                Label(model.schedule.wakeTimeText, systemImage: "sun.max")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            Text(summary)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var summary: String {
        guard model.schedule.isEnabled else { return "Alarm kapalı." }
        return "\(model.plan.start.timeText)'da kızıl ışıkla başlar, \(model.schedule.wakeTimeText)'da gün ışığına ulaşır."
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - Schedule

private struct ScheduleCard: View {
    @Bindable var model: SunriseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Saat")
                    .font(Typography.label)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                DatePicker("Uyanma saati", selection: $model.wakeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Doğuş süresi")
                    .font(Typography.label)
                    .foregroundStyle(Palette.textPrimary)
                Picker("Doğuş süresi", selection: $model.schedule.durationMinutes) {
                    ForEach(SunriseSchedule.durationOptions, id: \.self) { minutes in
                        Text("\(minutes) dk").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Günler")
                    .font(Typography.label)
                    .foregroundStyle(Palette.textPrimary)
                HStack(spacing: Spacing.xs) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        DayChip(day: day, isOn: model.schedule.weekdays.contains(day)) {
                            model.toggle(day)
                        }
                    }
                }
                if model.schedule.weekdays.isEmpty {
                    Label("En az bir gün seç.", systemImage: "exclamationmark.circle")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.danger)
                }
            }
        }
        .card()
    }
}

private struct DayChip: View {
    let day: Weekday
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(Typography.caption.weight(.semibold))
                .frame(width: Layout.dayChip, height: Layout.dayChip)
                .foregroundStyle(isOn ? Palette.accent : Palette.textSecondary)
                .background(Circle().fill(isOn ? Palette.accent.opacity(0.16) : Palette.surfaceMuted))
                .overlay(Circle().strokeBorder(isOn ? Palette.accent : Palette.border))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(day.fullName)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Lamp

private struct LampCard: View {
    let model: SunriseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            row
            if case .notFound = model.lampState {
                Text("Lamba açık ve aynı Wi-Fi'da olmalı. İzin sorulmadıysa: Sistem Ayarları › Gizlilik ve Güvenlik › Yerel Ağ › Sunrise Lamp.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var row: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "lightbulb.led.fill")
                .font(.title2)
                .foregroundStyle(model.lamp == nil ? Palette.textSecondary : Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Yeelight")
                    .font(Typography.label)
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

            if case .searching = model.lampState {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await model.findLamp() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Lambayı yeniden ara")
                .help("Lambayı yeniden ara")
            }

            Button("Test") {
                Task { await model.runTest() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.isWorking)
            .help("1 dakikalık güneş doğuşu dene")
        }
    }

    private var statusText: String {
        switch model.lampState {
        case .unknown: "Henüz aranmadı"
        case .searching: "Ağda aranıyor…"
        case .found(let lamp): "Bağlı · \(lamp.ip)"
        case .notFound: "Bulunamadı"
        }
    }

    private var dotColor: Color {
        switch model.lampState {
        case .found: Palette.success
        case .notFound: Palette.danger
        case .unknown, .searching: Palette.textSecondary
        }
    }
}

// MARK: - Status and save

private struct StatusBanner: View {
    let status: SunriseModel.Status

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
                ProgressView().controlSize(.small)
            }
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
    }
}

private struct SaveSection: View {
    let model: SunriseModel

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Button("Kaydet") {
                Task { await model.save() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(model.isWorking || (model.schedule.isEnabled && model.schedule.weekdays.isEmpty))

            Text("Mac'i uyandırmak için macOS yönetici şifreni soracak.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Activity and footer

private struct ActivityList: View {
    let entries: [ActivityEntry]

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Son olaylar")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                ForEach(entries) { entry in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: icon(for: entry.kind))
                            .foregroundStyle(entry.kind == .failure ? Palette.danger : Palette.textSecondary)
                            .frame(width: 16)
                            .accessibilityHidden(true)
                        Text(entry.message)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(entry.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                    }
                    .font(Typography.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xs)
        }
    }

    private func icon(for kind: ActivityEntry.Kind) -> String {
        switch kind {
        case .sunrise: "sunrise.fill"
        case .test: "play.circle"
        case .info: "info.circle"
        case .failure: "exclamationmark.triangle"
        }
    }
}

private struct Footer: View {
    var body: some View {
        HStack {
            Text("Mac kapalıyken çalışmaz, uykudayken uyandırır.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Çık") { NSApplication.shared.terminate(nil) }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut("q")
        }
        .padding(.top, Spacing.xs)
    }
}
