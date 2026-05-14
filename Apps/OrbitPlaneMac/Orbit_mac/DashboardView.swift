import SwiftUI

struct DashboardView: View {
    @State private var pulseAnimation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HomeDeckHeader(pulseAnimation: pulseAnimation)
                HomeStatusStrip()

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    DesignSpecTile(
                        label: "SIGNAL",
                        title: "Live deck",
                        value: "42ms",
                        caption: "UPLINK STABLE",
                        color: OrbitTheme.neonGreen,
                        glyph: "●"
                    )

                    DesignSpecTile(
                        label: "REPLAY",
                        title: "Pinned runs",
                        value: "08",
                        caption: "LOCAL REVIEW",
                        color: OrbitTheme.neonPurple,
                        glyph: "◌"
                    )

                    DesignSpecTile(
                        label: "PAGED",
                        title: "Operator checks",
                        value: "02",
                        caption: "ACTION REQUIRED",
                        color: OrbitTheme.neonPink,
                        glyph: "▲"
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    HomeTelemetryPanel()
                    HomeActionPanel()
                        .frame(width: 300)
                }
            }
            .padding(20)
        }
        .onAppear { pulseAnimation = true }
    }
}

struct HomeDeckHeader: View {
    let pulseAnimation: Bool

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 18) {
                OrbitPlaneMark(size: 66)

                VStack(alignment: .leading, spacing: 10) {
                    Text("┌─ AGT.FLEET / SECTOR 7G ─┐")
                        .font(OrbitTheme.labelFont(10, weight: .medium))
                        .tracking(2.4)
                        .foregroundStyle(OrbitTheme.textMuted)

                    HStack(spacing: 8) {
                        Text("ORBIT")
                        Text("◆")
                            .font(OrbitTheme.monoFont(15, weight: .bold))
                            .foregroundStyle(OrbitTheme.neonPurple)
                            .neonGlow(OrbitTheme.neonPurple, radius: 5)
                        Text("PLANE")
                    }
                    .font(OrbitTheme.displayFont(38))
                    .tracking(3.4)
                    .foregroundStyle(OrbitTheme.textPrimary)

                    HStack(spacing: 8) {
                        OrbitTag(text: "MISSION CONTROL", color: OrbitTheme.neonCyan)
                        OrbitTag(text: "NATIVE", color: OrbitTheme.neonGreen)
                        OrbitTag(text: "KEYCHAIN", color: OrbitTheme.neonOrange)
                    }

                    HStack(spacing: 7) {
                        Text("Control plane for observing, reviewing, and teaching agent runtime tasks")
                            .font(OrbitTheme.monoFont(13))
                            .foregroundStyle(OrbitTheme.textSecondary)
                        BlinkingCursor(color: OrbitTheme.neonCyan, size: 12)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background {
                ZStack {
                    OrbitTheme.bgSurface.opacity(0.92)
                    DotGridBackground(dotColor: OrbitTheme.borderStrong, spacing: 20, opacity: 0.55)
                    LinearGradient(
                        colors: [
                            OrbitTheme.neonCyan.opacity(0.08),
                            Color.clear,
                            OrbitTheme.neonPurple.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .stroke(OrbitTheme.border, lineWidth: 1)
            )
            .cornerBrackets(color: OrbitTheme.neonCyan.opacity(0.72), length: 14)

            CompactScopePanel(pulseAnimation: pulseAnimation)
                .frame(width: 260, height: 190)
        }
    }
}

struct CompactScopePanel: View {
    let pulseAnimation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NAV.SCOPE")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.neonCyan)
                Spacer()
                HStack(spacing: 5) {
                    SignalGlyph(symbol: "●", color: OrbitTheme.neonGreen, size: 8)
                        .scaleEffect(pulseAnimation ? 1.12 : 1)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulseAnimation)
                    Text("LIVE")
                        .font(OrbitTheme.labelFont(9, weight: .medium))
                        .tracking(1.3)
                        .foregroundStyle(OrbitTheme.neonGreen)
                }
            }

            RadarScope()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrbitTheme.bgVoid.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: OrbitTheme.radiusSoft)
                        .stroke(OrbitTheme.borderStrong.opacity(0.75), lineWidth: 1)
                )
        }
        .padding(12)
        .background(OrbitTheme.bgVoid.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                .stroke(OrbitTheme.border, lineWidth: 1)
        )
        .cornerBrackets(color: OrbitTheme.neonGreen.opacity(0.72))
    }
}

struct HomeStatusStrip: View {
    var body: some View {
        HStack(spacing: 10) {
            MiniReadout(label: "UPLINK", value: "STABLE · 42MS", color: OrbitTheme.neonGreen)
            MiniReadout(label: "TRACE", value: "LOCAL", color: OrbitTheme.neonCyan)
            MiniReadout(label: "VAULT", value: "KEYCHAIN ONLY", color: OrbitTheme.neonOrange)
            MiniReadout(label: "MODE", value: "APPLE NATIVE", color: OrbitTheme.textSecondary)
        }
        .padding(10)
        .background(OrbitTheme.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                .stroke(OrbitTheme.border, lineWidth: 1)
        )
    }
}

struct MiniReadout: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            SignalGlyph(symbol: "●", color: color, size: 8)
            Text(label)
                .font(OrbitTheme.labelFont(9, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(OrbitTheme.textMuted)
            Text(value)
                .font(OrbitTheme.labelFont(9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(OrbitTheme.bgDeep)
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.radiusSoft)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct DesignSpecTile: View {
    let label: String
    let title: String
    let value: String
    let caption: String
    let color: Color
    let glyph: String

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SignalGlyph(symbol: glyph, color: color, size: 11)
                Spacer()
                Text(label)
                    .font(OrbitTheme.labelFont(9, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(OrbitTheme.textMuted)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(value)
                    .font(OrbitTheme.displayFont(34, weight: .bold))
                    .foregroundStyle(OrbitTheme.textPrimary)
                Text(title.uppercased())
                    .font(OrbitTheme.labelFont(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(color)
            }

            Text(caption)
                .font(OrbitTheme.labelFont(10, weight: .medium))
                .tracking(1.3)
                .foregroundStyle(OrbitTheme.textMuted)
        }
        .padding(16)
        .frame(minHeight: 138, alignment: .topLeading)
        .cyberCard(isHovered: isHovered)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(color.opacity(0.9))
                .frame(height: 1)
                .neonGlow(color, radius: 4)
        }
        .cornerBrackets(color: color.opacity(0.58), length: 8)
        .onHover { isHovered = $0 }
    }
}

struct HomeTelemetryPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TERRAIN.STAT // DESIGN SIGNAL")
                    .font(OrbitTheme.labelFont())
                    .tracking(OrbitTheme.labelTracking)
                    .foregroundStyle(OrbitTheme.neonCyan)
                Spacer()
                Text("WINDOW 24H")
                    .font(OrbitTheme.labelFont(9, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(OrbitTheme.textMuted)
            }

            ZStack {
                DotGridBackground(dotColor: OrbitTheme.borderStrong, spacing: 30, opacity: 0.38)
                HorizonRidge(phase: 0)
                    .fill(OrbitTheme.neonCyan.opacity(0.12))
                HorizonRidge(phase: 0)
                    .stroke(OrbitTheme.neonCyan.opacity(0.72), lineWidth: 1)
                    .neonGlow(OrbitTheme.neonCyan, radius: 4)
                HorizonRidge(phase: 18)
                    .stroke(OrbitTheme.neonPurple.opacity(0.45), lineWidth: 1)
            }
            .frame(height: 150)
            .background(OrbitTheme.bgVoid.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .stroke(OrbitTheme.borderStrong.opacity(0.75), lineWidth: 1)
            )
            .cornerBrackets(color: OrbitTheme.neonCyan.opacity(0.55))
        }
        .padding(16)
        .cyberCard()
    }
}

struct HorizonRidge: Shape {
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let points: [CGFloat] = [0.74, 0.64, 0.72, 0.52, 0.68, 0.42, 0.60, 0.34, 0.56, 0.30, 0.50, 0.40, 0.36, 0.45, 0.28, 0.38, 0.44, 0.32, 0.40]
        let step = rect.width / CGFloat(points.count - 1)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))

        for index in points.indices {
            let x = CGFloat(index) * step
            let offset = sin((CGFloat(index) + phase) * 0.6) * 10
            path.addLine(to: CGPoint(x: x, y: rect.height * points[index] + offset))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct HomeActionPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONTROL // LOCAL")
                .font(OrbitTheme.labelFont())
                .tracking(OrbitTheme.labelTracking)
                .foregroundStyle(OrbitTheme.textMuted)

            VStack(spacing: 8) {
                QuickActionButton(title: "Open active runs", icon: "square.grid.2x2", color: OrbitTheme.neonCyan)
                QuickActionButton(title: "Review traces", icon: "clock.arrow.circlepath", color: OrbitTheme.neonPurple)
                QuickActionButton(title: "Field alerts", icon: "bell.badge", color: OrbitTheme.neonPink)
            }

            HStack(spacing: 6) {
                OrbitTag(text: "NATIVE", color: OrbitTheme.neonCyan)
                OrbitTag(text: "LOCAL", color: OrbitTheme.neonGreen)
            }
        }
        .padding(16)
        .cyberCard()
        .cornerBrackets(color: OrbitTheme.neonGreen.opacity(0.62))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(OrbitTheme.monoFont(11, weight: .medium))
                    .tracking(1.0)
                Spacer()
                Text("→")
                    .font(OrbitTheme.monoFont(12, weight: .bold))
            }
            .foregroundStyle(isHovered ? color : OrbitTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? color.opacity(0.08) : OrbitTheme.bgDeep)
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .stroke(isHovered ? color.opacity(0.25) : OrbitTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
    }
}
