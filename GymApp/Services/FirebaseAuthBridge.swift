//
//  FirebaseAuthBridge.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import FirebaseAuth

/// Bridge between Auth0 authentication and Firebase Authentication
/// Handles custom token exchange for Firestore security rules
final class FirebaseAuthBridge {
    static let shared = FirebaseAuthBridge()
    
    /// Your Cloud Function URL for token exchange
    /// Replace with your deployed function URL
    private let tokenExchangeURL = "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/createFirebaseToken"
    
    private init() {}
    
    // MARK: - Sign In with Custom Token
    
    /// Sign into Firebase using a custom token from your backend
    func signInWithCustomToken(_ token: String) async throws {
        try await Auth.auth().signIn(withCustomToken: token)
        
        #if DEBUG
        print("[FirebaseAuthBridge] Signed into Firebase with custom token")
        if let user = Auth.auth().currentUser {
            print("[FirebaseAuthBridge] Firebase UID: \(user.uid)")
        }
        #endif
    }
    
    /// Exchange Auth0 token for Firebase custom token
    /// Calls your Cloud Function backend
    func exchangeAuth0TokenForFirebaseToken(
        auth0Token: String,
        auth0UserId: String,
        currentRole: UserRole
    ) async throws -> String {
        guard let url = URL(string: tokenExchangeURL) else {
            throw FirebaseAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth0Token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "auth0UserId": auth0UserId,
            "activeRole": currentRole.rawValue
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FirebaseAuthError.tokenExchangeFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let firebaseToken = json["token"] as? String else {
            throw FirebaseAuthError.invalidTokenResponse
        }
        
        return firebaseToken
    }
    
    /// Complete authentication flow: Sign into Firebase
    /// Using anonymous auth for development
    func authenticateWithFirebase(
        auth0Token: String,
        auth0UserId: String,
        currentRole: UserRole
    ) async throws {
        // Use anonymous auth for development
        // This allows Firestore access with simple rules
        try await signInAnonymously()
    }
    
    /// Sign in anonymously to Firebase
    /// This allows Firestore access with authenticated rules
    func signInAnonymously() async throws {
        // Check if already signed in
        if let currentUser = Auth.auth().currentUser {
            #if DEBUG
            print("[FirebaseAuthBridge] Already signed in: \(currentUser.uid)")
            #endif
            return
        }
        
        // Sign in anonymously
        let result = try await Auth.auth().signInAnonymously()
        
        #if DEBUG
        print("[FirebaseAuthBridge] ✅ Signed in anonymously: \(result.user.uid)")
        #endif
    }
    
    /// Development workaround: Sign in anonymously
    /// This allows Firestore access but without proper role-based rules
    private func signInAnonymouslyForDevelopment(auth0UserId: String) async throws {
        // Check if already signed in
        if let currentUser = Auth.auth().currentUser {
            #if DEBUG
            print("[FirebaseAuthBridge] Already signed in: \(currentUser.uid)")
            #endif
            return
        }
        
        // Sign in anonymously for development
        let result = try await Auth.auth().signInAnonymously()
        
        #if DEBUG
        print("[FirebaseAuthBridge] Signed in anonymously: \(result.user.uid)")
        print("[FirebaseAuthBridge] ⚠️ For production, deploy the Cloud Function and configure tokenExchangeURL")
        #endif
    }
    
    /// Sign out from Firebase
    func signOut() {
        do {
            try Auth.auth().signOut()
            #if DEBUG
            print("[FirebaseAuthBridge] Signed out from Firebase")
            #endif
        } catch {
            #if DEBUG
            print("[FirebaseAuthBridge] Sign out error: \(error)")
            #endif
        }
    }
    
    /// Check if signed into Firebase
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }
    
    /// Current Firebase user
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
}

// MARK: - Errors

enum FirebaseAuthError: LocalizedError {
    case invalidURL
    case tokenExchangeFailed
    case invalidTokenResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de intercambio de token inválida"
        case .tokenExchangeFailed:
            return "Error al intercambiar token"
        case .invalidTokenResponse:
            return "Respuesta de token inválida"
        }
    }
}
