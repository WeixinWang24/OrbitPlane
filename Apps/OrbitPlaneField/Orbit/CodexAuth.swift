import Foundation
import CryptoKit
import AuthenticationServices

struct PKCESession: Sendable {
    let state: String
    let codeVerifier: String
    let codeChallenge: String
    let authorizeURL: URL
}

struct CodexCredential: Codable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAtEpochMs: Int64
    var accountEmail: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAtEpochMs = "expires_at_epoch_ms"
        case accountEmail = "account_email"
    }

    var isExpired: Bool {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        return expiresAtEpochMs <= nowMs
    }
}

final class CodexAuthManager: @unchecked Sendable {
    static let authorizeURL = "https://auth.openai.com/oauth/authorize"
    static let tokenURL = "https://auth.openai.com/oauth/token"
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let redirectURI = "http://localhost:1455/auth/callback"
    static let scope = "openid profile email offline_access"

    private static let keychainAccount = "codex_oauth_credential"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - PKCE Session

    func createPKCESession() -> PKCESession {
        let state = generateRandomString(length: 32)
        let codeVerifier = generateRandomString(length: 64)
        let codeChallenge = computeS256Challenge(codeVerifier)

        var components = URLComponents(string: Self.authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "originator", value: "orbit2"),
        ]

        return PKCESession(
            state: state,
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            authorizeURL: components.url!
        )
    }

    // MARK: - Callback Parsing

    func parseCallback(_ input: String, expectedState: String) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.contains("=") && !trimmed.contains("?") && !trimmed.contains("/") {
            return trimmed
        }

        let urlString: String
        if trimmed.hasPrefix("?") {
            urlString = "http://placeholder\(trimmed)"
        } else {
            urlString = trimmed
        }

        guard let components = URLComponents(string: urlString) else {
            throw CodexAuthError.invalidCallback
        }

        let items = components.queryItems ?? []

        if let error = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value ?? error
            throw CodexAuthError.oauthError(desc)
        }

        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw CodexAuthError.missingCode
        }

        if let callbackState = items.first(where: { $0.name == "state" })?.value {
            guard callbackState == expectedState else {
                throw CodexAuthError.stateMismatch
            }
        }

        return code
    }

    // MARK: - Token Exchange

    func exchange(code: String, pkceSession: PKCESession) async throws -> CodexCredential {
        let body = [
            "grant_type": "authorization_code",
            "client_id": Self.clientID,
            "redirect_uri": Self.redirectURI,
            "code": code,
            "code_verifier": pkceSession.codeVerifier,
            "state": pkceSession.state,
        ]

        let tokenResponse = try await postTokenRequest(body)
        return credentialFromTokenResponse(tokenResponse)
    }

    // MARK: - Refresh

    func refresh(_ credential: CodexCredential) async throws -> CodexCredential {
        let body = [
            "grant_type": "refresh_token",
            "client_id": Self.clientID,
            "refresh_token": credential.refreshToken,
            "scope": Self.scope,
        ]

        let tokenResponse = try await postTokenRequest(body)

        var updated = credentialFromTokenResponse(tokenResponse)
        if updated.refreshToken.isEmpty {
            updated.refreshToken = credential.refreshToken
        }
        return updated
    }

    // MARK: - Keychain Storage

    func saveCredential(_ credential: CodexCredential) throws {
        let data = try JSONEncoder().encode(credential)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CodexAuthError.encodingFailed
        }
        guard KeychainManager.save(account: Self.keychainAccount, password: json) else {
            throw CodexAuthError.keychainSaveFailed
        }
    }

    func loadCredential() throws -> CodexCredential {
        guard let json = KeychainManager.read(account: Self.keychainAccount) else {
            throw CodexAuthError.noStoredCredential
        }
        guard let data = json.data(using: .utf8) else {
            throw CodexAuthError.decodingFailed
        }
        return try JSONDecoder().decode(CodexCredential.self, from: data)
    }

    func deleteCredential() {
        KeychainManager.delete(account: Self.keychainAccount)
    }

    // MARK: - Import from JSON

    func importFromJSON(_ jsonString: String) throws -> CodexCredential {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw CodexAuthError.decodingFailed
        }

        // Try direct Orbit2 format: { "access_token": ..., "refresh_token": ... }
        if let credential = try? JSONDecoder().decode(CodexCredential.self, from: data) {
            try validateCredential(credential)
            return credential
        }

        // Try Codex CLI format: { "tokens": { "access_token": ..., "refresh_token": ... } }
        if let wrapper = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let tokens = wrapper["tokens"] as? [String: Any],
           let tokensData = try? JSONSerialization.data(withJSONObject: tokens),
           var credential = try? JSONDecoder().decode(CodexCredential.self, from: tokensData) {
            if credential.expiresAtEpochMs == 0 {
                credential.expiresAtEpochMs = Int64(Date().timeIntervalSince1970 * 1000) + 3_600_000
            }
            try validateCredential(credential)
            return credential
        }

        throw CodexAuthError.decodingFailed
    }

    private func validateCredential(_ credential: CodexCredential) throws {
        guard !credential.accessToken.isEmpty else {
            throw CodexAuthError.invalidImport("access_token is empty")
        }
        guard !credential.refreshToken.isEmpty else {
            throw CodexAuthError.invalidImport("refresh_token is empty")
        }
    }

    // MARK: - Helpers

    private func postTokenRequest(_ body: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encoded = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        request.httpBody = encoded.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexAuthError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CodexAuthError.tokenExchangeFailed(httpResponse.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexAuthError.decodingFailed
        }

        return json
    }

    private func credentialFromTokenResponse(_ json: [String: Any]) -> CodexCredential {
        let accessToken = json["access_token"] as? String ?? ""
        let refreshToken = json["refresh_token"] as? String ?? ""

        let expiresAtMs: Int64
        if let expiresAt = json["expires_at"] as? Double {
            expiresAtMs = Int64(expiresAt * 1000)
        } else if let expiresIn = json["expires_in"] as? Double {
            expiresAtMs = Int64(Date().timeIntervalSince1970 * 1000) + Int64(expiresIn * 1000)
        } else {
            expiresAtMs = Int64(Date().timeIntervalSince1970 * 1000) + 3_600_000
        }

        return CodexCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAtEpochMs: expiresAtMs,
            accountEmail: json["email"] as? String
        )
    }

    private func generateRandomString(length: Int) -> String {
        let bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .prefix(length)
            .description
    }

    private func computeS256Challenge(_ verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum CodexAuthError: LocalizedError {
    case invalidCallback
    case oauthError(String)
    case missingCode
    case stateMismatch
    case tokenExchangeFailed(Int, String)
    case networkError(String)
    case encodingFailed
    case decodingFailed
    case keychainSaveFailed
    case noStoredCredential
    case expiredCredential
    case invalidImport(String)

    var errorDescription: String? {
        switch self {
        case .invalidCallback: "Invalid callback URL"
        case .oauthError(let msg): "OAuth error: \(msg)"
        case .missingCode: "Authorization code missing"
        case .stateMismatch: "State mismatch — possible CSRF"
        case .tokenExchangeFailed(let code, let body): "Token exchange failed (\(code)): \(body)"
        case .networkError(let msg): "Network error: \(msg)"
        case .encodingFailed: "Failed to encode credential"
        case .decodingFailed: "Failed to decode credential — check JSON format"
        case .keychainSaveFailed: "Failed to save to Keychain"
        case .noStoredCredential: "No stored credential found"
        case .expiredCredential: "Access token expired"
        case .invalidImport(let msg): "Invalid credential: \(msg)"
        }
    }
}
