import SwiftUI

enum AgentStatus: String {
    case running = "Running"
    case idle = "Idle"
    case error = "Error"

    var color: Color {
        switch self {
        case .running: return OrbitTheme.neonGreen
        case .idle: return OrbitTheme.neonCyan
        case .error: return OrbitTheme.neonPink
        }
    }
}

struct AgentInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let status: AgentStatus
    let tasksCompleted: Int
    let model: String
    let uptime: String
}

struct AgentsView: View {
    let agents: [AgentInfo] = [
        AgentInfo(name: "data-processor", description: "Processes incoming data streams and transforms into structured formats", status: .running, tasksCompleted: 847, model: "claude-sonnet-4-6", uptime: "2h 12m"),
        AgentInfo(name: "code-reviewer", description: "Automated code review agent with security analysis capabilities", status: .running, tasksCompleted: 234, model: "claude-opus-4-6", uptime: "1h 45m"),
        AgentInfo(name: "web-scraper", description: "Web content extraction with rate limiting and retry logic", status: .idle, tasksCompleted: 1523, model: "claude-haiku-4-5", uptime: "45m"),
        AgentInfo(name: "report-gen", description: "Generates formatted reports from processed data", status: .error, tasksCompleted: 89, model: "claude-sonnet-4-6", uptime: "0m"),
        AgentInfo(name: "qa-tester", description: "Automated QA testing for end-to-end test execution", status: .running, tasksCompleted: 456, model: "claude-sonnet-4-6", uptime: "3h 20m"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AGENTS")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(OrbitTheme.textPrimary)

                        Text("Manage and monitor your AI agents")
                            .font(.system(size: 13))
                            .foregroundStyle(OrbitTheme.textSecondary)
                    }

                    Spacer()

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("NEW AGENT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(OrbitTheme.bgDeep)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(OrbitTheme.neonPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .neonGlow(OrbitTheme.neonPurple, radius: 5)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    ForEach(agents) { agent in
                        AgentCard(agent: agent)
                    }
                }
            }
            .padding(24)
        }
    }
}

struct AgentCard: View {
    let agent: AgentInfo
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(agent.status.color)
                .frame(width: 10, height: 10)
                .neonGlow(agent.status.color, radius: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(agent.name)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(OrbitTheme.textPrimary)

                    Text(agent.status.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(agent.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(agent.status.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(agent.description)
                    .font(.system(size: 12))
                    .foregroundStyle(OrbitTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 24) {
                AgentStat(value: "\(agent.tasksCompleted)", label: "tasks")
                AgentStat(value: agent.model, label: "model", valueColor: OrbitTheme.neonCyan, valueSize: 11)
                AgentStat(value: agent.uptime, label: "uptime")
            }

            HStack(spacing: 8) {
                AgentActionIcon(icon: "play.fill", color: OrbitTheme.neonGreen)
                AgentActionIcon(icon: "stop.fill", color: OrbitTheme.neonPink)
                AgentActionIcon(icon: "ellipsis", color: OrbitTheme.textSecondary)
            }
        }
        .padding(16)
        .cyberCard(isHovered: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct AgentStat: View {
    let value: String
    let label: String
    var valueColor: Color = OrbitTheme.textPrimary
    var valueSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(OrbitTheme.textMuted)
        }
    }
}

struct AgentActionIcon: View {
    let icon: String
    let color: Color
    @State private var isHovered = false

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isHovered ? color : OrbitTheme.textMuted)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? color.opacity(0.1) : OrbitTheme.bgDeep)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? color.opacity(0.2) : OrbitTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
