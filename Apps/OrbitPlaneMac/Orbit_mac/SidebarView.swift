import SwiftUI

enum NavigationPage: String, CaseIterable {
    case dashboard = "Deck"
    case chat = "Runs"
    case agents = "Agents"
    case workflows = "Missions"
    case codex = "Codex"
    case console = "Console"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chat: return "bubble.left.and.bubble.right"
        case .agents: return "cpu"
        case .workflows: return "arrow.triangle.branch"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .console: return "terminal"
        case .settings: return "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedPage: NavigationPage

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                OrbitPlaneMark(size: 44)

                Text("ORBITPLANE")
                    .font(OrbitTheme.displayFont(16, weight: .bold))
                    .foregroundStyle(OrbitTheme.textPrimary)
                    .tracking(4)

                Text("MISSION CONTROL")
                    .font(OrbitTheme.labelFont(9, weight: .medium))
                    .foregroundStyle(OrbitTheme.textMuted)
                    .tracking(3)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            VStack(spacing: 4) {
                ForEach(NavigationPage.allCases.filter { $0 != .settings }, id: \.self) { page in
                    SidebarItem(page: page, isSelected: selectedPage == page) {
                        selectedPage = page
                    }
                }
            }

            Spacer()

            VStack(spacing: 4) {
                SidebarItem(page: .settings, isSelected: selectedPage == .settings) {
                    selectedPage = .settings
                }

                Divider()
                    .background(OrbitTheme.border)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                HStack(spacing: 6) {
                    SignalGlyph(symbol: "●", color: OrbitTheme.neonGreen, size: 8)

                    Text("UPLINK STABLE · 42MS")
                        .font(OrbitTheme.labelFont(10, weight: .medium))
                        .foregroundStyle(OrbitTheme.textMuted)

                    BlinkingCursor(color: OrbitTheme.neonGreen, size: 9)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 216)
        .background(OrbitTheme.bgSurface)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(OrbitTheme.border),
            alignment: .trailing
        )
    }
}

struct SidebarItem: View {
    let page: NavigationPage
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)

                Text(page.rawValue)
                    .font(OrbitTheme.monoFont(12, weight: isSelected ? .semibold : .regular))
                    .tracking(1.2)
                    .textCase(.uppercase)

                Spacer()

                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(OrbitTheme.neonCyan)
                        .frame(width: 2, height: 16)
                        .neonGlow(OrbitTheme.neonCyan, radius: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(
                isSelected
                    ? OrbitTheme.neonCyan
                    : (isHovered ? OrbitTheme.textPrimary : OrbitTheme.textSecondary)
            )
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .fill(
                        isSelected
                            ? OrbitTheme.neonCyan.opacity(0.055)
                            : (isHovered ? OrbitTheme.bgCard : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.radiusControl)
                    .stroke(
                        isSelected ? OrbitTheme.neonCyan.opacity(0.28) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
    }
}
