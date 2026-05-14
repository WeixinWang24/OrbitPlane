import SwiftUI
import FoundationModels

enum ProviderType: String, CaseIterable {
    case vllm = "vLLM / OpenAI Compatible"
    case codex = "OpenAI Codex"
    case foundationModels = "Apple Intelligence"
}

private struct PersistedSettings: Codable {
    var selectedProvider: String
    var vllmBaseURL: String
    var vllmModel: String
    var vllmAPIKey: String
    var vllmUsername: String
    var vllmPassword: String
    var codexModel: String
    var telegramChatId: String?
    var telegramEnabled: Bool?
    var telegramAllowedUserIds: String?
}

@Observable
final class AppSettings {
    var selectedProvider: ProviderType {
        didSet { persist() }
    }
    var vllmBaseURL: String {
        didSet { persist() }
    }
    var vllmModel: String {
        didSet { persist() }
    }
    var vllmAPIKey: String {
        didSet { persist() }
    }
    var vllmUsername: String {
        didSet { persist() }
    }
    var vllmPassword: String {
        didSet { persist() }
    }
    var codexModel: String {
        didSet { persist() }
    }
    var telegramChatId: String {
        didSet { persist() }
    }
    var telegramEnabled: Bool {
        didSet { persist() }
    }
    var telegramAllowedUserIds: String {
        didSet { persist() }
    }

    var codexLoggedIn: Bool = false
    var codexEmail: String?

    private let authManager = CodexAuthManager()
    private let keychainAccount: String
    private let telegramTokenAccount: String

    init(username: String) {
        self.keychainAccount = "orbit_settings_\(username)"
        self.telegramTokenAccount = "orbit_telegram_token_\(username)"

        if let json = KeychainManager.read(account: keychainAccount),
           let data = json.data(using: .utf8),
           let saved = try? JSONDecoder().decode(PersistedSettings.self, from: data) {
            self.selectedProvider = ProviderType(rawValue: saved.selectedProvider) ?? .vllm
            self.vllmBaseURL = saved.vllmBaseURL
            self.vllmModel = saved.vllmModel
            self.vllmAPIKey = saved.vllmAPIKey
            self.vllmUsername = saved.vllmUsername
            self.vllmPassword = saved.vllmPassword
            self.codexModel = saved.codexModel
            self.telegramChatId = saved.telegramChatId ?? ""
            self.telegramEnabled = saved.telegramEnabled ?? false
            self.telegramAllowedUserIds = saved.telegramAllowedUserIds ?? ""
        } else {
            self.selectedProvider = .vllm
            self.vllmBaseURL = "http://localhost:8000/v1"
            self.vllmModel = "gpt-4o"
            self.vllmAPIKey = ""
            self.vllmUsername = ""
            self.vllmPassword = ""
            self.codexModel = "codex"
            self.telegramChatId = ""
            self.telegramEnabled = false
            self.telegramAllowedUserIds = ""
        }

        if let cred = try? authManager.loadCredential() {
            codexLoggedIn = true
            codexEmail = cred.accountEmail
        }
    }

    private func persist() {
        let settings = PersistedSettings(
            selectedProvider: selectedProvider.rawValue,
            vllmBaseURL: vllmBaseURL,
            vllmModel: vllmModel,
            vllmAPIKey: vllmAPIKey,
            vllmUsername: vllmUsername,
            vllmPassword: vllmPassword,
            codexModel: codexModel,
            telegramChatId: telegramChatId,
            telegramEnabled: telegramEnabled,
            telegramAllowedUserIds: telegramAllowedUserIds
        )
        if let data = try? JSONEncoder().encode(settings),
           let json = String(data: data, encoding: .utf8) {
            KeychainManager.save(account: keychainAccount, password: json)
        }
    }

    // MARK: - Telegram

    var telegramToken: String {
        KeychainManager.read(account: telegramTokenAccount) ?? ""
    }

    func saveTelegramToken(_ token: String) {
        if token.isEmpty {
            KeychainManager.delete(account: telegramTokenAccount)
        } else {
            _ = KeychainManager.save(account: telegramTokenAccount, password: token)
        }
    }

    var parsedAllowedUserIds: Set<String> {
        Set(
            telegramAllowedUserIds
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    func buildTelegramBridge() -> TelegramBridge? {
        let token = telegramToken
        guard !token.isEmpty, !telegramChatId.isEmpty, telegramEnabled else { return nil }
        return TelegramBridge(token: token, allowedChatId: telegramChatId, allowedUserIds: parsedAllowedUserIds)
    }

    // MARK: - Provider

    func buildProvider() -> any AgentProvider {
        switch selectedProvider {
        case .vllm:
            let normalized = ProviderSettings.normalizeBaseURL(vllmBaseURL)
            let url = URL(string: normalized) ?? URL(string: "http://localhost:8000/v1")!
            let settings = ProviderSettings(
                model: vllmModel,
                baseURL: url,
                apiKey: vllmAPIKey.isEmpty ? nil : vllmAPIKey,
                basicAuthUsername: vllmUsername.isEmpty ? nil : vllmUsername,
                basicAuthPassword: vllmPassword.isEmpty ? nil : vllmPassword,
                maxTokens: 1024
            )
            return OpenAICompatibleProvider(settings: settings)
        case .codex:
            return CodexProvider(model: codexModel, authManager: authManager)
        case .foundationModels:
            return FoundationModelsProvider()
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var authError: String?
    @State private var showLogoutConfirm = false
    @State private var importJSON = ""
    @State private var importSuccess = false
    @State private var telegramTokenInput = ""
    @State private var telegramStatus: String?
    @State private var showTelegramGuide = false

    private let authManager = CodexAuthManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        providerPicker
                        switch settings.selectedProvider {
                        case .vllm:
                            vllmSection
                        case .codex:
                            codexSection
                        case .foundationModels:
                            foundationModelsSection
                        }

                        telegramSection
                    }
                    .padding(20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PROVIDER")

            ForEach(ProviderType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.selectedProvider = type
                    }
                } label: {
                    HStack {
                        Image(systemName: providerIcon(type))
                            .frame(width: 20)
                        Text(type.rawValue)
                        Spacer()
                        if settings.selectedProvider == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.cyan)
                        }
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(settings.selectedProvider == type ? .cyan.opacity(0.1) : .white.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(settings.selectedProvider == type ? .cyan.opacity(0.5) : .white.opacity(0.1), lineWidth: 1)
                            }
                    }
                }
            }
        }
    }

    // MARK: - vLLM

    private var vllmSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("vLLM CONFIGURATION")

            settingsField("BASE URL", text: $settings.vllmBaseURL, placeholder: "http://localhost:8000/v1")
            settingsField("MODEL", text: $settings.vllmModel, placeholder: "gpt-4o")
            settingsField("API KEY (optional)", text: $settings.vllmAPIKey, placeholder: "Leave empty if not required", isSecure: true)

            sectionHeader("BASIC AUTH (NGINX)")

            settingsField("USERNAME", text: $settings.vllmUsername, placeholder: "Leave empty if not required")
            settingsField("PASSWORD", text: $settings.vllmPassword, placeholder: "Leave empty if not required", isSecure: true)

            infoBox("For direct access via Nginx with Basic Auth, enter the endpoint URL and credentials above. SSH tunnel is not required in this mode.")
        }
    }

    // MARK: - Codex

    private var codexSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("CODEX CONFIGURATION")

            settingsField("MODEL", text: $settings.codexModel, placeholder: "codex")

            if settings.codexLoggedIn {
                loggedInCard
            } else {
                loginCard
            }

            if let error = authError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.red.opacity(0.9))
            }
        }
    }

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("AUTHENTICATED")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.9))
            }

            if let email = settings.codexEmail {
                Text(email)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Button {
                showLogoutConfirm = true
            } label: {
                Text("REVOKE ACCESS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.red.opacity(0.4), lineWidth: 1)
                    }
            }
            .confirmationDialog("Revoke Codex Access?", isPresented: $showLogoutConfirm) {
                Button("Revoke", role: .destructive) {
                    authManager.deleteCredential()
                    settings.codexLoggedIn = false
                    settings.codexEmail = nil
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.green.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.green.opacity(0.3), lineWidth: 1)
                }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PASTE CREDENTIAL JSON")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            TextEditor(text: $importJSON)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.cyan.opacity(0.2), lineWidth: 1)
                        }
                }

            HStack(spacing: 10) {
                Button {
                    if let clip = UIPasteboard.general.string {
                        importJSON = clip
                    }
                } label: {
                    Label("PASTE", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.cyan)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.cyan.opacity(0.5), lineWidth: 1)
                        }
                }

                Button {
                    performImport()
                } label: {
                    Text("IMPORT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(.black)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                }
                .disabled(importJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if importSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Credential imported successfully")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.green.opacity(0.9))
            }

            infoBox("Copy the JSON from Orbit2 credential file and paste above. Tokens are stored in Keychain only.")
        }
    }

    // MARK: - Foundation Models

    private var foundationModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("ON-DEVICE MODEL")
            availabilityCard
            infoBox("Apple Intelligence runs entirely on-device. No API key or network connection required. Context window is limited — keep messages concise for best results.")
        }
    }

    private var availabilityCard: some View {
        let model = SystemLanguageModel.default

        return VStack(alignment: .leading, spacing: 12) {
            switch model.availability {
            case .available:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("MODEL READY")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.9))
                }
                Text("On-device model is loaded and ready")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

            case .unavailable(.deviceNotEligible):
                HStack(spacing: 8) {
                    Image(systemName: "xmark.shield.fill")
                        .foregroundStyle(.red)
                    Text("NOT SUPPORTED")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.9))
                }
                Text("This device does not support Apple Intelligence")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

            case .unavailable(.appleIntelligenceNotEnabled):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    Text("NOT ENABLED")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.9))
                }
                Text("Enable Apple Intelligence in Settings → Apple Intelligence & Siri")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

            case .unavailable(.modelNotReady):
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.yellow)
                    Text("DOWNLOADING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow.opacity(0.9))
                }
                Text("Model is being downloaded — this may take a few minutes")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

            case .unavailable:
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.shield.fill")
                        .foregroundStyle(.gray)
                    Text("UNAVAILABLE")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.9))
                }
                Text("On-device model is currently unavailable")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(availabilityColor(model.availability).opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(availabilityColor(model.availability).opacity(0.3), lineWidth: 1)
                }
        }
    }

    private func availabilityColor(_ availability: SystemLanguageModel.Availability) -> Color {
        switch availability {
        case .available: .green
        case .unavailable(.deviceNotEligible): .red
        case .unavailable(.appleIntelligenceNotEnabled): .orange
        case .unavailable(.modelNotReady): .yellow
        case .unavailable: .gray
        }
    }

    private func providerIcon(_ type: ProviderType) -> String {
        switch type {
        case .vllm: "server.rack"
        case .codex: "bolt.fill"
        case .foundationModels: "brain"
        }
    }

    // MARK: - Telegram

    private var telegramSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("TELEGRAM BRIDGE")

            VStack(alignment: .leading, spacing: 6) {
                Text("BOT TOKEN")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                SecureField("Paste bot token from @BotFather", text: $telegramTokenInput)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.05))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.cyan.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .onAppear {
                        let existing = settings.telegramToken
                        if !existing.isEmpty {
                            telegramTokenInput = existing
                        }
                    }
                    .onChange(of: telegramTokenInput) {
                        settings.saveTelegramToken(telegramTokenInput)
                    }
            }

            settingsField("CHAT ID", text: $settings.telegramChatId, placeholder: "-1001234567890")
            settingsField("ALLOWED USER IDS", text: $settings.telegramAllowedUserIds, placeholder: "Comma-separated, empty = allow all")

            HStack {
                Text("CONNECT")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Toggle("", isOn: $settings.telegramEnabled)
                    .tint(.cyan)
                    .labelsHidden()
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(settings.telegramEnabled ? .cyan.opacity(0.08) : .white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(settings.telegramEnabled ? .cyan.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
                    }
            }

            if settings.telegramEnabled && !settings.telegramToken.isEmpty {
                Button {
                    Task { await testTelegramConnection() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("TEST CONNECTION")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.cyan.opacity(0.5), lineWidth: 1)
                    }
                }
            }

            if let status = telegramStatus {
                HStack(spacing: 6) {
                    Image(systemName: status.hasPrefix("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(status)
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(status.hasPrefix("✓") ? .green.opacity(0.9) : .red.opacity(0.9))
            }

            Button {
                showTelegramGuide = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                    Text("SETUP GUIDE")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.8))
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.cyan.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.cyan.opacity(0.2), lineWidth: 1)
                        }
                }
            }
            .sheet(isPresented: $showTelegramGuide) {
                TelegramGuideView()
            }

            infoBox("Bot token is stored in Keychain (encrypted, hardware-backed). It never leaves your device.")
        }
    }

    private func testTelegramConnection() async {
        let bridge = TelegramBridge(token: settings.telegramToken)
        do {
            try await bridge.send(
                text: "🛰 Orbit connected successfully.",
                to: settings.telegramChatId
            )
            await MainActor.run {
                telegramStatus = "✓ Message sent to group"
            }
        } catch {
            await MainActor.run {
                telegramStatus = "✗ \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Import

    private func performImport() {
        authError = nil
        importSuccess = false

        do {
            let credential = try authManager.importFromJSON(importJSON)

            if credential.isExpired {
                Task {
                    do {
                        let refreshed = try await authManager.refresh(credential)
                        try authManager.saveCredential(refreshed)
                        await MainActor.run {
                            settings.codexLoggedIn = true
                            settings.codexEmail = refreshed.accountEmail
                            importJSON = ""
                            importSuccess = true
                            UIPasteboard.general.string = ""
                        }
                    } catch {
                        await MainActor.run {
                            authError = "Token expired and refresh failed: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                try authManager.saveCredential(credential)
                settings.codexLoggedIn = true
                settings.codexEmail = credential.accountEmail
                importJSON = ""
                importSuccess = true
                UIPasteboard.general.string = ""
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.cyan.opacity(0.7))
            .tracking(2)
    }

    private func settingsField(_ label: String, text: Binding<String>, placeholder: String, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.cyan.opacity(0.2), lineWidth: 1)
                    }
            }
        }
    }

    private func infoBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.cyan.opacity(0.5))
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.cyan.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.cyan.opacity(0.1), lineWidth: 1)
                }
        }
    }
}
