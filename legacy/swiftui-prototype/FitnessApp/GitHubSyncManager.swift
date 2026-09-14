import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftUI
import UIKit

private final class KeychainStore {
    private let service = "com.wu9o.fitnessapp"

    func save(_ value: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        let item = query.merging([kSecValueData as String: value]) { _, new in new }
        SecItemAdd(item as CFDictionary, nil)
    }

    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
}

@MainActor
final class GitHubSyncManager: NSObject, ObservableObject {
    static let shared = GitHubSyncManager()

    @Published private(set) var username: String?
    @Published private(set) var status = "尚未连接"
    @Published var repository = "wu9o/fitness-app-data"

    private let keychain = KeychainStore()
    private var authSession: ASWebAuthenticationSession?
    private var verifier = ""
    private var state = ""
    private nonisolated(unsafe) var anchor: ASPresentationAnchor?

    private var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GitHubOAuthClientID") as? String ?? "YOUR_GITHUB_OAUTH_CLIENT_ID"
    }

    private var token: String? {
        guard let data = keychain.load(key: "github.accessToken") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    override init() {
        super.init()
        username = UserDefaults.standard.string(forKey: "github.username")
        if username != nil { status = "已连接私密仓库" }
    }

    func connect() {
        guard clientID != "YOUR_GITHUB_OAUTH_CLIENT_ID" else {
            status = "请先配置 GitHub OAuth Client ID"
            return
        }

        verifier = Self.randomString(length: 48)
        let challenge = Self.base64URL(SHA256.hash(data: Data(verifier.utf8)))
        state = Self.randomString(length: 32)
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "movelog://oauth/callback"),
            URLQueryItem(name: "scope", value: "repo read:user user:email"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components.url else { return }
        guard let window = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })) else {
            status = "无法找到当前窗口"
            return
        }
        anchor = window
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "movelog") { [weak self] callback, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.status = error.localizedDescription
                    return
                }
                guard let callback,
                      let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                      query.first(where: { $0.name == "state" })?.value == self.state,
                      let code = query.first(where: { $0.name == "code" })?.value else {
                    self.status = "GitHub 授权未完成"
                    return
                }
                await self.exchange(code: code)
            }
        }
        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
        status = "等待 GitHub 授权"
    }

    func uploadEncryptedBackup(sleep: SleepSummary, routes: [SavedRoute]) async {
        guard let token else {
            status = "请先连接 GitHub"
            return
        }
        do {
            let payload = BackupPayload(schemaVersion: 1, createdAt: Date(), sleep: sleep, routes: routes)
            let raw = try JSONEncoder().encode(payload)
            let key = try encryptionKey()
            let sealed = try AES.GCM.seal(raw, using: key)
            guard let combined = sealed.combined else { throw SyncError.encryptionFailed }
            try await put(contents: combined.base64EncodedString(), token: token)
            status = "已完成加密备份"
        } catch {
            status = error.localizedDescription
        }
    }

    private func exchange(code: String) async {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "client_id": clientID,
            "code": code,
            "redirect_uri": "movelog://oauth/callback",
            "code_verifier": verifier
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw SyncError.authorizationFailed }
            let result = try JSONDecoder().decode(TokenResponse.self, from: data)
            keychain.save(Data(result.accessToken.utf8), key: "github.accessToken")
            let user = try await getUser(token: result.accessToken)
            username = user.login
            UserDefaults.standard.set(user.login, forKey: "github.username")
            status = "已连接私密仓库"
        } catch {
            status = error.localizedDescription
        }
    }

    private func getUser(token: String) async throws -> UserResponse {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw SyncError.authorizationFailed }
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }

    private func put(contents: String, token: String) async throws {
        let parts = repository.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw SyncError.invalidRepository }
        let path = "backup/latest.enc"
        let url = URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = ["message": "backup: encrypted MoveLog data", "content": contents, "branch": "main"]
        if let sha = try? await existingSHA(url: url, token: token) { body["sha"] = sha }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw SyncError.uploadFailed }
    }

    private func existingSHA(url: URL, token: String) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw SyncError.notFound }
        let result = try JSONDecoder().decode(ContentResponse.self, from: data)
        return result.sha
    }

    private func encryptionKey() throws -> SymmetricKey {
        if let data = keychain.load(key: "backup.encryptionKey") {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        keychain.save(key.withUnsafeBytes { Data($0) }, key: "backup.encryptionKey")
        return key
    }

    private static func randomString(length: Int) -> String {
        String((0..<length).map { _ in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
    }

    private static func base64URL(_ digest: SHA256.Digest) -> String {
        Data(digest).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private struct BackupPayload: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let sleep: SleepSummary
    let routes: [SavedRoute]
}

extension GitHubSyncManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor!
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
}

private struct UserResponse: Decodable { let login: String }
private struct ContentResponse: Decodable { let sha: String }

private enum SyncError: LocalizedError {
    case authorizationFailed, uploadFailed, invalidRepository, notFound, encryptionFailed
    var errorDescription: String? {
        switch self {
        case .authorizationFailed: "GitHub 授权失败"
        case .uploadFailed: "加密备份上传失败"
        case .invalidRepository: "仓库格式应为 owner/name"
        case .notFound: "备份文件尚不存在"
        case .encryptionFailed: "数据加密失败"
        }
    }
}
