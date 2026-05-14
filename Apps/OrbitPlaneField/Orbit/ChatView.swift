import SwiftUI
import FoundationModels

struct ChatView: View {
    let username: String
    let onLogout: () -> Void

    @State private var appSettings: AppSettings
    @State private var sessionManager: ChatSessionManager
    @State private var viewModel: ChatViewModel
    @State private var showSettings = false
    @State private var showSessionList = false
    @State private var contextSize = TokenEstimator.defaultContextSize
    @FocusState private var isInputFocused: Bool

    init(username: String, onLogout: @escaping () -> Void) {
        self.username = username
        self.onLogout = onLogout
        self._appSettings = State(initialValue: AppSettings(username: username))
        let store = ChatStore(username: username)
        let manager = ChatSessionManager(store: store)
        self._sessionManager = State(initialValue: manager)
        self._viewModel = State(initialValue: ChatViewModel(sessionManager: manager))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(.cyan.opacity(0.3))
            providerSwitcher
            Divider().background(.cyan.opacity(0.15))
            messageList
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }
            inputBar
        }
        .background {
            chatBackground
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: appSettings)
                .onDisappear {
                    viewModel.updateProvider(appSettings.buildProvider())
                }
        }
        .sheet(isPresented: $showSessionList) {
            SessionListView(
                sessionManager: sessionManager,
                onSelect: { id in
                    viewModel.switchSession(to: id)
                    viewModel.updateProvider(appSettings.buildProvider())
                    showSessionList = false
                },
                onNewChat: {
                    viewModel.createNewSession()
                    viewModel.updateProvider(appSettings.buildProvider())
                    showSessionList = false
                },
                onDelete: { id in
                    let needsProviderReset = sessionManager.currentSessionId == id
                    viewModel.deleteSession(id)
                    if needsProviderReset {
                        viewModel.updateProvider(appSettings.buildProvider())
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: appSettings.selectedProvider) {
            viewModel.updateProvider(appSettings.buildProvider())
        }
        .onChange(of: appSettings.telegramEnabled) {
            syncTelegramBridge()
        }
        .onAppear {
            viewModel.updateProvider(appSettings.buildProvider())
            contextSize = SystemLanguageModel.default.contextSize
            syncTelegramBridge()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green, radius: 4)

                Text("ORBIT")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }

            Spacer()

            HStack(spacing: 14) {
                if viewModel.telegramConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 9))
                        Text("TG")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(.green.opacity(0.12))
                            .overlay {
                                Capsule().stroke(.green.opacity(0.3), lineWidth: 1)
                            }
                    }
                }

                Label(username.uppercased(), systemImage: "person.fill")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Button { showSessionList = true } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan.opacity(0.8))
                }

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan.opacity(0.8))
                }

                Button(action: onLogout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.pink.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.6))
    }

    // MARK: - Provider Switcher

    private var providerSwitcher: some View {
        let showBudget = appSettings.selectedProvider == .foundationModels
        let budgetRatio: Double = {
            guard showBudget else { return 0 }
            let used = TokenEstimator.estimateConversation(
                system: viewModel.systemPrompt,
                messages: viewModel.messages,
                pendingInput: viewModel.inputText
            )
            return min(1.0, Double(used) / Double(contextSize))
        }()
        let budgetColor: Color = budgetRatio < 0.7 ? .cyan : budgetRatio < 0.9 ? .yellow : .red

        return HStack(spacing: 6) {
            ForEach(ProviderType.allCases, id: \.self) { type in
                let isSelected = appSettings.selectedProvider == type

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appSettings.selectedProvider = type
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: providerIcon(type))
                            .font(.system(size: 10))
                        Text(providerShortName(type))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .cyan.opacity(0.4), radius: 6)
                        } else {
                            Capsule()
                                .fill(.white.opacity(0.06))
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                }
                        }
                    }
                }
            }

            if showBudget {
                let remaining = max(0, contextSize - Int(budgetRatio * Double(contextSize)))
                Text("\(remaining)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(budgetColor.opacity(0.9))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack(alignment: .leading) {
                Color.black.opacity(0.5)

                if showBudget {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(budgetColor.opacity(0.12))
                            .frame(width: proxy.size.width * budgetRatio)
                            .animation(.easeOut(duration: 0.3), value: budgetRatio)
                    }
                }
            }
        }
    }

    private func providerIcon(_ type: ProviderType) -> String {
        switch type {
        case .vllm: "server.rack"
        case .codex: "bolt.fill"
        case .foundationModels: "brain"
        }
    }

    private func providerShortName(_ type: ProviderType) -> String {
        switch type {
        case .vllm: "vLLM"
        case .codex: "Codex"
        case .foundationModels: "On-Device"
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.last?.content) {
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message Orbit...", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .focused($isInputFocused)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.cyan.opacity(0.3), lineWidth: 1)
                        }
                }
                .onSubmit {
                    viewModel.send()
                }

            Button {
                viewModel.send()
            } label: {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonGradient)
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isStreaming)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.7))
    }

    private var sendButtonGradient: LinearGradient {
        LinearGradient(
            colors: viewModel.isStreaming ? [.pink, .red] : [.cyan, .mint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Telegram Bridge

    private func syncTelegramBridge() {
        if let bridge = appSettings.buildTelegramBridge() {
            viewModel.connectBridge(bridge, chatId: appSettings.telegramChatId)
        } else {
            viewModel.disconnectBridge()
        }
    }

    // MARK: - Background

    private var chatBackground: some View {
        ZStack {
            Image("BG2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Canvas { context, size in
                var lines = Path()
                stride(from: 0, through: size.height, by: 9).forEach { y in
                    lines.move(to: CGPoint(x: 0, y: y))
                    lines.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(lines, with: .color(.white.opacity(0.02)), lineWidth: 1)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Session List

private struct SessionListView: View {
    let sessionManager: ChatSessionManager
    let onSelect: (UUID) -> Void
    let onNewChat: () -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    Section {
                        Button(action: onNewChat) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.cyan)
                                Text("NEW SESSION")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.cyan)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.cyan.opacity(0.08))
                    }

                    Section {
                        ForEach(sessionManager.sessions) { session in
                            let isCurrent = session.id == sessionManager.currentSessionId

                            Button { onSelect(session.id) } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(isCurrent ? .cyan : .white.opacity(0.2))
                                        .frame(width: 6, height: 6)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(session.title)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundStyle(isCurrent ? .cyan : .white.opacity(0.8))
                                            .lineLimit(1)

                                        Text(session.updatedAt, format: .dateTime.month().day().hour().minute())
                                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.35))
                                    }

                                    Spacer()

                                    if isCurrent {
                                        Text("ACTIVE")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.cyan.opacity(0.6))
                                            .tracking(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(
                                isCurrent
                                    ? Color.cyan.opacity(0.06)
                                    : Color.white.opacity(0.03)
                            )
                            .swipeActions(edge: .trailing) {
                                if !isCurrent {
                                    Button(role: .destructive) {
                                        onDelete(session.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("SESSIONS (\(sessionManager.sessions.count))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let isStreaming: Bool

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }

                    Text(isUser ? "YOU" : "ORBIT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isUser ? .pink.opacity(0.8) : .cyan.opacity(0.8))
                        .tracking(1)
                }

                contentView
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        bubbleBackground
                    }

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isStreaming && message.content.isEmpty {
            streamingIndicator
        } else {
            Text(message.content)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .textSelection(.enabled)
        }
    }

    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(.cyan)
                    .frame(width: 6, height: 6)
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                        value: isStreaming
                    )
            }
        }
        .padding(.vertical, 4)
    }

    private var bubbleBackground: some View {
        Group {
            if isUser {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.pink.opacity(0.18),
                                Color.purple.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.pink.opacity(0.3), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.1),
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.cyan.opacity(0.25), lineWidth: 1)
                    }
            }
        }
        .shadow(color: (isUser ? Color.pink : Color.cyan).opacity(0.15), radius: 8, y: 4)
    }
}
