import SwiftUI

struct ContentView: View {
    @AppStorage(OrbitTheme.displayFontScaleKey) private var displayFontScale = 1.0
    @State private var selectedPage: NavigationPage = .dashboard
    @State private var backendClient = OrbitBackendClient()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selectedPage: $selectedPage)

            ZStack {
                AppBackgroundGradient()
                    .ignoresSafeArea()

                GridBackground()
                    .ignoresSafeArea()

                ScanlineOverlay()
                    .ignoresSafeArea()

                Group {
                    switch selectedPage {
                    case .dashboard:
                        DashboardView()
                    case .chat:
                        ChatView()
                    case .agents:
                        AgentsView()
                    case .workflows:
                        PlaceholderView(title: "WORKFLOWS", subtitle: "Visual workflow editor coming soon", icon: "arrow.triangle.branch")
                    case .codex:
                        CodexTutorialView()
                    case .console:
                        ConsoleView()
                    case .settings:
                        SettingsView()
                    }
                }
                .id(displayFontScale)
            }
        }
        .environment(backendClient)
        .background(AppBackgroundGradient())
        .preferredColorScheme(.dark)
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(OrbitTheme.neonPurple.opacity(0.4))
                .neonGlow(OrbitTheme.neonPurple, radius: 10)

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(OrbitTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(OrbitTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
