//
//  UserRole.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation

/// User roles with different permissions and tab configurations
enum UserRole: String, Codable, CaseIterable {
    case user = "user"
    case staff = "staff"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .user: return "Usuario"
        case .staff: return "Staff"
        case .admin: return "Administrador"
        }
    }
    
    var iconName: String {
        switch self {
        case .user: return "person.fill"
        case .staff: return "person.2.fill"
        case .admin: return "crown.fill"
        }
    }
}
