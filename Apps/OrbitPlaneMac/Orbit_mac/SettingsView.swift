import SwiftUI

struct SettingsView: View {
    @AppStorage(OrbitTheme.displayFontScaleKey) private var displayFontScale = 1.0

    private let presets: [(label: String, value: Double)] = [
        ("COMPACT", 0.9),
        ("NORMAL", 1.0),
        ("LARGE", 1.14),
        ("XL", 1.26),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHeader()

                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionLabel(title: "DISPLAY TYPE")

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.label) { preset in
                            SettingsPresetButton(
                                title: preset.label,
                                isSelected: abs(displayFontScale - preset.value) < 0.01
                            ) {
                                displayFontScale = preset.value
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("FONT SCALE")
                                .font(OrbitTheme.labelFont(10, weight: .semibold))
                                .tracking(OrbitTheme.labelTracking)
                                .foregroundStyle(OrbitTheme.textMuted)

                            Spacer()

                            Text("\(Int((displayFontScale * 100).rounded()))%")
                                .font(OrbitTheme.monoFont(12, weight: .semibold))
                                .foregroundStyle(OrbitTheme.neonCyan)
                        }

                        Slider(value: $displayFontScale, in: 0.82...1.34, step: 0.02)
                            .tint(OrbitTheme.neonCyan)

                        HStack {
                            Text("82%")
                            Spacer()
                            Text("134%")
                        }
                        .font(OrbitTheme.labelFont(9, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(OrbitTheme.textMuted)
                    }
                    .padding(14)
                    .background(OrbitTheme.bgCard.opacity(0.72))
                    .overlay(Rectangle().stroke(OrbitTheme.border, lineWidth: 1))

                    SettingsPreview(scale: displayFontScale)

                    HStack {
                        Button {
                            displayFontScale = 1.0
                        } label: {
                            Label("RESET", systemImage: "arrow.counterclockwise")
                                .font(OrbitTheme.labelFont(11, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(OrbitTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .overlay(Rectangle().stroke(OrbitTheme.borderStrong, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()

                        Spacer()
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OrbitTheme.bgDeep.opacity(0.58))
    }
}

private struct SettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(OrbitTheme.displayFont(18, weight: .semibold))
                    .foregroundStyle(OrbitTheme.neonCyan)

                Text("SETTINGS")
                    .font(OrbitTheme.displayFont(24, weight: .bold))
                    .tracking(3.2)
                    .foregroundStyle(OrbitTheme.textPrimary)
            }

            Text("Local display preferences for the OrbitPlane control surface.")
                .font(OrbitTheme.bodyFont(13))
                .foregroundStyle(OrbitTheme.textSecondary)
        }
    }
}

private struct SettingsSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(OrbitTheme.labelFont(10, weight: .semibold))
            .tracking(OrbitTheme.labelTracking)
            .foregroundStyle(OrbitTheme.textMuted)
    }
}

private struct SettingsPresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OrbitTheme.labelFont(11, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(isSelected ? OrbitTheme.neonCyan : OrbitTheme.textSecondary)
                .frame(minWidth: 82)
                .frame(height: 34)
                .background(isSelected ? OrbitTheme.neonCyan.opacity(0.055) : OrbitTheme.bgCard.opacity(0.64))
                .overlay(Rectangle().stroke(isSelected ? OrbitTheme.neonCyan.opacity(0.55) : OrbitTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

private struct SettingsPreview: View {
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionLabel(title: "PREVIEW")

            VStack(alignment: .leading, spacing: 8) {
                Text("CODEX // TEACHING NOTE")
                    .font(OrbitTheme.labelFont(10, weight: .semibold))
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.neonCyan)

                Text("教学案例：MCP、Python 和 Skill 是怎样配合的")
                    .font(OrbitTheme.bodyFont(18, weight: .semibold))
                    .foregroundStyle(OrbitTheme.textPrimary)

                Text("字体比例会影响 OrbitTheme 的 display、label、mono 和 body 字体。当前设置会保存到本机 UserDefaults。")
                    .font(OrbitTheme.bodyFont(13))
                    .lineSpacing(4)
                    .foregroundStyle(OrbitTheme.textSecondary)

                Text("scale=\(String(format: "%.2f", scale)) · event flags: STEP / DIFF / TEACH")
                    .font(OrbitTheme.monoFont(11, weight: .medium))
                    .foregroundStyle(OrbitTheme.textMuted)
            }
            .padding(16)
            .background(OrbitTheme.bgVoid.opacity(0.72))
            .overlay(Rectangle().stroke(OrbitTheme.border, lineWidth: 1))
        }
    }
}
