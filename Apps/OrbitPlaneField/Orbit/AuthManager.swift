import Foundation
import CryptoKit
import LocalAuthentication

@Observable
final class AuthManager {
    var isAuthenticated = false
    var currentUser: String?
    var errorMessage: String?

    private let registeredUsersKey = "orbit_registered_users"
    private static let biometricUserKey = "orbit_biometric_user"

    var savedBiometricUser: String? {
        UserDefaults.standard.string(forKey: Self.biometricUserKey)
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func register(username: String, password: String) -> Bool {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUser.isEmpty, !password.isEmpty else {
            errorMessage = "用户名和密码不能为空"
            return false
        }

        guard trimmedUser.count >= 3 else {
            errorMessage = "用户名至少需要3个字符"
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "密码至少需要6个字符"
            return false
        }

        guard !KeychainManager.exists(account: trimmedUser) else {
            errorMessage = "用户名已存在"
            return false
        }

        let hashed = hashPassword(password)
        guard KeychainManager.save(account: trimmedUser, password: hashed) else {
            errorMessage = "注册失败，请重试"
            return false
        }

        addToRegisteredUsers(trimmedUser)
        errorMessage = nil
        return true
    }

    func login(username: String, password: String) -> Bool {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUser.isEmpty, !password.isEmpty else {
            errorMessage = "请输入用户名和密码"
            return false
        }

        guard let storedHash = KeychainManager.read(account: trimmedUser) else {
            errorMessage = "用户名或密码错误"
            return false
        }

        let inputHash = hashPassword(password)
        guard inputHash == storedHash else {
            errorMessage = "用户名或密码错误"
            return false
        }

        isAuthenticated = true
        currentUser = trimmedUser
        errorMessage = nil
        UserDefaults.standard.set(trimmedUser, forKey: Self.biometricUserKey)
        return true
    }

    func loginWithBiometrics() async -> Bool {
        guard let savedUser = savedBiometricUser else {
            await MainActor.run { errorMessage = "没有已保存的登录账户" }
            return false
        }

        guard KeychainManager.exists(account: savedUser) else {
            await MainActor.run { errorMessage = "账户不存在" }
            UserDefaults.standard.removeObject(forKey: Self.biometricUserKey)
            return false
        }

        let context = LAContext()
        context.localizedCancelTitle = "使用密码登录"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "使用 Face ID 登录 Orbit"
            )
            guard success else { return false }

            await MainActor.run {
                isAuthenticated = true
                currentUser = savedUser
                errorMessage = nil
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage = nil
            }
            return false
        }
    }

    func logout() {
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }

    func clearBiometricUser() {
        UserDefaults.standard.removeObject(forKey: Self.biometricUserKey)
    }

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func addToRegisteredUsers(_ username: String) {
        var users = UserDefaults.standard.stringArray(forKey: registeredUsersKey) ?? []
        if !users.contains(username) {
            users.append(username)
            UserDefaults.standard.set(users, forKey: registeredUsersKey)
        }
    }
}
