import SunriseCore
import SwiftUI

/// The second tab: the lamp as a plain smart light.
struct LightView: View {
    @Bindable var remote: LampRemote

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    FailureBanner(status: remote.status)
                    orb
                        .padding(.top, Spacing.xl)
                    BrightnessBar(value: $remote.light.brightness, tint: lightColor)
                        .padding(.top, Spacing.xxl)
                    tones
                        .padding(.top, Spacing.xl)
                    scenes
                        .padding(.top, Spacing.xxl)
                }
                .padding(.horizontal, Spacing.xl - Spacing.xs)
                .padding(.bottom, Spacing.xl)
                .frame(maxWidth: Layout.maxContentWidth)
                .frame(maxWidth: .infinity)
                .animation(Motion.standard, value: remote.status)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Palette.background)
            .navigationTitle("Işık")
            .trailingBarItem {
                // Toolbars draw a plain Toggle as a text button; force the switch.
                Toggle("Lamba", isOn: power)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(Palette.success)
                    .fixedSize()
            }
            .sensoryFeedback(.selection, trigger: remote.light.kelvin)
        }
    }

    private var lightColor: Color { Color(rgb: remote.light.displayRGB) }

    private var power: Binding<Bool> {
        Binding(get: { remote.isOn }, set: { on in Task { await remote.setPower(on) } })
    }

    private var orb: some View {
        let brightness = Double(remote.light.brightness) / 100
        return VStack(spacing: Spacing.lg) {
            Group {
                if remote.isOn {
                    Circle()
                        .fill(Palette.orb(lightColor))
                        .shadow(color: lightColor.opacity(0.25 + 0.5 * brightness), radius: 20 + 30 * brightness)
                        .opacity(0.55 + 0.45 * brightness)
                } else {
                    Circle()
                        .fill(Palette.surfaceRaised)
                        .overlay(Circle().strokeBorder(Palette.border))
                }
            }
            .frame(width: Layout.lightOrb, height: Layout.lightOrb)
            .animation(Motion.standard, value: remote.light)
            .animation(Motion.standard, value: remote.isOn)
            .accessibilityHidden(true)

            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.title.monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text(remote.isOn ? "Yeelight · %\(remote.light.brightness)" : "Yeelight")
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var title: String {
        guard remote.isOn else { return "Kapalı" }
        switch remote.light.mode {
        case .white: return "\(String(remote.light.kelvin)) K"
        case .color: return "Renkli"
        }
    }

    private var tones: some View {
        HStack(spacing: 0) {
            ForEach(LightPreset.tones, id: \.self) { kelvin in
                let selected = remote.isOn && remote.light.mode == .white && remote.light.kelvin == kelvin
                Button {
                    remote.light.mode = .white
                    remote.light.kelvin = kelvin
                } label: {
                    Circle()
                        .fill(Palette.kelvin(kelvin))
                        .frame(width: Layout.tone, height: Layout.tone)
                        .selectionRing(selected)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(kelvin) Kelvin")
                .accessibilityAddTraits(selected ? .isSelected : [])
                Spacer(minLength: 0)
            }
            ColorPicker("Renk seç", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(Layout.tone / 28)
                .frame(width: Layout.tone, height: Layout.tone)
                .selectionRing(remote.isOn && remote.light.mode == .color)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(rgb: remote.light.rgb) },
            set: { color in
                guard let rgb = color.rgbValue else { return }
                remote.light.rgb = rgb
                remote.light.mode = .color
            }
        )
    }

    private var scenes: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)], spacing: Spacing.md) {
            ForEach(LightPreset.all) { preset in
                SceneTile(
                    name: preset.name,
                    detail: "\(String(preset.setting.kelvin)) K · %\(preset.setting.brightness)",
                    symbol: preset.symbol,
                    chip: Color(rgb: preset.setting.displayRGB)
                ) {
                    remote.light = preset.setting
                }
            }
            SceneTile(
                name: "Gün batımı",
                detail: "\(remote.schedule.sunsetMinutes) dk · söner",
                symbol: "sunset",
                chip: Color(hex: 0xFF6A2B)
            ) {
                Task { await remote.perform(.sunset) }
            }
        }
    }
}

private struct SceneTile: View {
    let name: String
    let detail: String
    let symbol: String
    let chip: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                IconTile(systemName: symbol, background: chip)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(name)
                        .font(Typography.callout.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(detail)
                        .font(Typography.small)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: Layout.sceneHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.border))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}

/// A thick bar you drag anywhere along to set brightness.
private struct BrightnessBar: View {
    @Binding var value: Int
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.lg).fill(Palette.surfaceRaised)
                LinearGradient(colors: [tint.opacity(0.33), tint.opacity(0.67)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * CGFloat(value) / 100)
                HStack {
                    Image(systemName: "sun.max")
                    Spacer()
                    Text("%\(value)")
                        .font(Typography.headline.monospacedDigit())
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Spacing.lg + 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let fraction = drag.location.x / max(proxy.size.width, 1)
                    value = LightSetting.brightnessRange.clamped(Int((fraction * 100).rounded()))
                }
            )
        }
        .frame(height: Layout.actionHeight)
        .accessibilityElement()
        .accessibilityLabel("Parlaklık")
        .accessibilityValue("Yüzde \(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = LightSetting.brightnessRange.clamped(value + 10)
            case .decrement: value = LightSetting.brightnessRange.clamped(value - 10)
            @unknown default: break
            }
        }
        .sensoryFeedback(.selection, trigger: value / 10)
    }
}

private extension ClosedRange where Bound == Int {
    func clamped(_ value: Int) -> Int { Swift.min(Swift.max(value, lowerBound), upperBound) }
}

private extension View {
    func selectionRing(_ selected: Bool) -> some View {
        overlay(Circle().strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2).padding(-5))
            .animation(Motion.standard, value: selected)
    }
}
