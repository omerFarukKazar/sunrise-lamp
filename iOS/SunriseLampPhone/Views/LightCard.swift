import SunriseCore
import SwiftUI

/// Manual light controls: presets, white or colour, brightness.
struct LightCard: View {
    @Bindable var remote: LampRemote

    private static let swatches: [Int] = [0xFF1E00, 0xFF4500, 0xFF8C00, 0xFFC93C, 0xFF5E8A, 0x8B5CF6, 0x3B82F6, 0x22C55E]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            presets
            Picker("Işık türü", selection: $remote.light.mode) {
                Text("Beyaz").tag(LightSetting.Mode.white)
                Text("Renk").tag(LightSetting.Mode.color)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch remote.light.mode {
            case .white: temperature
            case .color: colors
            }

            brightness
        }
        .card()
        .animation(Motion.standard, value: remote.light.mode)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(rgb: remote.light.displayRGB))
                .frame(width: Layout.lightPreview, height: Layout.lightPreview)
                .shadow(color: Color(rgb: remote.light.displayRGB).opacity(0.25 + 0.5 * Double(remote.light.brightness) / 100), radius: 12)
                .overlay(Circle().strokeBorder(Palette.border))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Işık")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text(summary)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
    }

    private var summary: String {
        switch remote.light.mode {
        case .white: "\(remote.light.kelvin) K · %\(remote.light.brightness)"
        case .color: "Renkli · %\(remote.light.brightness)"
        }
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(LightPreset.all) { preset in
                    let selected = remote.light == preset.setting
                    Button {
                        remote.light = preset.setting
                    } label: {
                        Label(preset.name, systemImage: preset.symbol)
                            .font(Typography.label)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: Layout.touchTarget)
                            .foregroundStyle(selected ? Palette.onAccent : Palette.textPrimary)
                            .background(selected ? Palette.accent : Palette.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private var temperature: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            valueRow("Renk sıcaklığı", "\(remote.light.kelvin) K")
            Capsule()
                .fill(Palette.kelvinScale(LightSetting.kelvinRange))
                .frame(height: Layout.timelineHeight)
                .accessibilityHidden(true)
            Slider(value: intBinding(\.kelvin), in: Double(LightSetting.kelvinRange.lowerBound)...Double(LightSetting.kelvinRange.upperBound), step: 100) {
                Text("Renk sıcaklığı")
            } minimumValueLabel: {
                Text("Sıcak").font(Typography.caption).foregroundStyle(Palette.textSecondary)
            } maximumValueLabel: {
                Text("Soğuk").font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .accessibilityValue("\(remote.light.kelvin) Kelvin")
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Renk")
                .font(Typography.label)
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: Spacing.sm) {
                ForEach(Self.swatches, id: \.self) { rgb in
                    Button {
                        remote.light.rgb = rgb
                    } label: {
                        Circle()
                            .fill(Color(rgb: rgb))
                            .padding(remote.light.rgb == rgb ? 4 : 0)
                            .overlay(Circle().strokeBorder(remote.light.rgb == rgb ? Palette.textPrimary : .clear, lineWidth: 2))
                            .frame(maxWidth: .infinity, minHeight: Layout.touchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Renk \(String(format: "%06X", rgb))")
                }
            }
            ColorPicker("Başka bir renk seç", selection: colorBinding, supportsOpacity: false)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var brightness: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            valueRow("Parlaklık", "%\(remote.light.brightness)")
            Slider(value: intBinding(\.brightness), in: 1...100, step: 1) {
                Text("Parlaklık")
            } minimumValueLabel: {
                Image(systemName: "sun.min").foregroundStyle(Palette.textSecondary)
            } maximumValueLabel: {
                Image(systemName: "sun.max.fill").foregroundStyle(Palette.accent)
            }
            .accessibilityValue("Yüzde \(remote.light.brightness)")
        }
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Typography.label)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(value)
                .font(Typography.label.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
                .contentTransition(.numericText())
        }
    }

    private func intBinding(_ keyPath: WritableKeyPath<LightSetting, Int>) -> Binding<Double> {
        Binding(
            get: { Double(remote.light[keyPath: keyPath]) },
            set: { remote.light[keyPath: keyPath] = Int($0.rounded()) }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(rgb: remote.light.rgb) },
            set: { if let rgb = $0.rgbValue { remote.light.rgb = rgb } }
        )
    }
}
