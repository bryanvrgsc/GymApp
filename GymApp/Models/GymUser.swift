//
//  GymUser.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import FirebaseFirestore

/// Complete user model matching Firebase structure
struct GymUser: Codable, Identifiable {
    let id: String  // Auth0 UserID
    var name: String
    var email: String?
    var nickname: String?
    var picture: String?
    
    // Roles - array of roles, default is ["user"]
    var roles: [UserRole]
    
    // Membership (new structure)
    var membership: Membership?
    
    // Legacy membership fields (for backward compatibility)
    var membershipExp: Date?
    var membershipStartDate: Date?
    var consecutiveMonths: Int
    var subscriberSince: Date?
    
    // Badge
    var currentBadge: BadgeTier?
    
    // Preferences
    var favoriteEquipment: [String]
    var favoriteActivities: [String]
    var notificationsEnabled: Bool
    
    // Timestamps
    var createdAt: Date
    var lastLogin: Date
    
    // Computed properties
    var isActive: Bool {
        // Check new membership object first, then fall back to legacy
        if let membership = membership {
            return membership.isActive
        }
        guard let exp = membershipExp else { return false }
        return exp > Date()
    }
    
    /// Check if user has a specific role
    func hasRole(_ role: UserRole) -> Bool {
        roles.contains(role)
    }
    
    /// Check if user has multiple roles (shows role switcher)
    var hasMultipleRoles: Bool {
        roles.count > 1
    }
    
    /// Get the highest priority role for default selection
    var primaryRole: UserRole {
        // Priority: admin > staff > user
        if roles.contains(.admin) { return .admin }
        if roles.contains(.staff) { return .staff }
        return .user
    }
    
    // MARK: - Initializers
    
    init(
        id: String,
        name: String,
        email: String? = nil,
        nickname: String? = nil,
        picture: String? = nil,
        roles: [UserRole] = [.user],
        membershipExp: Date? = nil,
        membershipStartDate: Date? = nil,
        consecutiveMonths: Int = 0,
        subscriberSince: Date? = nil,
        currentBadge: BadgeTier? = nil,
        favoriteEquipment: [String] = [],
        favoriteActivities: [String] = [],
        notificationsEnabled: Bool = true,
        createdAt: Date = Date(),
        lastLogin: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.nickname = nickname
        self.picture = picture
        self.roles = roles
        self.membershipExp = membershipExp
        self.membershipStartDate = membershipStartDate
        self.consecutiveMonths = consecutiveMonths
        self.subscriberSince = subscriberSince
        self.currentBadge = currentBadge
        self.favoriteEquipment = favoriteEquipment
        self.favoriteActivities = favoriteActivities
        self.notificationsEnabled = notificationsEnabled
        self.createdAt = createdAt
        self.lastLogin = lastLogin
    }
    
    /// Initialize from Firestore document data
    init?(from data: [String: Any], id: String) {
        self.id = id
        
        guard let name = data["name"] as? String else { return nil }
        self.name = name
        
        self.email = data["email"] as? String
        self.nickname = data["nickname"] as? String
        self.picture = data["picture"] as? String
        
        // Parse roles array
        if let rolesArray = data["roles"] as? [String] {
            self.roles = rolesArray.compactMap { UserRole(rawValue: $0) }
            if self.roles.isEmpty { self.roles = [.user] }
        } else {
            self.roles = [.user]
        }
        
        // Parse membership object (new structure)
        if let membershipData = data["membership"] as? [String: Any] {
            self.membership = Membership(from: membershipData)
        }
        
        // Parse timestamps
        if let createdTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let lastLoginTimestamp = data["lastLogin"] as? Timestamp {
            self.lastLogin = lastLoginTimestamp.dateValue()
        } else {
            self.lastLogin = Date()
        }
        
        // Legacy membership fields (for backward compatibility)
        if let exp = data["membershipExp"] as? Timestamp {
            self.membershipExp = exp.dateValue()
        }
        if let start = data["membershipStartDate"] as? Timestamp {
            self.membershipStartDate = start.dateValue()
        }
        
        self.consecutiveMonths = data["consecutiveMonths"] as? Int ?? 0
        
        if let since = data["subscriberSince"] as? Timestamp {
            self.subscriberSince = since.dateValue()
        }
        
        if let badgeRaw = data["currentBadge"] as? String {
            self.currentBadge = BadgeTier(rawValue: badgeRaw)
        }
        
        self.favoriteEquipment = data["favoriteEquipment"] as? [String] ?? []
        self.favoriteActivities = data["favoriteActivities"] as? [String] ?? []
        self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? true
    }
    
    /// Convert to dictionary for Firestore
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "roles": roles.map { $0.rawValue },
            "consecutiveMonths": consecutiveMonths,
            "favoriteEquipment": favoriteEquipment,
            "favoriteActivities": favoriteActivities,
            "notificationsEnabled": notificationsEnabled,
            "createdAt": Timestamp(date: createdAt),
            "lastLogin": Timestamp(date: lastLogin)
        ]
        
        if let email = email { dict["email"] = email }
        if let nickname = nickname { dict["nickname"] = nickname }
        if let picture = picture { dict["picture"] = picture }
        if let exp = membershipExp { dict["membershipExp"] = Timestamp(date: exp) }
        if let start = membershipStartDate { dict["membershipStartDate"] = Timestamp(date: start) }
        if let since = subscriberSince { dict["subscriberSince"] = Timestamp(date: since) }
        if let badge = currentBadge { dict["currentBadge"] = badge.rawValue }
        
        return dict
    }
}
