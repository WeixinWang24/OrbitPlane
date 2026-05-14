import SwiftUI

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let level: LogLevel
    let source: String
    let message: String
}

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"

    var color: Color {
        switch self {
        case .info: return OrbitTheme.neonCyan
        case .warn: return OrbitTheme.neonYellow
        case .error: return OrbitTheme.neonPink
        case .debug: return OrbitTheme.textMuted
        }
    }
}

struct ConsoleView: View {
    @State private var commandText = ""
    @State private var filterText = ""

    private let logs: [LogEntry] = [
        LogEntry(timestamp: "14:32:01.234", level: .info, source: "runtime", message: "Agent 'data-processor' completed task #847 successfully"),
        LogEntry(timestamp: "14:31:45.891", level: .info, source: "deploy", message: "Workflow 'pipeline-v3' deployed to production environment"),
        LogEntry(timestamp: "14:31:02.445", level: .debug, source: "scheduler", message: "Task queue rebalanced: 5 tasks redistributed across 3 agents"),
        LogEntry(timestamp: "14:30:12.667", level: .warn, source: "web-scraper", message: "Rate limit approaching: 85/100 requests per minute used"),
        LogEntry(timestamp: "14:29:58.123", level: .debug, source: "runtime", message: "Memory checkpoint created: 1.2GB snapshot saved"),
        LogEntry(timestamp: "14:28:33.902", level: .error, source: "task-845", message: "TimeoutError: Task execution exceeded 30s limit. Retries exhausted (3/3)"),
        LogEntry(timestamp: "14:28:01.334", level: .warn, source: "task-845", message: "Retry 3/3: Attempting task execution with extended timeout"),
        LogEntry(timestamp: "14:27:01.556", level: .info, source: "runtime", message: "Agent 'code-reviewer' picked up task #846 from queue"),
        LogEntry(timestamp: "14:26:44.778", level: .debug, source: "auth", message: "API key rotation completed. Next rotation in 24h"),
        LogEntry(timestamp: "14:25:44.221", level: .info, source: "system", message: "System checkpoint saved: all agent states persisted"),
        LogEntry(timestamp: "14:24:12.445", level: .info, source: "runtime", message: "Agent 'qa-tester' started batch execution: 15 test suites"),
        LogEntry(timestamp: "14:23:01.889", level: .debug, source: "network", message: "WebSocket connection stable: latency 12ms"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONSOLE")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(OrbitTheme.textPrimary)

                    Text("Runtime logs & command interface")
                        .font(.system(size: 13))
                        .foregroundStyle(OrbitTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundStyle(OrbitTheme.textMuted)
                        .font(.system(size: 12))

                    TextField("Filter logs...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(OrbitTheme.textPrimary)
                        .frame(width: 200)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(OrbitTheme.bgDeep)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(OrbitTheme.border, lineWidth: 1)
                )
            }
            .padding(24)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(logs) { entry in
                        LogRow(entry: entry)
                    }
                }
                .padding(.horizontal, 24)
            }
            .background(OrbitTheme.bgDeep.opacity(0.5))

            HStack(spacing: 10) {
                Text("›")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(OrbitTheme.neonPurple)
                    .neonGlow(OrbitTheme.neonPurple, radius: 3)

                TextField("Enter command...", text: $commandText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textPrimary)

                Button(action: {}) {
                    Text("RUN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(OrbitTheme.bgDeep)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(OrbitTheme.neonPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(OrbitTheme.bgSurface)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(OrbitTheme.border),
                alignment: .top
            )
        }
    }
}

struct LogRow: View {
    let entry: LogEntry
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.timestamp)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(OrbitTheme.textMuted)
                .frame(width: 105, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(entry.level.color)
                .frame(width: 44, alignment: .leading)

            Text("[\(entry.source)]")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(OrbitTheme.neonPurple.opacity(0.7))
                .frame(width: 100, alignment: .leading)

            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isHovered ? OrbitTheme.textPrimary : OrbitTheme.textSecondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isHovered ? OrbitTheme.bgCard.opacity(0.5) : Color.clear)
        .overlay(
            Divider().background(OrbitTheme.border.opacity(0.5)),
            alignment: .bottom
        )
        .onHover { isHovered = $0 }
    }
}
