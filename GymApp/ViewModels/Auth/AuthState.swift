import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthState: ObservableObject {
    static let shared = AuthState()

    @Published var isAuthenticated: Bool = false
    @Published var tokens: AuthService.Tokens?
    @Published var userProfile: UserProfile? = nil
    @Published var gymUser: GymUser? = nil  // Firebase user data
    @Published var currentRole: UserRole = .user {
        didSet {
            UserDefaults.standard.set(currentRole.rawValue, forKey: roleKey)
        }
    }

    private let membershipKey = "membership_exp"
    private let userProfileKey = "user_profile"
    private let roleKey = "current_role"
    private let gymUserKey = "gym_user"

    init() {
        do {
            if let t = try AuthService.shared.restoreSession() {
                self.tokens = t
                self.isAuthenticated = true
            }
        } catch {
            self.tokens = nil
            self.isAuthenticated = false
        }

        // Restore persisted profile if present
        if let data = UserDefaults.standard.data(forKey: userProfileKey) {
            if let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                self.userProfile = profile
            }
        }
        
        // Restore persisted GymUser if present
        if let data = UserDefaults.standard.data(forKey: gymUserKey) {
            if let user = try? JSONDecoder().decode(GymUser.self, from: data) {
                self.gymUser = user
                // Set role based on available roles
                if let roleRaw = UserDefaults.standard.string(forKey: roleKey),
                   let role = UserRole(rawValue: roleRaw),
                   user.roles.contains(role) {
                    self.currentRole = role
                } else {
                    self.currentRole = user.primaryRole
                }
            }
        } else {
            // Restore persisted role if present (fallback)
            if let roleRaw = UserDefaults.standard.string(forKey: roleKey),
               let role = UserRole(rawValue: roleRaw) {
                self.currentRole = role
            }
        }

#if DEBUG
        if let exp = UserDefaults.standard.object(forKey: membershipKey) as? TimeInterval {
            let d = Date(timeIntervalSince1970: exp)
            print("[DEBUG] Loaded membership_exp from UserDefaults = \(exp) -> \(formatDate(d))")
        } else {
            print("[DEBUG] No stored membership_exp")
        }
        print("[DEBUG] Current role: \(currentRole.displayName)")
        if let user = gymUser {
            print("[DEBUG] GymUser loaded: \(user.name), roles: \(user.roles.map { $0.rawValue })")
        }
#endif
    }

    // MARK: - Login

    func signIn(presentationProvider: ASWebAuthenticationPresentationContextProviding) async throws {
        let tokens = try await AuthService.shared.login(presentationContextProvider: presentationProvider)
        self.tokens = tokens
        self.isAuthenticated = true

        // After login, fetch membership_exp from app_metadata or top-level /userinfo and user profile
        await fetchAndStoreMembershipExpAndProfile()
        
        // Sync with Firebase Firestore (no Firebase Auth required with open rules)
        await syncWithFirebase()
    }

    func signOut() {
        do {
            try AuthService.shared.logout()
        } catch {}

        self.tokens = nil
        self.isAuthenticated = false
        self.gymUser = nil
        self.currentRole = .user

        UserDefaults.standard.removeObject(forKey: membershipKey)
        UserDefaults.standard.removeObject(forKey: userProfileKey)
        UserDefaults.standard.removeObject(forKey: gymUserKey)
        UserDefaults.standard.removeObject(forKey: roleKey)
        self.userProfile = nil
    }

    // MARK: - Refresh Session

    func refreshSession() async throws -> AuthService.Tokens {
        guard let stored = try AuthService.shared.restoreSession() else {
            throw AuthService.AuthError.invalidConfiguration
        }
        guard let refresh = stored.refreshToken else {
            throw AuthService.AuthError.invalidTokenResponse
        }

        let newTokens = try await AuthService.shared.refreshTokens(refreshToken: refresh)

        // Save refreshed tokens
        try KeychainHelper.standard.save(newTokens, service: "auth0_tokens", account: "default")

        self.tokens = newTokens
        self.isAuthenticated = true

        // Update membership and profile
        await fetchAndStoreMembershipExpAndProfile()
        
        // Update Firebase
        await syncWithFirebase()

        return newTokens
    }
    
    // MARK: - Firebase Sync
    
    /// Sync user data with Firebase on login/refresh
    private func syncWithFirebase() async {
        guard let tokens = tokens else {
            #if DEBUG
            print("[DEBUG] Cannot sync with Firebase: missing tokens")
            #endif
            return
        }
        
        // Try to get userId from idToken first, then from /userinfo
        var userId: String? = extractAuth0UserId(from: tokens)
        var profile = userProfile
        
        // If no userId from token or no profile, fetch from /userinfo
        if userId == nil || profile == nil {
            do {
                let info = try await AuthService.shared.getUserInfo(accessToken: tokens.accessToken)
                
                // Get sub (userId) from /userinfo response
                if userId == nil, let sub = info["sub"] as? String {
                    userId = sub
                    #if DEBUG
                    print("[DEBUG] Got userId from /userinfo: \(sub)")
                    #endif
                }
                
                // Build profile if needed
                if profile == nil {
                    var newProfile = UserProfile()
                    if let name = info["name"] as? String { newProfile.name = name }
                    if let email = info["email"] as? String { newProfile.email = email }
                    if let given = info["given_name"] as? String { newProfile.givenName = given }
                    if let family = info["family_name"] as? String { newProfile.familyName = family }
                    if let pic = info["picture"] as? String { newProfile.picture = pic }
                    if let nick = info["nickname"] as? String { newProfile.nickname = nick }
                    self.userProfile = newProfile
                    profile = newProfile
                    #if DEBUG
                    print("[DEBUG] Fetched profile for Firebase sync: \(newProfile.name ?? "unknown")")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[DEBUG] Failed to fetch /userinfo for Firebase sync: \(error)")
                #endif
            }
        }
        
        guard let sub = userId, let profile = profile else {
            #if DEBUG
            print("[DEBUG] Cannot sync with Firebase: missing userId or profile")
            #endif
            return
        }
        
        do {
            // Check if user exists in Firebase
            if let existingUser = try await FirebaseService.shared.getUser(auth0UserId: sub) {
                // User exists - update last login
                try await FirebaseService.shared.updateLastLogin(userId: sub)
                self.gymUser = existingUser
                
                // Set current role to user's primary role if not already set
                if !existingUser.roles.contains(currentRole) {
                    self.currentRole = existingUser.primaryRole
                }
                
                #if DEBUG
                print("[DEBUG] Existing user loaded from Firebase: \(existingUser.name)")
                #endif
            } else {
                // Create new user in Firebase
                let newUser = try await FirebaseService.shared.createUser(
                    auth0UserId: sub,
                    name: profile.name ?? "Usuario",
                    email: profile.email,
                    nickname: profile.nickname,
                    picture: profile.picture
                )
                self.gymUser = newUser
                self.currentRole = .user
                
                #if DEBUG
                print("[DEBUG] New user created in Firebase: \(newUser.name)")
                #endif
            }
            
            // Persist GymUser locally
            if let user = self.gymUser, let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: gymUserKey)
            }
            
        } catch {
            #if DEBUG
            print("[DEBUG] Firebase sync error: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Extract Auth0 user ID from tokens (the 'sub' claim from ID token)
    private func extractAuth0UserId(from tokens: AuthService.Tokens) -> String? {
        guard let idToken = tokens.idToken else { return nil }
        
        // Decode JWT to get 'sub' claim
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        var base64 = String(parts[1])
        // Pad base64 if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            return nil
        }
        
        return sub
    }

    // MARK: - Fetch Membership and Profile

    /// Fetch membership_exp (from app_metadata or top-level /userinfo) and store it; also extract user profile fields
    private func fetchAndStoreMembershipExpAndProfile() async {
        guard let access = tokens?.accessToken else { return }

        do {
            // Get the full /userinfo response (may include app_metadata and top-level membership_exp)
            let info = try await AuthService.shared.getUserInfo(accessToken: access)
#if DEBUG
            print("[DEBUG] /userinfo full response in AuthState: \(info)")
#endif

            // Extract and persist membership_exp: prefer top-level, then app_metadata, then namespaced keys
            if let top = info["membership_exp"], let val = toTimeInterval(top) {
                persistMembershipValue(val)
#if DEBUG
                print("[DEBUG] membership_exp read from /userinfo top-level = \(val) -> \(formatDate(Date(timeIntervalSince1970: val)))")
#endif
            } else if let appMeta = info["app_metadata"] as? [String: Any], let val = parseMembershipValue(from: appMeta) {
                persistMembershipValue(val)
#if DEBUG
                print("[DEBUG] membership_exp read from app_metadata = \(val) -> \(formatDate(Date(timeIntervalSince1970: val)))")
#endif
            } else {
                // namespaced key search across top-level
                var found = false
                for (k, v) in info {
                    if k.lowercased().contains("membership_exp") {
                        if let val = toTimeInterval(v) {
                            persistMembershipValue(val)
#if DEBUG
                            print("[DEBUG] membership_exp read from namespaced key \(k) = \(val) -> \(formatDate(Date(timeIntervalSince1970: val)))")
#endif
                            found = true
                            break
                        }
                    }
                }
                if !found {
#if DEBUG
                    print("[DEBUG] membership_exp NOT FOUND in /userinfo: info keys=\(Array(info.keys))")
#endif
                }
            }

            // Extract user profile fields and persist
            var profile = UserProfile()
            if let name = info["name"] as? String { profile.name = name }
            if let email = info["email"] as? String { profile.email = email }
            if let given = info["given_name"] as? String { profile.givenName = given }
            if let family = info["family_name"] as? String { profile.familyName = family }
            if let pic = info["picture"] as? String { profile.picture = pic }
            if let nick = info["nickname"] as? String { profile.nickname = nick }

            self.userProfile = profile
            persistUserProfile(profile)

        } catch {
#if DEBUG
            print("[DEBUG] Failed to fetch /userinfo: \(error.localizedDescription)")
#endif
        }
    }

    private func parseMembershipValue(from dict: [String: Any]) -> TimeInterval? {
        if let v = dict["membership_exp"] {
            return toTimeInterval(v)
        }
        // namespaced keys inside the dict
        for (k, v) in dict {
            if k.lowercased().contains("membership_exp") {
                return toTimeInterval(v)
            }
        }
        return nil
    }

    private func toTimeInterval(_ value: Any) -> TimeInterval? {
        if let d = value as? TimeInterval { return d }
        if let i = value as? Int { return TimeInterval(i) }
        if let d = value as? Double { return TimeInterval(d) }
        if let s = value as? String, let td = TimeInterval(s) { return td }
        return nil
    }

    private func persistMembershipValue(_ val: TimeInterval) {
        UserDefaults.standard.set(val, forKey: membershipKey)
    }

    private func persistUserProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
    }

    // MARK: - Helpers

    /// Returns membership expiry date (only from UserDefaults)
    var membershipExpiry: Date? {
        if let exp = UserDefaults.standard.object(forKey: membershipKey) as? TimeInterval {
            return Date(timeIntervalSince1970: exp)
        }
        return nil
    }

    var membershipExpiryString: String? {
        if let exp = membershipExpiry {
            return formatDate(exp)
        }
        return nil
    }

    var membershipStatus: String {
        if let exp = membershipExpiry {
            return exp > Date() ? "Membresía Activa" : "Membresía Expirada"
        }
        return "Sin información de membresía"
    }
    
    /// Check if current user can switch roles
    var canSwitchRoles: Bool {
        gymUser?.hasMultipleRoles ?? false
    }

    // MARK: - User Profile model
    struct UserProfile: Codable {
        var name: String? = nil
        var email: String? = nil
        var givenName: String? = nil
        var familyName: String? = nil
        var picture: String? = nil
        var nickname: String? = nil
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: date)
    }
}
