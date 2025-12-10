//
//  Badge.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import SwiftUI

/// Badge tiers based on consecutive membership months
enum BadgeTier: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    case diamond = "diamond"
    case emerald = "emerald"
    case ruby = "ruby"
    case opal = "opal"
    
    /// Months required to earn this badge
    var requiredMonths: Int {
        switch self {
        case .bronze: return 1
        case .silver: return 3
        case .gold: return 6
        case .platinum: return 12
        case .diamond: return 24
        case .emerald: return 36
        case .ruby: return 60
        case .opal: return 72
        }
    }
    
    /// Display name in Spanish
    var displayName: String {
        switch self {
        case .bronze: return "Bronce"
        case .silver: return "Plata"
        case .gold: return "Oro"
        case .platinum: return "Platino"
        case .diamond: return "Diamante"
        case .emerald: return "Esmeralda"
        case .ruby: return "Rubí"
        case .opal: return "Ópalo"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .platinum: return "star.circle.fill"
        case .diamond: return "diamond.fill"
        case .emerald: return "leaf.fill"
        case .ruby: return "flame.fill"
        case .opal: return "sparkles"
        }
    }
    
    /// Badge color
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.90, green: 0.89, blue: 0.88)
        case .diamond: return Color(red: 0.73, green: 0.87, blue: 0.98)
        case .emerald: return Color(red: 0.31, green: 0.78, blue: 0.47)
        case .ruby: return Color(red: 0.88, green: 0.07, blue: 0.37)
        case .opal: return LinearGradient.opalGradient.first ?? .white
        }
    }
    
    /// Gradient colors for premium effect
    var gradientColors: [Color] {
        switch self {
        case .bronze:
            return [Color(red: 0.80, green: 0.50, blue: 0.20), Color(red: 0.60, green: 0.35, blue: 0.15)]
        case .silver:
            return [Color(red: 0.85, green: 0.85, blue: 0.87), Color(red: 0.65, green: 0.65, blue: 0.67)]
        case .gold:
            return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.13)]
        case .platinum:
            return [Color(red: 0.90, green: 0.89, blue: 0.88), Color(red: 0.70, green: 0.70, blue: 0.72)]
        case .diamond:
            return [Color(red: 0.73, green: 0.87, blue: 0.98), Color(red: 0.53, green: 0.75, blue: 0.92)]
        case .emerald:
            return [Color(red: 0.31, green: 0.78, blue: 0.47), Color(red: 0.0, green: 0.55, blue: 0.27)]
        case .ruby:
            return [Color(red: 0.88, green: 0.07, blue: 0.37), Color(red: 0.70, green: 0.05, blue: 0.25)]
        case .opal:
            return [
                Color(red: 1.0, green: 0.8, blue: 0.9),
                Color(red: 0.8, green: 0.9, blue: 1.0),
                Color(red: 0.9, green: 1.0, blue: 0.85)
            ]
        }
    }
    
    /// Get the appropriate badge for given consecutive months
    static func forMonths(_ months: Int) -> BadgeTier? {
        // Return highest achieved tier
        for tier in allCases.reversed() {
            if months >= tier.requiredMonths {
                return tier
            }
        }
        return nil
    }
    
    /// Next tier after this one
    var nextTier: BadgeTier? {
        guard let currentIndex = BadgeTier.allCases.firstIndex(of: self) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < BadgeTier.allCases.count else { return nil }
        return BadgeTier.allCases[nextIndex]
    }
    
    /// Months remaining to next tier
    func monthsToNextTier(currentMonths: Int) -> Int? {
        guard let next = nextTier else { return nil }
        return next.requiredMonths - currentMonths
    }
}

// MARK: - Gradient Extension

extension LinearGradient {
    static var opalGradient: [Color] {
        [
            Color(red: 1.0, green: 0.8, blue: 0.9),
            Color(red: 0.8, green: 0.9, blue: 1.0),
            Color(red: 0.9, green: 1.0, blue: 0.85)
        ]
    }
}

// MARK: - Badge Model

struct Badge: Codable, Identifiable {
    let id: String
    let tier: BadgeTier
    let earnedDate: Date
    let isActive: Bool
    
    init(id: String = UUID().uuidString, tier: BadgeTier, earnedDate: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.tier = tier
        self.earnedDate = earnedDate
        self.isActive = isActive
    }
}
