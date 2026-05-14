import SwiftUI

struct ContentView: View {
    @State private var isBooting = false
    @State private var authManager = AuthManager()

    var body: some View {
        if authManager.isAuthenticated {
            ChatView(username: authManager.currentUser ?? "UNKNOWN") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    authManager.logout()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else {
            ZStack {
                CyberpunkBackground()
                LoginView(authManager: authManager, isBooting: isBooting)
            }
            .preferredColorScheme(.dark)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isBooting = true
                }
            }
            .transition(.opacity.combined(with: .move(edge: .leading)))
        }
    }
}

private struct LoginView: View {
    @Bindable var authManager: AuthManager
    let isBooting: Bool

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var biometricAttempted = false

    private var canShowBiometric: Bool {
        !isRegistering && authManager.isBiometricAvailable && authManager.savedBiometricUser != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 34) {
                Spacer(minLength: 26)

                OrbitLoginMark(isActive: isBooting)

                VStack(spacing: 10) {
                    GlitchText("ORBIT", isActive: isBooting)

                    Text(isRegistering ? "NEW IDENTITY CREATION" : "NEURAL ACCESS GATE")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.cyan.opacity(0.86))
                        .animation(.easeInOut, value: isRegistering)
                }

                LoginPanel(
                    username: $username,
                    password: $password,
                    confirmPassword: $confirmPassword,
                    isRegistering: isRegistering,
                    isProcessing: isProcessing,
                    errorMessage: authManager.errorMessage,
                    showSuccess: showSuccess,
                    canShowBiometric: canShowBiometric,
                    biometricUser: authManager.savedBiometricUser,
                    onSubmit: handleSubmit,
                    onBiometric: handleBiometric,
                    onToggleMode: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isRegistering.toggle()
                            confirmPassword = ""
                            authManager.errorMessage = nil
                            showSuccess = false
                        }
                    }
                )

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            if canShowBiometric && !biometricAttempted {
                biometricAttempted = true
                handleBiometric()
            }
        }
    }

    private func handleSubmit() {
        guard !isProcessing else { return }

        if isRegistering && password != confirmPassword {
            authManager.errorMessage = "两次输入的密码不一致"
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            isProcessing = true
            showSuccess = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if isRegistering {
                let success = authManager.register(username: username, password: password)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isProcessing = false
                    if success {
                        showSuccess = true
                        isRegistering = false
                        password = ""
                    }
                }
            } else {
                let success = authManager.login(username: username, password: password)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isProcessing = false
                    if success {
                        showSuccess = true
                    }
                }
            }
        }
    }

    private func handleBiometric() {
        Task {
            let success = await authManager.loginWithBiometrics()
            if success {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccess = true
                    }
                }
            }
        }
    }
}

private struct CyberpunkBackground: View {
    private let imageNames = ["BG1", "BG2", "BG3", "BG4"]

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                backgroundImages(time: time)

                Canvas { context, size in
                    drawScanLines(in: &context, size: size, time: time)
                    drawGlow(in: &context, size: size, time: time)
                }
            }
            .ignoresSafeArea()
        }
        .overlay {
            LinearGradient(
                colors: [
                    .black.opacity(0.18),
                    Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.34),
                    .black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func backgroundImages(time: TimeInterval) -> some View {
        GeometryReader { proxy in
            let cycleDuration = 8.0
            let progress = time.truncatingRemainder(dividingBy: cycleDuration * Double(imageNames.count)) / cycleDuration
            let activeIndex = Int(progress) % imageNames.count
            let fade = min(max((progress - Double(activeIndex)) * 2.0, 0), 1)
            let nextIndex = (activeIndex + 1) % imageNames.count

            ZStack {
                ForEach(imageNames.indices, id: \.self) { index in
                    Image(imageNames[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(opacity(for: index, activeIndex: activeIndex, nextIndex: nextIndex, fade: fade))
                }
            }
            .clipped()
        }
    }

    private func opacity(for index: Int, activeIndex: Int, nextIndex: Int, fade: Double) -> Double {
        if index == activeIndex {
            return 1 - fade
        }

        if index == nextIndex {
            return fade
        }

        return 0
    }

    private func drawScanLines(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        var lines = Path()
        let scanOffset = CGFloat(time.truncatingRemainder(dividingBy: 2)) * 9

        stride(from: scanOffset, through: size.height, by: 9).forEach { y in
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: size.width, y: y))
        }

        context.stroke(lines, with: .color(.white.opacity(0.035)), lineWidth: 1)
    }

    private func drawGlow(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let pulse = 0.5 + 0.5 * sin(time * 1.8)
        let rect = CGRect(
            x: size.width * (0.14 + 0.04 * pulse),
            y: size.height * 0.15,
            width: size.width * 0.72,
            height: size.height * 0.34
        )

        context.addFilter(.blur(radius: 52))
        context.fill(Ellipse().path(in: rect), with: .color(.cyan.opacity(0.12)))
        context.fill(
            Ellipse().path(in: rect.offsetBy(dx: size.width * 0.13, dy: size.height * 0.16)),
            with: .color(.pink.opacity(0.16))
        )
    }
}

private struct OrbitLoginMark: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .pink, .purple, .cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: CGFloat(142 + index * 28), height: CGFloat(142 + index * 28))
                    .rotationEffect(.degrees(isActive ? Double(220 + index * 70) : Double(index * 34)))
                    .opacity(0.72 - Double(index) * 0.12)
                    .animation(
                        .linear(duration: Double(6 + index * 2)).repeatForever(autoreverses: false),
                        value: isActive
                    )
            }

            Image("LoginIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.cyan.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .cyan.opacity(0.45), radius: 24)
        }
        .frame(height: 226)
    }
}

private struct GlitchText: View {
    let text: String
    let isActive: Bool

    init(_ text: String, isActive: Bool) {
        self.text = text
        self.isActive = isActive
    }

    var body: some View {
        ZStack {
            Text(text)
                .offset(x: isActive ? -3 : 2)
                .foregroundStyle(.cyan)
                .opacity(0.64)

            Text(text)
                .offset(x: isActive ? 3 : -2)
                .foregroundStyle(.pink)
                .opacity(0.7)

            Text(text)
                .foregroundStyle(.white)
        }
        .font(.system(size: 54, weight: .black, design: .monospaced))
        .tracking(4)
        .shadow(color: .cyan.opacity(0.8), radius: 16)
        .animation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true), value: isActive)
    }
}

private struct LoginPanel: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var confirmPassword: String
    let isRegistering: Bool
    let isProcessing: Bool
    let errorMessage: String?
    let showSuccess: Bool
    let canShowBiometric: Bool
    let biometricUser: String?
    let onSubmit: () -> Void
    let onBiometric: () -> Void
    let onToggleMode: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if canShowBiometric && !isRegistering {
                biometricSection
            }

            VStack(spacing: 12) {
                CyberTextField(
                    icon: "person.fill",
                    placeholder: "USERNAME",
                    text: $username
                )

                CyberTextField(
                    icon: "lock.fill",
                    placeholder: "PASSWORD",
                    text: $password,
                    isSecure: true
                )

                if isRegistering {
                    CyberTextField(
                        icon: "lock.badge.checkmark",
                        placeholder: "CONFIRM PASSWORD",
                        text: $confirmPassword,
                        isSecure: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.red.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showSuccess && !isRegistering {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("注册成功，请登录")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.green.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            NeonProgressBar(isActive: isProcessing)

            Button(action: onSubmit) {
                HStack(spacing: 10) {
                    Image(systemName: isProcessing ? "bolt.fill" : (isRegistering ? "person.badge.plus" : "lock.open.fill"))
                    Text(isProcessing ? "PROCESSING" : (isRegistering ? "REGISTER" : "LOGIN"))
                }
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(NeonButtonStyle(isActive: isProcessing))
            .disabled(isProcessing)

            Button(action: onToggleMode) {
                Text(isRegistering ? "< BACK TO LOGIN" : "CREATE NEW IDENTITY >")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.cyan.opacity(0.72))
            }
            .disabled(isProcessing)
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.48))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.9), .pink.opacity(0.8), .cyan.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .cyan.opacity(0.28), radius: 24, y: 10)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccess)
    }

    private var biometricSection: some View {
        VStack(spacing: 10) {
            Button(action: onBiometric) {
                VStack(spacing: 10) {
                    Image(systemName: "faceid")
                        .font(.system(size: 38))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.6), radius: 12)

                    if let user = biometricUser {
                        Text(user.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .tracking(1)
                    }

                    Text("TOUCH TO AUTHENTICATE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.6))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.cyan.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.cyan.opacity(0.3), lineWidth: 1)
                        }
                }
            }

            dividerRow
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)
        }
    }
}

private struct CyberTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.cyan.opacity(0.72))
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 14, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.cyan.opacity(0.3), lineWidth: 1)
                }
        }
    }
}

private struct NeonProgressBar: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * (isActive ? 0.86 : 0.22))
                    .shadow(color: .pink.opacity(0.75), radius: 12)
                    .animation(.easeInOut(duration: 0.7), value: isActive)
            }
        }
        .frame(height: 8)
    }
}

private struct NeonButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: isActive ? [.pink, .cyan] : [.cyan, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.8), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .shadow(color: (isActive ? Color.pink : Color.cyan).opacity(0.62), radius: 18, y: 8)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
