//
//  QRTokenService.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import CryptoKit
import Combine

/// Service for generating and validating secure QR tokens
final class QRTokenService: ObservableObject {
    static let shared = QRTokenService()
    
    // MARK: - Published Properties
    
    @Published private(set) var currentToken: String = ""
    @Published private(set) var secondsUntilRefresh: Int = 30
    
    // MARK: - Private Properties
    
    /// Secret key for HMAC signing (in production, use secure storage)
    private let secretKey = "GymApp_QR_Secret_Key_2024_Secure!"
    
    /// Token validity period in seconds
    private let tokenValiditySeconds: Int = 30
    
    /// Tolerance for timestamp validation (±60 seconds)
    private let timestampTolerance: TimeInterval = 60
    
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var currentUserId: String?
    
    private init() {}
    
    // MARK: - Token Generation
    
    /// Start generating tokens for a user
    func startGenerating(for userId: String) {
        currentUserId = userId
        generateNewToken()
        startTimers()
    }
    
    /// Stop generating tokens
    func stopGenerating() {
        timer?.invalidate()
        countdownTimer?.invalidate()
        timer = nil
        countdownTimer = nil
        currentUserId = nil
        currentToken = ""
        secondsUntilRefresh = tokenValiditySeconds
    }
    
    /// Generate a new token immediately
    private func generateNewToken() {
        guard let userId = currentUserId else { return }
        
        let token = createToken(userId: userId)
        DispatchQueue.main.async {
            self.currentToken = token
            self.secondsUntilRefresh = self.tokenValiditySeconds
        }
    }
    
    /// Create a signed token
    private func createToken(userId: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = generateNonce(length: 16)
        
        // Create signature
        let dataToSign = "\(userId)\(timestamp)\(nonce)"
        let signature = hmacSHA256(data: dataToSign, key: secretKey)
        
        // Create token payload
        let payload: [String: Any] = [
            "uid": userId,
            "ts": timestamp,
            "nonce": nonce,
            "sig": signature
        ]
        
        // Convert to JSON then Base64
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlSafeBase64) else {
            return ""
        }
        
        return base64
    }
    
    /// Generate random nonce
    private func generateNonce(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    
    /// HMAC-SHA256 signature
    private func hmacSHA256(data: String, key: String) -> String {
        let keyData = SymmetricKey(data: Data(key.utf8))
        let dataBytes = Data(data.utf8)
        let signature = HMAC<SHA256>.authenticationCode(for: dataBytes, using: keyData)
        return Data(signature).base64EncodedString()
    }
    
    // MARK: - Timers
    
    private func startTimers() {
        // Main timer: regenerate token every 30 seconds
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(tokenValiditySeconds), repeats: true) { [weak self] _ in
            self?.generateNewToken()
        }
        
        // Countdown timer: update seconds every second
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.secondsUntilRefresh > 0 {
                    self.secondsUntilRefresh -= 1
                }
            }
        }
    }
    
    // MARK: - Token Validation (for Staff)
    
    /// Validate a scanned token
    func validateToken(_ token: String) -> TokenValidationResult {
        // Decode Base64
        guard let decodedData = Data(base64Encoded: token.removingPercentEncoding ?? token) ??
                                Data(base64Encoded: token) else {
            return .invalid(reason: "Código no válido")
        }
        
        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
              let userId = json["uid"] as? String,
              let timestamp = json["ts"] as? Int,
              let nonce = json["nonce"] as? String,
              let signature = json["sig"] as? String else {
            return .invalid(reason: "Formato inválido")
        }
        
        // Verify signature
        let expectedSignature = hmacSHA256(data: "\(userId)\(timestamp)\(nonce)", key: secretKey)
        guard signature == expectedSignature else {
            return .invalid(reason: "Firma inválida")
        }
        
        // Check timestamp (±60 seconds tolerance)
        let tokenTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()
        let timeDiff = abs(now.timeIntervalSince(tokenTime))
        
        guard timeDiff <= timestampTolerance else {
            return .expired(reason: "Código expirado")
        }
        
        return .valid(userId: userId)
    }
}

// MARK: - Validation Result

enum TokenValidationResult {
    case valid(userId: String)
    case invalid(reason: String)
    case expired(reason: String)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    var userId: String? {
        if case .valid(let id) = self { return id }
        return nil
    }
    
    var errorMessage: String? {
        switch self {
        case .valid: return nil
        case .invalid(let reason): return reason
        case .expired(let reason): return reason
        }
    }
}

// MARK: - Character Set Extension

extension CharacterSet {
    static let urlSafeBase64 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=+/")
}
