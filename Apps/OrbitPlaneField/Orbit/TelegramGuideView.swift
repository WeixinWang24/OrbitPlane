import SwiftUI

struct TelegramGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        step1CreateBot
                        step2CreateGroup
                        step3GetChatId
                        step4ConfigureOrbit
                        step5PrivacySettings
                        securityNotes
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("SETUP GUIDE")
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.cyan)
                Text("Telegram Bot Setup")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Text("Connect Orbit to a Telegram group for multi-agent communication.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Steps

    private var step1CreateBot: some View {
        stepCard(number: 1, title: "CREATE A TELEGRAM BOT", icon: "bolt.fill") {
            VStack(alignment: .leading, spacing: 10) {
                instructionRow("1", "Open Telegram, search for @BotFather")
                instructionRow("2", "Send /newbot")
                instructionRow("3", "Enter a name (e.g. Orbit Agent)")
                instructionRow("4", "Enter a username ending in bot (e.g. orbit_agent_bot)")
                instructionRow("5", "BotFather replies with your Bot API Token:")

                codeBlock("7123456789:AAH1bGciOiJSUzI1NiIsInR5...")

                highlightNote("Copy this token — you'll paste it into Orbit Settings.")
            }
        }
    }

    private var step2CreateGroup: some View {
        stepCard(number: 2, title: "CREATE GROUP & ADD BOT", icon: "person.3.fill") {
            VStack(alignment: .leading, spacing: 10) {
                instructionRow("1", "Create a new Telegram group (or use an existing one)")
                instructionRow("2", "Add your bot as a member of the group")
                instructionRow("3", "Send at least one message in the group")
            }
        }
    }

    private var step3GetChatId: some View {
        stepCard(number: 3, title: "GET THE GROUP CHAT ID", icon: "number") {
            VStack(alignment: .leading, spacing: 14) {
                Text("OPTION A — Bot API")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))

                instructionRow("1", "Send a message in the group mentioning your bot")
                instructionRow("2", "Open this URL in your browser:")

                codeBlock("https://api.telegram.org/bot<TOKEN>/getUpdates")

                instructionRow("3", "Find the \"chat\" → \"id\" field in the response")

                highlightNote("Group chat IDs are negative numbers (e.g. -1001234567890)")

                Divider().overlay(.white.opacity(0.1))

                Text("OPTION B — @RawDataBot")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan.opacity(0.8))

                instructionRow("1", "Add @RawDataBot to your group temporarily")
                instructionRow("2", "Send any message — it replies with chat details")
                instructionRow("3", "Remove @RawDataBot after getting the ID")
            }
        }
    }

    private var step4ConfigureOrbit: some View {
        stepCard(number: 4, title: "CONFIGURE IN ORBIT", icon: "gearshape.fill") {
            VStack(alignment: .leading, spacing: 10) {
                instructionRow("1", "Go to Settings → TELEGRAM BRIDGE")
                instructionRow("2", "Paste your Bot Token")
                instructionRow("3", "Paste your Chat ID")
                instructionRow("4", "Enable the Connect toggle")

                highlightNote("Token is stored in your device's Keychain — never leaves your device.")
            }
        }
    }

    private var step5PrivacySettings: some View {
        stepCard(number: 5, title: "BOT PRIVACY SETTINGS", icon: "eye.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("By default, bots only receive:")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                bulletPoint("Messages starting with / (commands)")
                bulletPoint("Direct mentions (@your_bot)")

                Text("To receive all group messages:")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)

                instructionRow("1", "Open @BotFather")
                instructionRow("2", "Send /mybots → select your bot")
                instructionRow("3", "Bot Settings → Group Privacy → Disabled")
            }
        }
    }

    private var securityNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.orange)
                Text("SECURITY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.8))
                    .tracking(2)
            }

            VStack(alignment: .leading, spacing: 8) {
                securityRow("shield.checkered", "Token grants full bot control — treat it like a password")
                securityRow("lock.fill", "Stored in iOS Keychain (encrypted, hardware-backed)")
                securityRow("network.badge.shield.half.filled", "Only sent to api.telegram.org")
                securityRow("exclamationmark.triangle.fill", "If compromised, revoke via BotFather: /revoke")
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.orange.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.orange.opacity(0.25), lineWidth: 1)
                }
        }
    }

    // MARK: - Components

    private func stepCard(
        number: Int,
        title: String,
        icon: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan.opacity(0.6))

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func instructionRow(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.5))
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("·")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.4))
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.green.opacity(0.8))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.green.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.green.opacity(0.15), lineWidth: 1)
                    }
            }
            .textSelection(.enabled)
    }

    private func highlightNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.cyan.opacity(0.6))
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.8))
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.cyan.opacity(0.05))
        }
    }

    private func securityRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.orange.opacity(0.6))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
