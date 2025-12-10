//
//  AuthService.swift
//  GymApp
//
//  Created by Bryan Vargas on 14/11/25.
//

import Foundation
import AuthenticationServices
import CryptoKit

final class AuthService: NSObject {
    static let shared = AuthService()

    // TODO: Replace these with your Auth0 app values and configure the redirect URI in the project
    private let clientId = ""
    private let domain = "" // e.g. dev-xxxxx.us.auth0.com
    private let redirectURI = "com.gymapp://auth" // register as URL Type in Info.plist
    private let audience: String? = nil // optional

    private var currentSession: ASWebAuthenticationSession?
    private var codeVerifier: String?

    // Stored tokens (simple Keychain wrapper used below)
    struct Tokens: Codable {
        let accessToken: String
        let idToken: String?
        let refreshToken: String?
        let expiresIn: Int?
    }

    // MARK: - Public API

    func isConfigured() -> Bool {
        return clientId != "YOUR_AUTH0_CLIENT_ID" && domain != "YOUR_AUTH0_DOMAIN"
    }

    func login(presentationContextProvider: ASWebAuthenticationPresentationContextProviding) async throws -> Tokens {
        // Generate PKCE values
        let verifier = Self.generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/authorize"

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email offline_access"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        if let aud = audience {
            queryItems.append(URLQueryItem(name: "audience", value: aud))
        }
        components.queryItems = queryItems

        guard let authURL = components.url else {
            throw AuthError.invalidConfiguration
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: Self.callbackScheme(from: redirectURI)) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: AuthError.missingCode)
                    return
                }

                Task {
                    do {
                        let tokens = try await self.exchangeCodeForToken(code: code)
                        try KeychainHelper.standard.save(tokens, service: "auth0_tokens", account: "default")
                        continuation.resume(returning: tokens)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false
            self.currentSession = session
            session.start()
        }
    }

    func logout() throws {
        try KeychainHelper.standard.delete(service: "auth0_tokens", account: "default")
    }

    func restoreSession() throws -> Tokens? {
        return try KeychainHelper.standard.read(Tokens.self, service: "auth0_tokens", account: "default")
    }

    // MARK: - Token exchange

    private func exchangeCodeForToken(code: String) async throws -> Tokens {
        guard let verifier = codeVerifier else { throw AuthError.missingCodeVerifier }

        let tokenURL = URL(string: "https://\(domain)/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ]

        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(msg)
        }

        let decoder = JSONDecoder()
        let json = try decoder.decode([String: AnyCodable].self, from: responseData)

        guard let access = json["access_token"]?.value as? String else { throw AuthError.invalidTokenResponse }
        let idt = json["id_token"]?.value as? String
        let refresh = json["refresh_token"]?.value as? String
        let expires = json["expires_in"]?.value as? Int

        return Tokens(accessToken: access, idToken: idt, refreshToken: refresh, expiresIn: expires)
    }

    func refreshTokens(refreshToken: String) async throws -> Tokens {
        let tokenURL = URL(string: "https://\(domain)/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken
        ]

        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(msg)
        }

        let decoder = JSONDecoder()
        let json = try decoder.decode([String: AnyCodable].self, from: responseData)

        guard let access = json["access_token"]?.value as? String else { throw AuthError.invalidTokenResponse }
        let idt = json["id_token"]?.value as? String
        let refresh = json["refresh_token"]?.value as? String ?? refreshToken // sometimes refresh token not returned
        let expires = json["expires_in"]?.value as? Int

        return Tokens(accessToken: access, idToken: idt, refreshToken: refresh, expiresIn: expires)
    }

    /// Call the /userinfo endpoint with an access token to retrieve the latest profile claims.
    /// Returns only the `app_metadata` dictionary from the response (empty if not present).
    func getUserInfo(accessToken: String) async throws -> [String: Any] {
        let url = URL(string: "https://\(domain)/userinfo")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenExchangeFailed(msg)
        }

        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else { throw AuthError.invalidTokenResponse }
#if DEBUG
        print("[DEBUG] /userinfo response: \(dict)")
#endif
        // Return the full dictionary (including app_metadata) so callers can inspect top-level claims and nested app_metadata.
        return dict
    }

    /// Convenience: fetch only `app_metadata` from /userinfo (empty dict if not present)
    func getAppMetadata(accessToken: String) async throws -> [String: Any] {
        let dict = try await getUserInfo(accessToken: accessToken)
        if let appMeta = dict["app_metadata"] as? [String: Any] {
            return appMeta
        }
        return [:]
    }

    // MARK: - Helpers

    enum AuthError: Error {
        case invalidConfiguration
        case missingCode
        case missingCodeVerifier
        case tokenExchangeFailed(String)
        case invalidTokenResponse
    }

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private static func callbackScheme(from redirect: String) -> String? {
        guard let u = URL(string: redirect) else { return nil }
        return u.scheme
    }
}

// MARK: - Helpers and small utilities

fileprivate extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// AnyCodable for JSON parsing without external deps
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v; return }
        if let v = try? container.decode(Int.self) { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([String: AnyCodable].self) {
            value = v.mapValues { $0.value }; return
        }
        if let v = try? container.decode([AnyCodable].self) {
            value = v.map { $0.value }; return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: Any]: try container.encode(v.mapValues { AnyCodable($0) })
        case let v as [Any]: try container.encode(v.map { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - Keychain helper

final class KeychainHelper {
    static let standard = KeychainHelper()

    func save<T: Codable>(_ item: T, service: String, account: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }
    }

    func read<T: Codable>(_ type: T.Type, service: String, account: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status: status) }

        guard let data = item as? Data else { return nil }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandled(status: status) }
    }

    enum KeychainError: Error {
        case unhandled(status: OSStatus)
    }
}
