import SwiftUI

struct ChatView: View {
    @Environment(OrbitBackendClient.self) var client

    var body: some View {
        HStack(spacing: 0) {
            SessionListPanel()

            if client.selectedSession != nil {
                ChatContentArea()
            } else {
                ChatEmptyState()
            }
        }
    }
}

// MARK: - Session List

struct SessionListPanel: View {
    @Environment(OrbitBackendClient.self) var client

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SESSIONS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textSecondary)

                Spacer()

                Button(action: { client.createSession() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(OrbitTheme.neonPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OrbitTheme.neonPurple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(OrbitTheme.neonPurple.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().background(OrbitTheme.border)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(client.sessions) { session in
                        SessionRow(
                            session: session,
                            isSelected: session.sessionId == client.selectedSessionId
                        )
                        .onTapGesture { client.selectSession(session) }
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 240)
        .background(OrbitTheme.bgSurface.opacity(0.5))
        .overlay(
            Rectangle().frame(width: 1).foregroundStyle(OrbitTheme.border),
            alignment: .trailing
        )
    }
}

struct SessionRow: View {
    let session: OrbitSession
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(session.sessionId)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? OrbitTheme.neonPurple : OrbitTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(session.backendName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(backendColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(backendColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if let prompt = session.systemPrompt {
                Text(prompt)
                    .font(.system(size: 10))
                    .foregroundStyle(OrbitTheme.textMuted)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(session.status == "active" ? OrbitTheme.neonGreen : OrbitTheme.textMuted)
                    .frame(width: 5, height: 5)

                Text(timeAgo(session.updatedAt))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? OrbitTheme.neonPurple.opacity(0.08)
                        : (isHovered ? OrbitTheme.bgCard : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? OrbitTheme.neonPurple.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var backendColor: Color {
        session.backendName == "codex" ? OrbitTheme.neonCyan : OrbitTheme.neonOrange
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Date().timeIntervalSince(date)
        if s < 60 { return "just now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        if s < 86400 { return "\(Int(s / 3600))h ago" }
        return "\(Int(s / 86400))d ago"
    }
}

// MARK: - Chat Content

struct ChatContentArea: View {
    @Environment(OrbitBackendClient.self) var client
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderBar()

            Divider().background(OrbitTheme.border)

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(client.messages) { message in
                        MessageBubble(message: message)
                    }

                    if client.isRunningTurn {
                        TypingIndicator()
                    }
                }
                .padding(24)
            }
            .defaultScrollAnchor(.bottom)

            ComposerBar(inputText: $inputText) {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                inputText = ""
                client.sendMessage(text)
            }
        }
    }
}

struct ChatHeaderBar: View {
    @Environment(OrbitBackendClient.self) var client

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(client.selectedSession?.sessionId ?? "")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textPrimary)

                if let prompt = client.selectedSession?.systemPrompt {
                    Text(prompt)
                        .font(.system(size: 11))
                        .foregroundStyle(OrbitTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let session = client.selectedSession {
                HStack(spacing: 10) {
                    Text(session.backendName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            session.backendName == "codex"
                                ? OrbitTheme.neonCyan : OrbitTheme.neonOrange
                        )

                    Text(session.status.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            session.status == "active"
                                ? OrbitTheme.neonGreen : OrbitTheme.textMuted
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (session.status == "active"
                                ? OrbitTheme.neonGreen : OrbitTheme.textMuted
                            ).opacity(0.08)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(OrbitTheme.bgSurface.opacity(0.3))
    }
}

// MARK: - Messages

struct MessageBubble: View {
    let message: OrbitMessage

    var body: some View {
        switch message.role {
        case .system:
            SystemBubble(content: message.content)
        case .user:
            UserBubble(content: message.content, time: message.createdAt)
        case .assistant:
            AssistantBubble(message: message)
        case .tool:
            ToolBubble(message: message)
        }
    }
}

struct SystemBubble: View {
    let content: String

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(OrbitTheme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(OrbitTheme.bgCard.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer()
        }
    }
}

struct UserBubble: View {
    let content: String
    let time: Date

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 100)

            VStack(alignment: .trailing, spacing: 4) {
                Text(content)
                    .font(.system(size: 13))
                    .foregroundStyle(OrbitTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(OrbitTheme.neonPurple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OrbitTheme.neonPurple.opacity(0.15), lineWidth: 1)
                    )

                Text(Self.fmt.string(from: time))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textMuted)
            }
        }
    }
}

struct AssistantBubble: View {
    let message: OrbitMessage

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(OrbitTheme.neonCyan.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "cpu")
                        .font(.system(size: 12))
                        .foregroundStyle(OrbitTheme.neonCyan)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("assistant")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(OrbitTheme.neonCyan)

                    if let model = message.metadata["model"]?.stringValue {
                        Text(model)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(OrbitTheme.textMuted)
                    }
                }

                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(OrbitTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OrbitTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(OrbitTheme.border, lineWidth: 1)
                    )

                Text(Self.fmt.string(from: message.createdAt))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textMuted)
            }

            Spacer(minLength: 60)
        }
    }
}

struct ToolBubble: View {
    let message: OrbitMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Color.clear.frame(width: 28, height: 1)

            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10))
                    .foregroundStyle(OrbitTheme.neonOrange)

                if let name = message.metadata["tool_name"]?.stringValue {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(OrbitTheme.neonOrange)
                }

                Text(message.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(OrbitTheme.textSecondary)
                    .lineLimit(2)

                Spacer()

                if let ok = message.metadata["ok"] {
                    if case .bool(true) = ok {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(OrbitTheme.neonGreen)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(OrbitTheme.neonPink)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(OrbitTheme.bgDeep)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(OrbitTheme.neonOrange.opacity(0.12), lineWidth: 1)
            )

            Spacer(minLength: 60)
        }
    }
}

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(OrbitTheme.neonCyan.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "cpu")
                        .font(.system(size: 12))
                        .foregroundStyle(OrbitTheme.neonCyan)
                )

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(OrbitTheme.neonPurple.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(animate ? 1.0 : 0.5)
                        .opacity(animate ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(OrbitTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .onAppear { animate = true }
    }
}

// MARK: - Composer

struct ComposerBar: View {
    @Binding var inputText: String
    let onSend: () -> Void
    @Environment(OrbitBackendClient.self) var client

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !client.isRunningTurn
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Send a message...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(OrbitTheme.textPrimary)
                .onSubmit { if canSend { onSend() } }

            Button(action: { if canSend { onSend() } }) {
                Image(systemName: client.isRunningTurn ? "ellipsis.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(canSend ? OrbitTheme.neonPurple : OrbitTheme.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(OrbitTheme.bgSurface)
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(OrbitTheme.border),
            alignment: .top
        )
    }
}

// MARK: - Empty State

struct ChatEmptyState: View {
    @Environment(OrbitBackendClient.self) var client

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(OrbitTheme.neonPurple.opacity(0.3))
                .neonGlow(OrbitTheme.neonPurple, radius: 8)

            Text("SELECT A SESSION")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(OrbitTheme.textPrimary)

            Text("Choose an existing session or create a new one")
                .font(.system(size: 13))
                .foregroundStyle(OrbitTheme.textSecondary)

            Button(action: { client.createSession() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("NEW SESSION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(OrbitTheme.bgDeep)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(OrbitTheme.neonPurple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .neonGlow(OrbitTheme.neonPurple, radius: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
